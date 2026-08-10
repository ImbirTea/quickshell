import QtQuick

QtObject {
    id: root

    // Fallback glyph used when no title or app-id rule matches a window.
    readonly property string defaultIcon: "󰖯"

    // Title matches take precedence over app IDs because they describe a
    // particular window mode, such as picture-in-picture.
    readonly property var windowTitleIconRules: [
        { re: /.*Picture in picture.*/i, icon: "󰹗" },
        { re: /.*Picture-in-picture.*/i, icon: "󰹗" },
        { re: /.*yazi.*/i, icon: "󰉋" },
        { re: /.*nvim.*/i, icon: "" },
        { re: /.*vim.*/i, icon: "" },
        { re: /.*btop.*/i, icon: "" },
        { re: /.*htop.*/i, icon: "" },
    ]

    // App IDs are lower-cased before lookup to keep these keys predictable.
    readonly property var appIdIcons: ({
        // --- Terminals ---
        "kitty": "󰆍",
        "alacritty": "󰆍",
        "foot": "󰆍",
        "footclient": "󰆍",
        "com.mitchellh.ghostty": "󰆍",
        "ghostty": "󰆍",

        // --- Browsers ---
        "firefox": "󰈹",
        "firefox-esr": "󰈹",
        "zen": "",
        "zen-browser": "",
        "chromium": "",
        "google-chrome": "",
        "brave-browser": "",
        "tor browser": "",

        // --- Text Editors & IDEs ---
        "code": "󰨞",
        "code-url-handler": "󰨞",
        "code-oss": "󰨞",
        "vscodium": "󰨞",
        "cursor": "",
        "zed": "",
        "obsidian": "",
        "jetbrains-idea": "",
        "jetbrains-pycharm": "",
        "jetbrains-clion": "",
        "jetbrains-webstorm": "",

        // --- File Managers ---
        "org.gnome.nautilus": "󰉋",
        "thunar": "󰉋",
        "org.kde.dolphin": "󰉋",
        "pcmanfm": "󰉋",
        "nemo": "󰉋",

        // --- Communication & Social ---
        "org.telegram.desktop": "",
        "discord": "",
        "vesktop": "",
        "webcord": "",
        "slack": "",
        "signal": "󰍡",
        "element": "󰍡",
        "whatsapp-for-linux": "󰍡",

        // --- Media & Graphics ---
        "vlc": "󰕼",
        "mpv": "",
        "celluloid": "󰕼",
        "spotify": "",
        "org.gimp.gimp": "",
        "gimp": "",
        "org.inkscape.inkscape": "",
        "com.obsproject.studio": "",

        // --- Productivity & Documents ---
        "net.ankiweb.anki": "󰘸",
        "org.pwmt.zathura": "󰈦",
        "zathura": "󰈦",
        "evince": "󰈦",
        "okular": "󰈦",
        "libreoffice-writer": "",
        "libreoffice-calc": "",
        "libreoffice-impress": "",
        "libreoffice-startcenter": "󰈙",

        // --- Gaming ---
        "steam": "󰓓",
        "com.usebottles.bottles": "󰏗",

        // --- System Settings & Utilities ---
        "org.pulseaudio.pavucontrol": "󰕾",
        "com.saivert.pwvucontrol": "󰕾",
        "pavucontrol": "󰕾",
        "blueman-manager": "󰂰",
        "com.github.tchx84.flatseal": "󰌌",
        "gpartedbin": "󰋊",
        "gnome-disks": "󰋊",
        "systemsettings": "󰒓"
    })

    function iconForWindow(window) {
        const title = window.title ?? "";
        for (const rule of root.windowTitleIconRules) {
            if (rule.re.test(title))
                return rule.icon;
        }
        const appId = (window.wayland?.appId ?? "").toLowerCase();
        if (appId in root.appIdIcons)
            return root.appIdIcons[appId];
        return root.defaultIcon;
    }
}
