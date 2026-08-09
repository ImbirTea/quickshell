import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../services" as Services

Item {
    id: root
    visible: SystemTray.items.values.length > 0
    // Reveal the tray by resizing this container from the panel's right edge.
    clip: true
    Layout.alignment: Qt.AlignRight
    Layout.preferredHeight: iconSize

    property bool expanded: false
    readonly property int iconSize: 16
    readonly property int iconCount: SystemTray.items.values.length
    readonly property int iconSpacing: 6
    // The toggle occupies the first slot; icons are positioned to its right.
    readonly property real iconsWidth: iconCount * iconSize
        + Math.max(iconCount - 1, 0) * iconSpacing

    implicitWidth: arrowText.implicitWidth
        + (expanded ? iconSpacing + iconsWidth : 0)
    implicitHeight: iconSize
    Layout.preferredWidth: implicitWidth

    Behavior on Layout.preferredWidth {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayIcon

            required property var modelData
            required property int index

            x: arrowText.implicitWidth + root.iconSpacing
                + index * (root.iconSize + root.iconSpacing)
            width: root.iconSize
            height: root.iconSize
            opacity: root.expanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            IconImage {
                anchors.fill: parent
                implicitSize: root.iconSize
                smooth: true
                mipmap: true
                source: trayIcon.modelData.icon
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                enabled: root.expanded
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton && trayIcon.modelData.hasMenu)
                        trayIcon.modelData.display(trayIcon, 0, trayIcon.height);
                    else
                        trayIcon.modelData.activate();
                }
            }
        }
    }

    Item {
        id: toggle
        width: arrowText.implicitWidth
        height: root.iconSize

        Text {
            id: arrowText
            anchors.centerIn: parent
            text: ""
            font.pixelSize: 12
            color: Services.Theme.text
            opacity: toggleArea.containsMouse ? 1.0 : 0.20
            rotation: root.expanded ? 180 : 0
            transformOrigin: Item.Center

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
            Behavior on rotation {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }
}
