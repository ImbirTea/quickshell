import "../services" as Services
import QtQuick
import QtQuick.Layouts
import Qt.labs.settings
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root

    property bool openRequested: false
    property string targetScreenName: ""
    property string query: ""
    property int selectedIndex: 0
    readonly property int pinnedSearchScoreBonus: 20
    readonly property var pinnedApplicationIds: launcherSettings.pinnedApplicationIds || []
    readonly property var matches: filterApplications(query)

    Settings {
        id: launcherSettings

        category: "application-launcher"
        // Keep IDs instead of whole application objects: desktop metadata can
        // change between reloads, while the desktop-file ID remains stable.
        property var pinnedApplicationIds: []
    }

    function normalize(value) {
        if (value === undefined || value === null)
            return "";

        if (typeof value === "string")
            return value.toLocaleLowerCase();

        // array-like значение (list<string> из QML — keywords/categories),
        // не обязательно проходит Array.isArray, но поддерживает join через call
        return Array.prototype.join.call(value, " ").toLocaleLowerCase();
    }

    function filterApplications(searchText) {
        const terms = normalize(searchText).trim().split(/\s+/).filter((term) => {
            return term.length > 0;
        });
        const scored = [];
        for (const application of applicationModel.applications) {
            const name = normalize(application.name);
            const genericName = normalize(application.genericName);
            const comment = normalize(application.comment);
            const keywords = normalize(application.keywords);
            const haystack = name + " " + genericName + " " + comment + " " + keywords;
            if (!terms.every((term) => {
                return haystack.includes(term);
            }))
                continue;

            let score = 0;
            for (const term of terms) {
                if (name.startsWith(term))
                    score += 100;
                else if (name.includes(term))
                    score += 60;
                else if (genericName.includes(term))
                    score += 35;
                else
                    score += 15;
            }
            // Prefer a pinned app when its text match is otherwise equally
            // strong, without displacing substantially better matches.
            if (terms.length > 0 && isPinned(application.id))
                score += pinnedSearchScoreBonus;
            scored.push({
                "application": application,
                "score": score
            });
        }
        scored.sort((left, right) => {
            return right.score - left.score || left.application.name.localeCompare(right.application.name);
        });
        const applications = scored.map((item) => {
            return item.application;
        });
        // While searching, keep the relevance ordering above intact. Pins are
        // only promoted for the empty launcher view.
        if (terms.length > 0)
            return applications;

        // Preserve the order in which apps were pinned. A newly pinned app is
        // appended to the stored IDs, so it appears below existing pins.
        const pinned = [];
        const unpinned = [];
        for (const pinnedId of pinnedApplicationIds) {
            for (const application of applications) {
                if (application.id === pinnedId) {
                    pinned.push(application);
                    break;
                }
            }
        }
        for (const application of applications) {
            if (pinnedApplicationIds.indexOf(application.id) === -1)
                unpinned.push(application);
        }
        return pinned.concat(unpinned);
    }

    function isPinned(applicationId) {
        return pinnedApplicationIds.indexOf(applicationId) !== -1;
    }

    function togglePinned(applicationId) {
        const pins = pinnedApplicationIds.slice();
        const index = pins.indexOf(applicationId);
        if (index === -1)
            pins.push(applicationId);
        else
            pins.splice(index, 1);
        launcherSettings.pinnedApplicationIds = pins;
    }

    function focusedScreenName() {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    }

    function open() {
        targetScreenName = focusedScreenName();
        query = "";
        selectedIndex = 0;
        openRequested = true;
    }

    function close() {
        openRequested = false;
    }

    function toggle() {
        if (openRequested)
            close();
        else
            open();
    }

    function reloadApplications() {
        applicationModel.reload();
    }

    function moveSelection(offset) {
        if (matches.length === 0)
            return ;

        selectedIndex = Math.max(0, Math.min(matches.length - 1, selectedIndex + offset));
    }

    function launchSelected() {
        if (selectedIndex < 0 || selectedIndex >= matches.length)
            return ;

        const application = matches[selectedIndex];
        // gtk-launch cannot discover kitty as a terminal on this system. The
        // indexer provides a tokenized desktop-entry Exec command, so launch
        // console applications directly in kitty without involving GLib's
        // terminal discovery or Quickshell's separate desktop-entry index.
        if (application.runInTerminal && application.command.length > 0) {
            Quickshell.execDetached({
                command: ["kitty"].concat(application.command),
                workingDirectory: application.workingDirectory
            });
        } else {
            Quickshell.execDetached(["gtk-launch", application.id]);
        }
        close();
    }

    onQueryChanged: selectedIndex = 0
    onMatchesChanged: {
        if (selectedIndex >= matches.length)
            selectedIndex = Math.max(0, matches.length - 1);

    }

    ApplicationModel {
        id: applicationModel
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: launcherWindow

            required property var modelData

            function show() {
                root.query = "";
                root.selectedIndex = 0;
                searchInput.text = "";
                resultList.resetScrollPosition();
                backdrop.opacity = 0;
                card.opacity = 0;
                card.revealProgress = 0.006;
                card.contentProgress = 0;
                entrance.restart();
                searchInput.forceActiveFocus();
            }

            screen: modelData
            visible: root.openRequested && (!root.targetScreenName || modelData.name === root.targetScreenName)
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell:application-launcher"
            exclusionMode: ExclusionMode.Ignore
            onVisibleChanged: {
                if (visible)
                    show();

            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                id: backdrop

                anchors.fill: parent
                color: Qt.rgba(0.015, 0.014, 0.014, 0.14)
                opacity: 0
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: card

                readonly property real expandedHeight: Math.min(552, parent.height - 72)
                property real revealProgress: 1
                property real contentProgress: 1

                anchors.centerIn: parent
                width: Math.min(760, parent.width - 48)
                height: Math.max(2, expandedHeight * revealProgress)
                radius: 15
                clip: true
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.11)
                opacity: 0
                layer.enabled: true
                layer.smooth: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => {
                        return mouse.accepted = true;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Services.Theme.bgTopA
                        }

                        GradientStop {
                            position: 1
                            color: Services.Theme.bgBottomA
                        }

                    }

                }

                Column {
                    id: launcherContent

                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    opacity: card.contentProgress

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 10

                        Text {
                            width: 20
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: "󰍉"
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 19
                            color: Services.Theme.accentActive
                        }

                        TextInput {
                            id: searchInput

                            width: parent.width - 30
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 30
                            focus: launcherWindow.visible
                            clip: true
                            color: Services.Theme.text
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 17
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            selectionColor: Qt.rgba(Services.Theme.accent.r, Services.Theme.accent.g, Services.Theme.accent.b, 0.38)
                            selectedTextColor: "#171512"
                            onTextChanged: root.query = text
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    root.close();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    root.moveSelection(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.moveSelection(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.launchSelected();
                                    event.accepted = true;
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !searchInput.text
                                text: "Search applications"
                                font: searchInput.font
                                color: Qt.rgba(Services.Theme.textDim.r, Services.Theme.textDim.g, Services.Theme.textDim.b, 0.72)
                            }

                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    Text {
                        text: root.query.length > 0 ? "Results (" + root.matches.length + ")" : "Applications (" + applicationModel.applications.length + ")"
                        font.family: Services.Theme.fontFamily
                        font.pixelSize: 11
                        font.capitalization: Font.AllUppercase
                        color: Services.Theme.textDim
                    }

                    Item {
                        width: parent.width
                        height: Math.max(0, parent.height - 110)

                        ListView {
                            id: resultList

                            anchors.fill: parent
                            clip: true
                            model: root.matches
                            currentIndex: root.selectedIndex
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

                            delegate: Rectangle {
                                id: resultRow

                                required property var modelData
                                required property int index

                                width: resultList.width
                                height: 51
                                radius: 8
                                readonly property bool hovered: rowMouse.containsMouse || pinMouse.containsMouse
                                color: hovered && resultRow.index !== root.selectedIndex ? Qt.rgba(1, 1, 1, 0.055) : "transparent"

                                Item {
                                    id: iconSlot

                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26
                                    height: 26

                                    readonly property string resolvedIcon: Quickshell.iconPath(resultRow.modelData.icon, true)

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
                                            text: (resultRow.modelData.name || "?").charAt(0).toUpperCase()
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
                                        text: resultRow.modelData.name
                                        elide: Text.ElideRight
                                        font.family: Services.Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: resultRow.index === root.selectedIndex
                                        color: Services.Theme.text
                                    }

                                    Text {
                                        width: parent.width
                                        text: resultRow.modelData.genericName || resultRow.modelData.comment
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
                                        if (resultRow.index !== root.selectedIndex)
                                            root.selectedIndex = resultRow.index;
                                        else
                                            root.launchSelected();
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
                                    opacity: resultRow.hovered ? 1 : (root.isPinned(resultRow.modelData.id) ? 0.6 : 0)
                                    visible: opacity > 0
                                    z: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isPinned(resultRow.modelData.id) ? "★" : "☆"
                                        font.family: Services.Theme.fontFamily
                                        font.pixelSize: 17
                                        color: root.isPinned(resultRow.modelData.id) ? Services.Theme.accentActive : Services.Theme.textDim
                                    }

                                    MouseArea {
                                        id: pinMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: (mouse) => {
                                            root.togglePinned(resultRow.modelData.id);
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

                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !applicationModel.loading && root.matches.length === 0
                            text: applicationModel.error || "No applications found"
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 14
                            color: Services.Theme.textDim
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: applicationModel.loading
                            text: "Loading applications…"
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 14
                            color: Services.Theme.textDim
                        }

                    }

                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: escText.implicitWidth + 9
                            height: 18
                            radius: 4
                            color: Services.Theme.selectionBg
                            anchors.verticalCenter: parent.verticalCenter

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
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Close"
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 12
                            color: Services.Theme.textDim
                        }


                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Open" + (root.matches.length > 0 ? " " + root.matches[root.selectedIndex].name : "")
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 12
                            color: Services.Theme.textDim
                        }

                        Rectangle {
                            width: enterText.implicitWidth + 9
                            height: 18
                            radius: 4
                            color: Services.Theme.selectionBg
                            anchors.verticalCenter: parent.verticalCenter

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
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: arrowsText
                                anchors.centerIn: parent
                                text: ""
                                rotation: 90
                                font.family: Services.Theme.fontFamily
                                font.pixelSize: 10
                                color: Services.Theme.textDim
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Navigate"
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 12
                            color: Services.Theme.textDim
                        }
                    }

                    transform: Translate {
                        y: 8 * (1 - card.contentProgress)
                    }

                }

                // Match the bar's palette while keeping the launcher lighter
                // so the wallpaper remains visible behind the results.
                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Qt.rgba(Services.Theme.bgTop.r, Services.Theme.bgTop.g, Services.Theme.bgTop.b, 0.42)
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(Services.Theme.bgBottom.r, Services.Theme.bgBottom.g, Services.Theme.bgBottom.b, 0.42)
                    }

                }

            }

            ParallelAnimation {
                id: entrance

                NumberAnimation {
                    target: backdrop
                    property: "opacity"
                    to: 1
                    duration: 210
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: card
                    property: "opacity"
                    to: 1
                    duration: 130
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: card
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
                        target: card
                        property: "contentProgress"
                        to: 1
                        duration: 185
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
