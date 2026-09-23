pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

DrawerDialog {
    id: root

    required property var entry
    signal closeRequested()

    readonly property var info: loader.info
    readonly property string source: info?.source ?? ""
    readonly property bool isPackage: ["pacman", "aur", "flatpak"].includes(source)
    readonly property bool blocked: (info?.removeBlocked ?? []).length > 0

    title: Translation.tr("Uninstall %1?").arg(entry?.name ?? "")
    iconName: entry?.icon ?? ""

    AppInfoLoader {
        id: loader
        entry: root.entry
    }

    StyledIndeterminateProgressBar {
        Layout.fillWidth: true
        visible: loader.loading
    }

    component Paragraph: StyledText {
        Layout.fillWidth: true
        color: Appearance.colors.colOnLayer1
        font.pixelSize: Appearance.font.pixelSize.small
        wrapMode: Text.Wrap
        textFormat: Text.StyledText
    }

    Paragraph {
        visible: !loader.loading && !root.blocked
        text: {
            const i = root.info;
            if (!i) return "";
            switch (root.source) {
            case "pacman":
            case "aur":
                return Translation.tr("A terminal will open running <tt>paru -Rns %1</tt>. Confirm there to remove.").arg(i.package);
            case "flatpak":
                return Translation.tr("A terminal will open running <tt>flatpak uninstall %1</tt> and then offer to remove unused runtimes.").arg(i.package);
            case "webapp":
                return Translation.tr("The shortcut goes to the trash. The web app itself stays registered in %1 and can be removed there.").arg(i.repository || Translation.tr("the browser"));
            case "appimage":
                return Translation.tr("The shortcut goes to the trash. The AppImage file stays at <tt>%1</tt>.").arg(i.appimage ?? "");
            default:
                return Translation.tr("Only the shortcut (.desktop) goes to the trash; no program is uninstalled.")
                    + ((i.repository ?? "") !== "" ? " " + Translation.tr("The program comes from: %1.").arg(i.repository) : "");
            }
        }
    }

    Paragraph {
        visible: !loader.loading && !root.blocked && (root.info?.removes ?? []).length > 0
        text: Translation.tr("Packages removed: <b>%1</b>").arg((root.info?.removes ?? []).join(", "))
            + ((root.info?.freed ?? "") !== "" ? "<br>" + Translation.tr("Space freed: %1").arg(root.info.freed) : "")
    }

    Paragraph {
        visible: !loader.loading && !root.blocked && (root.info?.siblings ?? []).length > 0
        color: Appearance.colors.colSubtext
        text: Translation.tr("The same package also provides: %1 (they go too).")
            .arg((root.info?.siblings ?? []).map(f => AppCatalog.byId(f.replace(/\.desktop$/, ""))?.name ?? f).join(", "))
    }

    Paragraph {
        visible: !loader.loading && root.info?.overridden === true
        color: Appearance.colors.colSubtext
        text: Translation.tr("Your local customization of the shortcut is also moved to the trash.")
    }

    Rectangle {
        Layout.fillWidth: true
        visible: root.blocked
        implicitHeight: blockedText.implicitHeight + 24
        radius: Appearance.rounding.small
        color: Appearance.colors.colErrorContainer

        StyledText {
            id: blockedText
            anchors {
                fill: parent
                margins: 12
            }
            color: Appearance.colors.colOnErrorContainer
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.Wrap
            text: Translation.tr("%1 can't be removed on its own: it is required by %2.")
                .arg(root.info?.package ?? "").arg((root.info?.removeBlocked ?? []).join(", "))
        }
    }

    buttons: [
        DialogButton {
            buttonText: root.blocked ? Translation.tr("Close") : Translation.tr("Cancel")
            onClicked: root.closeRequested()
        },
        DialogButton {
            visible: !root.blocked
            enabled: !loader.loading
            buttonText: root.isPackage ? Translation.tr("Uninstall") : Translation.tr("Move to trash")
            colEnabled: Appearance.colors.colError
            onClicked: {
                AppCatalog.uninstall(root.info);
                if (root.isPackage)
                    GlobalStates.appDrawerOpen = false; // o terminal assume daqui
                else
                    root.closeRequested();
            }
        }
    ]
}
