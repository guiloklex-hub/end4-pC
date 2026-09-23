pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked

            property var monitor: WM.monitorFor(modelData)
            property bool fullscreenOnThisMonitor: WM.fullscreenOnMonitor(monitor?.name)

            // Tamanho vem de dock.height no config.json; ícones e botões escalam junto
            readonly property real barHeight: Math.max(38, Config.options?.dock.height ?? 52)
            readonly property real btnSize: barHeight - 8
            readonly property real iconSize: Math.round(btnSize * 0.77)

            anchors {
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: fullscreenOnThisMonitor ? 0 : barHeight
            implicitHeight: barHeight
            color: "transparent"

            // Full-width background across the bottom of the screen (Windows taskbar style)
            Rectangle {
                id: barBackground
                anchors.fill: parent
                color: Appearance.colors.colLayer0

                // 1px top border line
                Rectangle {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Appearance.colors.colLayer0Border
                }
            }

            // Centered apps & menu (Windows 11 style)
            RowLayout {
                id: centerRow
                anchors.centerIn: parent
                spacing: 8

                // Menu / Start button
                RippleButton {
                    id: menuBtn
                    implicitWidth: dockRoot.btnSize
                    implicitHeight: dockRoot.btnSize
                    Layout.alignment: Qt.AlignVCenter
                    buttonRadius: Appearance.rounding.small
                    hoverEnabled: true

                    colBackground: GlobalStates.appDrawerOpen ? Appearance.colors.colPrimaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colPrimaryActive
                    toggled: GlobalStates.appDrawerOpen

                    // Abre o menu de apps (as janelas dos workspaces ficam no Super+Tab)
                    onClicked: AppCatalog.toggleDrawer()

                    contentItem: Item {
                        anchors.fill: parent
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Math.round(dockRoot.iconSize * 0.8)
                            text: "apps"
                            color: menuBtn.toggled ? Appearance.colors.colOnPrimary : menuBtn.hovered ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                        }
                    }
                }

                // Subtle vertical divider
                Rectangle {
                    implicitWidth: 2
                    implicitHeight: Math.round(dockRoot.btnSize * 0.55)
                    radius: 1
                    color: Appearance.colors.colOutline
                    opacity: 0.6
                    Layout.alignment: Qt.AlignVCenter
                }

                // Application icons (small, pinned + active apps with status dots)
                DocktoPanel {
                    id: dockApps
                    Layout.alignment: Qt.AlignVCenter
                    vertical: false
                    screen: dockRoot.screen
                    iconSize: dockRoot.iconSize
                    btnSize: dockRoot.btnSize
                    btnSpacing: 6
                    popupEdge: Edges.Top
                }
            }
        }
    }
}

