import "../services" as Services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

RowLayout {
    id: root

    spacing: 10

    Rectangle {
        width: 1
        height: 12
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // Keyboard layout reported by Hyprland.
    Text {
        font.family: Services.Theme.fontFamily
        font.pixelSize: Services.Theme.fontSize
        font.bold: true
        color: Services.Theme.accentActive
        text: Services.LayoutService.currentLayout
    }

    Rectangle {
        width: 1
        height: 12
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // Volume control follows PipeWire's current default sink, rather than a
    // hard-coded device. It therefore remains correct after output switching.
    Item {
        id: volumeBlock

        property var sink: Pipewire.defaultAudioSink
        property int volumePercent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
        property bool muted: sink && sink.audio ? sink.audio.muted : false

        implicitWidth: volumeRow.implicitWidth
        implicitHeight: volumeRow.implicitHeight

        PwObjectTracker {
            objects: [volumeBlock.sink]
        }

        RowLayout {
            id: volumeRow

            anchors.fill: parent
            spacing: 4

            Text {
                text: volumeBlock.muted ? "" : ""
                font.family: Services.Theme.fontFamily
                font.pixelSize: Services.Theme.fontSize
                color: volumeBlock.muted ? Services.Theme.thirdText : Services.Theme.text
            }

            Text {
                text: volumeBlock.volumePercent + "%"
                font.family: Services.Theme.fontFamily
                font.pixelSize: Services.Theme.fontSize
                color: volumeBlock.muted ? Services.Theme.thirdText : Services.Theme.text
                Layout.preferredWidth: volumeBlock.muted ? 29 : 31
                horizontalAlignment: Text.AlignRight
            }

        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                // Right-click toggles mute. Left-click is intentionally reserved
                // for a future audio-device menu.
                if (!volumeBlock.sink || !volumeBlock.sink.audio)
                    return ;

                if (mouse.button === Qt.RightButton)
                    volumeBlock.sink.audio.muted = !volumeBlock.sink.audio.muted;

            }
            onWheel: (wheel) => {
                if (!volumeBlock.sink || !volumeBlock.sink.audio)
                    return ;

                // PipeWire volume is normalized to the 0–1 range.
                const step = 0.02;
                const newVolume = volumeBlock.sink.audio.volume + (wheel.angleDelta.y > 0 ? step : -step);
                volumeBlock.sink.audio.volume = Math.max(0, Math.min(1, newVolume));
            }
        }

    }

}
