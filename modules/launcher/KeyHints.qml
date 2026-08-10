import "../services" as Services
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property var launcher

    width: parent.width
    spacing: 8

    Rectangle {
        width: escText.implicitWidth + 9
        height: 18
        radius: 4
        color: Services.Theme.selectionBg
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: escText
            anchors.centerIn: parent
            text: "esc"
            font.family: Services.Theme.fontFamily
            font.pixelSize: 10
            color: Services.Theme.textDim
        }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: "Close"
        font.family: Services.Theme.fontFamily
        font.pixelSize: 12
        color: Services.Theme.textDim
    }

    Item {
        Layout.fillWidth: true
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: "Open" + (root.launcher.matches.length > 0 ? " " + root.launcher.matches[root.launcher.selectedIndex].name : "")
        font.family: Services.Theme.fontFamily
        font.pixelSize: 12
        color: Services.Theme.textDim
    }

    Rectangle {
        width: enterText.implicitWidth + 9
        height: 18
        radius: 4
        color: Services.Theme.selectionBg
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: enterText
            anchors.centerIn: parent
            text: "󱞥"
            font.family: Services.Theme.fontFamily
            font.pixelSize: 10
            color: Services.Theme.textDim
        }
    }

    Rectangle {
        width: 1
        height: 12
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    Rectangle {
        width: arrowsText.implicitWidth + 9
        height: 18
        radius: 4
        color: Services.Theme.selectionBg
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: arrowsText
            anchors.centerIn: parent
            text: ""
            rotation: 90
            font.family: Services.Theme.fontFamily
            font.pixelSize: 10
            color: Services.Theme.textDim
        }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: "Navigate"
        font.family: Services.Theme.fontFamily
        font.pixelSize: 12
        color: Services.Theme.textDim
    }
}
