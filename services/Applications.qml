pragma Singleton

import Quickshell

Singleton {
    id: root

    function launchCommand(command, inTerminal = false, slice = "a") {
        const argv = Array.from(command ?? [])
        if (argv.length === 0) return false

        const uwsmArgs = ["uwsm-app"]
        if (slice !== "a") uwsmArgs.push("-s", slice)
        if (inTerminal) uwsmArgs.push("-T")
        uwsmArgs.push("--", ...argv)
        Quickshell.execDetached(uwsmArgs)
        return true
    }

    function launchDesktopEntry(entry) {
        if (!entry) return false

        let desktopId = entry.id ?? ""
        if (desktopId.length > 0) {
            if (!desktopId.endsWith(".desktop")) desktopId += ".desktop"
            Quickshell.execDetached(["uwsm-app", "--", desktopId])
            return true
        }

        return root.launchCommand(entry.command ?? [], entry.runInTerminal ?? false)
    }

    function launchDesktopAction(action) {
        if (!action) return false
        return root.launchCommand(action.command ?? [])
    }
}
