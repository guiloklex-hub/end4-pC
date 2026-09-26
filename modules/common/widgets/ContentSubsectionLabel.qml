import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledText {
    text: "Subsection"
    color: Appearance.colors.colSubtext
    Layout.leftMargin: 2
    elide: Text.ElideRight
    maximumLineCount: 1
}
