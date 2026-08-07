import "../services" as Services
import QtQuick

Text {
    id: clock

    // Store the date separately so assigning a new value triggers the binding.
    property var currentTime: new Date()

    font.family: Services.Theme.fontFamily
    font.pixelSize: Services.Theme.fontSize
    font.bold: true
    color: Services.Theme.text
    text: Qt.formatDateTime(currentTime, "hh:mm")

    Timer {
        // Update every second so the displayed minute changes immediately.
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.currentTime = new Date()
    }

}
