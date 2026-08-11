import "./services" as LauncherServices
import "../services" as Services
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
    readonly property bool transitioning: Services.LauncherState.transitioning

    function setTransitioning(value) {
        Services.LauncherState.transitioning = value;
    }

    readonly property var usageCounts: parseUsage(launcherSettings.usageJson)

    Settings {
        id: launcherSettings

        location: "file://" + Quickshell.statePath("launcher-settings.ini")
        category: "application-launcher"
        property var pinnedApplicationIds: []
        property string usageJson: "{}"
    }

    function normalize(value) {
        if (value === undefined || value === null)
            return "";

        if (typeof value === "string")
            return value.toLocaleLowerCase();

        return Array.prototype.join.call(value, " ").toLocaleLowerCase();
    }

    function parseUsage(json) {
        try {
            const parsed = JSON.parse(json || "{}");
            return parsed && typeof parsed === "object" ? parsed : {};
        } catch (e) {
            return {};
        }
    }

    function usesCount(applicationId) {
        if (!applicationId)
            return 0;
        const count = usageCounts[applicationId];
        return typeof count === "number" ? count : 0;
    }

    function recordUsage(applicationId) {
        if (!applicationId)
            return;
        const next = Object.assign({}, usageCounts);
        next[applicationId] = (next[applicationId] || 0) + 1;
        launcherSettings.usageJson = JSON.stringify(next);
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
            if (terms.length > 0 && isPinned(application.id))
                score += pinnedSearchScoreBonus;
            scored.push({
                "application": application,
                "score": score
            });
        }
        scored.sort((left, right) => {
            if (right.score !== left.score)
                return right.score - left.score;
            const usageDiff = usesCount(right.application.id) - usesCount(left.application.id);
            if (usageDiff !== 0)
                return usageDiff;
            return left.application.name.localeCompare(right.application.name);
        });
        const applications = scored.map((item) => {
            return item.application;
        });
        if (terms.length > 0)
            return applications;

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
        recordUsage(application.id);
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

    Variants {
        model: Quickshell.screens

        LauncherWindow {
            launcher: root
        }
    }
}