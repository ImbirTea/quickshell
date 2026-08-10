import QtQuick
import Quickshell

Item {
    id: root

    readonly property var applications: DesktopEntries.applications.values.filter(entry => !entry.noDisplay)
    readonly property bool loading: false
    readonly property string error: ""

    function reload(): void {
    }

    visible: false
}
