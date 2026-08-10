import "../services" as Services
import "./items" as Items
import QtQuick

Item {
    id: root

    required property var launcher

    width: parent.width
    height: Math.max(0, parent.height - 110)

    function resetScrollPosition() {
        resultList.resetScrollPosition();
    }

    ListView {
        id: resultList

        anchors.fill: parent
        clip: true
        model: root.launcher.matches
        currentIndex: root.launcher.selectedIndex
        boundsBehavior: Flickable.DragAndOvershootBounds
        flickDeceleration: 2800
        maximumFlickVelocity: 2400
        spacing: 3

        function resetScrollPosition() {
            keyboardScroll.stop();
            cancelFlick();
            contentY = originY;
        }

        function smoothlyPositionCurrentItem() {
            if (currentIndex < 0)
                return ;

            const rowHeight = 51;
            const itemTop = currentIndex * (rowHeight + spacing);
            const itemBottom = itemTop + rowHeight;
            let targetY = contentY;

            if (itemTop < contentY)
                targetY = itemTop;
            else if (itemBottom > contentY + height)
                targetY = itemBottom - height;

            const minimumY = originY;
            const maximumY = Math.max(minimumY, contentHeight - height + originY);
            targetY = Math.max(minimumY, Math.min(maximumY, targetY));

            if (Math.abs(targetY - contentY) < 1)
                return ;

            keyboardScroll.stop();
            keyboardScroll.from = contentY;
            keyboardScroll.to = targetY;
            keyboardScroll.restart();
        }

        onCurrentIndexChanged: smoothlyPositionCurrentItem()

        PropertyAnimation {
            id: keyboardScroll

            target: resultList
            property: "contentY"
            duration: 180
            easing.type: Easing.OutCubic
        }

        rebound: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 260
                easing.type: Easing.OutBack
                easing.overshoot: 0.65
            }

        }

        highlight: Rectangle {
            width: resultList.width
            height: 51
            radius: 8
            color: Qt.rgba(Services.Theme.accent.r, Services.Theme.accent.g, Services.Theme.accent.b, 0.16)
        }
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 140
        highlightMoveVelocity: -1
        highlightResizeDuration: 120
        highlightResizeVelocity: -1

        // Currently always an app result; once other providers (clipboard,
        // emoji, wallpapers) land, this delegate will need to switch on the
        // match's kind and pick the matching item from ./items.
        delegate: Items.AppItem {
            width: resultList.width
            launcher: root.launcher
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.launcher.appsService.loading && root.launcher.matches.length === 0
        text: root.launcher.appsService.error || "No applications found"
        font.family: Services.Theme.fontFamily
        font.pixelSize: 14
        color: Services.Theme.textDim
    }

    Text {
        anchors.centerIn: parent
        visible: root.launcher.appsService.loading
        text: "Loading applications…"
        font.family: Services.Theme.fontFamily
        font.pixelSize: 14
        color: Services.Theme.textDim
    }
}
