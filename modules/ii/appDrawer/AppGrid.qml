pragma ComponentBehavior: Bound

import qs.services
import QtQuick

/**
 * Grade de AppTile. `selected` é a seleção do teclado (-1 = nenhuma); o
 * currentIndex da GridView não serve porque volta a 0 a cada troca de modelo.
 */
GridView {
    id: grid

    required property var drawer
    property int selected: -1
    readonly property int columns: Math.max(1, Math.floor(width / drawer.tileWidth))

    cellWidth: width / columns
    cellHeight: drawer.tileHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: -1
    keyNavigationEnabled: false

    onModelChanged: if (selected >= count) selected = count - 1

    function move(dx, dy) {
        if (count === 0) return;
        if (selected < 0) {
            selected = 0;
        } else {
            const next = selected + dx + dy * columns;
            if (next >= 0 && next < count) selected = next;
        }
        positionViewAtIndex(selected, GridView.Contain);
    }

    function selectedEntry() {
        return (selected >= 0 && selected < count) ? model[selected] : null;
    }

    function selectedItem() {
        return selected >= 0 ? itemAtIndex(selected) : null;
    }

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        width: grid.cellWidth
        height: grid.cellHeight

        AppTile {
            anchors.centerIn: parent
            width: Math.min(parent.width, implicitWidth)
            entry: cell.modelData
            current: grid.selected === cell.index
            onActivated: AppCatalog.launch(cell.modelData)
            onContextMenuRequested: (x, y) => grid.drawer.openMenu(cell.modelData, x, y)
            onDragStarted: (x, y) => grid.drawer.startDrag(cell.modelData, x, y)
            onDragMoved: (x, y) => {
                grid.drawer.dragX = x;
                grid.drawer.dragY = y;
            }
            onDragEnded: (x, y) => grid.drawer.endDrag(x, y)
        }
    }
}
