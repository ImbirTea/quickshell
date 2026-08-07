import QtQuick
import Quickshell
import Quickshell.Hyprland
pragma Singleton

Singleton {
    id: root

    property string currentLayout: "en"

    function updateLayoutFromName(layoutName) {
        if (!layoutName)
            return ;

        // The bar intentionally displays the two-letter layout code only.
        const layoutCode = layoutName.substring(0, 2).toLowerCase();
        if (root.currentLayout !== layoutCode)
            root.currentLayout = layoutCode;

    }

    function handleHyprlandEvent(event) {
        // Hyprland sends the active layout as the final field of this event.
        if (event.name === "activelayout") {
            const eventFields = event.parse(2);
            updateLayoutFromName(eventFields[eventFields.length - 1]);
        }
    }

    Component.onCompleted: {
        // Raw events are the only reliable way to track layout changes.
        Hyprland.rawEvent.connect(handleHyprlandEvent);
    }
}
