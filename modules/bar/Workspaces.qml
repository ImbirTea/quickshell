import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../services" as Services

RowLayout {
    id: root
    required property string screenName
    spacing: 16

    // Fallback glyph used when no title or app-id rule matches a window.
    readonly property string defaultIcon: "󰖯"

    // Title matches take precedence over app IDs because they describe a
    // particular window mode, such as picture-in-picture.
    readonly property var windowTitleIconRules: [
        { re: /.*Picture in picture.*/i, icon: "󰹗" },
        { re: /.*Picture-in-picture.*/i, icon: "󰹗" },
        { re: /.*yazi.*/i, icon: "󰉋" },
        { re: /.*nvim.*/i, icon: "" }
    ]

    // App IDs are lower-cased before lookup to keep these keys predictable.
    readonly property var appIdIcons: ({
        "kitty": "󰆍",
        "chromium": "",
        "firefox-esr": "󰈹",
        "firefox": "󰈹",
        "steam": "󰓓",
        "org.telegram.desktop": "",
        "discord": "",
        "vlc": "󰕼",
        "org.gnome.nautilus": "󰉋",
        "code": "󰨞",
        "net.ankiweb.anki": "󰘸",
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

    // Always show workspaces 1–3, plus every regular workspace on this screen.
    readonly property var visibleWorkspaceIds: {
        let workspaceIds = new Set([1, 2, 3]);
        for (const ws of Hyprland.workspaces.values) {
            // Special workspaces have negative IDs and are handled separately below.
            if (ws.id > 0 && ws.monitor && ws.monitor.name === root.screenName)
                workspaceIds.add(ws.id);
        }
        return Array.from(workspaceIds).sort((a, b) => a - b);
    }

    // This gives access to special-workspace windows and icons. Its presence alone
    // does not indicate that it is currently open; see specialWorkspaceState below.
    readonly property var specialWorkspace: {
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id < 0 && ws.monitor && ws.monitor.name === root.screenName)
                return ws;
        }
        return null;
    }

    // Track whether a special workspace is actually open through Hyprland's event.
    // Its monitor assignment can remain after it has been closed.
    QtObject {
        id: specialWorkspaceState
        property string activeName: ""
        property string activeMonitorName: ""
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                const eventFields = event.parse(2); // [workspaceName, monitorName]
                specialWorkspaceState.activeName = eventFields[0];
                specialWorkspaceState.activeMonitorName = eventFields[1];
            }
        }
    }

    readonly property bool isSpecialWorkspaceOpen: specialWorkspaceState.activeMonitorName === root.screenName
        && specialWorkspaceState.activeName !== ""

    Item {
        id: workspacesRoot
        visible: !root.isSpecialWorkspaceOpen
        implicitWidth: workspacesRow.implicitWidth
        implicitHeight: workspacesRow.implicitHeight

        RowLayout {
            id: workspacesRow
            spacing: 16

            Repeater {
                model: root.isSpecialWorkspaceOpen ? [] : root.visibleWorkspaceIds

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
                const ids = root.visibleWorkspaceIds
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

    // Replace regular workspaces with the active special workspace to avoid two active entries.
    Item {
        visible: root.isSpecialWorkspaceOpen
        implicitWidth: specialWorkspaceRow.implicitWidth
        implicitHeight: specialWorkspaceRow.implicitHeight
        Layout.alignment: Qt.AlignVCenter

        RowLayout {
            id: specialWorkspaceRow
            anchors.fill: parent
            spacing: 4

            readonly property bool hasWindows: root.specialWorkspace && root.specialWorkspace.toplevels.values.length > 0

            Text {
                text: "S" + (parent.hasWindows ? ":" : "")
                font.family: Services.Theme.fontFamily
                font.pixelSize: Services.Theme.fontSize
                font.bold: true
                color: Services.Theme.accentActive
            }

            Repeater {
                model: root.isSpecialWorkspaceOpen ? root.specialWorkspace.toplevels : []

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
}
