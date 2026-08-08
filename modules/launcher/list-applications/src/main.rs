use std::cell::RefCell;
use std::collections::{HashMap, HashSet, VecDeque};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use serde::Serialize;

const ICON_EXTENSIONS: [&str; 4] = [".svg", ".png", ".webp", ".xpm"];
/// The launcher renders icons at 26 logical pixels. Prefer a 64 px raster
/// source so the result stays sharp on high-DPI displays as well.
const PREFERRED_RASTER_ICON_SIZE: u32 = 64;

#[derive(Serialize)]
struct Application {
    id: String,
    name: String,
    #[serde(rename = "genericName")]
    generic_name: String,
    comment: String,
    icon: String,
    #[serde(rename = "iconPath")]
    icon_path: String,
    keywords: String,
}

// ---------------------------------------------------------------------
// XDG paths
// ---------------------------------------------------------------------

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn data_directories() -> Vec<PathBuf> {
    let home = home_dir();
    let user_data = env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".local/share"));
    let system_data =
        env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".to_string());

    let mut directories = vec![user_data];
    directories.extend(
        system_data
            .split(':')
            .filter(|entry| !entry.is_empty())
            .map(PathBuf::from),
    );

    // Flatpak exports use the same desktop-file format but live outside the
    // standard XDG roots on many distributions.
    directories.push(home.join(".local/share/flatpak/exports/share"));
    directories.push(PathBuf::from("/var/lib/flatpak/exports/share"));

    directories
}

// ---------------------------------------------------------------------
// Minimal INI reading (desktop entries and index.theme files)
// ---------------------------------------------------------------------

/// Read a single `[section_name]` group from an INI-style file.
fn read_ini_section(
    path: &Path,
    section_name: &str,
    case_sensitive: bool,
) -> Option<HashMap<String, String>> {
    let contents = fs::read_to_string(path).ok()?;
    let mut current_section: Option<String> = None;
    let mut found = false;
    let mut map = HashMap::new();

    for raw_line in contents.lines() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with(';') {
            continue;
        }
        if line.starts_with('[') && line.ends_with(']') {
            let name = &line[1..line.len() - 1];
            found = found || name == section_name;
            current_section = Some(name.to_string());
            continue;
        }
        if current_section.as_deref() != Some(section_name) {
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            let mut key = key.trim().to_string();
            if !case_sensitive {
                key = key.to_lowercase();
            }
            map.insert(key, value.trim().to_string());
        }
    }

    found.then_some(map)
}

fn parse_bool(value: Option<&String>) -> Option<bool> {
    match value?.trim().to_lowercase().as_str() {
        "1" | "true" | "yes" | "on" => Some(true),
        "0" | "false" | "no" | "off" => Some(false),
        _ => None,
    }
}

fn path_to_file_uri(path: &Path) -> String {
    let path_str = path.to_string_lossy();
    let mut encoded = String::from("file://");
    for byte in path_str.as_bytes() {
        let b = *byte;
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~' | b'/') {
            encoded.push(b as char);
        } else {
            encoded.push_str(&format!("%{b:02X}"));
        }
    }
    encoded
}

// ---------------------------------------------------------------------
// Icon theme resolution
// ---------------------------------------------------------------------

struct IconResolver {
    theme_roots: Vec<PathBuf>,
    configured_theme: String,
    metadata_cache: RefCell<HashMap<String, (Vec<String>, Vec<String>)>>,
    themed_path_cache: RefCell<HashMap<(String, String), String>>,
    resolve_cache: RefCell<HashMap<String, String>>,
}

impl IconResolver {
    fn new() -> Self {
        Self {
            theme_roots: icon_theme_roots(),
            configured_theme: configured_icon_theme(),
            metadata_cache: RefCell::new(HashMap::new()),
            themed_path_cache: RefCell::new(HashMap::new()),
            resolve_cache: RefCell::new(HashMap::new()),
        }
    }

