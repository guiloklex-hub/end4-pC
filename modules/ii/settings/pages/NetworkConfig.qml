import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.wifiNetworks

ContentPage {
    id: page
    forceWidth: true

    // Card de VPN: aparece só se existir um script `vpn-toggle` (no PATH ou em ~/.local/bin)
    property string vpnTogglePath: ""
    Process {
        running: true
        command: ["sh", "-c", "command -v vpn-toggle || { [ -x \"$HOME/.local/bin/vpn-toggle\" ] && echo \"$HOME/.local/bin/vpn-toggle\"; }"]
        stdout: StdioCollector {
            onStreamFinished: page.vpnTogglePath = text.trim()
        }
    }

    readonly property bool netOnline: Network.ethernet 
        || Network.wifiStatus === "connected" 
        || Network.wifiStatus === "limited"

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

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // 1. STATUS DA CONEXÃO
        ContentSection {
            icon: "wifi"
            shape: MaterialShape.Shape.Square
            title: Translation.tr("Network status")

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
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger + 4
                        implicitSize: 52
                        color: page.netOnline
                            ? Appearance.colors.colPrimaryContainer 
                            : Appearance.colors.colLayer2
                        colSymbol: page.netOnline
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
                                if (Network.ethernet) return Translation.tr("Wired Connection (Ethernet)")
                                if (!Network.wifiEnabled) return Translation.tr("Wi-Fi is turned off")
                                if (Network.wifiStatus === "connected") return Network.networkName || Translation.tr("Connected")
                                if (Network.wifiStatus === "limited") return (Network.networkName ? Network.networkName + " (" + Translation.tr("Limited") + ")" : Translation.tr("Limited connectivity"))
                                if (Network.wifiStatus === "connecting") return Translation.tr("Connecting...")
                                return Translation.tr("Disconnected")
                            }
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSurface
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: page.netOnline

                            StyledText {
                                text: Network.ipAddress !== "" ? ("IP: " + Network.ipAddress) : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: Network.gateway !== "" ? ("• Gateway: " + Network.gateway) : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                                visible: Network.gateway !== ""
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: Network.networkInterface !== "" ? ("• " + Network.networkInterface) : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                                visible: Network.networkInterface !== ""
                                elide: Text.ElideRight
                            }
                        }

                        // Botão de portal cativo para quando o status for limited
                        RippleButtonWithIcon {
                            visible: Network.wifiStatus === "limited"
                            materialIcon: "login"
                            mainText: Translation.tr("Open network portal")
                            onClicked: Network.openPublicWifiPortal()
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        RippleButtonWithIcon {
                            materialIcon: "refresh"
                            mainText: Translation.tr("Scan")
                            visible: Network.wifiEnabled
                            onClicked: Network.rescanWifi()
                        }

                        RippleButtonWithIcon {
                            materialIcon: Network.wifiEnabled ? "wifi_off" : "wifi"
                            mainText: Network.wifiEnabled ? Translation.tr("Turn Off") : Translation.tr("Turn On")
                            toggled: !Network.wifiEnabled
                            colBackground: Appearance.colors.colLayer2
                            colBackgroundToggled: Appearance.colors.colPrimaryContainer
                            onClicked: Network.toggleWifi()
                        }
                    }
                }
            }
        }

        // 2. REDES WI-FI DISPONÍVEIS
        ContentSection {
            icon: "network_wifi"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Available Wi-Fi networks")
            visible: Network.wifiEnabled

            StyledIndeterminateProgressBar {
                visible: Network.wifiScanning
                Layout.fillWidth: true
                Layout.topMargin: -10
                Layout.bottomMargin: 4
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(180, networkListLayout.implicitHeight + 16)
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                clip: true

                ColumnLayout {
                    id: networkListLayout
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 8
                    }
                    spacing: 2

                    Repeater {
                        model: ScriptModel {
                            values: Network.friendlyWifiNetworks
                        }
                        delegate: WifiNetworkItem {
                            required property WifiAccessPoint modelData
                            wifiNetwork: modelData
                            Layout.fillWidth: true
                        }
                    }
                }

                PagePlaceholder {
                    anchors.centerIn: parent
                    icon: "wifi_find"
                    title: Network.wifiScanning ? Translation.tr("Searching for networks...") : Translation.tr("No networks found")
                    shown: Network.friendlyWifiNetworks.length === 0
                    shape: MaterialShape.Shape.Cookie4Sided
                }
            }
        }

        // 3. VPN E ACESSO SEGURO
        ContentSection {
            visible: page.vpnTogglePath !== ""
            icon: "vpn_key"
            shape: MaterialShape.Shape.Diamond
            title: Translation.tr("VPN & Remote access")

            SettingsActionCard {
                icon: "shield_lock"
                iconShape: MaterialShape.Shape.Flower
                title: Translation.tr("Corporate IPsec VPN")
                description: Translation.tr("Connect / disconnect secure gateway tunnel")
                buttonText: Translation.tr("Toggle")
                buttonIcon: "sync_alt"
                action: () => {
                    Applications.launchCommand([page.vpnTogglePath, "toggle"]);
                }
            }
        }

        // 4. CONFIGURAÇÕES AVANÇADAS DE REDE
        ContentSection {
            icon: "tune"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Advanced network tools")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsActionCard {
                    icon: "settings_ethernet"
                    iconShape: MaterialShape.Shape.Square
                    title: Translation.tr("Advanced Network Configuration")
                    description: Translation.tr("NetworkManager connection editor (static IP, DNS, Wi-Fi, Ethernet, VPN, routes)")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["nm-connection-editor"]);
                    }
                }

                SettingsActionCard {
                    icon: "lan"
                    iconShape: MaterialShape.Shape.Pill
                    title: Translation.tr("KDE Network Management")
                    description: Translation.tr("Plasma/KDE network settings control module")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["kcmshell6", "kcm_networkmanagement"]);
                    }
                }

                SettingsActionCard {
                    icon: "wifi_tethering"
                    iconShape: MaterialShape.Shape.PixelCircle
                    title: Translation.tr("Mobile Hotspot")
                    description: Translation.tr("Configure and share internet as a wireless access point")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["kcmshell6", "kcm_mobile_hotspot"]);
                    }
                }
            }
        }
    }
}
