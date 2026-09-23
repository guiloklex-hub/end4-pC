import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

MouseArea {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property color pillContentColor: Appearance.colors.colOnSecondaryContainer
    // Na tomada, o raio aparece junto do número; alarga a barra só quando precisa (3 dígitos + raio)
    readonly property bool showBolt: root.isCharging || root.isPluggedIn || root.chargeState == UPowerDeviceState.FullyCharged
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    readonly property string displayText: (root.vertical && root.percentage > 99) ? "" : batteryProgress.text

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : batteryProgress.valueBarWidth + 8
    implicitHeight: vertical ? batteryProgress.valueBarWidth + 8 : Appearance.sizes.barHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    ClippedProgressBar {
        id: batteryProgress
        anchors.centerIn: parent
        value: percentage
        rotation: root.vertical ? -90 : 0
        highlightColor: (isLow && !isCharging) ? Appearance.m3colors.m3error : root.pillContentColor
        valueBarWidth: (!root.vertical && root.showBolt && root.percentage >= 0.995) ? 40 : 30
        font.weight: Font.Bold
        Item {
            anchors.centerIn: parent
            width: batteryProgress.valueBarWidth
            height: batteryProgress.valueBarHeight
            // Horizontal
            Loader {
                id: rowLoader
                active: !root.vertical
                visible: active
                anchors.centerIn: parent
                sourceComponent: RowLayout {
                    spacing: 0
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: 2
                        Layout.leftMargin: -2
                        Layout.rightMargin: -2
                        fill: 1
                        text: "bolt"
                        iconSize: Appearance.font.pixelSize.smaller
                        visible: root.showBolt
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: 2
                        font: batteryProgress.font
                        text: batteryProgress.text
                    }
                }
            }
            // Vertical
            Loader {
                id: colLoader
                active: root.vertical
                visible: active
                anchors.centerIn: parent
                sourceComponent: ColumnLayout {
                    rotation: 90
                    spacing: -7
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        fill: 1
                        text: "bolt"
                        Layout.topMargin: 4
                        iconSize: Appearance.font.pixelSize.smaller
                        visible: root.showBolt
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: root.isCharging ? 2 : 4
                        font: batteryProgress.font
                        text: root.percentage * 100 
                        visible: root.percentage < 1
                    }
                }
            }
        }
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}