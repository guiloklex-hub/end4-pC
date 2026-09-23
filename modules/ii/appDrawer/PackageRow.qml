import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Pacote encontrado nos repositórios, no AUR ou no Flathub, com botão de instalar.
 */
RowLayout {
    id: root

    required property var pkg
    spacing: 12

    MaterialSymbol {
        Layout.alignment: Qt.AlignVCenter
        text: root.pkg.source === "flatpak" ? "package_2" : root.pkg.source === "aur" ? "construction" : "deployed_code"
        iconSize: 24
        color: Appearance.colors.colPrimary
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            spacing: 8
            StyledText {
                text: root.pkg.name
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: root.pkg.version
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            Rectangle {
                implicitWidth: sourceText.implicitWidth + 12
                implicitHeight: sourceText.implicitHeight + 4
                radius: Appearance.rounding.full
                color: Appearance.colors.colSecondaryContainer
                StyledText {
                    id: sourceText
                    anchors.centerIn: parent
                    text: root.pkg.source === "flatpak" ? "Flathub" : root.pkg.repository
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.pkg.description
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }

    DialogButton {
        buttonText: root.pkg.installed ? Translation.tr("Installed") : Translation.tr("Install")
        enabled: !root.pkg.installed
        onClicked: AppCatalog.install(root.pkg)
    }
}
