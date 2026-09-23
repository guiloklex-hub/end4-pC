pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.overview
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

/**
 * Menu de apps (botão de apps do dock / Super+Espaço): busca, fixados,
 * recentes, todos os apps por categoria, menu de contexto e diálogos de
 * detalhes, edição e desinstalação.
 */
Scope {
    id: root

    property var targetScreen: Quickshell.screens[0]
    readonly property var window: drawerLoader.item

    Connections {
        target: GlobalStates
        function onAppDrawerOpenChanged() {
            if (!GlobalStates.appDrawerOpen) return;
            GlobalStates.overviewOpen = false;
            const focusedName = Hyprland.focusedMonitor?.name;
            root.targetScreen = Quickshell.screens.find(s => s.name === focusedName) ?? Quickshell.screens[0];
        }
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) GlobalStates.appDrawerOpen = false;
        }
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) GlobalStates.appDrawerOpen = false;
        }
    }

    // Janela criada uma vez e só mostrada/escondida: a primeira montagem da grade leva ~1 s
    LazyLoader {
        id: drawerLoader
        active: Config.ready
        component: PanelWindow {
            id: win
            screen: root.targetScreen
            visible: GlobalStates.appDrawerOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:appDrawer"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // O dock continua clicável (o botão de apps fecha o menu), exceto durante um arraste
            mask: Region {
                item: inputArea
            }

            readonly property real dockHeight: Config.options.dock.enable ? Math.max(38, Config.options.dock.height ?? 52) : 0
            readonly property real topReserved: !Config.options.bar.vertical && !Config.options.bar.bottom ? Appearance.sizes.barHeight : 0
            readonly property real tileWidth: 104
            readonly property real tileHeight: 108

            property string query: ""
            property string category: "all"
            property bool showRecents: false
            property bool showHidden: false

            readonly property var searchPrefixes: ["action", "clipboard", "emojis", "symbols", "math", "shellCommand", "webSearch"]
                .map(k => Config.options.search.prefix[k]).filter(p => p && p.length > 0)
            readonly property bool prefixedQuery: searchPrefixes.some(p => query.startsWith(p))
            readonly property string appQuery: StringUtils.cleanPrefix(query, Config.options.search.prefix.app).trim()
            readonly property var searchApps: (query.length > 0 && !prefixedQuery) ? AppCatalog.search(appQuery).slice(0, 24) : []
            // Sem número na busca, o qalc "calcula" palavras como unidades ("obsidian" vira bit·g·m³)
            readonly property bool queryHasDigit: /\d/.test(query)
            readonly property var otherResults: query.length > 0
                ? LauncherSearch.results.filter(r => r.type !== Translation.tr("App")
                    && (queryHasDigit || prefixedQuery || r.type !== Translation.tr("Math result"))).slice(0, 8)
                : []

            readonly property var gridApps: {
                const source = win.showHidden ? AppCatalog.apps : AppCatalog.visibleApps;
                return win.category === "all" ? source : source.filter(a => AppCatalog.categoryOf(a) === win.category);
            }
            readonly property var rowApps: win.showRecents
                ? AppCatalog.entriesFor(AppCatalog.recentIds)
                : AppCatalog.entriesFor(AppCatalog.menuPins)

            // Menu de contexto, diálogo e arraste
            property var menuEntry: null
            property var menuItems: []
            property real menuX: 0
            property real menuY: 0
            property var dialogEntry: null
            property string dialogKind: ""
            property var dragEntry: null
            property real dragX: 0
            property real dragY: 0
            readonly property bool dragOverDock: dragEntry !== null && dragY >= height - dockHeight
            readonly property bool dragOverPins: {
                if (dragEntry === null || win.showRecents || win.query.length > 0) return false;
                const p = pinsArea.mapToItem(null, 0, 0);
                return dragX >= p.x && dragX <= p.x + pinsArea.width && dragY >= p.y && dragY <= p.y + pinsArea.height;
            }

            function close() {
                GlobalStates.appDrawerOpen = false;
            }

            function search(text) {
                searchField.text = text;
            }

            function setQuery(text) {
                win.query = text;
                LauncherSearch.query = text;
            }

            function openMenu(entry, x, y) {
                const e = entry;
                const items = [{ icon: "open_in_new", text: Translation.tr("Open"), action: () => AppCatalog.launch(e) }];
                for (const action of (e.actions ?? []))
                    items.push({ iconName: action.icon || e.icon, text: action.name, action: () => AppCatalog.launchAction(action) });
                items.push({ separator: true });
                const menuPinned = AppCatalog.isMenuPinned(e);
                items.push({ icon: "keep", text: menuPinned ? Translation.tr("Unpin from menu") : Translation.tr("Pin to menu"), action: () => AppCatalog.toggleMenuPin(e) });
                if (menuPinned && AppCatalog.menuPins.indexOf(e.id) > 0)
                    items.push({ icon: "first_page", text: Translation.tr("Move to front"), action: () => LauncherApps.moveToFront(e.id) });
                items.push({ icon: "dock_to_bottom", text: AppCatalog.isDockPinned(e) ? Translation.tr("Unpin from dock") : Translation.tr("Pin to dock"), action: () => AppCatalog.toggleDockPin(e) });
                items.push({ icon: AppCatalog.isHidden(e) ? "visibility" : "visibility_off", text: AppCatalog.isHidden(e) ? Translation.tr("Show in menu") : Translation.tr("Hide from menu"), action: () => AppCatalog.toggleHidden(e) });
                items.push({ icon: "edit", text: Translation.tr("Edit name and icon…"), action: () => win.openDialog("edit", e) });
                items.push({ icon: "info", text: Translation.tr("Details"), action: () => win.openDialog("details", e) });
                items.push({ separator: true });
                items.push({ icon: "delete", text: Translation.tr("Uninstall…"), danger: true, action: () => win.openDialog("uninstall", e) });
                win.menuItems = items;
                win.menuX = x;
                win.menuY = y;
                win.menuEntry = e;
            }

            function closeMenu() {
                win.menuEntry = null;
            }

            function openDialog(kind, entry) {
                win.closeMenu();
                win.dialogEntry = entry;
                win.dialogKind = kind;
            }

            function closeDialog() {
                win.dialogKind = "";
                win.dialogEntry = null;
                searchField.forceActiveFocus();
            }

            function showToast(text) {
                toast.text = text;
                toast.opacity = 1;
                toastTimer.restart();
            }

            function startDrag(entry, x, y) {
                win.closeMenu();
                win.dragEntry = entry;
                win.dragX = x;
                win.dragY = y;
            }

            function endDrag(x, y) {
                const entry = win.dragEntry;
                const overDock = win.dragOverDock;
                const overPins = win.dragOverPins;
                win.dragEntry = null;
                if (!entry || x < 0) return;
                if (overDock) {
                    if (AppCatalog.isDockPinned(entry)) {
                        win.showToast(Translation.tr("%1 is already in the dock").arg(entry.name));
                    } else {
                        AppCatalog.pinToDock(entry);
                        win.showToast(Translation.tr("%1 pinned to the dock").arg(entry.name));
                    }
                } else if (overPins && !AppCatalog.isMenuPinned(entry)) {
                    AppCatalog.toggleMenuPin(entry);
                    win.showToast(Translation.tr("%1 pinned to the menu").arg(entry.name));
                }
            }

            // Grade que recebe as setas/Enter: resultados da busca ou todos os apps
            readonly property AppGrid activeGrid: query.length > 0 ? searchGrid : allGrid

            function openMenuForCurrent() {
                const grid = win.activeGrid;
                const item = grid.selectedItem();
                if (!item) return;
                const p = item.mapToItem(null, item.width / 2, item.height / 2);
                win.openMenu(grid.selectedEntry(), p.x, p.y);
            }

            function handleKey(event) {
                const grid = win.activeGrid;
                if (event.key === Qt.Key_Escape) {
                    if (win.menuEntry) win.closeMenu();
                    else if (win.dialogKind !== "") win.closeDialog();
                    else if (win.query.length > 0) searchField.text = "";
                    else win.close();
                    event.accepted = true;
                    return;
                }
                // Com menu/diálogo aberto, nada chega à busca que fica atrás
                if (win.dialogKind !== "" || win.menuEntry) {
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                    win.openMenuForCurrent();
                    event.accepted = true;
                    return;
                }
                const nav = {
                    [Qt.Key_Down]: [0, 1],
                    [Qt.Key_Up]: [0, -1],
                    [Qt.Key_Right]: [1, 0],
                    [Qt.Key_Left]: [-1, 0],
                };
                if (nav[event.key] && grid.count > 0) {
                    grid.move(nav[event.key][0], nav[event.key][1]);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (grid.selectedEntry()) {
                        AppCatalog.launch(grid.selectedEntry());
                    } else if (win.query.length > 0 && win.otherResults.length > 0) {
                        win.otherResults[0].execute();
                        win.close();
                    }
                    event.accepted = true;
                }
            }

            // Clique em outra janela (dock, barra, app) fecha o menu
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.appDrawerOpen = false;
                }
            }

            // Cada abertura começa do zero
            Connections {
                target: GlobalStates
                function onAppDrawerOpenChanged() {
                    if (GlobalStates.appDrawerOpen) {
                        searchField.text = "";
                        win.category = "all";
                        win.showRecents = AppCatalog.menuPins.length === 0;
                        allGrid.selected = -1;
                        allGrid.positionViewAtBeginning();
                        openAnimation.restart();
                        searchField.forceActiveFocus();
                        GlobalFocusGrab.addDismissable(win);
                    } else {
                        GlobalFocusGrab.removeDismissable(win);
                        win.closeMenu();
                        win.dialogKind = "";
                        win.dialogEntry = null;
                        win.dragEntry = null;
                        LauncherSearch.query = "";
                    }
                }
            }

            Item {
                id: inputArea
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: win.dragEntry ? win.height : win.height - win.dockHeight
            }

            // Fundo: clique fora do cartão fecha o menu de contexto/diálogo ou o menu de apps
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: {
                    if (win.menuEntry) win.closeMenu();
                    else if (win.dialogKind !== "") win.closeDialog();
                    else win.close();
                }
            }

            StyledRectangularShadow {
                target: card
            }

            Rectangle {
                id: card
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: win.dockHeight + 12
                }
                readonly property int columns: Math.max(4, Math.min(8, Math.floor((win.width - 64 - 40) / win.tileWidth)))
                width: columns * win.tileWidth + 40 + 12
                height: Math.min(win.height - win.dockHeight - win.topReserved - 36, 820)
                radius: Appearance.rounding.windowRounding
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                property real openProgress: 0
                opacity: openProgress
                transform: Translate {
                    y: (1 - card.openProgress) * 40
                }
                NumberAnimation {
                    id: openAnimation
                    target: card
                    property: "openProgress"
                    from: 0
                    to: 1
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                }

                MouseArea { // Cliques dentro do cartão não chegam ao fundo
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: win.closeMenu()
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 20
                    }
                    spacing: 14

                    // ---------------- Busca ----------------
                    ToolbarTextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        implicitHeight: 48
                        leftPadding: 48
                        font.pixelSize: Appearance.font.pixelSize.normal
                        placeholderText: Translation.tr("Search apps, calculate, run or install…")
                        colBackground: Appearance.colors.colLayer1
                        focus: true
                        onTextChanged: {
                            win.setQuery(text);
                            searchGrid.selected = text.length > 0 ? 0 : -1;
                            autoPackageSearch.restart();
                        }
                        Keys.priority: Keys.BeforeItem
                        Keys.onPressed: event => win.handleKey(event)

                        MaterialSymbol {
                            anchors {
                                left: parent.left
                                leftMargin: 16
                                verticalCenter: parent.verticalCenter
                            }
                            text: "search"
                            iconSize: 22
                            color: Appearance.colors.colSubtext
                        }
                    }

                    // ---------------- Início: fixados/recentes + todos ----------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: win.query.length === 0
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { recents: false, text: Translation.tr("Pinned apps"), icon: "keep" },
                                    { recents: true, text: Translation.tr("Recently opened"), icon: "history" },
                                ]
                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.text
                                    symbol: modelData.icon
                                    selected: win.showRecents === modelData.recents
                                    onClicked: win.showRecents = modelData.recents
                                }
                            }
                            Item { Layout.fillWidth: true }
                            StyledText {
                                visible: !win.showRecents
                                text: Translation.tr("Right-click or drag an app here to pin it")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Item {
                            id: pinsArea
                            Layout.fillWidth: true
                            implicitHeight: Math.max(1, Math.min(2, Math.ceil(win.rowApps.length / card.columns))) * win.tileHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.normal
                                color: win.dragOverPins ? Appearance.colors.colPrimaryContainer : "transparent"
                                border.width: win.dragEntry && !win.showRecents ? 1 : 0
                                border.color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                anchors.centerIn: parent
                                visible: win.rowApps.length === 0
                                text: win.showRecents ? Translation.tr("Apps you open show up here") : Translation.tr("No pinned apps yet")
                                color: Appearance.colors.colSubtext
                            }

                            AppGrid {
                                id: pinsGrid
                                anchors.fill: parent
                                interactive: false
                                model: win.rowApps.slice(0, card.columns * 2)
                                drawer: win
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: AppCatalog.categories
                                delegate: Chip {
                                    required property var modelData
                                    label: `${modelData.name}  ${modelData.count}`
                                    symbol: modelData.icon
                                    selected: win.category === modelData.key
                                    onClicked: {
                                        win.category = modelData.key;
                                        allGrid.selected = -1;
                                        allGrid.positionViewAtBeginning();
                                    }
                                }
                            }
                        }

                        AppGrid {
                            id: allGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: win.gridApps
                            drawer: win
                            ScrollBar.vertical: StyledScrollBar {}
                        }
                    }

                    // ---------------- Resultados da busca ----------------
                    StyledFlickable {
                        id: searchFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: win.query.length > 0
                        clip: true
                        contentHeight: searchColumn.implicitHeight
                        ScrollBar.vertical: StyledScrollBar {}

                        ColumnLayout {
                            id: searchColumn
                            width: searchFlick.width
                            spacing: 8

                            SectionLabel {
                                visible: win.searchApps.length > 0
                                text: Translation.tr("Apps")
                            }
                            AppGrid {
                                id: searchGrid
                                Layout.fillWidth: true
                                implicitHeight: Math.ceil(count / card.columns) * win.tileHeight
                                interactive: false
                                model: win.searchApps
                                drawer: win
                            }

                            SectionLabel {
                                visible: win.otherResults.length > 0
                                text: win.prefixedQuery ? Translation.tr("Results") : Translation.tr("Other results")
                            }
                            Repeater {
                                model: win.otherResults
                                delegate: SearchItem {
                                    id: resultItem
                                    required property var modelData
                                    Layout.fillWidth: true
                                    entry: modelData
                                    query: win.appQuery
                                    Connections {
                                        target: resultItem
                                        function onClicked() {
                                            win.close();
                                        }
                                    }
                                }
                            }

                            // Instalar: busca nos repositórios, AUR e Flathub
                            SectionLabel {
                                visible: !win.prefixedQuery && win.appQuery.length >= 2
                                text: Translation.tr("Install")
                            }
                            RippleButton {
                                Layout.fillWidth: true
                                visible: !win.prefixedQuery && win.appQuery.length >= 2 && AppCatalog.packageQuery !== win.appQuery
                                implicitHeight: 44
                                buttonRadius: Appearance.rounding.small
                                colBackground: Appearance.colors.colLayer1
                                onClicked: AppCatalog.searchPackages(win.appQuery)
                                contentItem: RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 14
                                        rightMargin: 14
                                    }
                                    spacing: 12
                                    MaterialSymbol {
                                        text: "travel_explore"
                                        iconSize: 22
                                        color: Appearance.colors.colPrimary
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("Search “%1” in the repositories, AUR and Flathub").arg(win.appQuery)
                                        color: Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            StyledIndeterminateProgressBar {
                                Layout.fillWidth: true
                                visible: AppCatalog.packageSearching && AppCatalog.packageQuery === win.appQuery
                            }
                            StyledText {
                                visible: !AppCatalog.packageSearching && AppCatalog.packageQuery === win.appQuery && AppCatalog.packageList.length === 0
                                text: Translation.tr("No packages found")
                                color: Appearance.colors.colSubtext
                            }
                            Repeater {
                                model: AppCatalog.packageQuery === win.appQuery ? AppCatalog.packageList : []
                                delegate: PackageRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 6
                                    Layout.rightMargin: 6
                                    pkg: modelData
                                }
                            }
                        }
                    }

                    Timer {
                        id: autoPackageSearch
                        interval: 700
                        // Sem app instalado com esse nome: já procura o que dá para instalar
                        onTriggered: {
                            if (!win.prefixedQuery && win.appQuery.length >= 3 && win.searchApps.length === 0 && AppCatalog.packageQuery !== win.appQuery)
                                AppCatalog.searchPackages(win.appQuery);
                        }
                    }

                    // ---------------- Rodapé ----------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ClippingRectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colLayer1
                            Image {
                                anchors.fill: parent
                                source: SystemInfo.username !== "user" ? `file://${Directories.userAvatarPathAccountsService}` : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(68, 68)
                                asynchronous: true
                            }
                        }
                        StyledText {
                            text: SystemInfo.username
                            color: Appearance.colors.colOnLayer0
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: Translation.tr("%1 apps").arg(AppCatalog.visibleApps.length)
                                + (AppCatalog.hiddenApps.length > 0 ? " · " + Translation.tr("%1 hidden").arg(AppCatalog.hiddenApps.length) : "")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        FooterButton {
                            visible: AppCatalog.hiddenApps.length > 0
                            symbol: win.showHidden ? "visibility" : "visibility_off"
                            tooltip: win.showHidden ? Translation.tr("Hide hidden apps") : Translation.tr("Show hidden apps")
                            toggled: win.showHidden
                            onClicked: win.showHidden = !win.showHidden
                        }
                        FooterButton {
                            symbol: "settings"
                            tooltip: Translation.tr("Settings")
                            onClicked: {
                                win.close();
                                GlobalStates.settingsOpen = true;
                            }
                        }
                        FooterButton {
                            symbol: "power_settings_new"
                            tooltip: Translation.tr("Session")
                            onClicked: {
                                win.close();
                                GlobalStates.sessionOpen = true;
                            }
                        }
                    }
                }

                // ---------------- Aviso rápido ----------------
                Rectangle {
                    id: toast
                    property alias text: toastText.text
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: 70
                    }
                    implicitWidth: toastText.implicitWidth + 32
                    implicitHeight: toastText.implicitHeight + 16
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colTooltip
                    opacity: 0
                    visible: opacity > 0
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    StyledText {
                        id: toastText
                        anchors.centerIn: parent
                        color: Appearance.colors.colOnTooltip
                    }
                    Timer {
                        id: toastTimer
                        interval: 1800
                        onTriggered: toast.opacity = 0
                    }
                }

                // ---------------- Diálogos ----------------
                Rectangle {
                    anchors.fill: parent
                    radius: card.radius
                    visible: win.dialogKind !== ""
                    color: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.35)

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: win.closeDialog()
                    }

                    Loader {
                        anchors.centerIn: parent
                        width: Math.min(560, card.width - 48)
                        active: win.dialogKind !== "" && win.dialogEntry !== null
                        sourceComponent: win.dialogKind === "details" ? detailsComponent
                            : win.dialogKind === "uninstall" ? uninstallComponent
                            : editComponent

                        Component {
                            id: detailsComponent
                            AppDetailsDialog {
                                entry: win.dialogEntry
                                onCloseRequested: win.closeDialog()
                                onUninstallRequested: win.openDialog("uninstall", win.dialogEntry)
                            }
                        }
                        Component {
                            id: uninstallComponent
                            AppUninstallDialog {
                                entry: win.dialogEntry
                                onCloseRequested: win.closeDialog()
                            }
                        }
                        Component {
                            id: editComponent
                            AppEditDialog {
                                entry: win.dialogEntry
                                onCloseRequested: win.closeDialog()
                            }
                        }
                    }
                }
            }

            // ---------------- Menu de contexto ----------------
            AppContextMenu {
                id: contextMenu
                visible: win.menuEntry !== null
                items: win.menuItems
                x: Math.max(8, Math.min(win.menuX, win.width - width - 8))
                y: Math.max(8, Math.min(win.menuY, win.height - win.dockHeight - height - 8))
                onDismissed: win.closeMenu()
            }

            // ---------------- Arraste para o dock ----------------
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: win.dockHeight
                visible: win.dragEntry !== null && win.dockHeight > 0
                color: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, win.dragOverDock ? 0.05 : 0.35)
                border.width: 2
                border.color: win.dragOverDock ? Appearance.colors.colPrimary : "transparent"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol {
                        text: "dock_to_bottom"
                        iconSize: 22
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        text: Translation.tr("Drop here to pin to the dock")
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
            }

            IconImage {
                visible: win.dragEntry !== null
                x: win.dragX - implicitSize / 2
                y: win.dragY - implicitSize / 2
                implicitSize: 56
                source: Quickshell.iconPath(win.dragEntry?.icon ?? "", "application-x-executable")
            }

            // ---------------- Componentes locais ----------------
            component SectionLabel: StyledText {
                Layout.topMargin: 4
                Layout.leftMargin: 6
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            component Chip: RippleButton {
                id: chip
                property string symbol
                property string label
                property bool selected: false
                buttonText: ""
                implicitHeight: 32
                implicitWidth: chipRow.implicitWidth + 24
                buttonRadius: Appearance.rounding.full
                toggled: selected
                colBackground: Appearance.colors.colLayer1
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                contentItem: Item {
                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: chip.symbol
                            iconSize: 18
                            color: chip.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: chip.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: chip.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            component FooterButton: RippleButton {
                id: footerButton
                property string symbol
                property string tooltip
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                contentItem: Item {
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: footerButton.symbol
                        iconSize: 22
                        color: footerButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                    }
                }
                StyledToolTip {
                    text: footerButton.tooltip
                }
            }
        }
    }

    IpcHandler {
        target: "appDrawer"

        function toggle(): void {
            GlobalStates.appDrawerOpen = !GlobalStates.appDrawerOpen;
        }
        function open(): void {
            GlobalStates.appDrawerOpen = true;
        }
        function close(): void {
            GlobalStates.appDrawerOpen = false;
        }
        function search(query: string): void {
            GlobalStates.appDrawerOpen = true;
            root.window?.search(query);
        }
    }

    CompositorGlobalShortcut {
        name: "appDrawerToggle"
        description: "Toggles the app drawer"
        onPressed: GlobalStates.appDrawerOpen = !GlobalStates.appDrawerOpen
    }
}
