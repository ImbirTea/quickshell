import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "./workspaces" as WorkspacesImpl

RowLayout {
    id: root
    required property string screenName
    spacing: 16

    WorkspacesImpl.WindowIcons {
        id: windowIcons
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

    // Replaced by the special row below to avoid two active entries at once.
    WorkspacesImpl.RegularWorkspaces {
        visible: !root.isSpecialWorkspaceOpen
        screenName: root.screenName
        workspaceIds: root.visibleWorkspaceIds
        specialOpen: root.isSpecialWorkspaceOpen
        iconForWindow: windowIcons.iconForWindow
    }

    WorkspacesImpl.SpecialWorkspace {
        workspace: root.specialWorkspace
        open: root.isSpecialWorkspaceOpen
        iconForWindow: windowIcons.iconForWindow
    }
}
