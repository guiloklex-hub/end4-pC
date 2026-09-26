pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

import qs.modules.common

Singleton {
    id: root

    property string filePath: Directories.agendaPath
    property string syncScript: Directories.agendaSyncScript

    property var calendars: []
    property var rawEvents: []
    property string activeFilter: "all"
    property var filteredEvents: []

    property bool isSyncing: false
    property string lastUpdated: ""
    property string syncError: ""

    // 15 minutos em milissegundos
    readonly property int syncIntervalMs: 15 * 60 * 1000

    function updateFilteredEvents() {
        if (root.activeFilter === "all") {
            root.filteredEvents = root.rawEvents.slice(0);
        } else {
            root.filteredEvents = root.rawEvents.filter(ev => ev.calendar_id === root.activeFilter);
        }
    }

    onActiveFilterChanged: {
        updateFilteredEvents();
    }

    onRawEventsChanged: {
        updateFilteredEvents();
    }

    function setFilter(filterId) {
        root.activeFilter = filterId;
    }

    function refresh() {
        if (root.isSyncing) return;
        root.isSyncing = true;
        root.syncError = "";
        syncProcess.running = true;
    }

    function getCalendarColorsForDate(targetDate) {
        if (!targetDate) return [];
        let dStr = "";
        if (typeof targetDate === "string") {
            dStr = targetDate.slice(0, 10);
        } else if (targetDate instanceof Date) {
            const year = targetDate.getFullYear();
            const month = String(targetDate.getMonth() + 1).padStart(2, "0");
            const day = String(targetDate.getDate()).padStart(2, "0");
            dStr = `${year}-${month}-${day}`;
        } else {
            return [];
        }

        const colors = [];
        for (let i = 0; i < root.rawEvents.length; i++) {
            const ev = root.rawEvents[i];
            const inRange = (ev.date_str === dStr) || (ev.end_date_str && ev.date_str <= dStr && dStr <= ev.end_date_str);
            if (inRange && !colors.includes(ev.calendar_color)) {
                colors.push(ev.calendar_color);
            }
        }
        return colors;
    }

    function openCalendarWeb() {
        Qt.openUrlExternally("https://calendar.google.com");
    }

    function openMeetingUrl(url) {
        if (url && url.length > 0) {
            Qt.openUrlExternally(url);
        }
    }

    Timer {
        id: periodicSyncTimer
        interval: root.syncIntervalMs
        running: true
        repeat: true
        onTriggered: {
            root.refresh();
        }
    }

    Process {
        id: syncProcess
        command: ["python3", root.syncScript]
        onExited: (exitCode, exitStatus) => {
            root.isSyncing = false;
            if (exitCode === 0) {
                agendaFileView.reload();
                root.syncError = "";
            } else {
                root.syncError = "Erro no sync (" + exitCode + ")";
                console.error("[GoogleAgenda] Sincronização falhou com código: " + exitCode);
            }
        }
    }

    FileView {
        id: agendaFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            try {
                const textContent = agendaFileView.text();
                if (!textContent || textContent.trim().length === 0) {
                    return;
                }
                const data = JSON.parse(textContent);
                root.calendars = data.calendars || [];
                root.rawEvents = data.events || [];
                root.lastUpdated = data.last_updated || "";
                root.updateFilteredEvents();
                console.log("[GoogleAgenda] Cache carregado: " + root.rawEvents.length + " eventos em " + root.calendars.length + " agendas.");
            } catch(e) {
                console.error("[GoogleAgenda] Erro ao analisar cache JSON: " + e);
            }
        }
        onLoadFailed: (error) => {
            console.log("[GoogleAgenda] Cache não encontrado ou falhou ao carregar: " + error + ". Disparando sincronização inicial...");
            root.refresh();
        }
    }

    Component.onCompleted: {
        agendaFileView.reload();
        // Disparar sincronização inicial
        root.refresh();
    }
}
