import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules/bar" as BarComponents

ShellRoot {
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
