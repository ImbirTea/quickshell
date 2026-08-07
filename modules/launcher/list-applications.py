#!/usr/bin/env python3
"""Emit visible desktop applications as a small JSON list for the QML launcher."""

from __future__ import annotations

import configparser
import json
import os
from functools import cache
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


ICON_EXTENSIONS = (".svg", ".png", ".webp", ".xpm")


@cache
def configured_icon_theme() -> str:
    """Return the icon theme selected by the desktop, if it is known.

    Hyprland does not set a Qt platform theme by itself. Consequently Qt's
    theme lookup used by Quickshell can miss icons that GTK applications find
    without trouble. Reading GTK's setting lets the launcher resolve the same
    theme the rest of the desktop uses.
    """
    if theme := os.environ.get("QT_ICON_THEME"):
        return theme

    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    for settings_path in (config_home / "gtk-4.0/settings.ini", config_home / "gtk-3.0/settings.ini"):
        try:
            for line in settings_path.read_text(encoding="utf-8").splitlines():
                key, separator, value = line.partition("=")
                if separator and key.strip() == "gtk-icon-theme-name" and value.strip():
                    return value.strip()
        except OSError:
            continue

    return "hicolor"


@cache
def icon_theme_roots() -> tuple[Path, ...]:
    roots = [Path.home() / ".icons"]
    roots.extend(data_dir / "icons" for data_dir in data_directories())
    return tuple(root for root in roots if root.is_dir())


@cache
def theme_metadata(theme: str) -> tuple[tuple[str, ...], tuple[str, ...]]:
    """Read icon directories and inherited themes from ``index.theme``."""
    directories: list[str] = []
    inherits: list[str] = []
    for root in icon_theme_roots():
        index_path = root / theme / "index.theme"
        if not index_path.is_file():
            continue
        parser = configparser.ConfigParser(interpolation=None)
        try:
            parser.read(index_path, encoding="utf-8")
            section = parser["Icon Theme"]
        except (OSError, KeyError, configparser.Error):
            continue
        directories.extend(item for item in section.get("Directories", "").split(",") if item)
        inherits.extend(item for item in section.get("Inherits", "").split(",") if item)
    return tuple(directories), tuple(inherits)


@cache
def themed_icon_path(icon: str, theme: str) -> str:
    directories, _ = theme_metadata(theme)
    filename = Path(icon).name
    # Reverse-DNS desktop IDs contain dots (for example
    # ``org.telegram.desktop``); a dot is not necessarily a file extension.
    filenames = (
        (filename,)
        if filename.lower().endswith(ICON_EXTENSIONS)
        else tuple(filename + extension for extension in ICON_EXTENSIONS)
    )
    for root in icon_theme_roots():
        theme_root = root / theme
        for directory in directories:
            for candidate in filenames:
                path = theme_root / directory / candidate
                if path.is_file():
                    return path.as_uri()
    return ""


@cache
def resolve_icon_path(icon: str) -> str:
    """Resolve a desktop-entry icon to a file Qt can always load directly."""
    if icon.startswith("/"):
        path = Path(icon)
        return path.as_uri() if path.is_file() else ""

    queue = [configured_icon_theme()]
    visited: set[str] = set()
    while queue:
        theme = queue.pop(0)
        if not theme or theme in visited:
            continue
        visited.add(theme)
        if path := themed_icon_path(icon, theme):
            return path
        _, inherits = theme_metadata(theme)
        queue.extend(inherits)

    # Broken or incomplete themes are common. Retain an application icon from
    # another installed theme before falling back to the generic executable.
    for root in icon_theme_roots():
        for theme_dir in root.iterdir():
            if theme_dir.is_dir() and (path := themed_icon_path(icon, theme_dir.name)):
                return path

    if icon != "application-x-executable":
        return resolve_icon_path("application-x-executable")
    return ""


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
        "iconPath": resolve_icon_path(entry.get("Icon", "application-x-executable")),
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
