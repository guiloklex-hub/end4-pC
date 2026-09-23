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

            readonly property real barHeight: 38

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
                spacing: 6

                // Menu / Start button
                RippleButton {
                    id: menuBtn
                    implicitWidth: 32
                    implicitHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    buttonRadius: Appearance.rounding.small
                    hoverEnabled: true

                    colBackground: GlobalStates.overviewOpen ? Appearance.colors.colPrimaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colPrimaryActive
                    toggled: GlobalStates.overviewOpen

                    onClicked: {
                        GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                    }

                    contentItem: Item {
                        anchors.fill: parent
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 20
                            text: "apps"
                            color: menuBtn.hovered || menuBtn.toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                        }
                    }
                }

                // Subtle vertical divider
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 18
                    color: Appearance.colors.colOutlineVariant
                    opacity: 0.35
                    Layout.alignment: Qt.AlignVCenter
                }

                // Application icons (small, pinned + active apps with status dots)
                DocktoPanel {
                    id: dockApps
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}

