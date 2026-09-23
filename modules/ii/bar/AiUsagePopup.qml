pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    property var aiData: null

    ColumnLayout {
        id: popupContent
        implicitWidth: 360
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 8

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Flower6
                text: "neurology"
                iconSize: Appearance.font.pixelSize.large
                implicitSize: 38
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    text: "AI Plans & Quotas"
                    font {
                        weight: Font.DemiBold
                        pixelSize: Appearance.font.pixelSize.normal
                    }
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.7
                    text: (root.aiData && root.aiData.totalConfigured > 0)
                        ? `${root.aiData.totalConfigured} planos ativos`
                        : "Verificando cotas..."
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                Layout.rightMargin: 4
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                color: Appearance.colors.colPrimary
                text: root.aiData && root.aiData.primary ? root.aiData.primary.text : "--"
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.3
        }

        // Providers Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Repeater {
                id: providerRepeater
                model: root.aiData ? root.aiData.providers : []
                delegate: ColumnLayout {
                    id: providerEntry
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 4

                    // Provider title
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: providerEntry.modelData.icon || "smart_toy"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            text: providerEntry.modelData.name || ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSurface
                        }
                    }

                    // Cards Flow
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            id: itemRepeater
                            model: providerEntry.modelData.items || []
                            delegate: ResourceCard {
                                id: cardDelegate
                                required property var modelData
                                required property int index
                                cardWidth: (providerEntry.modelData.items.length === 1) ? 356 : 175
                                label: cardDelegate.modelData ? (cardDelegate.modelData.label || "") : ""
                                iconText: {
                                    const lbl = (cardDelegate.modelData?.label || "").toLowerCase();
                                    if (lbl.indexOf("week") !== -1) return "calendar_today";
                                    if (lbl.indexOf("month") !== -1) return "calendar_month";
                                    if (lbl.indexOf("credit") !== -1 || lbl.indexOf("balance") !== -1) return "account_balance_wallet";
                                    return "timer";
                                }
                                iconShape: MaterialShape.Shape.Clover4Leaf
                                value: cardDelegate.modelData ? ((cardDelegate.modelData.pct || 0) / 100) : 0
                                sublabel: cardDelegate.modelData ? (cardDelegate.modelData.reset || cardDelegate.modelData.detail || "") : ""
                                sublabelColor: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        // Footer hint
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 4

            MaterialSymbol {
                text: "touch_app"
                iconSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
                opacity: 0.85
            }

            StyledText {
                text: "Scroll na barra para alternar • Botão direito atualiza"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
                opacity: 0.85
            }
        }
    }
}
