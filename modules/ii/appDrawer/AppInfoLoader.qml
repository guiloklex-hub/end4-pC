import qs.services
import QtQuick
import Quickshell.Io

/**
 * Pede ao appctl.py os dados do app (origem, pacote, tamanho...) e guarda em
 * `info` quando chegam. Cada diálogo tem o seu processo, então uma resposta
 * atrasada de outro app nunca cai aqui.
 */
Process {
    id: root

    required property var entry
    property var info: null
    readonly property bool loading: info === null

    command: ["python3", AppCatalog.appctl, "info", entry?.id ?? ""]
    running: entry !== null

    stdout: StdioCollector {
        onStreamFinished: {
            try {
                root.info = JSON.parse(text);
            } catch (e) {
                root.info = { error: text };
            }
        }
    }
}
