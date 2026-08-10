import "../services" as Services
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property var launcher
    required property bool windowVisible

    width: parent.width
    height: 32
    spacing: 10

    function clear() {
        searchInput.text = "";
    }

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    Text {
        Layout.preferredWidth: 24
        Layout.alignment: Qt.AlignVCenter
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

        Layout.fillWidth: true
        height: parent.height
        focus: root.windowVisible
        clip: true
        color: Services.Theme.text
        font.family: Services.Theme.fontFamily
        font.pixelSize: 17
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        selectionColor: Qt.rgba(Services.Theme.accent.r, Services.Theme.accent.g, Services.Theme.accent.b, 0.38)
        selectedTextColor: "#171512"
        onTextChanged: root.launcher.query = text
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.launcher.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                root.launcher.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                root.launcher.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.launcher.launchSelected();
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
