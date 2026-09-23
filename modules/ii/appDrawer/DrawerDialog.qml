import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

/**
 * Caixa de diálogo dentro do menu de apps: título com ícone, corpo e botões.
 */
Rectangle {
    id: root

    property string title
    property string iconName
    default property alias content: body.data
    property alias buttons: buttonRow.data

    implicitWidth: 520
    implicitHeight: column.implicitHeight + 48
    radius: Appearance.rounding.large
    color: Appearance.m3colors.m3surfaceContainerHigh // opaco: fica por cima do cartão translúcido
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant

    MouseArea { // Não deixa o clique atravessar para o fundo (que fecharia o diálogo)
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
        id: column
        anchors {
            fill: parent
            margins: 24
        }
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            IconImage {
                visible: root.iconName.length > 0
                implicitSize: 44
                source: Quickshell.iconPath(root.iconName, "application-x-executable")
            }
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
                wrapMode: Text.Wrap
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 10
        }

        RowLayout {
            id: buttonRow
            Layout.alignment: Qt.AlignRight
            spacing: 8
        }
    }
}
