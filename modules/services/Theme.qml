import QtQuick
pragma Singleton

QtObject {
    // Kape-inspired semantic colors. Keep only roles used by the current UI.
    // Widget code should use these roles instead of embedding palette values.
    readonly property color text: "#d4be98"
    readonly property color textDim: "#928374"
    readonly property color thirdText: textDim
    readonly property color accent: "#e7bb5c"
    readonly property color accentActive: "#f0cc7a"
    readonly property color selectionBg: "#2e2a2a"
    // Semantic roles used by the shell UI. The alpha is intentional: it lets
    // the wallpaper subtly show through without changing the palette itself.
    readonly property color bgTop: Qt.rgba(0.094, 0.086, 0.086, 0.6)
    readonly property color bgBottom: Qt.rgba(0.118, 0.106, 0.106, 0.6)
    readonly property color bgTopA: Qt.rgba(0.094, 0.086, 0.086, 0.2)
    readonly property color bgBottomA: Qt.rgba(0.118, 0.106, 0.106, 0.2)
    readonly property int fontSize: 14
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    // This remains writable to allow later configuration overrides.
    property real barHeight: 28
}
