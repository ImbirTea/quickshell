import "../services" as Services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string screenName

    // A translucent gradient gives the panel depth while preserving wallpaper context.
    Rectangle {
        anchors.fill: parent
        border.width: 0

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Services.Theme.bgTop
            }

            GradientStop {
                position: 1
                color: Services.Theme.bgBottom
            }

        }

    }

    // Separate the panel from the content below it without a heavy border.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter

        // Workspaces are screen-specific, unlike the centered clock and tray.
        Workspaces {
            screenName: root.screenName
        }

    }

    Clock {
        anchors.centerIn: parent
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // Keep system-provided tray entries before the shell's own indicators.
        Tray {
        }

        StatusBlock {
        }

    }

}