    /// Read icon directories and inherited themes from `index.theme`,
    /// merging across every theme root that ships a copy (matches the
    /// original's behaviour of accumulating, not overwriting).
    fn theme_metadata(&self, theme: &str) -> (Vec<String>, Vec<String>) {
        if let Some(cached) = self.metadata_cache.borrow().get(theme) {
            return cached.clone();
        }

        let mut directories = Vec::new();
        let mut inherits = Vec::new();
        for root in &self.theme_roots {
            let index_path = root.join(theme).join("index.theme");
            if !index_path.is_file() {
                continue;
            }
            if let Some(section) = read_ini_section(&index_path, "Icon Theme", false) {
                if let Some(dirs) = section.get("directories") {
                    directories.extend(dirs.split(',').filter(|s| !s.is_empty()).map(String::from));
                }
                if let Some(inh) = section.get("inherits") {
                    inherits.extend(inh.split(',').filter(|s| !s.is_empty()).map(String::from));
                }
            }
        }

        let result = (directories, inherits);
        self.metadata_cache
            .borrow_mut()
            .insert(theme.to_string(), result.clone());
        result
    }

    fn themed_icon_path(&self, icon: &str, theme: &str) -> String {
        let cache_key = (icon.to_string(), theme.to_string());
        if let Some(cached) = self.themed_path_cache.borrow().get(&cache_key) {
            return cached.clone();
        }

        let (directories, _) = self.theme_metadata(theme);
        let filename = Path::new(icon)
            .file_name()
            .and_then(|f| f.to_str())
            .unwrap_or(icon);

        // Reverse-DNS desktop IDs contain dots (e.g. `org.telegram.desktop`);
        // a dot is not necessarily a file extension.
        let lower = filename.to_lowercase();
        let filenames: Vec<String> = if ICON_EXTENSIONS.iter().any(|ext| lower.ends_with(ext)) {
            vec![filename.to_string()]
        } else {
            ICON_EXTENSIONS
                .iter()
                .map(|ext| format!("{filename}{ext}"))
                .collect()
        };

        let mut best: Option<(String, (u8, u32))> = None;
        for root in &self.theme_roots {
            let theme_root = root.join(theme);
            for directory in &directories {
                for candidate in &filenames {
                    let path = theme_root.join(directory).join(candidate);
                    if path.is_file() {
                        let extension = path
                            .extension()
                            .and_then(|extension| extension.to_str())
                            .unwrap_or_default();
                        let format_score = u8::from(extension.eq_ignore_ascii_case("svg"));
                        let raster_score = self.icon_directory_score(theme, directory);
                        let score = (format_score, raster_score);
                        let uri = path_to_file_uri(&path);

                        if best
                            .as_ref()
                            .is_none_or(|(_, best_score)| score > *best_score)
                        {
                            best = Some((uri, score));
                        }
                    }
                }
            }
        }

        let result = best.map(|(path, _)| path).unwrap_or_default();

        self.themed_path_cache
            .borrow_mut()
            .insert(cache_key, result.clone());
        result
    }

    /// Score a raster icon directory by how well it suits the launcher's
    /// rendered size. `index.theme` directory order is not a quality order:
    /// it commonly starts with `16x16`, which was causing visibly blurred
    /// icons when Qt enlarged that first match.
    fn icon_directory_score(&self, theme: &str, directory: &str) -> u32 {
        let index_path_score = self
            .theme_roots
            .iter()
            .map(|root| root.join(theme).join("index.theme"))
            .find_map(|index_path| {
                read_ini_section(&index_path, directory, false).and_then(|section| {
                    let size = section.get("size")?.parse::<u32>().ok()?;
                    let scale = section
                        .get("scale")
                        .and_then(|scale| scale.parse::<u32>().ok())
                        .unwrap_or(1);
                    Some(size.saturating_mul(scale))
                })
            });

        let size = index_path_score.or_else(|| {
            directory
                .split('/')
                .find_map(|part| part.split_once('x'))
                .and_then(|(width, height)| {
                    (width == height)
                        .then(|| width.parse::<u32>().ok())
                        .flatten()
                })
        });

        match size {
            // Prefer the smallest source that is still large enough, avoiding
            // both upscaling and needlessly loading huge bitmap assets.
            Some(size) if size >= PREFERRED_RASTER_ICON_SIZE => {
                10_000 - (size - PREFERRED_RASTER_ICON_SIZE).min(9_999)
            }
            Some(size) => size,
            None => 0,
        }
    }

