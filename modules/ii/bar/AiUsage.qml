pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
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
    property bool borderless: Config.options.bar.borderless

    property var aiData: ({
        primary: { text: "48%", class: "low", vendor: "anthropic" },
        topPct: 48,
        topLabel: "Claude Pro",
        topReset: "",
        providers: [],
        totalConfigured: 5
    })

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

    function getUsageColor() {
        const cls = root.aiData?.primary?.class ?? "low";
        if (cls === "critical") return Appearance.colors.colError;
        if (cls === "mid" || cls === "warning") return Appearance.m3colors.m3tertiary || Appearance.colors.colPrimary;
        return Appearance.colors.colPrimary;
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
                text: "neurology"
                iconSize: 14
                color: Appearance.colors.colOnPrimary
            }
        }

        MaterialSymbol {
            visible: !root.isMaterial
            Layout.alignment: Qt.AlignVCenter
            text: "neurology"
            iconSize: Appearance.font.pixelSize.normal
            color: root.getUsageColor()
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
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
