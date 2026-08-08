import "../services" as Services
import QtQuick
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
    readonly property var matches: filterApplications(query)

    function normalize(value) {
        return (value || "").toLocaleLowerCase();
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
            scored.push({
                "application": application,
                "score": score
            });
        }
        scored.sort((left, right) => {
            return right.score - left.score || left.application.name.localeCompare(right.application.name);
        });
        return scored.map((item) => {
            return item.application;
        });
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

        Quickshell.execDetached(["gtk-launch", matches[selectedIndex].id]);
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
                            color: Qt.rgba(1, 1, 1, 0.035)
                        }

                        GradientStop {
                            position: 1
                            color: Qt.rgba(1, 1, 1, 0)
                        }

                    }

                }

                Column {
                    id: launcherContent

                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12
                    opacity: card.contentProgress

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 10

                        Text {
                            width: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 19
                            color: Services.Theme.accentActive
                        }

                        TextInput {
                            id: searchInput

                            width: parent.width - 30
                            height: parent.height
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
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 3
                            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                            delegate: Rectangle {
                                id: resultRow

                                required property var modelData
                                required property int index

                                width: resultList.width
                                height: 51
                                radius: 8
                                color: resultRow.index === root.selectedIndex ? Qt.rgba(Services.Theme.accent.r, Services.Theme.accent.g, Services.Theme.accent.b, 0.16) : rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.055) : "transparent"

                                IconImage {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26
                                    height: 26
                                    // Prefer a file resolved by the scanner. It avoids Qt's
                                    // incomplete icon-theme lookup under standalone Hyprland.
                                    source: resultRow.modelData.iconPath || Quickshell.iconPath(resultRow.modelData.icon, "application-x-executable")
                                    smooth: true
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
                                    onEntered: root.selectedIndex = resultRow.index
                                    onClicked: root.launchSelected()
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

                    Row {
                        width: parent.width
                        spacing: 15

                        Text {
                            text: "󱞥 open"
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 12
                            color: Services.Theme.textDim
                        }

                        Text {
                            text: "󱦲󱦳 navigate"
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 12
                            color: Services.Theme.textDim
                        }

                        Text {
                            text: "esc close"
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
