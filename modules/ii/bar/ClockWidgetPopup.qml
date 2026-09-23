import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    property var today: new Date()
    property int activeTab: 0 // 0: Agenda, 1: Tarefas (To Do)
    contentItem: mainLayout

    function usageColor(value) {
        if (value > 0.9) return Appearance.colors.colError
        if (value > 0.6) return Appearance.m3colors.m3tertiary
        return Appearance.colors.colPrimary
    }

    ColumnLayout {
        id: mainLayout
        spacing: 10
        implicitWidth: 500
        width: 500

        // Cabeçalho com Mês/Ano e Ações Rápidas (Sync e Abrir Web)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: Qt.locale().toString(root.today, " MMMM")
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: Qt.locale().toString(root.today, "yyyy")
                    font.pixelSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            // Espaçador para empurrar os botões de ação para a direita
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            // Botão de Sincronização Manual com animação de giro
            RippleButton {
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                downAction: () => GoogleAgenda.refresh()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.normal + 2
                    color: GoogleAgenda.isSyncing ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                        running: GoogleAgenda.isSyncing
                    }
                }
            }

            // Botão para abrir o Google Agenda no navegador
            RippleButton {
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                downAction: () => GoogleAgenda.openCalendarWeb()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "open_in_new"
                    iconSize: Appearance.font.pixelSize.normal + 2
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        // Faixa Semanal (7 dias) com tamanho ampliado e Multi-dots coloridos
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: 7
                delegate: Rectangle {
                    required property int index

                    readonly property var date: {
                        const today = root.today
                        const dow = today.getDay()
                        const d = new Date(today)
                        d.setDate(today.getDate() - dow + index)
                        return d
                    }
                    readonly property bool isToday: {
                        const t = root.today
                        return date.getDate()     === t.getDate() &&
                               date.getMonth()    === t.getMonth() &&
                               date.getFullYear() === t.getFullYear()
                    }

                    Layout.fillWidth: true
                    height: 66
                    radius: Appearance.rounding.normal
                    color: isToday
                        ? Appearance.colors.colPrimaryContainer
                        : Appearance.colors.colSurfaceContainerHigh

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.locale().toString(date, "ddd").slice(0, 2)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: isToday
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnSurfaceVariant
                            font.weight: isToday ? Font.Bold : Font.Normal
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: date.getDate()
                            font.pixelSize: isToday
                                ? Appearance.font.pixelSize.normal + 1
                                : Appearance.font.pixelSize.small
                            font.weight: isToday ? Font.Bold : Font.Normal
                            color: isToday
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnLayer1
                        }

                        // Multi-dots coloridos das agendas para este dia
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 3
                            height: 6

                            Repeater {
                                model: GoogleAgenda.getCalendarColorsForDate(date)
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: modelData
                                }
                            }
                        }
                    }
                }
            }
        }

        // Seletor de Abas: Agenda vs Tarefas
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RippleButton {
                id: agendaTabBtn
                Layout.fillWidth: true
                implicitHeight: 34
                buttonRadius: Appearance.rounding.small
                property bool isSelected: root.activeTab === 0
                colBackground: agendaTabBtn.isSelected ? Appearance.colors.colSecondaryContainer : "transparent"
                downAction: () => root.activeTab = 0

                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol {
                        text: "calendar_month"
                        iconSize: Appearance.font.pixelSize.normal
                        color: agendaTabBtn.isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Translation.tr("Agenda") + ` (${GoogleAgenda.filteredEvents.length})`
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: agendaTabBtn.isSelected ? Font.DemiBold : Font.Normal
                        color: agendaTabBtn.isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            RippleButton {
                id: todoTabBtn
                Layout.fillWidth: true
                implicitHeight: 34
                buttonRadius: Appearance.rounding.small
                property bool isSelected: root.activeTab === 1
                colBackground: todoTabBtn.isSelected ? Appearance.colors.colSecondaryContainer : "transparent"
                downAction: () => root.activeTab = 1

                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol {
                        text: "checklist"
                        iconSize: Appearance.font.pixelSize.normal
                        color: todoTabBtn.isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Translation.tr("Tarefas") + ` (${Todo.list.filter(t => !t.done).length})`
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: todoTabBtn.isSelected ? Font.DemiBold : Font.Normal
                        color: todoTabBtn.isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Conteúdo da Aba 0: Google Agenda (Chips de Filtro + Lista de Compromissos)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.activeTab === 0

            // Chips de Filtro em Flickable horizontal com espaçamento aprimorado
            Flickable {
                Layout.fillWidth: true
                implicitHeight: 34
                contentWidth: filterChipsRow.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: filterChipsRow
                    spacing: 8

                    // Chip 'Todas'
                    RippleButton {
                        id: allChipBtn
                        property bool isSelected: GoogleAgenda.activeFilter === "all"
                        implicitHeight: 28
                        implicitWidth: chipTextAll.implicitWidth + 20
                        buttonRadius: Appearance.rounding.full
                        colBackground: allChipBtn.isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                        downAction: () => GoogleAgenda.setFilter("all")

                        contentItem: StyledText {
                            id: chipTextAll
                            anchors.centerIn: parent
                            text: Translation.tr("Todas") + ` (${GoogleAgenda.rawEvents.length})`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: allChipBtn.isSelected ? Font.DemiBold : Font.Normal
                            color: allChipBtn.isSelected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                        }
                    }

                    // Chips individuais para cada uma das 3 agendas
                    Repeater {
                        model: GoogleAgenda.calendars
                        delegate: RippleButton {
                            id: calChipBtn
                            required property var modelData
                            property bool isSelected: GoogleAgenda.activeFilter === modelData.id
                            implicitHeight: 28
                            implicitWidth: calChipContent.implicitWidth + 20
                            buttonRadius: Appearance.rounding.full
                            colBackground: calChipBtn.isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                            downAction: () => GoogleAgenda.setFilter(modelData.id)

                            contentItem: Row {
                                id: calChipContent
                                anchors.centerIn: parent
                                spacing: 6

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: modelData.color
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: `${modelData.name} (${modelData.count})`
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: calChipBtn.isSelected ? Font.DemiBold : Font.Normal
                                    color: calChipBtn.isSelected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            // Lista de Compromissos ampla com scroll
            ListView {
                id: eventsListView
                Layout.fillWidth: true
                implicitHeight: Math.min(260, contentHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 8
                model: GoogleAgenda.filteredEvents
                visible: GoogleAgenda.filteredEvents.length > 0

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: eventsListView.width
                    implicitHeight: cardContent.implicitHeight + 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHigh

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GoogleAgenda.openCalendarWeb()
                    }

                    RowLayout {
                        id: cardContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 12
                            rightMargin: 12
                        }
                        spacing: 10

                        // Faixa vertical na cor do calendário
                        Rectangle {
                            Layout.preferredWidth: 4
                            Layout.preferredHeight: 36
                            radius: 2
                            color: modelData.calendar_color
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.summary
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 8

                                // Badge da agenda
                                Rectangle {
                                    implicitWidth: calNameText.implicitWidth + 10
                                    implicitHeight: 20
                                    radius: Appearance.rounding.full
                                    color: modelData.calendar_color_container || Appearance.colors.colSecondaryContainer

                                    StyledText {
                                        id: calNameText
                                        anchors.centerIn: parent
                                        text: modelData.calendar_name
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: modelData.calendar_on_color_container || Appearance.colors.colOnSecondaryContainer
                                    }
                                }

                                // Horário e Data formatados considerando fuso horário local
                                StyledText {
                                    text: {
                                        const t = root.today;
                                        const nowStr = `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, "0")}-${String(t.getDate()).padStart(2, "0")}`;
                                        const isToday = modelData.date_str === nowStr;
                                        let datePrefix = isToday ? Translation.tr("Hoje") : modelData.date_str.slice(5).replace("-", "/");
                                        if (modelData.end_date_str && modelData.end_date_str !== modelData.date_str) {
                                            datePrefix += " - " + modelData.end_date_str.slice(5).replace("-", "/");
                                        }
                                        if (modelData.is_all_day) {
                                            return `${datePrefix} • ${Translation.tr("Dia inteiro")}`;
                                        }
                                        return `${datePrefix} • ${modelData.start_time_str} - ${modelData.end_time_str}`;
                                    }
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSurfaceVariant
                                }
                            }
                        }

                        // Botão para entrar na reunião se houver link do Google Meet/Zoom
                        RippleButton {
                            visible: !!modelData.meet_url
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colPrimaryContainer
                            downAction: () => GoogleAgenda.openMeetingUrl(modelData.meet_url)

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "video_call"
                                iconSize: Appearance.font.pixelSize.normal + 2
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }
            }

            // Empty State para quando não há compromissos
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 70
                visible: GoogleAgenda.filteredEvents.length === 0
                radius: Appearance.rounding.normal
                color: Appearance.colors.colSurfaceContainerHigh

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    MaterialSymbol {
                        text: "event_available"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        text: Translation.tr("Nenhum compromisso próximo")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }

        // Conteúdo da Aba 1: Tarefas (To Do original preservado)
        Row {
            Layout.fillWidth: true
            spacing: 8
            visible: root.activeTab === 1

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                MaterialShapeWrappedMaterialSymbol {
                    shape: MaterialShape.Shape.Clover4Leaf
                    text: "checklist"
                    iconSize: Appearance.font.pixelSize.large
                    implicitSize: 40
                    color: Appearance.colors.colPrimaryContainer
                    colSymbol: Appearance.colors.colPrimary
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Todo.list.filter(t => !t.done).length}`
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                }
            }

            Column {
                width: parent.width - 40 - 8
                spacing: 4

                Repeater {
                    id: todoRepeater
                    model: Math.min(3, Todo.list.filter(t => !t.done).length)

                    delegate: Rectangle {
                        required property int index
                        readonly property var filteredList: Todo.list.filter(t => !t.done)
                        readonly property var todo: filteredList[filteredList.length - 1 - index]
                        readonly property int total: todoRepeater.count
                        readonly property bool isFirst: index === 0
                        readonly property bool isLast: index === total - 1
                        readonly property real bigRadius: Appearance.rounding.normal
                        readonly property real smallRadius: Appearance.rounding.unsharpenmore

                        width: parent.width
                        height: 34
                        topLeftRadius:     isFirst ? bigRadius : smallRadius
                        topRightRadius:    isFirst ? bigRadius : smallRadius
                        bottomLeftRadius:  isLast  ? bigRadius : smallRadius
                        bottomRightRadius: isLast  ? bigRadius : smallRadius
                        color: Appearance.colors.colSurfaceContainerHigh

                        StyledText {
                            anchors {
                                left: parent.left
                                leftMargin: 12
                                verticalCenter: parent.verticalCenter
                                right: parent.right
                                rightMargin: 12
                            }
                            text: `    ${todo.content} `
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 64
                    visible: Todo.list.filter(t => !t.done).length === 0
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHigh

                    StyledText {
                        anchors.centerIn: parent
                        text: Translation.tr("No pending tasks")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }

        // Rodapé com System Uptime
        Rectangle {
            Layout.fillWidth: true
            height: 16
            color: "transparent"

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: "timelapse"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    text: Translation.tr("System Uptime")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    text: "•"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    text: DateTime.uptime
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }
    }
}