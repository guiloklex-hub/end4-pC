pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

/**
 * Menu de clique direito de um app. `items` é montado por quem abre o menu:
 * { icon, iconName, text, danger, action } ou { separator: true }.
 */
Rectangle {
    id: root

    property var items: []
    signal dismissed()

    implicitWidth: 260
    implicitHeight: column.implicitHeight + 12
    radius: Appearance.rounding.normal
    color: Appearance.m3colors.m3surfaceContainerHigh // opaco: fica por cima do cartão translúcido
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
        id: column
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 6
        }
        spacing: 0

        Repeater {
            model: root.items

            delegate: Loader {
                id: itemLoader
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: modelData.separator ? separatorComponent : rowComponent

                Component {
                    id: separatorComponent
                    Rectangle {
                        implicitHeight: 9
                        color: "transparent"
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            height: 1
                            color: Appearance.colors.colOutlineVariant
                        }
                    }
                }

                Component {
                    id: rowComponent
                    RippleButton {
                        id: rowButton
                        implicitHeight: 38
                        buttonRadius: Appearance.rounding.small
                        colBackgroundHover: itemLoader.modelData.danger ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer2Hover
                        onClicked: {
                            root.dismissed();
                            itemLoader.modelData.action();
                        }

                        contentItem: RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 12

                            Item {
                                implicitWidth: 20
                                implicitHeight: 20
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: !itemLoader.modelData.iconName
                                    text: itemLoader.modelData.icon ?? ""
                                    iconSize: 20
                                    color: itemLoader.modelData.danger ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                                }
                                IconImage {
                                    anchors.centerIn: parent
                                    visible: !!itemLoader.modelData.iconName
                                    implicitSize: 18
                                    source: itemLoader.modelData.iconName ? Quickshell.iconPath(itemLoader.modelData.iconName, "application-x-executable") : ""
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: itemLoader.modelData.text
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: itemLoader.modelData.danger ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }
    }
}
