pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

MouseArea {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property color pillContentColor: Appearance.colors.colOnLayer1
    property bool borderless: Config.options.bar.borderless

    // Placeholder neutro até o primeiro fetch (antes mostrava um "48%" fictício).
    property var aiData: ({
        primary: { text: "…", class: "low", vendor: "none", icon: "neurology" },
        topPct: 0,
        topLabel: "",
        topReset: "",
        providers: [],
        totalConfigured: 0,
        errorCount: 0
    })
    readonly property string vendorIcon: aiData?.primary?.icon || "neurology"

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : Math.max(54, contentRow.implicitWidth + 14)
    implicitHeight: vertical ? Math.max(34, contentRow.implicitHeight + 14) : Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton) {
            cycleProc.running = true
        } else if (mouse.button === Qt.RightButton) {
            fetchProc.running = true
        }
    }

    onWheel: (wheel) => {
        if (wheel.angleDelta.y > 0) {
            cycleProc.running = true
        } else {
            cyclePrevProc.running = true
        }
    }

    // Process to fetch quota JSON
    Process {
        id: fetchProc
        running: true
        command: [FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/get-ai-quotas.py`)]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "") return;
                try {
                    root.aiData = JSON.parse(text);
                } catch (e) {
                    console.log("[AiUsage] Failed to parse quotas JSON:", e);
                }
            }
        }
    }

    // Process to cycle forward
    Process {
        id: cycleProc
        command: ["ai-usagebar", "--cycle-next"]
        onExited: {
            fetchProc.running = true
        }
    }

    // Process to cycle backward
    Process {
        id: cyclePrevProc
        command: ["ai-usagebar", "--cycle-prev"]
        onExited: {
            fetchProc.running = true
        }
    }

    // Auto-refresh timer every 60s
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            fetchProc.running = true
        }
    }

    // Normal = cor do tema, atenção = âmbar, crítico = vermelho.
    // (Antes o estado "mid" usava m3tertiary, que em algumas paletas é quase branco.)
    readonly property string usageClass: root.aiData?.primary?.class ?? "low"
    function getUsageColor() {
        if (usageClass === "critical") return Appearance.colors.colError;
        if (usageClass === "mid" || usageClass === "high" || usageClass === "warning")
            return Appearance.m3colors.darkmode ? "#FFB84D" : "#9A5B00";
        return Appearance.colors.colPrimary;
    }
    function getUsageIconColor() {
        if (usageClass === "critical") return Appearance.m3colors.m3onError;
        if (usageClass === "mid" || usageClass === "high" || usageClass === "warning")
            return Appearance.m3colors.darkmode ? "#3D2400" : "#FFFFFF";
        return Appearance.colors.colOnPrimary;
    }

    // Bar Content
    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5

        // Icon badge
        Rectangle {
            visible: root.isMaterial
            width: 22
            height: 22
            radius: Appearance.rounding.full
            color: root.getUsageColor()

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.vendorIcon
                iconSize: 14
                color: root.getUsageIconColor()
            }
        }

        MaterialSymbol {
            visible: !root.isMaterial
            Layout.alignment: Qt.AlignVCenter
            text: root.vendorIcon
            iconSize: Appearance.font.pixelSize.normal
            color: root.getUsageColor()
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: root.pillContentColor
            text: root.aiData?.primary?.text ?? "AI"
        }
    }

    // Tooltip popup on hover
    AiUsagePopup {
        id: aiUsagePopup
        hoverTarget: root
        aiData: root.aiData
    }
}
