pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import "../"

NestableObject {
    id: root

    property var monitors: []

    Component.onCompleted: fetchProc.running = true

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "monitoradded" || event.name === "monitorremoved") {
                fetchProc.running = true
            }
        }
    }

    function updateMonitor(index, changes) {
        let m = root.monitors.slice()
        m[index] = Object.assign({}, m[index], changes)
        root.monitors = m
    }

    function _buildLuaLine(m) {
        if (m.disabled)
            return `hl.monitor({ output = "${m.name}", disabled = true })`

        const pos = `${m.x}x${m.y}`
        let line = `hl.monitor({ output = "${m.name}", mode = "${m.currentMode}", position = "${pos}", scale = ${m.scale}`

        if (m.transform && m.transform !== 0)
            line += `, transform = ${m.transform}`

        line += ` })`
        return line
    }

    function _buildConfLine(m) {
        if (m.disabled)
            return `monitor=${m.name},disable`

        let line = `monitor=${m.name},${m.currentMode},${m.x}x${m.y},${m.scale}`
        if (m.transform && m.transform !== 0)
            line += `,transform,${m.transform}`

        return line
    }

    function save() {
        if (root.monitors.length === 0) return
        if (root.monitors.some(m => !m.name)) return

        const luaLines = root.monitors.map(m => root._buildLuaLine(m)).join("\n")
        const confLines = "# Configuração de Monitores gerada pelo QuickShell\n" + root.monitors.map(m => root._buildConfLine(m)).join("\n")

        const escapedLua = luaLines.replace(/'/g, "'\\''")
        const escapedConf = confLines.replace(/'/g, "'\\''")

        saveProc.command = ["bash", "-c",
            `printf '%s\\n' '${escapedLua}' > ~/.config/hypr/monitors.lua && printf '%s\\n' '${escapedConf}' > ~/.config/hypr/monitors.conf`]
        saveProc.running = true
    }

    function applyMonitor(m) {
        if (!m.name) return
        root.applyAll([m])
    }

    // Aplica TODOS os monitores numa unica invocacao do hyprctl.
    // Chamar applyMonitor dentro de um laco nao funciona: todas as chamadas
    // compartilham o mesmo Process, entao cada iteracao sobrescreve o comando
    // da anterior e na pratica so uma delas chega a ser executada -- por isso
    // mudar o arranjo das telas "nao aplicava".
    function applyAll(list) {
        const mons = (list ?? root.monitors).filter(m => m && m.name)
        if (mons.length === 0) return
        const body = mons.map(m => root._buildLuaLine(m)).join(" ")
        applyProc.command = ["hyprctl", "eval", `(function() ${body} end)()`]
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
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                        name:          m.name,
                        description:   m.description,
                        width:         m.width,
                        height:        m.height,
                        refreshRate:   m.refreshRate,
                        x:             m.x,
                        y:             m.y,
                        scale:         m.scale,
                        transform:     m.transform ?? 0,
                        disabled:      m.disabled,
                        availableModes: m.availableModes,
                        currentMode:   `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}Hz`
                    }))
                } catch(e) {
                    console.log("[MonitorConfig] Error parseando JSON:", e)
                }
            }
        }
    }

    Process { id: applyProc }

    Process {
        id: saveProc
        onRunningChanged: if (!running) reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }
}