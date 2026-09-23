import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import qs.modules.common.functions
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

ContentPage {
    id: page
    forceWidth: true

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

    Component.onCompleted: {
        const h = Config.options.hyprland
        HyprlandConfig.setMany({
            "decoration:rounding":                  h.decoration.rounding,
            "decoration:blur:enabled":              h.decoration.blur.enabled ? 1 : 0,
            "decoration:blur:size":                 h.decoration.blur.size,
            "decoration:blur:passes":               h.decoration.blur.passes,
            "decoration:blur:xray":                 (h.decoration.blur?.xray ?? true) ? 1 : 0,
            "decoration:shadow:enabled":            (h.decoration.shadow?.enabled ?? false) ? 1 : 0,
            "decoration:shadow:range":              h.decoration.shadow?.range ?? 4,
            "decoration:active_opacity":            h.decoration.activeOpacity,
            "decoration:inactive_opacity":          h.decoration.inactiveOpacity,
            "general:border_size":                  h.general.borderSize,
            "general:gaps_in":                      h.general.gapsIn,
            "general:gaps_out":                     h.general.gapsOut,
            "general:layout":                       (h.general.layout === "scrolling") ? "dwindle" : h.general.layout,
            "animations:enabled":                   h.animations.enable ? 1 : 0,
            "input:kb_layout":                      h.input.kbLayout,
            "input:numlock_by_default":             h.input.numlock ? 1 : 0,
            "input:repeat_delay":                   h.input.repeatDelay,
            "input:repeat_rate":                    h.input.repeatRate,
            "input:follow_mouse":                   h.input.followMouse,
            "input:touchpad:tap_to_click":          (h.input.touchpad.tapToClick ?? true) ? 1 : 0,
            "input:touchpad:natural_scroll":        h.input.touchpad.naturalScroll ? 1 : 0,
            "input:touchpad:disable_while_typing":  h.input.touchpad.disableWhileTyping ? 1 : 0,
            "input:touchpad:clickfinger_behavior":  h.input.touchpad.clickfingerBehavior ? 1 : 0,
            "input:touchpad:scroll_factor":         h.input.touchpad.scrollFactor
        })
    }
    MonitorConfigOption { id: monitorConfig }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // Displays
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

            ContentSubsection {
                Layout.topMargin: 10
                title: (monitorConfig.monitors[monitorCanvas.selectedIndex]?.name ?? "")
                    + " · "
                    + (monitorConfig.monitors[monitorCanvas.selectedIndex]?.description ?? "")

                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "tv_off"
                        text: Translation.tr("Enabled")
                        checked: !(monitorConfig.monitors[monitorCanvas.selectedIndex]?.disabled ?? false)
                        onCheckedChanged: {
                            if (checked === !(monitorConfig.monitors[monitorCanvas.selectedIndex]?.disabled ?? false)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { disabled: !checked })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "aspect_ratio"
                        text: Translation.tr("Resolution & Refresh Rate")
                        textRole: "display"
                        model: (monitorConfig.monitors[monitorCanvas.selectedIndex]?.availableModes ?? [])
                            .map(mode => ({ display: mode, value: mode }))
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.currentMode ?? ""
                        onSelected: newValue => {
                            const mode = newValue
                            const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
                            if (parts) {
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, {
                                    currentMode: mode,
                                    width: parseInt(parts[1]),
                                    height: parseInt(parts[2]),
                                    refreshRate: parseFloat(parts[3])
                                })
                                monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                            }
                        }
                    }

                    ConfigSelectionArray {
                        text: Translation.tr("Orientation")
                        icon: "mobile_rotate"
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.transform ?? 0
                        onSelected: newValue => {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { transform: newValue })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                        options: [
                            { displayName: Translation.tr("Normal"), icon: "screen_rotation_alt", value: 0 },
                            { displayName: "90°",                    icon: "rotate_90_degrees_cw",  value: 1 },
                            { displayName: "180°",                   icon: "screen_rotation",       value: 2 },
                            { displayName: "270°",                   icon: "rotate_90_degrees_ccw", value: 3 },
                        ]
                    }
    
                    ConfigSpinBox {
                        icon: "zoom_in"
                        text: Translation.tr("Scale (%)")
                        value: Math.round((monitorConfig.monitors[monitorCanvas.selectedIndex]?.scale ?? 1.0) * 100)
                        from: 50; to: 300; stepSize: 5
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.scale ?? 1.0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { scale: newVal })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swap_horiz"
                        text: Translation.tr("Position X")
                        value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.x ?? 0
                        from: 0; to: 7680; stepSize: 10
                        onValueChanged: {
                            if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.x ?? 0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { x: value })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swap_vert"
                        text: Translation.tr("Position Y")
                        value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.y ?? 0
                        from: 0; to: 4320; stepSize: 10
                        onValueChanged: {
                            if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.y ?? 0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { y: value })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }
                }        
            }
        }

        // Layout
        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Layout")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Tiling Layout")
                    icon: "responsive_layout"
                    currentValue: (Config.options.hyprland.general.layout === "scrolling") ? "dwindle" : Config.options.hyprland.general.layout
                    onSelected: newValue => {
                        Config.options.hyprland.general.layout = newValue
                        HyprlandConfig.set("general:layout", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Dwindle (Dynamic)"), icon: "browse",             value: "dwindle" },
                        { displayName: Translation.tr("Master & Stack"),    icon: "auto_awesome_mosaic", value: "master"  },
                    ]
                }

                ConfigSwitch {
                    buttonIcon: "splitscreen"
                    text: Translation.tr("Dwindle: Preserve Split")
                    checked: true
                    onCheckedChanged: {
                        HyprlandConfig.set("dwindle:preserve_split", checked ? 1 : 0)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "auto_awesome"
                    text: Translation.tr("Dwindle: Smart Split")
                    checked: false
                    onCheckedChanged: {
                        HyprlandConfig.set("dwindle:smart_split", checked ? 1 : 0)
                    }
                }
            }
        }

        // Input
        ContentSection {
            icon: "trackpad_input"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Input")

            ContentSubsection {
                title: Translation.tr("Keyboard")

                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("Quick Presets")
                        icon: "keyboard"
                        currentValue: Config.options.hyprland.input.kbLayout
                        onSelected: newValue => {
                            Config.options.hyprland.input.kbLayout = newValue
                            kbLayoutField.value = newValue
                            if (newValue === "br") {
                                HyprlandConfig.setMany({
                                    "input:kb_layout": "br",
                                    "input:kb_model": "abnt2",
                                    "input:kb_variant": ""
                                })
                            } else if (newValue === "us") {
                                HyprlandConfig.setMany({
                                    "input:kb_layout": "us",
                                    "input:kb_model": "",
                                    "input:kb_variant": "intl"
                                })
                            } else {
                                HyprlandConfig.set("input:kb_layout", newValue)
                            }
                        }
                        options: [
                            { displayName: "Português (ABNT2)", icon: "flag", value: "br" },
                            { displayName: "US Intl (AltGr)",   icon: "flag", value: "us" },
                            { displayName: "Español",           icon: "flag", value: "es" },
                        ]
                    }

                    ConfigTextArea {
                        id: kbLayoutField
                        Layout.fillWidth: true
                        buttonIcon: "edit_note"
                        text: Translation.tr("Custom Layout")
                        placeholderText: Translation.tr("e.g. br, us, es, latam")
                        Component.onCompleted: value = Config.options.hyprland.input.kbLayout
                        onValueChanged: kbLayoutDebounceTimer.restart()

                        Timer {
                            id: kbLayoutDebounceTimer
                            interval: 800
                            repeat: false
                            onTriggered: {
                                if (kbLayoutField.value.trim() === "") return
                                Config.options.hyprland.input.kbLayout = kbLayoutField.value.trim()
                                if (kbLayoutField.value.trim() === "br") {
                                    HyprlandConfig.setMany({
                                        "input:kb_layout": "br",
                                        "input:kb_model": "abnt2"
                                    })
                                } else {
                                    HyprlandConfig.set("input:kb_layout", kbLayoutField.value.trim())
                                }
                            }
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "numbers"
                        text: Translation.tr("Numlock by default")
                        checked: Config.options.hyprland.input.numlock
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.numlock) return
                            Config.options.hyprland.input.numlock = checked
                            HyprlandConfig.set("input:numlock_by_default", checked ? 1 : 0)
                        }
                    }

                    ConfigSpinBox {
                        icon: "keyboard_return"
                        text: Translation.tr("Repeat delay (ms)")
                        value: Config.options.hyprland.input.repeatDelay
                        from: 100; to: 1000; stepSize: 10
                        onValueChanged: {
                            if (value === Config.options.hyprland.input.repeatDelay) return
                            Config.options.hyprland.input.repeatDelay = value
                            HyprlandConfig.set("input:repeat_delay", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "speed"
                        text: Translation.tr("Repeat rate")
                        value: Config.options.hyprland.input.repeatRate
                        from: 10; to: 100; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.input.repeatRate) return
                            Config.options.hyprland.input.repeatRate = value
                            HyprlandConfig.set("input:repeat_rate", value)
                        }
                    }

                    ConfigSelectionArray {
                        text: Translation.tr("Follow mouse")
                        icon: "mouse"
                        currentValue: Config.options.hyprland.input.followMouse
                        onSelected: newValue => {
                            Config.options.hyprland.input.followMouse = newValue
                            HyprlandConfig.set("input:follow_mouse", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Disabled"), icon: "mouse",     value: 0 },
                            { displayName: Translation.tr("Full"),     icon: "open_with",  value: 1 },
                            { displayName: Translation.tr("Loose"),    icon: "drag_pan",   value: 2 },
                            { displayName: Translation.tr("Explicit"), icon: "ads_click",  value: 3 },
                        ]
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad & Pointer")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "touch_app"
                        text: Translation.tr("Tap to click")
                        checked: Config.options.hyprland.input.touchpad.tapToClick ?? true
                        onCheckedChanged: {
                            if (checked === (Config.options.hyprland.input.touchpad.tapToClick ?? true)) return
                            Config.options.hyprland.input.touchpad.tapToClick = checked
                            HyprlandConfig.set("input:touchpad:tap_to_click", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: Config.options.hyprland.input.touchpad.naturalScroll
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.naturalScroll) return
                            Config.options.hyprland.input.touchpad.naturalScroll = checked
                            HyprlandConfig.set("input:touchpad:natural_scroll", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "keyboard_hide"
                        text: Translation.tr("Disable while typing")
                        checked: Config.options.hyprland.input.touchpad.disableWhileTyping
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.disableWhileTyping) return
                            Config.options.hyprland.input.touchpad.disableWhileTyping = checked
                            HyprlandConfig.set("input:touchpad:disable_while_typing", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "pan_tool"
                        text: Translation.tr("Clickfinger behavior")
                        checked: Config.options.hyprland.input.touchpad.clickfingerBehavior
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.clickfingerBehavior) return
                            Config.options.hyprland.input.touchpad.clickfingerBehavior = checked
                            HyprlandConfig.set("input:touchpad:clickfinger_behavior", checked ? 1 : 0)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swipe"
                        text: Translation.tr("Scroll factor")
                        value: Math.round(Config.options.hyprland.input.touchpad.scrollFactor * 10)
                        from: 1; to: 30; stepSize: 1
                        onValueChanged: {
                            const newVal = value / 10.0
                            if (newVal === Config.options.hyprland.input.touchpad.scrollFactor) return
                            Config.options.hyprland.input.touchpad.scrollFactor = newVal
                            HyprlandConfig.set("input:touchpad:scroll_factor", newVal)
                        }
                    }

                    ConfigSpinBox {
                        icon: "tune"
                        text: Translation.tr("Pointer Sensitivity")
                        value: Math.round(((Config.options.hyprland.input.sensitivity ?? 0.0) + 1.0) * 10)
                        from: 0; to: 20; stepSize: 1
                        onValueChanged: {
                            const newVal = (value / 10.0) - 1.0
                            Config.options.hyprland.input.sensitivity = newVal
                            HyprlandConfig.set("input:sensitivity", newVal)
                        }
                    }
                }
            }
        }

        // Visual & Aesthetics
        ContentSection {
            icon: "deblur"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Visual & Aesthetics")

            ContentSubsection {
                title: Translation.tr("Windows & Borders")
                GroupedList {
                    ConfigSpinBox {
                        icon: "rounded_corner"
                        text: Translation.tr("Window Rounding")
                        value: Config.options.hyprland.decoration.rounding
                        from: 0; to: 30; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.decoration.rounding) return
                            Config.options.hyprland.decoration.rounding = value
                            HyprlandConfig.set("decoration:rounding", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "border_outer"
                        text: Translation.tr("Border Size")
                        value: Config.options.hyprland.general.borderSize
                        from: 0; to: 10; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.general.borderSize) return
                            Config.options.hyprland.general.borderSize = value
                            HyprlandConfig.set("general:border_size", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "margin"
                        text: Translation.tr("Gaps In")
                        value: Config.options.hyprland.general.gapsIn
                        from: 0; to: 40; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.general.gapsIn) return
                            Config.options.hyprland.general.gapsIn = value
                            HyprlandConfig.set("general:gaps_in", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "open_in_full"
                        text: Translation.tr("Gaps Out")
                        value: Config.options.hyprland.general.gapsOut
                        from: 0; to: 60; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.general.gapsOut) return
                            Config.options.hyprland.general.gapsOut = value
                            HyprlandConfig.set("general:gaps_out", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Active Opacity (%)")
                        value: Math.round(Config.options.hyprland.decoration.activeOpacity * 100)
                        from: 10; to: 100; stepSize: 5
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === Config.options.hyprland.decoration.activeOpacity) return
                            Config.options.hyprland.decoration.activeOpacity = newVal
                            HyprlandConfig.set("decoration:active_opacity", newVal)
                        }
                    }

                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Inactive Opacity (%)")
                        value: Math.round(Config.options.hyprland.decoration.inactiveOpacity * 100)
                        from: 10; to: 100; stepSize: 5
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === Config.options.hyprland.decoration.inactiveOpacity) return
                            Config.options.hyprland.decoration.inactiveOpacity = newVal
                            HyprlandConfig.set("decoration:inactive_opacity", newVal)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Blur & Effects")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "blur_on"
                        text: Translation.tr("Blur")
                        checked: Config.options.hyprland.decoration.blur.enabled
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.decoration.blur.enabled) return
                            Config.options.hyprland.decoration.blur.enabled = checked
                            HyprlandConfig.set("decoration:blur:enabled", checked ? 1 : 0)
                        }
                    }

                    ConfigSpinBox {
                        icon: "blur_circular"
                        text: Translation.tr("Blur Size")
                        value: Config.options.hyprland.decoration.blur.size
                        from: 1; to: 20; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.decoration.blur.size) return
                            Config.options.hyprland.decoration.blur.size = value
                            HyprlandConfig.set("decoration:blur:size", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "layers"
                        text: Translation.tr("Blur Passes")
                        value: Config.options.hyprland.decoration.blur.passes
                        from: 1; to: 6; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.decoration.blur.passes) return
                            Config.options.hyprland.decoration.blur.passes = value
                            HyprlandConfig.set("decoration:blur:passes", value)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "visibility"
                        text: Translation.tr("Blur X-Ray (Saves GPU)")
                        checked: Config.options.hyprland.decoration.blur?.xray ?? true
                        onCheckedChanged: {
                            if (checked === (Config.options.hyprland.decoration.blur?.xray ?? true)) return
                            if (!Config.options.hyprland.decoration.blur) Config.options.hyprland.decoration.blur = {}
                            Config.options.hyprland.decoration.blur.xray = checked
                            HyprlandConfig.set("decoration:blur:xray", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "wb_shade"
                        text: Translation.tr("Drop Shadows")
                        checked: Config.options.hyprland.decoration.shadow?.enabled ?? false
                        onCheckedChanged: {
                            if (checked === (Config.options.hyprland.decoration.shadow?.enabled ?? false)) return
                            if (!Config.options.hyprland.decoration.shadow) Config.options.hyprland.decoration.shadow = {}
                            Config.options.hyprland.decoration.shadow.enabled = checked
                            HyprlandConfig.set("decoration:shadow:enabled", checked ? 1 : 0)
                        }
                    }

                    ConfigSpinBox {
                        icon: "shadow"
                        text: Translation.tr("Shadow Range")
                        visible: Config.options.hyprland.decoration.shadow?.enabled ?? false
                        value: Config.options.hyprland.decoration.shadow?.range ?? 4
                        from: 1; to: 30; stepSize: 1
                        onValueChanged: {
                            if (value === (Config.options.hyprland.decoration.shadow?.range ?? 4)) return
                            if (!Config.options.hyprland.decoration.shadow) Config.options.hyprland.decoration.shadow = {}
                            Config.options.hyprland.decoration.shadow.range = value
                            HyprlandConfig.set("decoration:shadow:range", value)
                        }
                    }
                }
            }
        }

        // Autostart Apps
        ContentSection {
            icon: "app_registration"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Autostart Apps")
            Layout.fillWidth: true

            AutostartApps {}
        }

        // Animations
        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Animations")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable Animations")
                    checked: Config.options.hyprland.animations.enable
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.animations.enable) return
                        Config.options.hyprland.animations.enable = checked
                        HyprlandConfig.set("animations:enabled", checked ? 1 : 0)
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Presets")
                    icon: "present_to_all"
                    currentValue: Config.options.hyprland.animations.animation
                    onSelected: newValue => {
                        Config.options.hyprland.animations.animation = newValue
                        HyprlandConfig.setAnimPreset(newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Elastic"),   icon: "move_selection_right", value: "fast"   },
                        { displayName: Translation.tr("Normal"),    icon: "animation",            value: "normal" },
                        { displayName: Translation.tr("Niri Like"), icon: "mobiledata_arrows",    value: "niri"   },
                    ]
                }
            }

            NoticeBox {
                Layout.fillWidth: true
                Layout.topMargin: 15
                text: Translation.tr("Animation presets are active and loaded automatically via:") + '\n\n~/.config/hypr/hyprland/shellOverrides/animations.lua'

                Item { Layout.fillWidth: true }

                RippleButtonWithIcon {
                    id: copySourceButton
                    property bool justCopied: false
                    Layout.fillWidth: false
                    buttonRadius: Appearance.rounding.small
                    materialIcon: justCopied ? "check" : "content_copy"
                    mainText: justCopied ? Translation.tr("Copied!") : Translation.tr("Copy path")
                    onClicked: {
                        copySourceButton.justCopied = true
                        Quickshell.clipboardText = '~/.config/hypr/hyprland/shellOverrides/animations.lua'
                        revertSourceTimer.restart()
                    }
                    colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    Timer {
                        id: revertSourceTimer
                        interval: 1500
                        onTriggered: copySourceButton.justCopied = false
                    }
                }
            }
        }
    }
}