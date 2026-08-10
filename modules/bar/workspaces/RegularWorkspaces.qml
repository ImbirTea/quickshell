import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../services" as Services

Item {
    id: root

    required property string screenName
    required property var workspaceIds
    required property bool specialOpen
    required property var iconForWindow

    implicitWidth: workspacesRow.implicitWidth
    implicitHeight: workspacesRow.implicitHeight

    RowLayout {
        id: workspacesRow
        spacing: 16

        Repeater {
            model: root.specialOpen ? [] : root.workspaceIds

            delegate: Item {
                id: workspaceDelegate
                required property int modelData
                readonly property int workspaceId: modelData
                readonly property bool isWorkspace: true
                implicitWidth: workspaceContent.implicitWidth
                implicitHeight: workspaceContent.implicitHeight

                readonly property var workspace: {
                    for (const ws of Hyprland.workspaces.values) {
                        if (ws.id === workspaceDelegate.workspaceId && ws.monitor && ws.monitor.name === root.screenName)
                            return ws;
                    }
                    return null;
                }

                property bool isActive: Hyprland.focusedMonitor
                    && Hyprland.focusedMonitor.activeWorkspace
                    && Hyprland.focusedMonitor.activeWorkspace.id === workspaceDelegate.workspaceId

                readonly property bool hasWindows: workspaceDelegate.workspace
                    && workspaceDelegate.workspace.toplevels.values.length > 0

                RowLayout {
                    id: workspaceContent
                    anchors.fill: parent
                    spacing: 4

                    Text {
                        text: workspaceDelegate.workspaceId + (workspaceDelegate.hasWindows ? ":" : "")
                        font.family: Services.Theme.fontFamily
                        font.pixelSize: Services.Theme.fontSize
                        font.bold: workspaceDelegate.isActive
                        color: workspaceDelegate.isActive ? Services.Theme.accentActive : Services.Theme.textDim
                    }

                    Repeater {
                        model: workspaceDelegate.workspace ? workspaceDelegate.workspace.toplevels : []

                        delegate: Text {
                            required property var modelData
                            text: root.iconForWindow(modelData)
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: Services.Theme.fontSize
                            color: workspaceDelegate.isActive ? Services.Theme.accentActive : Services.Theme.textDim
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: workspacesRow

        onClicked: event => {
            const item = workspacesRow.childAt(event.x, event.y)
            if (item && item.isWorkspace)
                Hyprland.dispatch(`hl.dsp.focus({workspace = ${item.workspaceId}})`)
        }

        onWheel: wheel => {
            const ids = root.workspaceIds
            if (ids.length === 0) return

            const current = Hyprland.focusedMonitor?.activeWorkspace?.id
            let idx = ids.indexOf(current)
            if (idx === -1) idx = 0

            const nextIdx = wheel.angleDelta.y > 0
                ? (idx - 1 + ids.length) % ids.length
                : (idx + 1) % ids.length

            Hyprland.dispatch(`hl.dsp.focus({workspace = ${ids[nextIdx]}})`)
        }
    }
}
