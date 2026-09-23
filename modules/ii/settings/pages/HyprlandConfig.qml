import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import qs.modules.common.functions
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

// Configurações do Hyprland. Cada mudança é salva em config.json e gravada em
// ~/.config/hypr/hyprland/shellOverrides/main.lua (carrega por último e vence).
// Telas são gravadas em ~/.config/hypr/monitors.lua, com confirmação.
ContentPage {
    id: page
    forceWidth: true

    readonly property var hypr: Config.options.hyprland
    readonly property var selectedMonitor: monitorConfig.monitors[monitorCanvas.selectedIndex] ?? null

    // Presets de teclado: layout + modelo + variante sempre juntos
    readonly property var kbPresets: ({
        "br": { model: "abnt2", variant: "" },
        "us": { model: "",      variant: "intl" },
        "es": { model: "",      variant: "" }
    })

    function applyKeyboard(layout, model, variant) {
        page.hypr.input.kbLayout = layout
        page.hypr.input.kbModel = model
        page.hypr.input.kbVariant = variant
        HyprlandConfig.setMany({
            "input:kb_layout":  layout,
            "input:kb_model":   model,
            "input:kb_variant": variant
        })
    }

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
            page.contentY = Math.max(0, pos.y - 0)
        }
    }

    // Sincroniza config.json -> main.lua ao abrir, só no arquivo: reaplicar ao
    // vivo recarregaria o mapa do teclado a cada abertura do painel.
    Component.onCompleted: {
        const h = page.hypr
        HyprlandConfig.syncFile({
            "decoration:rounding":                  h.decoration.rounding,
            "decoration:blur:enabled":              h.decoration.blur.enabled ? 1 : 0,
            "decoration:blur:size":                 h.decoration.blur.size,
            "decoration:blur:passes":               h.decoration.blur.passes,
            "decoration:blur:xray":                 (h.decoration.blur?.xray ?? true) ? 1 : 0,
            "decoration:shadow:enabled":            (h.decoration.shadow?.enabled ?? false) ? 1 : 0,
            "decoration:shadow:range":              h.decoration.shadow?.range ?? 4,
            "decoration:active_opacity":            h.decoration.activeOpacity,
            "decoration:inactive_opacity":          h.decoration.inactiveOpacity,
            "decoration:dim_inactive":              h.decoration.dimInactive ? 1 : 0,
            "general:border_size":                  h.general.borderSize,
            "general:gaps_in":                      h.general.gapsIn,
            "general:gaps_out":                     h.general.gapsOut,
            "general:layout":                       (h.general.layout === "scrolling") ? "dwindle" : h.general.layout,
            "dwindle:preserve_split":               h.general.preserveSplit ? 1 : 0,
            "dwindle:smart_split":                  h.general.smartSplit ? 1 : 0,
            "animations:enabled":                   h.animations.enable ? 1 : 0,
            "input:kb_layout":                      h.input.kbLayout,
            "input:kb_model":                       h.input.kbModel,
            "input:kb_variant":                     h.input.kbVariant,
            "input:numlock_by_default":             h.input.numlock ? 1 : 0,
            "input:repeat_delay":                   h.input.repeatDelay,
            "input:repeat_rate":                    h.input.repeatRate,
            "input:follow_mouse":                   h.input.followMouse,
            "input:sensitivity":                    h.input.sensitivity ?? 0,
            "input:touchpad:tap_to_click":          (h.input.touchpad.tapToClick ?? true) ? 1 : 0,
            "input:touchpad:natural_scroll":        h.input.touchpad.naturalScroll ? 1 : 0,
            "input:touchpad:disable_while_typing":  h.input.touchpad.disableWhileTyping ? 1 : 0,
            "input:touchpad:clickfinger_behavior":  h.input.touchpad.clickfingerBehavior ? 1 : 0,
            "input:touchpad:scroll_factor":         h.input.touchpad.scrollFactor
        })
    }
    MonitorConfigOption { id: monitorConfig }

    // Texto de apoio abaixo de um grupo de opções
    component Hint: StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 2
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        wrapMode: Text.Wrap
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // ── Telas ─────────────────────────────────────────────────────────
        ContentSection {
            icon: "monitor"
            shape: MaterialShape.Shape.ClamShell
            title: Translation.tr("Displays")
            visible: monitorConfig.monitors.length > 0

            MonitorCanvas {
                id: monitorCanvas
                Layout.fillWidth: true
                monitorConfig: monitorConfig
            }

            NoticeBox {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: monitorConfig.pendingConfirm
                materialIcon: "timer"
                text: Translation.tr("Keep these display settings? Reverting in %1 s.").arg(monitorConfig.confirmSecondsLeft)

                Item { Layout.fillWidth: true }

                RippleButtonWithIcon {
                    Layout.fillWidth: false
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "undo"
                    mainText: Translation.tr("Revert")
                    onClicked: monitorConfig.revertChanges()
                }
                RippleButtonWithIcon {
                    Layout.fillWidth: false
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "check"
                    mainText: Translation.tr("Keep")
                    // Texto do botão é onSecondaryContainer: fundo precisa ser o par dele
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    onClicked: monitorConfig.keepChanges()
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: (page.selectedMonitor?.name ?? "")
                    + " · "
                    + (page.selectedMonitor?.description ?? "")

                GroupedList {
                    ConfigSwitch {
                        id: monitorEnabledSwitch
                        buttonIcon: "tv_off"
                        text: Translation.tr("Enabled")
                        // A última tela ligada não pode ser desligada
                        enabled: (page.selectedMonitor?.disabled ?? false) || monitorConfig.enabledCount > 1
                        checked: !(page.selectedMonitor?.disabled ?? false)
                        onCheckedChanged: {
                            if (checked === !(page.selectedMonitor?.disabled ?? false)) return
                            monitorConfig.changeMonitor(monitorCanvas.selectedIndex, { disabled: !checked })
                            // O clique quebra o binding; restaura para acompanhar reverter/manter
                            checked = Qt.binding(() => !(page.selectedMonitor?.disabled ?? false))
                        }
                    }

                    ConfigComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "aspect_ratio"
                        text: Translation.tr("Resolution & Refresh Rate")
                        fieldMaxWidth: 300
                        textRole: "display"
                        model: (page.selectedMonitor?.availableModes ?? [])
                            .map(mode => ({ display: mode.replace("@", " · ").replace("Hz", " Hz"), value: mode }))
                        currentValue: page.selectedMonitor?.currentMode ?? ""
                        onSelected: newValue => {
                            const parts = newValue.match(/(\d+)x(\d+)@([\d.]+)Hz/)
                            if (!parts) return
                            const changes = {
                                currentMode: newValue,
                                width: parseInt(parts[1]),
                                height: parseInt(parts[2]),
                                refreshRate: parseFloat(parts[3])
                            }
                            // Escala inválida para a nova resolução volta a 100%
                            const scales = monitorConfig.validScales(changes)
                            if (!scales.some(s => Math.abs(s - (page.selectedMonitor?.scale ?? 1)) < 0.01))
                                changes.scale = 1
                            monitorConfig.changeMonitor(monitorCanvas.selectedIndex, changes)
                        }
                    }

                    ConfigComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "zoom_in"
                        text: Translation.tr("Scale")
                        fieldMaxWidth: 300
                        textRole: "display"
                        model: monitorConfig.validScales(page.selectedMonitor)
                            .map(s => ({ display: `${Math.round(s * 100)}%`, value: s }))
                        currentValue: {
                            const current = page.selectedMonitor?.scale ?? 1
                            const match = monitorConfig.validScales(page.selectedMonitor)
                                .find(s => Math.abs(s - current) < 0.01)
                            return match ?? current
                        }
                        onSelected: newValue => {
                            if (Math.abs(newValue - (page.selectedMonitor?.scale ?? 1)) < 0.001) return
                            monitorConfig.changeMonitor(monitorCanvas.selectedIndex, { scale: newValue })
                        }
                    }

                    ConfigSelectionArray {
                        text: Translation.tr("Orientation")
                        icon: "mobile_rotate"
                        currentValue: page.selectedMonitor?.transform ?? 0
                        onSelected: newValue => {
                            if (newValue === (page.selectedMonitor?.transform ?? 0)) return
                            monitorConfig.changeMonitor(monitorCanvas.selectedIndex, { transform: newValue })
                        }
                        options: [
                            { displayName: Translation.tr("Normal"), icon: "screen_rotation_alt", value: 0 },
                            { displayName: "90°",                    icon: "rotate_90_degrees_cw",  value: 1 },
                            { displayName: "180°",                   icon: "screen_rotation",       value: 2 },
                            { displayName: "270°",                   icon: "rotate_90_degrees_ccw", value: 3 },
                        ]
                    }
                }

                Hint {
                    text: Translation.tr("Drag the displays in the drawing above to arrange them. Every change asks for confirmation and reverts by itself after %1 s.").arg(monitorConfig.confirmTimeout)
                }
            }
        }

        // ── Aparência das janelas ─────────────────────────────────────────
        ContentSection {
            icon: "deblur"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Window Appearance")

            ContentSubsection {
                title: Translation.tr("Windows & Borders")
                GroupedList {
                    ConfigSpinBox {
                        icon: "rounded_corner"
                        text: Translation.tr("Window Rounding")
                        value: page.hypr.decoration.rounding
                        from: 0; to: 30; stepSize: 1
                        onValueChanged: {
                            if (value === page.hypr.decoration.rounding) return
                            page.hypr.decoration.rounding = value
                            HyprlandConfig.set("decoration:rounding", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "border_outer"
                        text: Translation.tr("Border Size")
                        value: page.hypr.general.borderSize
                        from: 0; to: 10; stepSize: 1
                        onValueChanged: {
                            if (value === page.hypr.general.borderSize) return
                            page.hypr.general.borderSize = value
                            HyprlandConfig.set("general:border_size", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "margin"
                        text: Translation.tr("Gaps In")
                        value: page.hypr.general.gapsIn
                        from: 0; to: 40; stepSize: 1
                        onValueChanged: {
                            if (value === page.hypr.general.gapsIn) return
                            page.hypr.general.gapsIn = value
                            HyprlandConfig.set("general:gaps_in", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "open_in_full"
                        text: Translation.tr("Gaps Out")
                        value: page.hypr.general.gapsOut
                        from: 0; to: 60; stepSize: 1
                        onValueChanged: {
                            if (value === page.hypr.general.gapsOut) return
                            page.hypr.general.gapsOut = value
                            HyprlandConfig.set("general:gaps_out", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Active Opacity (%)")
                        value: Math.round(page.hypr.decoration.activeOpacity * 100)
                        from: 10; to: 100; stepSize: 5
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === page.hypr.decoration.activeOpacity) return
                            page.hypr.decoration.activeOpacity = newVal
                            HyprlandConfig.set("decoration:active_opacity", newVal)
                        }
                    }

                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Inactive Opacity (%)")
                        value: Math.round(page.hypr.decoration.inactiveOpacity * 100)
                        from: 10; to: 100; stepSize: 5
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === page.hypr.decoration.inactiveOpacity) return
                            page.hypr.decoration.inactiveOpacity = newVal
                            HyprlandConfig.set("decoration:inactive_opacity", newVal)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "contrast"
                        text: Translation.tr("Dim inactive windows")
                        checked: page.hypr.decoration.dimInactive
                        onCheckedChanged: {
                            if (checked === page.hypr.decoration.dimInactive) return
                            page.hypr.decoration.dimInactive = checked
                            HyprlandConfig.set("decoration:dim_inactive", checked ? 1 : 0)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Blur")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "blur_on"
                        text: Translation.tr("Blur behind panels and transparent windows")
                        checked: page.hypr.decoration.blur.enabled
                        onCheckedChanged: {
                            if (checked === page.hypr.decoration.blur.enabled) return
                            page.hypr.decoration.blur.enabled = checked
                            HyprlandConfig.set("decoration:blur:enabled", checked ? 1 : 0)
                        }
                    }
                }
                GroupedList {
                    visible: page.hypr.decoration.blur.enabled
                    ConfigSpinBox {
                        icon: "blur_circular"
                        text: Translation.tr("Blur Size")
                        value: page.hypr.decoration.blur.size
                        from: 1; to: 20; stepSize: 1
                        onValueChanged: {
                            if (value === page.hypr.decoration.blur.size) return
                            page.hypr.decoration.blur.size = value
                            HyprlandConfig.set("decoration:blur:size", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "layers"
                        text: Translation.tr("Blur Passes")
                        value: page.hypr.decoration.blur.passes
                        from: 1; to: 6; stepSize: 1
                        onValueChanged: {
                            if (value === page.hypr.decoration.blur.passes) return
                            page.hypr.decoration.blur.passes = value
                            HyprlandConfig.set("decoration:blur:passes", value)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "visibility"
                        text: Translation.tr("Blur X-Ray (Saves GPU)")
                        checked: page.hypr.decoration.blur?.xray ?? true
                        onCheckedChanged: {
                            if (checked === (page.hypr.decoration.blur?.xray ?? true)) return
                            page.hypr.decoration.blur.xray = checked
                            HyprlandConfig.set("decoration:blur:xray", checked ? 1 : 0)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Shadow")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "wb_shade"
                        text: Translation.tr("Drop Shadows")
                        checked: page.hypr.decoration.shadow?.enabled ?? false
                        onCheckedChanged: {
                            if (checked === (page.hypr.decoration.shadow?.enabled ?? false)) return
                            page.hypr.decoration.shadow.enabled = checked
                            HyprlandConfig.set("decoration:shadow:enabled", checked ? 1 : 0)
                        }
                    }
                }
                GroupedList {
                    visible: page.hypr.decoration.shadow?.enabled ?? false
                    ConfigSpinBox {
                        icon: "shadow"
                        text: Translation.tr("Shadow Range")
                        value: page.hypr.decoration.shadow?.range ?? 4
                        from: 1; to: 30; stepSize: 1
                        onValueChanged: {
                            if (value === (page.hypr.decoration.shadow?.range ?? 4)) return
                            page.hypr.decoration.shadow.range = value
                            HyprlandConfig.set("decoration:shadow:range", value)
                        }
                    }
                }
            }
        }

        // ── Animações ─────────────────────────────────────────────────────
        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Animations")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "motion_mode"
                    text: Translation.tr("Enable Animations")
                    checked: page.hypr.animations.enable
                    onCheckedChanged: {
                        if (checked === page.hypr.animations.enable) return
                        page.hypr.animations.enable = checked
                        HyprlandConfig.set("animations:enabled", checked ? 1 : 0)
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "animation"
                    enabled: page.hypr.animations.enable
                    currentValue: animationsHint.preset
                    onSelected: newValue => {
                        if (newValue === animationsHint.preset) return
                        page.hypr.animations.animation = newValue
                        HyprlandConfig.setAnimPreset(newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Material 3"),        icon: "auto_awesome",          value: "material" },
                        { displayName: Translation.tr("Elastic"),           icon: "move_selection_right",  value: "fast"     },
                        { displayName: Translation.tr("Vertical (Niri)"),   icon: "mobiledata_arrows",     value: "niri"     },
                    ]
                }
            }

            Hint {
                id: animationsHint
                // "normal" era o nome antigo do conjunto padrão (Material 3)
                readonly property string preset: {
                    const p = page.hypr.animations.animation
                    return (p === "fast" || p === "niri") ? p : "material"
                }
                text: preset === "fast"
                    ? Translation.tr("Windows slide in with a slight bounce; faster and more playful.")
                    : preset === "niri"
                        ? Translation.tr("Like Elastic, but workspaces switch vertically, as in Niri.")
                        : Translation.tr("Default: smooth Material 3 curves, windows pop in and workspaces slide with a fade.")
            }
        }

        // ── Organização das janelas ───────────────────────────────────────
        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Window Layout")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Tiling Layout")
                    icon: "responsive_layout"
                    currentValue: (page.hypr.general.layout === "scrolling") ? "dwindle" : page.hypr.general.layout
                    onSelected: newValue => {
                        page.hypr.general.layout = newValue
                        HyprlandConfig.set("general:layout", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Dwindle (Dynamic)"), icon: "browse",             value: "dwindle" },
                        { displayName: Translation.tr("Master & Stack"),    icon: "auto_awesome_mosaic", value: "master"  },
                    ]
                }
            }

            GroupedList {
                visible: page.hypr.general.layout !== "master"

                ConfigSwitch {
                    buttonIcon: "splitscreen"
                    text: Translation.tr("Preserve split direction")
                    checked: page.hypr.general.preserveSplit
                    onCheckedChanged: {
                        if (checked === page.hypr.general.preserveSplit) return
                        page.hypr.general.preserveSplit = checked
                        HyprlandConfig.set("dwindle:preserve_split", checked ? 1 : 0)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "auto_awesome"
                    text: Translation.tr("Smart split (follows the cursor)")
                    checked: page.hypr.general.smartSplit
                    onCheckedChanged: {
                        if (checked === page.hypr.general.smartSplit) return
                        page.hypr.general.smartSplit = checked
                        HyprlandConfig.set("dwindle:smart_split", checked ? 1 : 0)
                    }
                }
            }

            Hint {
                text: page.hypr.general.layout === "master"
                    ? Translation.tr("Master & Stack: one large main window and the others stacked beside it.")
                    : Translation.tr("Dwindle: each new window splits the focused one in half.")
            }
        }

        // ── Teclado ───────────────────────────────────────────────────────
        ContentSection {
            icon: "keyboard"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Keyboard")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Layout")
                    icon: "language"
                    currentValue: page.hypr.input.kbLayout
                    onSelected: newValue => {
                        const preset = page.kbPresets[newValue]
                        page.applyKeyboard(newValue, preset.model, preset.variant)
                        kbLayoutField.value = newValue
                    }
                    options: [
                        { displayName: "Português (ABNT2)", icon: "keyboard", value: "br" },
                        { displayName: "US Intl (AltGr)",   icon: "keyboard", value: "us" },
                        { displayName: "Español",           icon: "keyboard", value: "es" },
                    ]
                }

                ConfigTextArea {
                    id: kbLayoutField
                    Layout.fillWidth: true
                    buttonIcon: "edit_note"
                    text: Translation.tr("Other layout")
                    placeholderText: Translation.tr("e.g. br, us, es, latam")
                    Component.onCompleted: value = page.hypr.input.kbLayout
                    onValueChanged: kbLayoutDebounceTimer.restart()

                    Timer {
                        id: kbLayoutDebounceTimer
                        interval: 800
                        repeat: false
                        onTriggered: {
                            const layout = kbLayoutField.value.trim()
                            if (layout === "" || layout === page.hypr.input.kbLayout) return
                            // Layout conhecido usa o preset; outro limpa modelo e variante
                            const preset = page.kbPresets[layout] ?? { model: "", variant: "" }
                            page.applyKeyboard(layout, preset.model, preset.variant)
                        }
                    }
                }

                ConfigSwitch {
                    buttonIcon: "pin"
                    text: Translation.tr("Numlock by default")
                    checked: page.hypr.input.numlock
                    onCheckedChanged: {
                        if (checked === page.hypr.input.numlock) return
                        page.hypr.input.numlock = checked
                        HyprlandConfig.set("input:numlock_by_default", checked ? 1 : 0)
                    }
                }

                ConfigSpinBox {
                    icon: "keyboard_return"
                    text: Translation.tr("Repeat delay (ms)")
                    value: page.hypr.input.repeatDelay
                    from: 100; to: 1000; stepSize: 10
                    onValueChanged: {
                        if (value === page.hypr.input.repeatDelay) return
                        page.hypr.input.repeatDelay = value
                        HyprlandConfig.set("input:repeat_delay", value)
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Repeat rate (per second)")
                    value: page.hypr.input.repeatRate
                    from: 10; to: 100; stepSize: 1
                    onValueChanged: {
                        if (value === page.hypr.input.repeatRate) return
                        page.hypr.input.repeatRate = value
                        HyprlandConfig.set("input:repeat_rate", value)
                    }
                }
            }
        }

        // ── Mouse e touchpad ──────────────────────────────────────────────
        ContentSection {
            icon: "trackpad_input"
            shape: MaterialShape.Shape.Cookie6Sided
            title: Translation.tr("Mouse & Touchpad")

            ContentSubsection {
                title: Translation.tr("Mouse")
                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("Window focus")
                        icon: "ads_click"
                        currentValue: page.hypr.input.followMouse
                        onSelected: newValue => {
                            page.hypr.input.followMouse = newValue
                            HyprlandConfig.set("input:follow_mouse", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("On click"),      icon: "left_click", value: 0 },
                            { displayName: Translation.tr("Follows mouse"), icon: "open_with",  value: 1 },
                            { displayName: Translation.tr("Loose"),         icon: "drag_pan",   value: 2 },
                            { displayName: Translation.tr("Detached"),      icon: "link_off",   value: 3 },
                        ]
                    }

                    ConfigSpinBox {
                        icon: "tune"
                        text: Translation.tr("Pointer speed (%)")
                        value: Math.round((page.hypr.input.sensitivity ?? 0) * 100)
                        from: -100; to: 100; stepSize: 5
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === (page.hypr.input.sensitivity ?? 0)) return
                            page.hypr.input.sensitivity = newVal
                            HyprlandConfig.set("input:sensitivity", newVal)
                        }
                    }
                }

                Hint {
                    text: [
                        Translation.tr("On click: the focus only changes when you click a window."),
                        Translation.tr("Follows mouse: the window under the cursor gets the focus."),
                        Translation.tr("Loose: the focus changes on click, but scrolling goes to the window under the cursor."),
                        Translation.tr("Detached: keyboard and mouse focus are fully independent.")
                    ][page.hypr.input.followMouse] ?? ""
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "touch_app"
                        text: Translation.tr("Tap to click")
                        checked: page.hypr.input.touchpad.tapToClick ?? true
                        onCheckedChanged: {
                            if (checked === (page.hypr.input.touchpad.tapToClick ?? true)) return
                            page.hypr.input.touchpad.tapToClick = checked
                            HyprlandConfig.set("input:touchpad:tap_to_click", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: page.hypr.input.touchpad.naturalScroll
                        onCheckedChanged: {
                            if (checked === page.hypr.input.touchpad.naturalScroll) return
                            page.hypr.input.touchpad.naturalScroll = checked
                            HyprlandConfig.set("input:touchpad:natural_scroll", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "keyboard_hide"
                        text: Translation.tr("Disable while typing")
                        checked: page.hypr.input.touchpad.disableWhileTyping
                        onCheckedChanged: {
                            if (checked === page.hypr.input.touchpad.disableWhileTyping) return
                            page.hypr.input.touchpad.disableWhileTyping = checked
                            HyprlandConfig.set("input:touchpad:disable_while_typing", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "pan_tool"
                        text: Translation.tr("Two-finger click = right click, three = middle")
                        checked: page.hypr.input.touchpad.clickfingerBehavior
                        onCheckedChanged: {
                            if (checked === page.hypr.input.touchpad.clickfingerBehavior) return
                            page.hypr.input.touchpad.clickfingerBehavior = checked
                            HyprlandConfig.set("input:touchpad:clickfinger_behavior", checked ? 1 : 0)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swipe"
                        text: Translation.tr("Scroll speed (%)")
                        value: Math.round(page.hypr.input.touchpad.scrollFactor * 100)
                        from: 10; to: 300; stepSize: 10
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === page.hypr.input.touchpad.scrollFactor) return
                            page.hypr.input.touchpad.scrollFactor = newVal
                            HyprlandConfig.set("input:touchpad:scroll_factor", newVal)
                        }
                    }
                }
            }
        }

        // ── Apps ao iniciar ───────────────────────────────────────────────
        ContentSection {
            icon: "app_registration"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Autostart Apps")
            Layout.fillWidth: true

            AutostartApps {}

            Hint {
                text: Translation.tr("Opens each app on the chosen workspace when the session starts. The play button runs the list now.")
            }
        }
    }
}
