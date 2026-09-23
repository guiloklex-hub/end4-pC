pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

/**
 * Popup do dock ao passar o mouse: nome do app (app fechado) ou miniaturas ao
 * vivo de cada janela, com título e botão de fechar (app aberto).
 * A captura (ScreencopyView) só existe enquanto o popup está aberto.
 */
PopupWindow {
    id: root

    required property Item anchorItem
    property string appName: ""
    property var toplevels: []
    property bool showPreviews: true
    property int popupEdge: Edges.Top
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool previewMode: showPreviews && toplevels.length > 0
    readonly property real gap: 6
    readonly property real cardWidth: toplevels.length > 5 ? 180 : 232

    signal windowActivated()

    visible: true
    color: "transparent"

    anchor {
        item: root.anchorItem
        edges: root.popupEdge
        gravity: root.popupEdge
        adjustment: PopupAdjustment.Slide
    }

    implicitWidth: background.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: background.implicitHeight + Appearance.sizes.elevationMargin * 2 + gap

    Item {
        anchors.fill: parent

        // Cobre também a margem transparente: atravessar do ícone até o popup não o fecha
        HoverHandler {
            id: hoverHandler
        }

        StyledRectangularShadow {
            target: background
        }

        Rectangle {
            id: background
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: root.popupEdge === Edges.Bottom ? parent.top : undefined
                bottom: root.popupEdge === Edges.Top ? parent.bottom : undefined
                topMargin: Appearance.sizes.elevationMargin + (root.popupEdge === Edges.Bottom ? root.gap : 0)
                bottomMargin: Appearance.sizes.elevationMargin + (root.popupEdge === Edges.Top ? root.gap : 0)
            }
            readonly property real padding: root.previewMode ? 10 : 8
            implicitWidth: content.implicitWidth + padding * 2
            implicitHeight: content.implicitHeight + padding * 2
            color: Appearance.colors.colLayer1Base
            radius: root.previewMode ? Appearance.rounding.normal + 4 : Appearance.rounding.full
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: 8

                // Nome do app (sempre)
                RowLayout {
                    Layout.alignment: root.previewMode ? Qt.AlignLeft : Qt.AlignHCenter
                    Layout.leftMargin: root.previewMode ? 4 : 6
                    Layout.rightMargin: root.previewMode ? 0 : 6
                    spacing: 6
                    StyledText {
                        text: root.appName
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        visible: root.toplevels.length > 1
                        text: `· ${root.toplevels.length} janelas`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                // Miniaturas
                RowLayout {
                    visible: root.previewMode
                    spacing: 8

                    Repeater {
                        model: root.previewMode ? root.toplevels : []

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property bool isActive: modelData?.activated ?? false
                            implicitWidth: root.cardWidth
                            implicitHeight: cardColumn.implicitHeight + 12
                            radius: Appearance.rounding.normal
                            color: cardMouse.containsMouse
                                ? ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.9)
                                : ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.96)
                            border.width: isActive ? 2 : 0
                            border.color: Appearance.colors.colPrimary

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton) {
                                        card.modelData?.close()
                                        return
                                    }
                                    card.modelData?.activate()
                                    root.windowActivated()
                                }
                            }

                            ColumnLayout {
                                id: cardColumn
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 6
                                }
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 2
                                        text: card.modelData?.title || root.appName
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer2
                                    }
                                    RippleButton {
                                        id: closeButton
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colError
                                        colRipple: Appearance.colors.colErrorActive
                                        onClicked: card.modelData?.close()
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "close"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: closeButton.hovered ? Appearance.colors.colOnError : Appearance.colors.colOnLayer1
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: {
                                        const w = preview.sourceSize.width
                                        const ratio = w > 0 ? preview.sourceSize.height / w : 0.6
                                        return Math.max(70, Math.min(170, (root.cardWidth - 12) * ratio))
                                    }
                                    radius: Appearance.rounding.small
                                    color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.94)
                                    clip: true

                                    ScreencopyView {
                                        id: preview
                                        anchors.fill: parent
                                        captureSource: card.modelData
                                        live: true
                                        constraintSize: Qt.size(root.cardWidth * 2, 340)
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: !preview.hasContent
                                        text: "web_asset"
                                        iconSize: 28
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
