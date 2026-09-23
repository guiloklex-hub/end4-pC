pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

/**
 * Menu de contexto de um app do dock (clique direito): janelas abertas,
 * nova janela, fixar/desafixar e fechar. Fecha ao clicar fora ou com Esc.
 */
PopupWindow {
    id: root

    required property Item anchorItem
    property string appName: ""
    property string appIcon: ""
    property var toplevels: []
    property bool pinned: false
    property int popupEdge: Edges.Top
    readonly property int windowCount: toplevels.length
    readonly property var focusedWindow: toplevels.find(t => t.activated) ?? toplevels[windowCount - 1] ?? null

    signal newWindowRequested()
    signal togglePinRequested()
    signal dismissed()

    function close() {
        root.visible = false
    }
    // Também cobre o fechamento pelo compositor (popup descartado)
    onVisibleChanged: if (!visible) root.dismissed()

    // Executa a ação e fecha o menu
    function run(action) {
        action()
        root.close()
    }

    visible: true
    color: "transparent"

    anchor {
        item: root.anchorItem
        edges: root.popupEdge
        gravity: root.popupEdge
        adjustment: PopupAdjustment.Slide
    }

    implicitWidth: background.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: background.implicitHeight + Appearance.sizes.elevationMargin * 2 + 6

    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.close()
    }

    component MenuEntry: RippleButton {
        id: entry
        property string iconName: ""
        property string label: ""
        property bool danger: false
        Layout.fillWidth: true
        implicitHeight: 36
        buttonRadius: Appearance.rounding.small
        colBackground: "transparent"
        colBackgroundHover: danger
            ? ColorUtils.transparentize(Appearance.colors.colError, 0.8)
            : ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.9)
        colRipple: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            MaterialSymbol {
                text: entry.iconName
                iconSize: Appearance.font.pixelSize.larger
                color: entry.danger ? Appearance.colors.colError : Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: entry.label
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: entry.danger ? Appearance.colors.colError : Appearance.colors.colOnLayer2
            }
        }
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Appearance.colors.colOutlineVariant
        opacity: 0.6
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()

        StyledRectangularShadow {
            target: background
        }

        Rectangle {
            id: background
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: root.popupEdge === Edges.Bottom ? parent.top : undefined
                bottom: root.popupEdge === Edges.Top ? parent.bottom : undefined
                topMargin: Appearance.sizes.elevationMargin + (root.popupEdge === Edges.Bottom ? 6 : 0)
                bottomMargin: Appearance.sizes.elevationMargin + (root.popupEdge === Edges.Top ? 6 : 0)
            }
            implicitWidth: 300
            implicitHeight: column.implicitHeight + 12
            color: Appearance.colors.colLayer1Base
            radius: Appearance.rounding.normal + 4
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: column
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 6
                }
                spacing: 2

                // Cabeçalho: ícone + nome
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 6
                    spacing: 10
                    IconImage {
                        source: root.appIcon
                        implicitSize: 26
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.appName
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer2
                    }
                }

                // Janelas abertas: clicar foca, X fecha aquela janela
                Repeater {
                    model: root.toplevels
                    delegate: RippleButton {
                        id: windowRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.small
                        colBackground: modelData?.activated
                            ? ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.4)
                            : "transparent"
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.9)
                        colRipple: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                        onClicked: root.run(() => windowRow.modelData?.activate())

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 4
                            spacing: 10
                            Rectangle {
                                implicitWidth: 8
                                implicitHeight: 8
                                radius: 4
                                color: windowRow.modelData?.activated ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: windowRow.modelData?.title || root.appName
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer2
                            }
                            RippleButton {
                                id: rowClose
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colError
                                colRipple: Appearance.colors.colErrorActive
                                onClicked: {
                                    windowRow.modelData?.close()
                                    if (root.windowCount <= 1) root.close()
                                }
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: rowClose.hovered ? Appearance.colors.colOnError : Appearance.colors.colOnLayer1
                                }
                            }
                        }
                    }
                }

                Divider {}

                MenuEntry {
                    iconName: "add"
                    label: "Nova janela"
                    onClicked: root.run(() => root.newWindowRequested())
                }
                MenuEntry {
                    iconName: root.pinned ? "keep_off" : "keep"
                    label: root.pinned ? "Desafixar do dock" : "Fixar no dock"
                    onClicked: root.run(() => root.togglePinRequested())
                }

                Divider {
                    visible: root.windowCount > 0
                }

                MenuEntry {
                    visible: root.windowCount > 1
                    iconName: "close"
                    label: "Fechar janela atual"
                    danger: true
                    onClicked: root.run(() => root.focusedWindow?.close())
                }
                MenuEntry {
                    visible: root.windowCount > 0
                    iconName: root.windowCount > 1 ? "close_small" : "close"
                    label: root.windowCount > 1 ? `Fechar todas as janelas (${root.windowCount})` : "Fechar janela"
                    danger: true
                    onClicked: root.run(() => {
                        const windows = root.toplevels.slice()
                        windows.forEach(t => t.close())
                    })
                }
            }
        }
    }
}
