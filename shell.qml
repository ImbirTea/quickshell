import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "modules/bar" as BarComponents
import "modules/launcher" as LauncherComponents

ShellRoot {
    LauncherComponents.Launcher {
        id: applicationLauncher
    }

    // The launcher is deliberately exposed over Quickshell IPC so a compositor
    // shortcut can open it without the shell needing to own global key bindings.
    IpcHandler {
        function toggle() {
            applicationLauncher.toggle();
        }

        function open() {
            applicationLauncher.open();
        }

        function close() {
            applicationLauncher.close();
        }

        function reload() {
            applicationLauncher.reloadApplications();
        }

        target: "launcher"
    }

    // Quickshell creates and destroys these windows as displays are attached
    // or removed, so no monitor-specific setup is needed here.
    // Create one panel window for every connected screen.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

            screen: modelData
            implicitHeight: 28
            // Reserve panel space in the compositor so tiled windows stay below it.
            exclusiveZone: implicitHeight
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            // A stable namespace makes this surface easier to identify in tools.
            WlrLayershell.namespace: "quickshell:bar"

            anchors {
                top: true
                left: true
                right: true
            }

            BarComponents.Bar {
                anchors.fill: parent
                screenName: modelData.name
            }

        }

    }

}
