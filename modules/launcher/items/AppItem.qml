import "../../services" as Services
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: appItem

    required property var modelData
    required property int index
    required property var launcher

    height: 51
    radius: 8
    readonly property bool hovered: rowMouse.containsMouse || pinMouse.containsMouse
    color: hovered && appItem.index !== appItem.launcher.selectedIndex ? Qt.rgba(1, 1, 1, 0.055) : "transparent"

    Item {
        id: iconSlot

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26

        readonly property string resolvedIcon: Quickshell.iconPath(appItem.modelData.icon, true)

        IconImage {
            anchors.fill: parent
            visible: iconSlot.resolvedIcon.length > 0
            source: iconSlot.resolvedIcon
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            visible: iconSlot.resolvedIcon.length === 0
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.08)

            Text {
                anchors.centerIn: parent
                text: (appItem.modelData.name || "?").charAt(0).toUpperCase()
                font.family: Services.Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: Services.Theme.textDim
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 48
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: appItem.modelData.name
            elide: Text.ElideRight
            font.family: Services.Theme.fontFamily
            font.pixelSize: 14
            font.bold: appItem.index === appItem.launcher.selectedIndex
            color: Services.Theme.text
        }

        Text {
            width: parent.width
            text: appItem.modelData.genericName || appItem.modelData.comment
            visible: text.length > 0
            elide: Text.ElideRight
            font.family: Services.Theme.fontFamily
            font.pixelSize: 11
            color: Services.Theme.textDim
        }
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (appItem.index !== appItem.launcher.selectedIndex)
                appItem.launcher.selectedIndex = appItem.index;
            else
                appItem.launcher.launchSelected();
        }
    }

    Rectangle {
        id: pinButton

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 25
        height: 25
        radius: 6
        color: pinMouse.containsMouse ? Qt.rgba(Services.Theme.accent.r, Services.Theme.accent.g, Services.Theme.accent.b, 0.18) : "transparent"
        opacity: appItem.hovered ? 1 : (appItem.launcher.isPinned(appItem.modelData.id) ? 0.6 : 0)
        visible: opacity > 0
        z: 1

        Text {
            anchors.centerIn: parent
            text: appItem.launcher.isPinned(appItem.modelData.id) ? "★" : "☆"
            font.family: Services.Theme.fontFamily
            font.pixelSize: 17
            color: appItem.launcher.isPinned(appItem.modelData.id) ? Services.Theme.accentActive : Services.Theme.textDim
        }

        MouseArea {
            id: pinMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => {
                appItem.launcher.togglePinned(appItem.modelData.id);
                mouse.accepted = true;
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 190
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: 110
        }
    }
}
