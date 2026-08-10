import QtQuick

ParallelAnimation {
    id: root

    required property var backdrop
    required property var card

    NumberAnimation {
        target: root.backdrop
        property: "opacity"
        to: 1
        duration: 210
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        target: root.card
        property: "opacity"
        to: 1
        duration: 130
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        target: root.card
        property: "revealProgress"
        to: 1
        duration: 300
        easing.type: Easing.OutQuint
    }

    SequentialAnimation {
        PauseAnimation {
            duration: 75
        }

        NumberAnimation {
            target: root.card
            property: "contentProgress"
            to: 1
            duration: 185
            easing.type: Easing.OutCubic
        }

    }

}
