import "../services" as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: launcherWindow

    required property var launcher
    required property var modelData
    property real barHeight: 28
    property bool closing: false
    property bool isVisible: false   // ← единственный источник правды для видимости

    readonly property bool matchesThisScreen: !launcher.targetScreenName || modelData.name === launcher.targetScreenName

    function show() {
        closing = false;
        isVisible = true;   // ставим сразу, без гонок

        launcher.query = "";
        launcher.selectedIndex = 0;
        searchField.clear();
        resultsList.resetScrollPosition();

        card.horizontalProgress = 0;
        card.verticalProgress = 0;
        card.contentProgress = 0;
        backdrop.opacity = 0;

        closeAnimation.stop();
        launcher.setTransitioning(true);
        openAnimation.restart();
        searchField.focusInput();
    }

    function hide() {
        closing = true;
        // isVisible остаётся true — окно не прячется, пока не доиграет анимация
        openAnimation.stop();
        launcher.setTransitioning(true);
        closeAnimation.restart();
    }

    visible: isVisible && matchesThisScreen   // больше НЕ зависит от launcher.openRequested напрямую


    screen: modelData
    // visible: (launcher.openRequested || closing) && matchesThisScreen
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:application-launcher"
    exclusionMode: ExclusionMode.Ignore

    Connections {
        target: launcher

        function onOpenRequestedChanged() {
            if (!matchesThisScreen)
                return;

            if (launcher.openRequested)
                launcherWindow.show();
            else
                launcherWindow.hide();
        }
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

        readonly property real expandedHeight: Math.min(440, parent.height - 72)
        readonly property real collapsedWidth: Math.min(660, parent.width - 48)

        // 0 = во всю ширину экрана (как бар), 1 = сжат до своей ширины
        property real horizontalProgress: 1
        // 0 = высота бара, 1 = полностью раскрыт по высоте
        property real verticalProgress: 1
        property real contentProgress: 1

        anchors.top: parent.top
        anchors.topMargin: 5 * verticalProgress
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - (parent.width - collapsedWidth) * horizontalProgress
        height: Math.max(2, launcherWindow.barHeight + (expandedHeight - launcherWindow.barHeight) * verticalProgress)
        radius: 8 * verticalProgress
        clip: true
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.11 * verticalProgress)
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
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12
            opacity: card.contentProgress
            visible: opacity > 0.01

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

        // Тот же градиент, что и у бара — визуальная подмена должна быть незаметна.
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

    LauncherOpenAnimation {
        id: openAnimation

        card: card
        backdrop: backdrop
        onFinished: launcher.setTransitioning(true)
    }

    LauncherCloseAnimation {
        id: closeAnimation
        card: card
        backdrop: backdrop
        onFinished: {
            launcherWindow.closing = false;
            launcherWindow.isVisible = false;   // ← прячем окно только теперь, когда анимация реально закончилась
            launcher.setTransitioning(false);
        }
    }
}