    /// Resolve a desktop-entry icon to a file Qt can always load directly.
    fn resolve_icon_path(&self, icon: &str) -> String {
        if let Some(cached) = self.resolve_cache.borrow().get(icon) {
            return cached.clone();
        }

        let result = self.resolve_icon_path_uncached(icon);
        self.resolve_cache
            .borrow_mut()
            .insert(icon.to_string(), result.clone());
        result
    }

    fn resolve_icon_path_uncached(&self, icon: &str) -> String {
        if let Some(rest) = icon.strip_prefix('/') {
            let _ = rest;
            let path = Path::new(icon);
            return if path.is_file() {
                path_to_file_uri(path)
            } else {
                String::new()
            };
        }

        let mut queue: VecDeque<String> = VecDeque::new();
        queue.push_back(self.configured_theme.clone());
        let mut visited: HashSet<String> = HashSet::new();

        while let Some(theme) = queue.pop_front() {
            if theme.is_empty() || visited.contains(&theme) {
                continue;
            }
            visited.insert(theme.clone());

            let path = self.themed_icon_path(icon, &theme);
            if !path.is_empty() {
                return path;
            }
            let (_, inherits) = self.theme_metadata(&theme);
            queue.extend(inherits);
        }

        // Broken or incomplete themes are common. Retain an application icon
        // from another installed theme before falling back to the generic
        // executable icon.
        for root in &self.theme_roots {
            if let Ok(entries) = fs::read_dir(root) {
                for entry in entries.flatten() {
                    if !entry.path().is_dir() {
                        continue;
                    }
                    if let Some(name) = entry.file_name().to_str() {
                        let path = self.themed_icon_path(icon, name);
                        if !path.is_empty() {
                            return path;
                        }
                    }
                }
            }
        }

        if icon != "application-x-executable" {
            return self.resolve_icon_path("application-x-executable");
        }
        String::new()
    }
}

/// Return the icon theme selected by the desktop, if it is known.
///
/// Hyprland does not set a Qt platform theme by itself. Consequently Qt's
/// theme lookup used by Quickshell can miss icons that GTK applications find
/// without trouble. Reading GTK's setting lets the launcher resolve the same
/// theme the rest of the desktop uses.
fn configured_icon_theme() -> String {
    if let Ok(theme) = env::var("QT_ICON_THEME") {
        if !theme.is_empty() {
            return theme;
        }
    }

    let config_home = env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".config"));

    for settings_path in [
        config_home.join("gtk-4.0/settings.ini"),
        config_home.join("gtk-3.0/settings.ini"),
    ] {
        if let Ok(contents) = fs::read_to_string(&settings_path) {
            for line in contents.lines() {
                if let Some((key, value)) = line.split_once('=') {
                    if key.trim() == "gtk-icon-theme-name" {
                        let value = value.trim();
                        if !value.is_empty() {
                            return value.to_string();
                        }
                    }
                }
            }
        }
    }

    "hicolor".to_string()
}

fn icon_theme_roots() -> Vec<PathBuf> {
    let mut roots = vec![home_dir().join(".icons")];
    roots.extend(data_directories().into_iter().map(|dir| dir.join("icons")));
    roots.into_iter().filter(|root| root.is_dir()).collect()
}

// ---------------------------------------------------------------------
// Desktop entries
// ---------------------------------------------------------------------

fn desktop_id(applications_dir: &Path, desktop_file: &Path) -> String {
    desktop_file
        .strip_prefix(applications_dir)
        .unwrap_or(desktop_file)
        .to_string_lossy()
        .replace('/', "-")
}

