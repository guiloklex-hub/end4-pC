import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.bluetoothDevices

ContentPage {
    id: page
    forceWidth: true

    readonly property bool btAvailable: BluetoothStatus.available
    readonly property bool btEnabled: BluetoothStatus.enabled
    readonly property bool isDiscovering: Bluetooth.defaultAdapter?.discovering ?? false

    function goTo(term) {
        const t = term.toLowerCase().trim()
        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i]
                if (child.title && child.title.toLowerCase().includes(t)) {
                    return child
                }
            }
            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i])
                if (found) return found
            }
            return null
        }

        let target = findTarget(mainLayout)
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0)
            page.contentY = Math.max(0, pos.y)
        }
    }

    Timer {
        id: scanTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (page.btAvailable && Bluetooth.defaultAdapter) {
                Bluetooth.defaultAdapter.discovering = false;
            }
        }
    }

    onVisibleChanged: {
        if (!visible && page.btAvailable && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = false;
            scanTimer.stop();
        }
    }

    Component.onDestruction: {
        if (page.btAvailable && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = false;
            scanTimer.stop();
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // 1. STATUS DO BLUETOOTH E ADAPTADOR
        ContentSection {
            icon: "bluetooth"
            shape: MaterialShape.Shape.Square
            title: Translation.tr("Bluetooth status")

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: statusRow.implicitHeight + 32
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                clip: true

                RowLayout {
                    id: statusRow
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        wrappedShape: MaterialShape.Shape.Circle
                        text: !page.btEnabled ? "bluetooth_disabled" : (BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth")
                        iconSize: Appearance.font.pixelSize.larger + 4
                        implicitSize: 52
                        color: page.btEnabled
                            ? Appearance.colors.colPrimaryContainer 
                            : Appearance.colors.colLayer2
                        colSymbol: page.btEnabled
                            ? Appearance.colors.colOnPrimaryContainer 
                            : Appearance.colors.colOnSurfaceVariant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (!page.btAvailable) return Translation.tr("No Bluetooth adapter found")
                                if (!page.btEnabled) return Translation.tr("Bluetooth is turned off")
                                if (BluetoothStatus.connected) {
                                    const devName = BluetoothStatus.firstActiveDevice?.name || Translation.tr("Device connected")
                                    return BluetoothStatus.activeDeviceCount > 1 
                                        ? devName + " (+" + (BluetoothStatus.activeDeviceCount - 1) + ")" 
                                        : devName
                                }
                                return Translation.tr("Ready to connect")
                            }
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSurface
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: page.btAvailable

                            StyledText {
                                text: Bluetooth.defaultAdapter?.name ? (Translation.tr("Adapter: ") + Bluetooth.defaultAdapter.name) : Translation.tr("Local adapter")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: Bluetooth.defaultAdapter?.adapterId ? ("• " + Bluetooth.defaultAdapter.adapterId) : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                                visible: (Bluetooth.defaultAdapter?.adapterId ?? "") !== ""
                                elide: Text.ElideRight
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8
                        visible: page.btAvailable

                        RippleButtonWithIcon {
                            materialIcon: page.isDiscovering ? "stop" : "refresh"
                            mainText: page.isDiscovering ? Translation.tr("Stop") : Translation.tr("Scan")
                            visible: page.btEnabled
                            toggled: page.isDiscovering
                            onClicked: {
                                if (Bluetooth.defaultAdapter) {
                                    if (page.isDiscovering) {
                                        Bluetooth.defaultAdapter.discovering = false;
                                        scanTimer.stop();
                                    } else {
                                        Bluetooth.defaultAdapter.discovering = true;
                                        scanTimer.restart();
                                    }
                                }
                            }
                        }

                        RippleButtonWithIcon {
                            materialIcon: page.btEnabled ? "bluetooth_disabled" : "bluetooth"
                            mainText: page.btEnabled ? Translation.tr("Turn Off") : Translation.tr("Turn On")
                            toggled: !page.btEnabled
                            colBackground: Appearance.colors.colLayer2
                            colBackgroundToggled: Appearance.colors.colPrimaryContainer
                            onClicked: {
                                if (Bluetooth.defaultAdapter) {
                                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2. DISPOSITIVOS BLUETOOTH
        ContentSection {
            icon: "devices"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Bluetooth devices")
            visible: page.btEnabled

            StyledIndeterminateProgressBar {
                visible: page.isDiscovering
                Layout.fillWidth: true
                Layout.topMargin: -10
                Layout.bottomMargin: 4
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(180, deviceListLayout.implicitHeight + 16)
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                clip: true

                ColumnLayout {
                    id: deviceListLayout
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 8
                    }
                    spacing: 2

                    Repeater {
                        model: ScriptModel {
                            values: BluetoothStatus.friendlyDeviceList
                        }
                        delegate: BluetoothDeviceItem {
                            required property BluetoothDevice modelData
                            device: modelData
                            Layout.fillWidth: true
                        }
                    }
                }

                PagePlaceholder {
                    anchors.centerIn: parent
                    icon: "bluetooth_searching"
                    title: page.isDiscovering ? Translation.tr("Searching for devices...") : Translation.tr("No devices found")
                    shown: BluetoothStatus.friendlyDeviceList.length === 0
                    shape: MaterialShape.Shape.Cookie4Sided
                }
            }
        }

        // 3. FERRAMENTAS AVANÇADAS DE BLUETOOTH
        ContentSection {
            icon: "tune"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Advanced Bluetooth tools")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsActionCard {
                    icon: "settings_bluetooth"
                    iconShape: MaterialShape.Shape.Square
                    title: Translation.tr("Blueman Bluetooth Manager")
                    description: Translation.tr("Advanced device pairing, audio profiles (A2DP/HFP), and file transfers")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["blueman-manager"]);
                    }
                }

                SettingsActionCard {
                    icon: "settings_input_antenna"
                    iconShape: MaterialShape.Shape.Pill
                    title: Translation.tr("Bluetooth Adapters & Visibility")
                    description: Translation.tr("Configure local adapter discoverability, friendly name, and timeout")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["blueman-adapters"]);
                    }
                }

                SettingsActionCard {
                    icon: "bluetooth"
                    iconShape: MaterialShape.Shape.PixelCircle
                    title: Translation.tr("KDE Bluetooth Settings")
                    description: Translation.tr("Plasma/KDE Bluetooth configuration module")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["kcmshell6", "kcm_bluetooth"]);
                    }
                }
            }
        }
    }
}
