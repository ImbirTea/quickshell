import "../services" as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: launcherWindow

    required property var launcher
    required property var modelData

    function show() {
        launcher.query = "";
        launcher.selectedIndex = 0;
        searchField.clear();
        resultsList.resetScrollPosition();
        backdrop.opacity = 0;
        card.opacity = 0;
        card.revealProgress = 0.006;
        card.contentProgress = 0;
        entrance.restart();
        searchField.focusInput();
    }

    screen: modelData
    visible: launcher.openRequested && (!launcher.targetScreenName || modelData.name === launcher.targetScreenName)
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
        onClicked: launcher.close()
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

            SearchField {
                id: searchField

                launcher: launcherWindow.launcher
                windowVisible: launcherWindow.visible
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Text {
                text: launcher.query.length > 0 ? "Results (" + launcher.matches.length + ")" : "Applications (" + launcher.appsService.applications.length + ")"
                font.family: Services.Theme.fontFamily
                font.pixelSize: 11
                font.capitalization: Font.AllUppercase
                color: Services.Theme.textDim
            }

            ResultsList {
                id: resultsList

                launcher: launcherWindow.launcher
            }

            KeyHints {
                launcher: launcherWindow.launcher
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

    LauncherEntrance {
        id: entrance

        backdrop: backdrop
        card: card
    }

}
