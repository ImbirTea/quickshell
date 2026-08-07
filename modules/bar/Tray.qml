import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

RowLayout {
    spacing: 8
    // Do not leave an empty gap in the panel when no applications expose tray items.
    visible: SystemTray.items.values.length > 0

    Repeater {
        // SystemTray exposes the current items as a dynamic model.
        model: SystemTray.items

        delegate: Item {
            id: trayIcon

            required property var modelData

            width: 16
            height: 16

            IconImage {
                // Quickshell resolves both themed icon names and image sources here.
                anchors.fill: parent
                source: trayIcon.modelData.icon
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    // The status notifier convention is context menu on right-click,
                    // with activation as the fallback when no menu is available.
                    if (mouse.button === Qt.RightButton && trayIcon.modelData.hasMenu)
                        trayIcon.modelData.display(trayIcon, 0, trayIcon.height);
                    else
                        trayIcon.modelData.activate();
                }
            }

        }

    }

}
