pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DrawerDialog {
    id: root

    required property var entry
    signal closeRequested()

    property string error: ""

    title: Translation.tr("Edit shortcut")
    iconName: iconField.text || (entry?.icon ?? "")

    AppInfoLoader {
        id: loader
        entry: root.entry
    }

    Connections {
        target: AppCatalog
        function onEditDone(appId, result) {
            if (appId !== root.entry?.id) return;
            if (result.ok) root.closeRequested();
            else root.error = result.error ?? Translation.tr("Couldn't save");
        }
    }

    MaterialTextField {
        id: nameField
        Layout.fillWidth: true
        placeholderText: Translation.tr("Name")
        text: root.entry?.name ?? ""
        Component.onCompleted: forceActiveFocus()
        onAccepted: saveButton.clicked()
        Keys.onEscapePressed: root.closeRequested()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MaterialTextField {
            id: iconField
            Layout.fillWidth: true
            placeholderText: Translation.tr("Icon (theme name or file path)")
            text: root.entry?.icon ?? ""
            onAccepted: saveButton.clicked()
            Keys.onEscapePressed: root.closeRequested()
        }
        IconImage {
            implicitSize: 40
            source: Quickshell.iconPath(iconField.text, "image-missing")
        }
    }

    StyledText {
        Layout.fillWidth: true
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.smaller
        wrapMode: Text.Wrap
        text: Translation.tr("Saved to ~/.local/share/applications. The system file is not changed.")
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.error.length > 0
        color: Appearance.colors.colError
        font.pixelSize: Appearance.font.pixelSize.small
        wrapMode: Text.Wrap
        text: root.error
    }

    buttons: [
        DialogButton {
            visible: loader.info?.override === true
            buttonText: Translation.tr("Restore original")
            onClicked: AppCatalog.restore(root.entry)
        },
        DialogButton {
            buttonText: Translation.tr("Cancel")
            onClicked: root.closeRequested()
        },
        DialogButton {
            id: saveButton
            buttonText: Translation.tr("Save")
            enabled: nameField.text.trim().length > 0
            onClicked: AppCatalog.edit(root.entry, nameField.text.trim(), iconField.text.trim())
        }
    ]
}
