pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Catálogo do menu de apps: categorias, fixados (menu e dock), recentes,
 * ocultos e a ponte para scripts/apps/appctl.py (detalhes, remoção,
 * instalação e edição de atalhos).
 */
Singleton {
    id: root

    readonly property string appctl: Quickshell.shellPath("scripts/apps/appctl.py")

    // Ordem = prioridade: o app entra na primeira categoria que casar
    readonly property var categoryDefs: [
        { key: "WebApps", name: Translation.tr("Web apps"), icon: "public" },
        { key: "Game", name: Translation.tr("Games"), icon: "sports_esports", match: ["Game"] },
        { key: "Development", name: Translation.tr("Development"), icon: "code", match: ["Development", "IDE"] },
        { key: "Graphics", name: Translation.tr("Graphics"), icon: "palette", match: ["Graphics"] },
        { key: "Office", name: Translation.tr("Office"), icon: "description", match: ["Office"] },
        { key: "AudioVideo", name: Translation.tr("Multimedia"), icon: "play_circle", match: ["AudioVideo", "Audio", "Video"] },
        { key: "Network", name: Translation.tr("Internet"), icon: "language", match: ["Network", "WebBrowser", "Chat"] },
        { key: "Education", name: Translation.tr("Education"), icon: "school", match: ["Education", "Science"] },
        { key: "Settings", name: Translation.tr("Settings"), icon: "tune", match: ["Settings"] },
        { key: "System", name: Translation.tr("System"), icon: "memory", match: ["System", "Monitor"] },
        { key: "Utility", name: Translation.tr("Utilities"), icon: "construction", match: ["Utility", "Accessories"] },
        { key: "Other", name: Translation.tr("Others"), icon: "category" },
    ]

    readonly property var hiddenApps: Config.options?.launcher.hiddenApps ?? []
    readonly property var menuPins: Config.options?.launcher.pinnedApps ?? []
    readonly property var recentIds: Persistent.states?.launcher.recentApps ?? []

    // Todos os apps (inclusive ocultos), em ordem alfabética
    readonly property var apps: AppSearch.list.slice().sort((a, b) => a.name.localeCompare(b.name, "pt-BR", { sensitivity: "base" }))
    readonly property var visibleApps: apps.filter(a => !isHidden(a))

    readonly property var categoryCounts: {
        const counts = {};
        for (const app of root.visibleApps) {
            const key = root.categoryOf(app);
            counts[key] = (counts[key] ?? 0) + 1;
        }
        return counts;
    }

    readonly property var categories: [{ key: "all", name: Translation.tr("All"), icon: "apps", count: visibleApps.length }]
        .concat(categoryDefs.filter(c => (categoryCounts[c.key] ?? 0) > 0).map(c => Object.assign({ count: categoryCounts[c.key] }, c)))

    function categoryOf(entry) {
        if (!entry) return "Other";
        if (/^(chrome|brave|msedge)-/.test(entry.id)) return "WebApps";
        const cats = entry.categories ?? [];
        for (const def of root.categoryDefs) {
            if (def.match && def.match.some(m => cats.includes(m))) return def.key;
        }
        return "Other";
    }

    function categoryName(key) {
        return root.categoryDefs.find(c => c.key === key)?.name ?? key;
    }

    function byId(id) {
        return root.apps.find(a => a.id === id) ?? DesktopEntries.byId(id) ?? null;
    }

    function entriesFor(ids) {
        return ids.map(id => root.byId(id)).filter(e => e !== null && !root.isHidden(e));
    }

    // Apps: busca fuzzy do AppSearch, sem os ocultos
    function search(query) {
        if (!query) return [];
        return AppSearch.fuzzyQuery(query).filter(a => !root.isHidden(a));
    }

    // Clicar fora (no dock, por exemplo) fecha o menu pelo focus grab antes do clique chegar ao
    // botão de apps; sem esta janela de tempo o mesmo clique o reabriria
    property real drawerClosedAt: 0
    Connections {
        target: GlobalStates
        function onAppDrawerOpenChanged() {
            if (!GlobalStates.appDrawerOpen) root.drawerClosedAt = Date.now();
        }
    }
    function toggleDrawer() {
        if (GlobalStates.appDrawerOpen) GlobalStates.appDrawerOpen = false;
        else if (Date.now() - root.drawerClosedAt > 250) GlobalStates.appDrawerOpen = true;
    }

    function launch(entry) {
        if (!entry) return;
        Applications.launchDesktopEntry(entry);
        GlobalStates.appDrawerOpen = false;
    }

    function launchAction(action) {
        Applications.launchDesktopAction(action);
        GlobalStates.appDrawerOpen = false;
    }

    // ---- Ocultos ----
    function isHidden(entry) {
        return root.hiddenApps.indexOf(entry?.id) !== -1;
    }
    function toggleHidden(entry) {
        const list = Config.options.launcher.hiddenApps;
        Config.options.launcher.hiddenApps = root.isHidden(entry) ? list.filter(id => id !== entry.id) : list.concat([entry.id]);
    }

    // ---- Fixados no menu ----
    function isMenuPinned(entry) {
        return LauncherApps.isPinned(entry?.id);
    }
    function toggleMenuPin(entry) {
        LauncherApps.togglePin(entry.id);
    }

    // ---- Fixados no dock (ids em minúsculas, como o dock grava) ----
    function dockPinFor(entry) {
        if (!entry) return "";
        const pins = Config.options.dock.pinnedApps;
        const id = entry.id.toLowerCase();
        const startup = (entry.startupClass ?? "").toLowerCase();
        return pins.find(p => {
            const lp = p.toLowerCase();
            return lp === id || (startup.length > 0 && lp === startup) || DesktopEntries.heuristicLookup(p)?.id === entry.id;
        }) ?? "";
    }
    function isDockPinned(entry) {
        return root.dockPinFor(entry) !== "";
    }
    function toggleDockPin(entry) {
        const existing = root.dockPinFor(entry);
        if (existing !== "")
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.filter(p => p !== existing);
        else
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.concat([entry.id.toLowerCase()]);
    }
    function pinToDock(entry) {
        if (!root.isDockPinned(entry)) root.toggleDockPin(entry);
    }

    // ---- appctl.py ----
    signal editDone(string appId, var result)

    function sourceLabel(source) {
        switch (source) {
        case "pacman": return Translation.tr("Official repositories (pacman)");
        case "aur": return Translation.tr("AUR");
        case "flatpak": return Translation.tr("Flatpak");
        case "webapp": return Translation.tr("Web app");
        case "appimage": return Translation.tr("AppImage");
        default: return Translation.tr("Local shortcut");
        }
    }

    function uninstall(info) {
        const leftover = info.overridden ? [info.path] : [];
        Quickshell.execDetached(["python3", root.appctl, "uninstall", info.source, info.removeTarget, ...leftover]);
    }

    function install(pkg) {
        Quickshell.execDetached(["python3", root.appctl, "install", pkg.source, pkg.id]);
        GlobalStates.appDrawerOpen = false;
    }

    function edit(entry, name, icon) {
        editProc.appId = entry.id;
        editProc.command = ["python3", root.appctl, "edit", entry.id, name, icon];
        editProc.running = true;
    }

    function restore(entry) {
        editProc.appId = entry.id;
        editProc.command = ["python3", root.appctl, "restore", entry.id];
        editProc.running = true;
    }

    Process {
        id: editProc
        property string appId
        stdout: StdioCollector {
            onStreamFinished: {
                let result;
                try {
                    result = JSON.parse(text);
                } catch (e) {
                    result = { ok: false, error: text };
                }
                root.editDone(editProc.appId, result);
            }
        }
    }

    // ---- Busca de pacotes para instalar (três fontes em paralelo) ----
    property string packageQuery: ""
    property var packageResults: ({ repo: [], aur: [], flatpak: [] })
    readonly property bool packageSearching: repoProc.running || aurProc.running || flatpakProc.running
    readonly property var packageList: packageResults.repo.concat(packageResults.aur, packageResults.flatpak)

    function searchPackages(query) {
        root.packageQuery = query;
        root.packageResults = { repo: [], aur: [], flatpak: [] };
        for (const proc of [repoProc, aurProc, flatpakProc]) {
            proc.running = false;
            proc.query = query;
            proc.command = ["python3", root.appctl, "search", proc.source, query];
            proc.running = true;
        }
    }

    function clearPackages() {
        root.packageQuery = "";
        root.packageResults = { repo: [], aur: [], flatpak: [] };
        for (const proc of [repoProc, aurProc, flatpakProc])
            proc.running = false;
    }

    component PackageSearchProcess: Process {
        id: proc
        required property string source
        property string query
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.query !== root.packageQuery) return; // resposta de uma busca anterior
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {}
                const results = Object.assign({}, root.packageResults);
                results[proc.source] = list;
                root.packageResults = results;
            }
        }
    }
    PackageSearchProcess { id: repoProc; source: "repo" }
    PackageSearchProcess { id: aurProc; source: "aur" }
    PackageSearchProcess { id: flatpakProc; source: "flatpak" }
}
