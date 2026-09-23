import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property real iconSize:      23
    property real btnSize:       28
    property real btnSpacing:    2
    property var  screen:        null  // definido pelo dock: mostra só janelas deste monitor
    property bool showPreviews:  true
    property int  popupEdge: vertical
        ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
        : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)

    // Janelas visíveis neste monitor. Sem monitor informado pelo compositor, mostra em todos.
    function windowsOnScreen(toplevels) {
        if (!root.screen) return toplevels ?? []
        return (toplevels ?? []).filter(t =>
            !t.screens || t.screens.length === 0 || t.screens.some(s => s?.name === root.screen.name))
    }
    property bool vertical:    Config.options.bar.vertical
    property bool isMaterial:  Config.options.bar.cornerStyle === 3
    property var pinnedApps: Config.options?.dock.pinnedApps ?? []
    property var activeUnpinned: TaskbarApps.apps.filter(
        a => !a.pinned && a.appId !== "SEPARATOR" && root.windowsOnScreen(a.toplevels).length > 0
    )
    property bool showSeparator: _workOrder.length > 0 && activeUnpinned.length > 0
    property var  _workOrder:            pinnedApps.slice()
    property bool _dragging:             false

    property bool dragging: false
    property bool _suppressTranslateAnim: false
    property int dragSourceIndex: -1
    property int _dragTargetIndex: -1
    property real dragCursorX: 0
    property real dragStartCursorX: 0
    property real slotWidth: root.btnSize + root.btnSpacing

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    function _getPinnedItemWrapper(index) {
        return pinnedRepeater.itemAt(index)
    }

    function _getPinnedItemWidth(index) {
        var wrapper = _getPinnedItemWrapper(index)
        return wrapper ? (root.vertical ? wrapper.height : wrapper.width) : root.btnSize
    }

    function _getMaxDragOffset(index) {
        var count = _workOrder.length
        if (count <= 1) return { left: 0, right: 0 }
        var left = 0, right = 0
        for (var i = 0; i < count; i++) {
            var w = _getPinnedItemWidth(i) + root.btnSpacing
            if (i < index) left += w
            else if (i > index) right += w
        }
        return { left: -left, right: right }
    }

    function _recomputeDragTarget() {
        if (!dragging) {
            _dragTargetIndex = dragSourceIndex
            return
        }

        var count = _workOrder.length
        if (count <= 1) {
            _dragTargetIndex = dragSourceIndex
            return
        }

        var delta = dragCursorX - dragStartCursorX
        var draggedCenter = delta
        var target = dragSourceIndex

        if (delta > 0) {
            var pos = 0
            for (var i = dragSourceIndex + 1; i < count; ++i) {
                pos += (_getPinnedItemWidth(i - 1) + root.btnSpacing) / 2
                pos += (_getPinnedItemWidth(i) + root.btnSpacing) / 2

                if (draggedCenter >= pos)
                    target = i
                else
                    break
            }
        } else if (delta < 0) {
            var pos = 0
            for (var i = dragSourceIndex - 1; i >= 0; --i) {
                pos -= (_getPinnedItemWidth(i + 1) + root.btnSpacing) / 2
                pos -= (_getPinnedItemWidth(i) + root.btnSpacing) / 2

                if (draggedCenter <= pos)
                    target = i
                else
                    break
            }
        }

        _dragTargetIndex = target
    }

    function _startPinnedItemDrag(index) {
        _suppressTranslateAnim = true
        dragSourceIndex = index
        _dragTargetIndex = index
        slotWidth = root.btnSize + root.btnSpacing
        dragStartCursorX = 0
        dragCursorX = 0
        dragging = true
        Qt.callLater(function() { _suppressTranslateAnim = false })
    }

    function _endPinnedItemDrag() {
        _suppressTranslateAnim = true

        var src = dragSourceIndex
        var tgt = _dragTargetIndex

        if (dragging &&
            src >= 0 &&
            tgt >= 0 &&
            src < _workOrder.length &&
            tgt < _workOrder.length &&
            src !== tgt) {

            var arr = _workOrder.slice()

            var item = arr[src]
            arr.splice(src, 1)
            arr.splice(tgt, 0, item)

            _workOrder = arr
            Config.options.dock.pinnedApps = arr
        }

        dragging = false
        dragSourceIndex = -1
        _dragTargetIndex = -1
        dragCursorX = 0
        dragStartCursorX = 0

        Qt.callLater(function() {
            _suppressTranslateAnim = false
        })
    }

    function _cancelPinnedDrag() {
        _suppressTranslateAnim = true
        dragging = false
        dragSourceIndex = -1
        _dragTargetIndex = -1
        Qt.callLater(function() { _suppressTranslateAnim = false })
    }

    onPinnedAppsChanged: {
        if (!_dragging)
            _workOrder = pinnedApps.slice()
    }

    implicitWidth:  vertical
        ? (isMaterial ? Appearance.sizes.verticalBarWidth : Appearance.sizes.verticalBarWidth - 10)
        : pill.implicitWidth
    implicitHeight: vertical
        ? pill.implicitHeight
        : Appearance.sizes.barHeight

    function swapSlots(from, to) {
        if (from === to) return
        if (from < 0 || from >= _workOrder.length) return
        if (to   < 0 || to   >= _workOrder.length) return
        let arr = _workOrder.slice()
        let tmp = arr[from]; arr[from] = arr[to]; arr[to] = tmp
        _workOrder = arr
    }

    function commitOrder() {
        Config.options.dock.pinnedApps = _workOrder.slice()
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: "transparent"
        radius: Appearance.rounding.full

        implicitWidth: root.isMaterial && !root.vertical
            ? flow.implicitWidth + 10
            : root.vertical
                ? (root.isMaterial ? 32 : Appearance.sizes.verticalBarWidth - 10)
                : flow.implicitWidth + 4

        implicitHeight: root.isMaterial && root.vertical
            ? flow.implicitHeight + 10
            : root.isMaterial
                ? 32
                : root.vertical
                    ? flow.implicitHeight + 4
                    : Appearance.sizes.barHeight

        Behavior on implicitWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Flow {
            id: flow
            anchors.centerIn: parent
            flow:    root.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: root.btnSpacing

            Repeater {
                id: pinnedRepeater
                model: root._workOrder.length

                delegate: Item {
                    id: slotItem
                    required property int index

                    property string appId:        root._workOrder[index] ?? ""
                    property var    appEntry:     TaskbarApps.apps.find(a => a.appId.toLowerCase() === appId.toLowerCase()) ?? null

                    readonly property bool isDragged: root.dragging && index === root.dragSourceIndex
                    readonly property real dragTranslate: {
                        if (!root.dragging) return 0
                        if (isDragged) {
                            var raw = root.dragCursorX - root.dragStartCursorX
                            var maxOff = root._getMaxDragOffset(index)
                            var clamped = Math.max(maxOff.left, Math.min(maxOff.right, raw))
                            return clamped
                        }
                        var src = root.dragSourceIndex
                        var tgt = root._dragTargetIndex
                        var idx = index
                        var sw = root.slotWidth
                        if (src < tgt && idx > src && idx <= tgt) return -sw
                        if (src > tgt && idx >= tgt && idx < src) return sw
                        return 0
                    }

                    z: isDragged ? 100 : 0
                    opacity: isDragged ? 0.85 : 1
                    scale: isDragged ? 1.05 : 1

                    Behavior on opacity {
                        enabled: !root._suppressTranslateAnim
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on scale {
                        enabled: !root._suppressTranslateAnim
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    transform: Translate {
                        x: root.vertical ? 0 : slotItem.dragTranslate
                        y: root.vertical ? slotItem.dragTranslate : 0
                        Behavior on x {
                            enabled: !slotItem.isDragged && !root._suppressTranslateAnim
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on y {
                            enabled: !slotItem.isDragged && !root._suppressTranslateAnim
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }

                    width:  root.btnSize
                    height: root.btnSize

                    DragHandler {
                        id: dragHandler
                        target: null
                        grabPermissions: PointerHandler.CanTakeOverFromAnything

                        onActiveChanged: {
                            if (active) {
                                root._startPinnedItemDrag(index)
                                var pos = root.vertical ? centroid.scenePosition.y : centroid.scenePosition.x
                                root.dragStartCursorX = pos
                                root.dragCursorX = pos
                            } else {
                                if (root.dragging) {
                                    root._endPinnedItemDrag()
                                }
                            }
                        }

                        onCentroidChanged: {
                            if (!active || !root.dragging) return
                            var pos = root.vertical ? centroid.scenePosition.y : centroid.scenePosition.x
                            root.dragCursorX = pos
                            root._recomputeDragTarget()
                        }
                    }

                    DockAppItem {
                        anchors.fill: parent
                        appId: slotItem.appId
                        pinned: true
                        toplevels: root.windowsOnScreen(slotItem.appEntry?.toplevels)
                        iconSize: root.iconSize
                        btnSize: root.btnSize
                        vertical: root.vertical
                        showPreviews: root.showPreviews
                        popupEdge: root.popupEdge
                        interactionsBlocked: root.dragging
                    }
                }
            }

            Item {
                width:   root.vertical ? root.btnSize          : (root.showSeparator ? (1 + root.btnSpacing * 3) : 0)
                height:  root.vertical ? (root.showSeparator ? (1 + root.btnSpacing * 3) : 0) : root.btnSize
                visible: root.showSeparator

                Rectangle {
                    anchors.centerIn: parent
                    width:  root.vertical ? Math.round(root.btnSize * 0.6) : 2
                    height: root.vertical ? 2 : Math.round(root.btnSize * 0.6)
                    radius: 1
                    color:  root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                }
            }

            Repeater {
                id: activeRepeater
                model: ScriptModel { values: root.activeUnpinned }

                delegate: DockAppItem {
                    required property var modelData
                    appId: modelData.appId
                    pinned: false
                    toplevels: root.windowsOnScreen(modelData.toplevels)
                    iconSize: root.iconSize
                    btnSize: root.btnSize
                    vertical: root.vertical
                    showPreviews: root.showPreviews
                    popupEdge: root.popupEdge
                    interactionsBlocked: root.dragging
                }
            }
        }
    }
}
