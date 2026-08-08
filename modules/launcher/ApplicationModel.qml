import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var applications: []
    property bool loading: false
    property string error: ""
    property string queryResult: ""

    function reload() {
        if (applicationQuery.running)
            return ;

        error = "";
        loading = true;
        queryResult = "";
        applicationQuery.running = true;
    }

    visible: false
    Component.onCompleted: reload()

    Process {
        id: applicationQuery

        command: [Quickshell.shellPath("modules/launcher/list-applications")]
        onExited: (exitCode) => {
            root.loading = false;
            if (exitCode !== 0) {
                root.error = "Couldn't read desktop applications";
                return ;
            }
            try {
                root.applications = JSON.parse(root.queryResult);
            } catch (exception) {
                root.error = "Couldn't parse desktop applications";
                console.warn("Application launcher:", exception);
            }
        }

        // The scanner deliberately emits one JSON line. Keeping the buffer in
        // this component means a manual reload never reuses stale output.
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                return root.queryResult += data;
            }
        }

    }

}
