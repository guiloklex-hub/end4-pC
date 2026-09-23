import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property string iconName
    required property double percentage
    property bool vertical: false
    property int warningThreshold: 100
    property bool shown: true
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property string valueSuffix: ""
    // Vermelho que contrasta com o fundo do grupo: conteúdo escuro => fundo claro => errorContainer (escuro)
    readonly property color warningColor: contentColor.hslLightness < 0.5 ? Appearance.m3colors.m3errorContainer : Appearance.colors.colError
    clip: !vertical
    visible: vertical ? true : width > 0 && height > 0
    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : (resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth)
    implicitHeight: vertical ? resourceProgress.implicitHeight : Appearance.sizes.barHeight
    property bool warning: percentage * 100 >= warningThreshold

    Component {
        id: outlineStyle
        ClippedOutlineCircularProgress {
            lineWidth: Appearance.rounding.unsharpen
            value: root.percentage
            implicitSize: vertical ? 20 : 20
            colPrimary: root.warning ? root.warningColor : root.contentColor
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 20
                height: 20
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: Font.DemiBold
                    fill: 1
                    text: root.iconName
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.warning ? root.warningColor : root.contentColor
                }
            }
        }
    }

    Component {
        id: filledStyle
        ClippedFilledCircularProgress {
            lineWidth: Appearance.rounding.unsharpen
            value: root.percentage
            implicitSize: 20
            colPrimary: root.warning ? root.warningColor : root.contentColor
            accountForLightBleeding: !root.warning
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 20
                height: 20
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: vertical ? Font.Medium : Font.DemiBold
                    fill: 1
                    text: root.iconName
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.contentColor
                }
            }
        }
    }

    // Vertical
    Loader {
        id: resourceProgress
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: Config.options.bar.resources.style === "filled" ? filledStyle : outlineStyle
    }

    // Horizontal
    RowLayout {
        id: resourceRowLayout
        visible: !root.vertical
        spacing: 2
        x: shown ? 0 : -resourceRowLayout.width
        anchors.verticalCenter: parent.verticalCenter

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: !root.vertical
            visible: active
            sourceComponent: Config.options.bar.resources.style === "filled" ? filledStyle : outlineStyle
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            visible: Config.options.bar.resources.showValue
            implicitWidth: visible ? fullPercentageTextMetrics.width : 0
            implicitHeight: percentageText.implicitHeight
            TextMetrics {
                id: fullPercentageTextMetrics
                text: "100" + root.valueSuffix
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                id: percentageText
                anchors.centerIn: parent
                color: root.warning ? root.warningColor : root.contentColor
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                text: `${Math.round(root.percentage * 100).toString()}${root.valueSuffix}`
            }
        }

        Behavior on x {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: vertical ? root.visible : (resourceRowLayout.x >= 0 && root.width > 0 && root.visible)
    }

    Behavior on implicitWidth {
        enabled: false
    }
}
