import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    // Fabricante e modelo do computador (ex.: "LENOVO ThinkPad T14"), lidos do firmware
    property string productName: ""
    Process {
        running: true
        command: ["sh", "-c", "cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name 2>/dev/null | tr '\\n' ' '"]
        stdout: StdioCollector {
            onStreamFinished: page.productName = text.trim()
        }
    }

    function goTo(term) {
        if (!term || typeof term !== "string") return
        const t = term.toLowerCase().trim()
        if (t === "") return

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

    Component.onCompleted: {
        if (SystemInfo.cpu === "") SystemInfo.refresh()
        getPowerProfile.running = true
    }

    property string rawPowerProfile: ""
    readonly property string friendlyPowerProfile: {
        switch (rawPowerProfile) {
            case "performance": return Translation.tr("Performance");
            case "balanced": return Translation.tr("Balanced");
            case "power-saver": return Translation.tr("Power Saver");
            default: return rawPowerProfile !== "" ? rawPowerProfile : Translation.tr("Unknown");
        }
    }

    Process {
        id: getPowerProfile
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim()
                if (p !== "") page.rawPowerProfile = p
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && page.rawPowerProfile === "") {
                page.rawPowerProfile = "unknown"
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // 1. HARDWARE & INFORMAÇÕES DO SISTEMA
        ContentSection {
            icon: "memory"
            shape: MaterialShape.Shape.Diamond
            title: Translation.tr("System & Hardware Status")

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: infoCol.implicitHeight + 32
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                clip: true

                ColumnLayout {
                    id: infoCol
                    anchors {
                        fill: parent
                        margins: 16
                    }
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        MaterialShapeWrappedMaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            wrappedShape: MaterialShape.Shape.Circle
                            text: "laptop_chromebook"
                            iconSize: Appearance.font.pixelSize.larger + 6
                            implicitSize: 52
                            color: Appearance.colors.colPrimaryContainer
                            colSymbol: Appearance.colors.colOnPrimaryContainer
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: [page.productName, SystemInfo.distroName].filter(t => t && t !== "Unknown").join(" • ")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: SystemInfo.kernelVersion !== "" ? `Kernel ${SystemInfo.kernelVersion}` : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        RippleButtonWithIcon {
                            materialIcon: "refresh"
                            mainText: Translation.tr("Refresh")
                            onClicked: {
                                SystemInfo.refresh()
                                getPowerProfile.running = true
                            }
                        }
                    }

                    // Detalhes de hardware em pills / badges
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            height: 30
                            width: Math.min(260, cpuRow.implicitWidth + 20)
                            radius: 15
                            color: Appearance.colors.colLayer2
                            clip: true

                            RowLayout {
                                id: cpuRow
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    text: "speed"
                                    iconSize: 16
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    Layout.maximumWidth: 200
                                    text: SystemInfo.cpu !== "" ? SystemInfo.cpu : "Intel Core i7-1260P"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSurface
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            height: 30
                            width: Math.min(260, gpuRow.implicitWidth + 20)
                            radius: 15
                            color: Appearance.colors.colLayer2
                            clip: true

                            RowLayout {
                                id: gpuRow
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    text: "videogame_asset"
                                    iconSize: 16
                                    color: Appearance.colors.colTertiary
                                }
                                StyledText {
                                    Layout.maximumWidth: 200
                                    text: SystemInfo.gpu !== "" ? SystemInfo.gpu : "Intel Iris Xe Graphics"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSurface
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            height: 30
                            width: Math.min(260, memRow.implicitWidth + 20)
                            radius: 15
                            color: Appearance.colors.colLayer2
                            clip: true

                            RowLayout {
                                id: memRow
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    text: "memory"
                                    iconSize: 16
                                    color: Appearance.colors.colSecondary
                                }
                                StyledText {
                                    Layout.maximumWidth: 200
                                    text: SystemInfo.memory !== "" ? (Translation.tr("RAM: ") + SystemInfo.memory) : Translation.tr("16 GB LPDDR5")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSurface
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            height: 30
                            width: powerRow.implicitWidth + 20
                            radius: 15
                            color: Appearance.colors.colLayer2

                            RowLayout {
                                id: powerRow
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    text: "bolt"
                                    iconSize: 16
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    text: Translation.tr("Power: ") + page.friendlyPowerProfile
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSurface
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2. KERNEL & CACHYOS TWEAKS
        ContentSection {
            icon: "tune"
            shape: MaterialShape.Shape.Flower
            title: Translation.tr("CachyOS Kernel & Optimization Tools")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsActionCard {
                    title: Translation.tr("CachyOS Kernel Manager")
                    description: Translation.tr("Install, update, or configure optimized CachyOS kernels and modules")
                    icon: "memory"
                    iconShape: MaterialShape.Shape.Cookie4Sided
                    action: () => {
                        Applications.launchCommand(["cachyos-kernel-manager"]);
                    }
                }

                SettingsActionCard {
                    title: Translation.tr("Sched-ext CPU Scheduler Manager (scx)")
                    description: Translation.tr("Configure BPF CPU schedulers like scx_rusty, scx_lavd, or scx_bpfland")
                    icon: "speed"
                    iconShape: MaterialShape.Shape.Pill
                    action: () => {
                        Applications.launchCommand(["scx-manager"]);
                    }
                }

                SettingsActionCard {
                    title: Translation.tr("CachyOS Hello & Tweaks")
                    description: Translation.tr("Welcome center, driver installer, system tweaks, and apps")
                    icon: "handshake"
                    iconShape: MaterialShape.Shape.Flower
                    action: () => {
                        Applications.launchCommand(["cachyos-hello"]);
                    }
                }
            }
        }

        // 3. ARMAZENAMENTO & GERENCIAMENTO DE PACOTES
        ContentSection {
            icon: "folder"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Storage, Snapshots & Packages")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsActionCard {
                    title: Translation.tr("Btrfs Assistant & Snapper")
                    description: Translation.tr("Manage Btrfs subvolumes, Snapper system restore points, and disk maintenance")
                    icon: "history"
                    iconShape: MaterialShape.Shape.Bun
                    action: () => {
                        Applications.launchCommand(["btrfs-assistant-launcher"]);
                    }
                }

                SettingsActionCard {
                    title: Translation.tr("Software & Package Manager (Pamac)")
                    description: Translation.tr("Graphical installer for official CachyOS/Arch repositories, AUR, and Flatpak")
                    icon: "package_2"
                    iconShape: MaterialShape.Shape.Clover4Leaf
                    action: () => {
                        Applications.launchCommand(["pamac-manager"]);
                    }
                }
            }
        }

        // 4. DISPLAYS, MONITORES & TEMAS VISUAIS
        ContentSection {
            icon: "display_settings"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Displays & Visual Appearance Tools")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsActionCard {
                    title: Translation.tr("Display Layout (wdisplays)")
                    description: Translation.tr("Configure multi-monitor layout, resolution, refresh rate, and orientation")
                    icon: "display_settings"
                    iconShape: MaterialShape.Shape.PixelCircle
                    action: () => {
                        Applications.launchCommand(["wdisplays"]);
                    }
                }

                SettingsActionCard {
                    title: Translation.tr("Display Layout (nwg-displays)")
                    description: Translation.tr("Alternative graphical output manager with monitor workspace assignments")
                    icon: "desktop_windows"
                    iconShape: MaterialShape.Shape.Circle
                    action: () => {
                        Applications.launchCommand(["nwg-displays"]);
                    }
                }

                SettingsActionCard {
                    title: Translation.tr("GTK Look & Feel (nwg-look)")
                    description: Translation.tr("Configure GTK themes, icon packs, cursors, and system fonts")
                    icon: "palette"
                    iconShape: MaterialShape.Shape.Diamond
                    action: () => {
                        Applications.launchCommand(["nwg-look"]);
                    }
                }

                SettingsActionCard {
                    title: Translation.tr("Qt6 Style Settings (qt6ct)")
                    description: Translation.tr("Fine-tune Qt6 application palette, style plugins, and font rendering")
                    icon: "brush"
                    iconShape: MaterialShape.Shape.Square
                    action: () => {
                        Applications.launchCommand(["qt6ct"]);
                    }
                }
            }
        }
    }
}
