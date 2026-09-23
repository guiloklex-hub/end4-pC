pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import "../"

NestableObject {
    id: root

    property var monitors: []

    // Confirmação: toda mudança é aplicada ao vivo e só é gravada em disco
    // quando confirmada. Sem resposta em confirmTimeout segundos, volta ao
    // arranjo anterior (protege contra tela preta / escala ilegível).
    readonly property int confirmTimeout: 15
    property bool pendingConfirm: false
    property int confirmSecondsLeft: 0
    property var confirmedMonitors: null

    readonly property int enabledCount: monitors.filter(m => !m.disabled).length

    Component.onCompleted: fetchProc.running = true
    Component.onDestruction: if (pendingConfirm) revertChanges()

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

    // Aplica uma mudança num monitor e reencosta os vizinhos: se o tamanho
    // lógico mudou (escala, resolução, rotação), quem estava colado à direita
    // ou abaixo acompanha a nova borda, sem buraco nem sobreposição.
    function changeMonitor(index, changes) {
        const list = root.monitors.map(m => Object.assign({}, m))
        const old = list[index]
        const updated = Object.assign({}, old, changes)
        list[index] = updated
        if (!old.disabled && !updated.disabled) {
            const oldRight = old.x + root.logicalWidth(old)
            const newRight = updated.x + root.logicalWidth(updated)
            const oldBottom = old.y + root.logicalHeight(old)
            const newBottom = updated.y + root.logicalHeight(updated)
            for (let i = 0; i < list.length; i++) {
                if (i === index) continue
                if (list[i].x === oldRight) list[i].x = newRight
                if (list[i].y === oldBottom) list[i].y = newBottom
            }
        }
        root.applyWithConfirm(list)
    }

    function applyWithConfirm(list) {
        if (!root.pendingConfirm)
            root.confirmedMonitors = root.monitors.map(m => Object.assign({}, m))
        root.monitors = list
        root.applyAll(list)
        root.pendingConfirm = true
        root.confirmSecondsLeft = root.confirmTimeout
        confirmTimer.restart()
    }

    function keepChanges() {
        confirmTimer.stop()
        root.pendingConfirm = false
        root.confirmedMonitors = null
        root.save()
    }

    function revertChanges() {
        confirmTimer.stop()
        root.pendingConfirm = false
        const previous = root.confirmedMonitors
        root.confirmedMonitors = null
        if (!previous) return
        root.monitors = previous
        root.applyAll(previous)
    }

    // Escalas que dão tamanho lógico inteiro para o modo atual (Hyprland
    // recusa as demais e troca por outra por conta própria)
    function validScales(m) {
        if (!m || !m.width || !m.height) return [1]
        const candidates = [1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.25, 2.5, 3]
        const isInt = v => Math.abs(v - Math.round(v)) < 0.01
        return candidates.filter(s => isInt(m.width / s) && isInt(m.height / s))
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

        // Telas desconectadas não aparecem no hyprctl: mantém as linhas delas
        // (sem isso, salvar com o monitor externo desplugado apagava a config dele)
        const connected = new Set(root.monitors.map(m => m.name))
        const keptLua = (luaFile.text() ?? "").split("\n").filter(line => {
            const match = line.match(/^\s*hl\.monitor\(\{\s*output\s*=\s*"([^"]+)"/)
            return match && !connected.has(match[1])
        })
        const keptConf = (confFile.text() ?? "").split("\n").filter(line => {
            const match = line.match(/^\s*monitor\s*=\s*([^,\s]+)/)
            return match && !connected.has(match[1])
        })

        const luaLines = "-- Gerado pelo painel do Quickshell (Super+Z > Hyprland > Telas).\n"
            + "-- Posições em pixels LÓGICOS (resolução / escala).\n"
            + keptLua.concat(root.monitors.map(m => root._buildLuaLine(m))).join("\n")
        const confLines = "# Configuração de Monitores gerada pelo QuickShell\n"
            + keptConf.concat(root.monitors.map(m => root._buildConfLine(m))).join("\n")

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
        // execDetached: também funciona ao reverter durante a destruição do objeto
        Quickshell.execDetached(["hyprctl", "eval", `(function() ${body} end)()`])
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

    FileView {
        id: luaFile
        path: `${Quickshell.env("HOME")}/.config/hypr/monitors.lua`
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: confFile
        path: `${Quickshell.env("HOME")}/.config/hypr/monitors.conf`
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    Timer {
        id: confirmTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.confirmSecondsLeft -= 1
            if (root.confirmSecondsLeft <= 0) root.revertChanges()
        }
    }

    Process {
        id: saveProc
        onRunningChanged: if (!running) reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }
}