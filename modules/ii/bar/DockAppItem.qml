pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Wayland

/**
 * Um app no dock: ícone, indicadores de janelas, dica/miniaturas ao passar o
 * mouse e menu de contexto no clique direito.
 *
 * Esquerdo: abre / foca / alterna janelas. Meio: nova janela.
 * Direito: menu (janelas, nova janela, fixar/desafixar, fechar). Roda: alterna janelas.
 */
Item {
    id: root

    required property string appId
    property var toplevels: []               // janelas deste app (já filtradas por monitor)
    property bool pinned: false
    property real iconSize: 23
    property real btnSize: 28
    property bool vertical: false
    property bool interactionsBlocked: false // durante o arrastar para reordenar
    property bool showPreviews: true
    property int popupEdge: Edges.Top          // lado em que menu/miniaturas abrem

    property var deskEntry: DesktopEntries.heuristicLookup(appId)
    readonly property string appName: deskEntry?.name || appId
    readonly property int windowCount: toplevels.length
    readonly property bool running: windowCount > 0
    readonly property bool focused: toplevels.some(t => t.activated)
    property int _lastFocused: -1

    readonly property bool menuOpen: menuLoader.active
    readonly property bool hovered: button.hovered

    width: btnSize
    height: btnSize

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.deskEntry = DesktopEntries.heuristicLookup(root.appId)
        }
    }

    function launchNew() {
        Applications.launchDesktopEntry(root.deskEntry)
    }

    function cycle(step) {
        if (!running) return
        const n = windowCount
        let idx = root.toplevels.findIndex(t => t.activated)
        if (idx < 0) idx = Math.max(0, Math.min(root._lastFocused, n - 1))
        else idx = (idx + step + n) % n
        root._lastFocused = idx
        root.toplevels[idx].activate()
    }

    function primaryClick() {
        if (!running) { launchNew(); return }
        // App sem foco: traz a última janela usada. Já focado: passa para a próxima.
        if (!focused) {
            const idx = Math.max(0, Math.min(root._lastFocused, windowCount - 1))
            root._lastFocused = idx
            root.toplevels[idx].activate()
        } else {
            cycle(1)
        }
    }

    // ── Botão ─────────────────────────────────────────────────────────────
    RippleButton {
        id: button
        anchors.fill: parent
        buttonRadius: Appearance.rounding.small
        hoverEnabled: true
        toggled: root.focused
        // Fundos explícitos: colLayer1Hover herda a transparência automática (~0.9) e sumiria
        colBackground: root.running
            ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.94)
            : "transparent"
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.86)
        colBackgroundToggled: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.1)
        colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
        colRipple: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.8)
        colRippleToggled: Appearance.colors.colPrimaryContainerActive

        onClicked: {
            if (root.interactionsBlocked) return
            hoverPopupLoader.dismiss()
            root.primaryClick()
        }
        middleClickAction: () => {
            if (root.interactionsBlocked) return
            root.launchNew()
        }
        altAction: () => {
            if (root.interactionsBlocked) return
            hoverPopupLoader.dismiss()
            menuLoader.active = true
        }

        contentItem: Item {
            anchors.fill: parent

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.vertical ? 0 : -1
                source: Quickshell.iconPath(AppSearch.guessIcon(root.appId), "image-missing")
                implicitSize: root.iconSize
                scale: button.hovered && !root.interactionsBlocked ? 1.1 : 1
                Behavior on scale {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            Loader {
                active: Config.options.dock.monochromeIcons
                anchors.fill: appIcon
                sourceComponent: Item {
                    Desaturate {
                        id: desat; visible: false
                        anchors.fill: parent
                        source: appIcon; desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desat; source: desat
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                    }
                }
            }

            // Indicadores: 1 janela = traço (mais largo se em foco); várias = segmentos
            Row {
                id: indicators
                visible: root.running
                spacing: 3
                anchors {
                    bottom: root.vertical ? undefined : parent.bottom
                    bottomMargin: 2
                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                    left: root.vertical ? parent.left : undefined
                    leftMargin: 2
                    verticalCenter: root.vertical ? parent.verticalCenter : undefined
                }
                rotation: root.vertical ? 90 : 0

                Repeater {
                    model: Math.min(root.windowCount, 3)
                    delegate: Rectangle {
                        required property int index
                        implicitHeight: 3
                        implicitWidth: root.windowCount === 1 ? (root.focused ? 20 : 12) : (root.focused ? 8 : 6)
                        radius: Appearance.rounding.full
                        color: root.focused ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                        opacity: root.focused ? 1 : 0.6
                        Behavior on implicitWidth {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (root.interactionsBlocked || !root.running) return
                root.cycle(event.angleDelta.y < 0 ? 1 : -1)
            }
        }
    }

    // ── Dica / miniaturas ao passar o mouse ───────────────────────────────
    LazyLoader {
        id: hoverPopupLoader
        property bool popupHovered: false
        property bool armed: false     // passou o atraso de abertura
        property bool lingering: false // tolerância para atravessar até o popup

        function dismiss() {
            armed = false; lingering = false; popupHovered = false
            openDelay.stop()
        }

        property Timer openDelay: Timer {
            interval: 350
            onTriggered: hoverPopupLoader.armed = true
        }
        property Timer lingerTimer: Timer {
            interval: 250
            onTriggered: hoverPopupLoader.lingering = false
        }
        property bool targetHovered: button.hovered && !root.interactionsBlocked && !root.menuOpen
        readonly property bool wanted: targetHovered || popupHovered || lingering
        onTargetHoveredChanged: {
            if (targetHovered) {
                lingering = false
                if (!armed) openDelay.restart()
            } else {
                openDelay.stop()
                if (armed) { lingering = true; lingerTimer.restart() }
            }
        }
        // Saiu de vez: próximo hover volta a ter o atraso de abertura
        onWantedChanged: if (!wanted) armed = false

        active: armed && wanted && !root.menuOpen && !root.interactionsBlocked

        component: DockHoverPopup {
            anchorItem: root
            appName: root.appName
            toplevels: root.toplevels
            showPreviews: root.showPreviews
            popupEdge: root.popupEdge
            onHoveredChanged: hoverPopupLoader.popupHovered = hovered
            onWindowActivated: hoverPopupLoader.dismiss()
            Component.onDestruction: hoverPopupLoader.popupHovered = false
        }
    }

    // ── Menu de contexto ──────────────────────────────────────────────────
    LazyLoader {
        id: menuLoader
        active: false
        component: DockContextMenu {
            anchorItem: root
            appName: root.appName
            appIcon: Quickshell.iconPath(AppSearch.guessIcon(root.appId), "image-missing")
            toplevels: root.toplevels
            pinned: root.pinned
            popupEdge: root.popupEdge
            onNewWindowRequested: root.launchNew()
            onTogglePinRequested: TaskbarApps.togglePin(root.appId)
            onDismissed: menuLoader.active = false
        }
    }
}
