import QtQuick
import QtQuick.Layouts
import "../../services" as Services

Item {
    id: root

    // Presence of `workspace` alone does not indicate it is currently open;
    // `open` tracks that separately via Hyprland's "activespecial" event.
    required property var workspace
    required property bool open
    required property var iconForWindow

    visible: root.open
    implicitWidth: specialWorkspaceRow.implicitWidth
    implicitHeight: specialWorkspaceRow.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: specialWorkspaceRow
        anchors.fill: parent
        spacing: 4

        readonly property bool hasWindows: root.workspace && root.workspace.toplevels.values.length > 0

        Text {
            text: "S" + (parent.hasWindows ? ":" : "")
            font.family: Services.Theme.fontFamily
            font.pixelSize: Services.Theme.fontSize
            font.bold: true
            color: Services.Theme.accentActive
        }

        Repeater {
            model: root.open ? root.workspace.toplevels : []

            delegate: Text {
                required property var modelData
                text: root.iconForWindow(modelData)
                font.family: Services.Theme.fontFamily
                font.pixelSize: Services.Theme.fontSize
                color: Services.Theme.accentActive
            }
        }
    }
}
