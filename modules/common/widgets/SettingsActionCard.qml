import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    property string icon: "settings"
    property var iconShape: MaterialShape.Shape.Square
    property color iconColor: Appearance.colors.colOnPrimaryContainer
    property color iconContainerColor: Appearance.colors.colPrimaryContainer
    property string title: ""
    property string description: ""
    property string buttonText: Translation.tr("Open")
    property string buttonIcon: "open_in_new"
    property var action: null

    Layout.fillWidth: true
    implicitHeight: Math.max(72, contentRow.implicitHeight + 32)
    radius: Appearance.rounding.normal
    color: (root.action && cardMouseArea.containsPress) ? Appearance.colors.colLayer1Active : ((root.action && cardMouseArea.containsMouse) ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1)
    Behavior on color { ColorAnimation { duration: 150 } }
    border.width: 1
    border.color: Appearance.colors.colLayer0Border
    clip: true

    // MouseArea declarada antes para ficar sob o botão (não intercepta o RippleButton)
    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        enabled: !!root.action
        hoverEnabled: true
        cursorShape: !!root.action ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.action) root.action();
        }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            wrappedShape: root.iconShape
            text: root.icon
            iconSize: Appearance.font.pixelSize.larger
            implicitSize: 42
            color: root.iconContainerColor
            colSymbol: root.iconColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.description
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.WordWrap
                visible: root.description.length > 0
            }
        }

        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignVCenter
            materialIcon: root.buttonIcon
            mainText: root.buttonText
            onClicked: {
                if (root.action) root.action();
            }
        }
    }
}
