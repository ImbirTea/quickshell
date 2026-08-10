import "./services" as LauncherServices
import QtQuick
import QtCore
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property bool openRequested: false
    property string targetScreenName: ""
    property string query: ""
    property int selectedIndex: 0
    readonly property int pinnedSearchScoreBonus: 20
    readonly property var pinnedApplicationIds: launcherSettings.pinnedApplicationIds || []
    readonly property var matches: filterApplications(query)
    readonly property alias appsService: appsService

    Settings {
        id: launcherSettings

        // Explicit location bypasses Qt's organizationName/applicationName lookup
        // entirely (unset under standalone Hyprland, which caused the QSettings
        // init warning) — Quickshell.statePath() gives us a reserved, per-shell
        // writable directory to store it in.
        location: "file://" + Quickshell.statePath("launcher-settings.ini")
        category: "application-launcher"
        // Keep IDs instead of whole application objects: desktop metadata can
        // change between reloads, while the desktop-file ID remains stable.
        property var pinnedApplicationIds: []
    }

    function normalize(value) {
        if (value === undefined || value === null)
            return "";

        if (typeof value === "string")
            return value.toLocaleLowerCase();

        // array-like значение (list<string> из QML — keywords/categories),
        // не обязательно проходит Array.isArray, но поддерживает join через call
        return Array.prototype.join.call(value, " ").toLocaleLowerCase();
    }

    function filterApplications(searchText) {
        const terms = normalize(searchText).trim().split(/\s+/).filter((term) => {
            return term.length > 0;
        });
        const scored = [];
        for (const application of appsService.applications) {
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
            // Prefer a pinned app when its text match is otherwise equally
            // strong, without displacing substantially better matches.
            if (terms.length > 0 && isPinned(application.id))
                score += pinnedSearchScoreBonus;
            scored.push({
                "application": application,
                "score": score
            });
        }
        scored.sort((left, right) => {
            return right.score - left.score || left.application.name.localeCompare(right.application.name);
        });
        const applications = scored.map((item) => {
            return item.application;
        });
        // While searching, keep the relevance ordering above intact. Pins are
        // only promoted for the empty launcher view.
        if (terms.length > 0)
            return applications;

        // Preserve the order in which apps were pinned. A newly pinned app is
        // appended to the stored IDs, so it appears below existing pins.
        const pinned = [];
        const unpinned = [];
        for (const pinnedId of pinnedApplicationIds) {
            for (const application of applications) {
                if (application.id === pinnedId) {
                    pinned.push(application);
                    break;
                }
            }
        }
        for (const application of applications) {
            if (pinnedApplicationIds.indexOf(application.id) === -1)
                unpinned.push(application);
        }
        return pinned.concat(unpinned);
    }

    function isPinned(applicationId) {
        return pinnedApplicationIds.indexOf(applicationId) !== -1;
    }

    function togglePinned(applicationId) {
        const pins = pinnedApplicationIds.slice();
        const index = pins.indexOf(applicationId);
        if (index === -1)
            pins.push(applicationId);
        else
            pins.splice(index, 1);
        launcherSettings.pinnedApplicationIds = pins;
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
        appsService.reload();
    }

    function moveSelection(offset) {
        if (matches.length === 0)
            return ;

        selectedIndex = Math.max(0, Math.min(matches.length - 1, selectedIndex + offset));
    }

    function launchSelected() {
        if (selectedIndex < 0 || selectedIndex >= matches.length)
            return ;

        const application = matches[selectedIndex];
        if (application.runInTerminal && application.command.length > 0) {
            Quickshell.execDetached({
                command: ["kitty"].concat(application.command),
                workingDirectory: application.workingDirectory
            });
        } else {
            application.execute();
        }
        close();
    }

    onQueryChanged: selectedIndex = 0
    onMatchesChanged: {
        if (selectedIndex >= matches.length)
            selectedIndex = Math.max(0, matches.length - 1);

    }

    LauncherServices.Apps {
        id: appsService
    }

    // One window per screen; each stays hidden until openRequested targets it.
    Variants {
        model: Quickshell.screens

        LauncherWindow {
            launcher: root
        }

    }

}
