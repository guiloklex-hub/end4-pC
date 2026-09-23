pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

/**
 * Ícone + nome de um app. Clique abre, botão direito abre o menu de contexto,
 * arrastar leva o app para o dock ou para os fixados do menu.
 */
Item {
    id: root

    required property var entry
    property bool current: false
    property real iconSize: 48
    property bool dimmed: entry ? AppCatalog.isHidden(entry) : false

    signal activated()
    signal contextMenuRequested(real sceneX, real sceneY)
    signal dragStarted(real sceneX, real sceneY)
    signal dragMoved(real sceneX, real sceneY)
    signal dragEnded(real sceneX, real sceneY)

    implicitWidth: 104
    implicitHeight: 104

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: 3
        radius: Appearance.rounding.normal
        color: mouseArea.pressed && !mouseArea.dragging ? Appearance.colors.colLayer1Active
            : (mouseArea.containsMouse || root.current) ? Appearance.colors.colLayer1Hover
            : "transparent"
        border.width: root.current ? 1 : 0
        border.color: Appearance.colors.colOutlineVariant

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 12
        spacing: 6
        opacity: (root.dimmed ? 0.45 : 1) * (mouseArea.dragging ? 0.35 : 1)

        IconImage {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: root.iconSize
            source: Quickshell.iconPath(root.entry?.icon ?? "", "application-x-executable")

            MaterialSymbol {
                visible: root.dimmed
                anchors { right: parent.right; bottom: parent.bottom; margins: -4 }
                text: "visibility_off"
                iconSize: 16
                color: Appearance.colors.colSubtext
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.entry?.name ?? ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true // senão a GridView rouba o arraste para rolar
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property bool dragging: false
        property real pressX: 0
        property real pressY: 0

        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
        }
        onPositionChanged: mouse => {
            if (!(mouse.buttons & Qt.LeftButton)) return;
            const p = mapToItem(null, mouse.x, mouse.y);
            if (!dragging && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 12) {
                dragging = true;
                root.dragStarted(p.x, p.y);
            }
            if (dragging) root.dragMoved(p.x, p.y);
        }
        onReleased: mouse => {
            if (!dragging) return;
            dragging = false;
            const p = mapToItem(null, mouse.x, mouse.y);
            root.dragEnded(p.x, p.y);
        }
        onCanceled: {
            if (dragging) {
                dragging = false;
                root.dragEnded(-1, -1);
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                const p = mapToItem(null, mouse.x, mouse.y);
                root.contextMenuRequested(p.x, p.y);
            } else {
                root.activated();
            }
        }
    }

    StyledToolTip {
        text: root.entry?.comment || root.entry?.genericName || root.entry?.name || ""
        extraVisibleCondition: mouseArea.containsMouse && !mouseArea.dragging && text.length > 0
    }
}