fn current_desktops() -> HashSet<String> {
    env::var("XDG_CURRENT_DESKTOP")
        .unwrap_or_default()
        .split(':')
        .filter(|entry| !entry.is_empty())
        .map(String::from)
        .collect()
}

fn is_visible(entry: &HashMap<String, String>, desktops: &HashSet<String>) -> bool {
    let entry_type = entry
        .get("Type")
        .map(String::as_str)
        .unwrap_or("Application");
    if entry_type != "Application" {
        return false;
    }
    if parse_bool(entry.get("Hidden")).unwrap_or(false)
        || parse_bool(entry.get("NoDisplay")).unwrap_or(false)
    {
        return false;
    }

    let has_exec = entry.get("Exec").map(|s| !s.is_empty()).unwrap_or(false);
    let dbus_activatable = parse_bool(entry.get("DBusActivatable")).unwrap_or(false);
    if !has_exec && !dbus_activatable {
        return false;
    }

    let only_show_in: HashSet<&str> = entry
        .get("OnlyShowIn")
        .map(|s| s.split(';').filter(|v| !v.is_empty()).collect())
        .unwrap_or_default();
    let not_show_in: HashSet<&str> = entry
        .get("NotShowIn")
        .map(|s| s.split(';').filter(|v| !v.is_empty()).collect())
        .unwrap_or_default();

    if !only_show_in.is_empty() && !desktops.iter().any(|d| only_show_in.contains(d.as_str())) {
        return false;
    }
    !desktops.iter().any(|d| not_show_in.contains(d.as_str()))
}

fn read_entry(
    path: &Path,
    identifier: &str,
    desktops: &HashSet<String>,
    resolver: &IconResolver,
) -> Option<Application> {
    let section = read_ini_section(path, "Desktop Entry", true)?;

    if !is_visible(&section, desktops) {
        return None;
    }

    let icon = section
        .get("Icon")
        .cloned()
        .unwrap_or_else(|| "application-x-executable".to_string());
    let icon_path = resolver.resolve_icon_path(&icon);

    let name = section.get("Name").cloned().unwrap_or_else(|| {
        path.file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or_default()
            .to_string()
    });

    Some(Application {
        id: identifier.to_string(),
        name,
        generic_name: section.get("GenericName").cloned().unwrap_or_default(),
        comment: section.get("Comment").cloned().unwrap_or_default(),
        icon,
        icon_path,
        keywords: section.get("Keywords").cloned().unwrap_or_default(),
    })
}

fn find_desktop_files(dir: &Path) -> Vec<PathBuf> {
    let mut results = Vec::new();
    let mut stack = vec![dir.to_path_buf()];
    while let Some(current) = stack.pop() {
        let Ok(entries) = fs::read_dir(&current) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else if path.extension().and_then(|e| e.to_str()) == Some("desktop") {
                results.push(path);
            }
        }
    }
    results
}

fn main() {
    let mut applications: Vec<Application> = Vec::new();
    let mut seen_ids: HashSet<String> = HashSet::new();
    let desktops = current_desktops();
    let resolver = IconResolver::new();

    // Earlier XDG roots take precedence. A Hidden entry therefore correctly
    // masks the system entry with the same desktop-file ID.
    for data_dir in data_directories() {
        let applications_dir = data_dir.join("applications");
        if !applications_dir.is_dir() {
            continue;
        }
        for desktop_file in find_desktop_files(&applications_dir) {
            let identifier = desktop_id(&applications_dir, &desktop_file);
            if seen_ids.contains(&identifier) {
                continue;
            }
            seen_ids.insert(identifier.clone());
            if let Some(application) = read_entry(&desktop_file, &identifier, &desktops, &resolver)
            {
                applications.push(application);
            }
        }
    }

    applications.sort_by_key(|application| application.name.to_lowercase());

    println!("{}", serde_json::to_string(&applications).unwrap());
}
