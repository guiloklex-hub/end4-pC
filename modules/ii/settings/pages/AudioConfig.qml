import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.volumeMixer

ContentPage {
    id: page
    forceWidth: true

    readonly property real outVolume: Audio.sink?.audio?.volume ?? 0
    readonly property bool outMuted: Audio.sink?.audio?.muted ?? false
    readonly property real inVolume: Audio.source?.audio?.volume ?? 0
    readonly property bool inMuted: Audio.source?.audio?.muted ?? false

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

        // 1. DISPOSITIVOS DE SOM (SAÍDA E ENTRADA)
        ContentSection {
            icon: "volume_up"
            shape: MaterialShape.Shape.Square
            title: Translation.tr("Audio devices")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                // SAÍDA DE ÁUDIO (SPEAKERS / HEADPHONES)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: outputCol.implicitHeight + 32
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    ColumnLayout {
                        id: outputCol
                        anchors {
                            fill: parent
                            margins: 16
                        }
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            MaterialShapeWrappedMaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                wrappedShape: MaterialShape.Shape.Circle
                                text: page.outMuted ? "volume_off" : (page.outVolume > 0.6 ? "volume_up" : (page.outVolume > 0.2 ? "volume_down" : "volume_mute"))
                                iconSize: Appearance.font.pixelSize.larger + 2
                                implicitSize: 46
                                color: page.outMuted ? Appearance.colors.colLayer2 : Appearance.colors.colPrimaryContainer
                                colSymbol: page.outMuted ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnPrimaryContainer
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Audio output")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : Translation.tr("No output device")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }

                            RippleButtonWithIcon {
                                enabled: !!(Audio.sink && Audio.sink.audio)
                                opacity: enabled ? 1.0 : 0.4
                                materialIcon: page.outMuted ? "volume_off" : "volume_up"
                                mainText: page.outMuted ? Translation.tr("Unmute") : Translation.tr("Mute")
                                toggled: page.outMuted
                                colBackground: Appearance.colors.colLayer2
                                colBackgroundToggled: Appearance.colors.colErrorContainer
                                onClicked: Audio.toggleMute()
                            }
                        }

                        // Seletor de dispositivo de saída
                        StyledComboBox {
                            enabled: Audio.outputDevices.length > 0
                            opacity: enabled ? 1.0 : 0.4
                            Layout.fillWidth: true
                            model: Audio.outputDevices.map(node => Audio.friendlyDeviceName(node))
                            currentIndex: Audio.outputDevices.findIndex(item => item.id === Pipewire.defaultAudioSink?.id)
                            onActivated: (index) => {
                                const item = Audio.outputDevices[index]
                                if (item) Audio.setDefaultSink(item)
                            }
                        }

                        // Slider de volume de saída
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            MaterialSymbol {
                                text: "volume_mute"
                                iconSize: 18
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledSlider {
                                enabled: !!(Audio.sink && Audio.sink.audio)
                                opacity: enabled ? 1.0 : 0.4
                                Layout.fillWidth: true
                                value: page.outVolume
                                from: 0
                                to: 1.0
                                onMoved: {
                                    if (Audio.sink?.audio)
                                        Audio.sink.audio.volume = value
                                }
                            }

                            StyledText {
                                text: `${Math.round(page.outVolume * 100)}%`
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurface
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // ENTRADA DE ÁUDIO (MICROFONE)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: inputCol.implicitHeight + 32
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    ColumnLayout {
                        id: inputCol
                        anchors {
                            fill: parent
                            margins: 16
                        }
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            MaterialShapeWrappedMaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                wrappedShape: MaterialShape.Shape.Circle
                                text: page.inMuted ? "mic_off" : "mic"
                                iconSize: Appearance.font.pixelSize.larger + 2
                                implicitSize: 46
                                color: page.inMuted ? Appearance.colors.colLayer2 : Appearance.colors.colSecondaryContainer
                                colSymbol: page.inMuted ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnSecondaryContainer
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Microphone input")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Audio.source ? Audio.friendlyDeviceName(Audio.source) : Translation.tr("No input device")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }

                            RippleButtonWithIcon {
                                enabled: !!(Audio.source && Audio.source.audio)
                                opacity: enabled ? 1.0 : 0.4
                                materialIcon: page.inMuted ? "mic_off" : "mic"
                                mainText: page.inMuted ? Translation.tr("Unmute") : Translation.tr("Mute")
                                toggled: page.inMuted
                                colBackground: Appearance.colors.colLayer2
                                colBackgroundToggled: Appearance.colors.colErrorContainer
                                onClicked: Audio.toggleMicMute()
                            }
                        }

                        // Seletor de dispositivo de entrada
                        StyledComboBox {
                            enabled: Audio.inputDevices.length > 0
                            opacity: enabled ? 1.0 : 0.4
                            Layout.fillWidth: true
                            model: Audio.inputDevices.map(node => Audio.friendlyDeviceName(node))
                            currentIndex: Audio.inputDevices.findIndex(item => item.id === Pipewire.defaultAudioSource?.id)
                            onActivated: (index) => {
                                const item = Audio.inputDevices[index]
                                if (item) Audio.setDefaultSource(item)
                            }
                        }

                        // Slider de volume de entrada
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            MaterialSymbol {
                                text: "mic"
                                iconSize: 18
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledSlider {
                                enabled: !!(Audio.source && Audio.source.audio)
                                opacity: enabled ? 1.0 : 0.4
                                Layout.fillWidth: true
                                value: page.inVolume
                                from: 0
                                to: 1.0
                                onMoved: {
                                    if (Audio.source?.audio)
                                        Audio.source.audio.volume = value
                                }
                            }

                            StyledText {
                                text: `${Math.round(page.inVolume * 100)}%`
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurface
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }

        // 2. MIXER POR APLICATIVO
        ContentSection {
            icon: "apps"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Application volume mixer")

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(180, mixerListLayout.implicitHeight + 16)
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                clip: true

                ColumnLayout {
                    id: mixerListLayout
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 8
                    }
                    spacing: 4

                    Repeater {
                        model: ScriptModel {
                            values: Audio.outputAppNodes
                        }
                        delegate: VolumeMixerEntry {
                            required property var modelData
                            node: modelData
                            Layout.fillWidth: true
                        }
                    }
                }

                PagePlaceholder {
                    anchors.centerIn: parent
                    icon: "widgets"
                    title: Translation.tr("No applications playing audio")
                    shown: Audio.outputAppNodes.length === 0
                    shape: MaterialShape.Shape.Cookie4Sided
                }
            }
        }

        // 3. FERRAMENTAS PROFISSIONAIS DE ÁUDIO
        ContentSection {
            icon: "tune"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Advanced audio tools")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsActionCard {
                    icon: "tune"
                    iconShape: MaterialShape.Shape.Square
                    title: Translation.tr("PulseAudio Volume Control (Pavucontrol)")
                    description: Translation.tr("Fine-grained hardware card profiles, latency settings, and audio stream routing")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["pavucontrol"]);
                    }
                }

                SettingsActionCard {
                    icon: "graphic_eq"
                    iconShape: MaterialShape.Shape.Pill
                    title: Translation.tr("EasyEffects Audio Suite")
                    description: Translation.tr("Parametric equalizer, bass enhancer, compressor, and RNNoise AI noise reduction")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["easyeffects"]);
                    }
                }

                SettingsActionCard {
                    icon: "notifications_active"
                    iconShape: MaterialShape.Shape.Flower
                    title: Translation.tr("System Sound Themes")
                    description: Translation.tr("Configure system event sounds and audio alerts")
                    buttonText: Translation.tr("Open")
                    buttonIcon: "open_in_new"
                    action: () => {
                        Applications.launchCommand(["kcmshell6", "kcm_soundtheme"]);
                    }
                }
            }
        }
    }
}
