pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell.Io
import qs.services
import "../"

/**
 * Same interface as models/hyprland/MonitorConfigOption, backed by niri.
 * Fetches via `niri msg -j outputs`, applies live via `niri msg output`,
 * persists via NiriConfig (qssettings/outputs.kdl).
 */
NestableObject {
    id: root

    property var monitors: []

    readonly property var transformNames: ["normal", "90", "180", "270"]

    Component.onCompleted: { if (WM.compositor === "niri") fetchProc.running = true }

    function updateMonitor(index, changes) {
        let m = root.monitors.slice()
        m[index] = Object.assign({}, m[index], changes)
        root.monitors = m
    }

    function save() {
        if (root.monitors.length === 0) return
        NiriConfig.generateOutputsKdl(root.monitors)
    }

    function _buildNiriCmds(m) {
        if (m.disabled)
            return [`niri msg output "${m.name}" off`]
        const mode = m.currentMode.replace(/Hz$/, "")
        return [
            `niri msg output "${m.name}" on`,
            `niri msg output "${m.name}" mode "${mode}"`,
            `niri msg output "${m.name}" scale ${m.scale}`,
            `niri msg output "${m.name}" transform "${root.transformNames[m.transform] ?? "normal"}"`,
            `niri msg output "${m.name}" position set ${m.x} ${m.y}`
        ]
    }

    function applyMonitor(m) {
        if (!m.name) return
        root.applyAll([m])
    }

    // Mesma razao do modelo do Hyprland: um unico Process e compartilhado, entao
    // os monitores precisam ir todos juntos em um comando so.
    function applyAll(list) {
        const mons = (list ?? root.monitors).filter(m => m && m.name)
        if (mons.length === 0) return
        let cmds = []
        for (let i = 0; i < mons.length; i++)
            cmds = cmds.concat(root._buildNiriCmds(mons[i]))
        applyProc.command = ["sh", "-c", cmds.join(" && ")]
        applyProc.running = true
    }

    function applyAndSave(index) {
        root.applyAll(root.monitors)
        root.save()
    }

    // Tamanho LOGICO = resolucao fisica / scale. E nessa unidade que o
    // compositor posiciona os monitores. Usar a resolucao fisica aqui fazia o
    // snap do arraste encostar as telas na largura errada, deixando um buraco
    // entre elas (ex.: 3840 fisico vs 3072 logico com scale 1.25 => gap de 768px)
    // e prendendo o cursor no monitor de origem.
    // Transforms 1/3 (90/270) e 5/7 (flipped-90/270) trocam largura e altura.
    function _swapsAxes(m) {
        const t = m.transform ?? 0
        return t === 1 || t === 3 || t === 5 || t === 7
    }

    function _effScale(m) {
        const s = Number(m.scale)
        return (isFinite(s) && s > 0) ? s : 1
    }

    function logicalWidth(m) {
        return Math.round((root._swapsAxes(m) ? m.height : m.width) / root._effScale(m))
    }

    function logicalHeight(m) {
        return Math.round((root._swapsAxes(m) ? m.width : m.height) / root._effScale(m))
    }

    Process {
        id: fetchProc
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outputs = JSON.parse(text)
                    root.monitors = Object.entries(outputs).map(([connector, o]) => {
                        const current = o.modes?.[o.current_mode] ?? null
                        const refresh = current ? current.refresh_rate / 1000 : 60
                        return {
                            name:          connector,
                            description:   [o.make, o.model].filter(s => s && s !== "Unknown").join(" "),
                            width:         current?.width ?? 1920,
                            height:        current?.height ?? 1080,
                            refreshRate:   refresh,
                            x:             o.logical?.x ?? 0,
                            y:             o.logical?.y ?? 0,
                            scale:         o.logical?.scale ?? 1.0,
                            transform:     Math.max(0, root.transformNames.indexOf(o.logical?.transform ?? "normal")),
                            disabled:      o.logical === null,
                            vrr:           o.vrr_enabled ?? false,
                            availableModes: (o.modes ?? []).map(mode => `${mode.width}x${mode.height}@${(mode.refresh_rate / 1000).toFixed(2)}Hz`),
                            currentMode:   current ? `${current.width}x${current.height}@${refresh.toFixed(2)}Hz` : ""
                        }
                    })
                } catch (e) {
                    console.log("[NiriMonitorConfig] Error parsing outputs JSON:", e)
                }
            }
        }
    }

    Process { id: applyProc }
}
