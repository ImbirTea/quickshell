import QtQuick

ParallelAnimation {
    id: root

    required property var card
    required property var backdrop

    NumberAnimation {
        target: root.backdrop
        property: "opacity"
        to: 0
        duration: 140
        easing.type: Easing.InCubic
    }

    SequentialAnimation {
        NumberAnimation {
            target: root.card
            property: "contentProgress"
            to: 0
            duration: 60
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root.card
            property: "verticalProgress"
            to: 0
            duration: 90
            easing.type: Easing.InQuint
        }

        NumberAnimation {
            target: root.card
            property: "horizontalProgress"
            to: 0
            duration: 90
            easing.type: Easing.InCubic
        }

    }

}