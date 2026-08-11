import "../services" as Services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string screenName

    // Фон переключается мгновенно, без анимации.
    Rectangle {
        anchors.fill: parent
        border.width: 0
        opacity: Services.LauncherState.transitioning ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: 70
                easing.type: Easing.OutCubic
            }
        }

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
        opacity: Services.LauncherState.transitioning ? 0 : 1
    }

    // Весь контент (иконки, текст) затухает/появляется плавно.
    Item {
        id: content

        anchors.fill: parent
        opacity: Services.LauncherState.transitioning ? 0 : 1
        enabled: !Services.LauncherState.transitioning

        Behavior on opacity {
            NumberAnimation {
                duration: 110
                // property: "horizontalProgress"
                easing.type: Easing.OutCubic
            }
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

}