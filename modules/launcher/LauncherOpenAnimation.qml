import QtQuick

ParallelAnimation {
    id: root

    required property var card
    required property var backdrop

    NumberAnimation {
        target: root.backdrop
        property: "opacity"
        to: 1
        duration: 600
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        // Фаза 1: бар "стягивается" до ширины лаунчера, оставаясь наверху.
        NumberAnimation {
            target: root.card
            property: "horizontalProgress"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }

        // Фаза 2: только теперь начинается рост вниз.
        NumberAnimation {
            target: root.card
            property: "verticalProgress"
            to: 1
            duration: 170
            easing.type: Easing.OutQuint
        }

        PauseAnimation {
            duration: 10
        }

        // Контент (поиск, список) проявляется в последнюю очередь.
        NumberAnimation {
            target: root.card
            property: "contentProgress"
            to: 1
            duration: 120
            easing.type: Easing.OutCubic
        }

    }

}
