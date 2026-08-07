#!/usr/bin/env python3
"""Emit visible desktop applications as a small JSON list for the QML launcher."""

from __future__ import annotations

import configparser
import json
import os
from pathlib import Path


def data_directories() -> list[Path]:
    home = Path.home()
    user_data = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    system_data = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    directories = [user_data]
    directories.extend(Path(directory) for directory in system_data.split(":") if directory)

    # Flatpak exports use the same desktop-file format but live outside the
    # standard XDG roots on many distributions.
    directories.extend([
        home / ".local/share/flatpak/exports/share",
        Path("/var/lib/flatpak/exports/share"),
    ])
    return directories


def desktop_id(applications_dir: Path, desktop_file: Path) -> str:
    return str(desktop_file.relative_to(applications_dir)).replace("/", "-")


def current_desktops() -> set[str]:
    return {entry for entry in os.environ.get("XDG_CURRENT_DESKTOP", "").split(":") if entry}


def is_visible(entry: configparser.SectionProxy, desktops: set[str]) -> bool:
    if entry.get("Type", "Application") != "Application":
        return False
    if entry.getboolean("Hidden", fallback=False) or entry.getboolean("NoDisplay", fallback=False):
        return False
    if not entry.get("Exec", fallback="") and not entry.getboolean("DBusActivatable", fallback=False):
        return False

    only_show_in = {value for value in entry.get("OnlyShowIn", "").split(";") if value}
    not_show_in = {value for value in entry.get("NotShowIn", "").split(";") if value}
    if only_show_in and not desktops.intersection(only_show_in):
        return False
    return not desktops.intersection(not_show_in)


def read_entry(path: Path, identifier: str, desktops: set[str]) -> dict[str, str] | None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
        entry = parser["Desktop Entry"]
    except (OSError, UnicodeError, KeyError, configparser.Error):
        return None

    if not is_visible(entry, desktops):
        return None

    return {
        "id": identifier,
        "name": entry.get("Name", path.stem),
        "genericName": entry.get("GenericName", ""),
        "comment": entry.get("Comment", ""),
        "icon": entry.get("Icon", "application-x-executable"),
        "keywords": entry.get("Keywords", ""),
    }


def main() -> None:
    applications: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    desktops = current_desktops()

    # Earlier XDG roots take precedence. A Hidden entry therefore correctly
    # masks the system entry with the same desktop-file ID.
    for data_dir in data_directories():
        applications_dir = data_dir / "applications"
        if not applications_dir.is_dir():
            continue
        for desktop_file in applications_dir.rglob("*.desktop"):
            identifier = desktop_id(applications_dir, desktop_file)
            if identifier in seen_ids:
                continue
            seen_ids.add(identifier)
            application = read_entry(desktop_file, identifier, desktops)
            if application:
                applications.append(application)

    applications.sort(key=lambda application: application["name"].casefold())
    print(json.dumps(applications, ensure_ascii=False))


if __name__ == "__main__":
    main()
