pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

DrawerDialog {
    id: root

    required property var entry
    signal closeRequested()
    signal uninstallRequested()

    readonly property var info: loader.info

    title: entry?.name ?? ""
    iconName: entry?.icon ?? ""

    AppInfoLoader {
        id: loader
        entry: root.entry
    }

    StyledText {
        Layout.fillWidth: true
        visible: text.length > 0
        text: root.entry?.comment || root.info?.description || ""
        color: Appearance.colors.colSubtext
        wrapMode: Text.Wrap
    }

    StyledIndeterminateProgressBar {
        Layout.fillWidth: true
        visible: loader.loading
    }

    GridLayout {
        Layout.fillWidth: true
        visible: !loader.loading
        columns: 2
        columnSpacing: 16
        rowSpacing: 6

        component Label: StyledText {
            Layout.alignment: Qt.AlignTop
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
        component Value: StyledText {
            Layout.fillWidth: true
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.Wrap
        }

        Label { text: Translation.tr("Source") }
        Value { text: AppCatalog.sourceLabel(root.info?.source) + (root.info?.overridden ? " · " + Translation.tr("customized locally") : "") }

        Label { text: Translation.tr("Package"); visible: (root.info?.package ?? "") !== "" }
        Value { text: root.info?.package ?? ""; visible: text !== "" }

        Label { text: Translation.tr("Version"); visible: (root.info?.version ?? "") !== "" }
        Value { text: root.info?.version ?? ""; visible: text !== "" }

        Label { text: Translation.tr("Repository"); visible: (root.info?.repository ?? "") !== "" }
        Value { text: root.info?.repository ?? ""; visible: text !== "" }

        Label { text: Translation.tr("Size"); visible: (root.info?.size ?? "") !== "" }
        Value { text: root.info?.size ?? ""; visible: text !== "" }

        Label { text: Translation.tr("Installed on"); visible: (root.info?.installDate ?? "") !== "" }
        Value {
            visible: text !== ""
            text: {
                const raw = root.info?.installDate ?? "";
                const date = new Date(raw);
                return isNaN(date) ? raw : date.toLocaleString(Qt.locale(), Locale.ShortFormat);
            }
        }

        Label { text: Translation.tr("Category") }
        Value { text: AppCatalog.categoryName(AppCatalog.categoryOf(root.entry)) + " · " + (root.entry?.categories ?? []).join(", ") }

        Label { text: Translation.tr("Command") }
        Value {
            text: root.entry?.execString ?? ""
            font.family: Appearance.font.family.monospace
            wrapMode: Text.WrapAnywhere
        }

        Label { text: Translation.tr("Shortcut file") }
        Value {
            text: root.info?.path ?? ""
            font.family: Appearance.font.family.monospace
            wrapMode: Text.WrapAnywhere
        }

        Label { text: Translation.tr("Same package"); visible: (root.info?.siblings ?? []).length > 0 }
        Value {
            visible: (root.info?.siblings ?? []).length > 0
            text: (root.info?.siblings ?? []).map(f => AppCatalog.byId(f.replace(/\.desktop$/, ""))?.name ?? f).join(", ")
        }
    }

    buttons: [
        DialogButton {
            buttonText: Translation.tr("Uninstall")
            colEnabled: Appearance.colors.colError
            onClicked: root.uninstallRequested()
        },
        DialogButton {
            buttonText: Translation.tr("Copy path")
            enabled: !loader.loading
            onClicked: Quickshell.clipboardText = root.info?.path ?? ""
        },
        DialogButton {
            buttonText: Translation.tr("Open")
            onClicked: AppCatalog.launch(root.entry)
        },
        DialogButton {
            buttonText: Translation.tr("Close")
            onClicked: root.closeRequested()
        }
    ]
}
