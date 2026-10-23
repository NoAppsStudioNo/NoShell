pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// Desktop widget: today's episodes of shows tracked from animeheaven.me
StyledRect {
    id: root

    property bool picking
    readonly property int coverHeight: 50

    function subtitle(entry: var): string {
        const t = entry.today;
        const now = AnimeHeaven.now.getTime();
        const time = Qt.formatTime(new Date(t.at), Units.twelveHourClock ? "h:mm AP" : "hh:mm");
        if (t.at > now) {
            const mins = Math.round((t.at - now) / 60000);
            const left = mins >= 60 ? `${Math.floor(mins / 60)}h ${mins % 60}m` : `${mins}m`;
            return Tr.tr("Ep %1 · %2 · in %3").arg(t.ep).arg(time).arg(left);
        }
        const aired = t.at ? Tr.tr("Ep %1 · aired %2").arg(t.ep).arg(time) : Tr.tr("Ep %1 · aired").arg(t.ep);
        return entry.uploaded >= t.ep ? aired : Tr.tr("%1 · waiting for upload").arg(aired);
    }

    implicitWidth: 420
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: Qt.alpha(Colours.palette.m3surfaceContainer, AnimeHeaven.opacity)

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "live_tv"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: root.picking ? Tr.tr("Pick shows to track") : Tr.tr("Airing today")
                font: Tokens.font.title.medium
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                disabled: AnimeHeaven.loading
                onClicked: AnimeHeaven.poll(true)
            }

            IconButton {
                icon: root.picking ? "check" : "add"
                type: IconButton.Text
                onClicked: root.picking = !root.picking
            }
        }

        // Today view, scrolls past 4 shows
        StyledText {
            visible: !root.picking && AnimeHeaven.entries.length === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Colours.palette.m3onSurfaceVariant
            text: Object.keys(AnimeHeaven.tracked).length ? Tr.tr("Nothing you track airs today.") : Tr.tr("Nothing tracked yet. Press + to pick airing shows.")
        }

        VerticalFadeFlickable {
            readonly property real rowHeight: root.coverHeight + Tokens.padding.extraSmall * 2

            visible: !root.picking && AnimeHeaven.entries.length > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(todayList.implicitHeight, rowHeight * 4 + todayList.spacing * 3)
            contentHeight: todayList.implicitHeight
            interactive: contentHeight > height
            clip: true

            ColumnLayout {
                id: todayList

                width: parent.width
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.picking ? [] : AnimeHeaven.entries

                    ShowRow {
                        id: entry

                        required property var modelData

                        show: modelData
                        subtitle: root.subtitle(modelData)
                        onClicked: AnimeHeaven.openPage(modelData.id)

                        IconButton {
                            visible: entry.modelData.episode !== null
                            icon: "download"
                            type: entry.modelData.watched ? IconButton.Tonal : IconButton.Filled
                            onClicked: AnimeHeaven.play(entry.modelData.id, entry.modelData.episode)
                        }
                    }
                }
            }
        }

        // Picker view
        VerticalFadeFlickable {
            visible: root.picking
            Layout.fillWidth: true
            implicitHeight: 440
            contentHeight: list.implicitHeight
            clip: true

            ColumnLayout {
                id: list

                width: parent.width
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.picking ? AnimeHeaven.schedule : []

                    ShowRow {
                        id: pick

                        required property var modelData

                        show: modelData
                        subtitle: Tr.tr("Ep %1").arg(modelData.nextEp)
                        onClicked: AnimeHeaven.toggle(modelData)

                        MaterialIcon {
                            text: AnimeHeaven.isTracked(pick.modelData.id) ? "check_circle" : "add_circle"
                            fill: AnimeHeaven.isTracked(pick.modelData.id) ? 1 : 0
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }
                    }
                }
            }
        }
    }

    component ShowRow: Item {
        id: row

        required property var show
        property alias subtitle: sub.text
        default property alias trailing: trailing.data

        signal clicked

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + Tokens.padding.extraSmall * 2

        StateLayer {
            radius: Tokens.rounding.small
            onClicked: row.clicked()
        }

        RowLayout {
            id: rowLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall
            spacing: Tokens.spacing.medium

            StyledClippingRect {
                implicitWidth: 36
                implicitHeight: root.coverHeight
                radius: Tokens.rounding.extraSmall
                color: Colours.palette.m3surfaceContainerHigh

                Image {
                    anchors.fill: parent
                    source: row.show.image
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 72
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: row.show.title
                    elide: Text.ElideRight
                    font: Tokens.font.body.medium
                }

                StyledText {
                    id: sub

                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            RowLayout {
                id: trailing

                spacing: Tokens.spacing.extraSmall
            }
        }
    }
}
