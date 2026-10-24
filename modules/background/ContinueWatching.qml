pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import "../../utils/scripts/anime.js" as Anime

// Desktop widget above the anime calendar: the show being watched, play resumes where you left off and a show
// moves to its next episode once 80% of one is watched. The library picks the show and searches AniList to add more.
StyledRect {
    id: root

    property bool library

    function subtitle(w: var): string {
        if (w.ep > w.aired) {
            if (!w.airAt)
                return Tr.tr("Ep %1 · not out yet").arg(w.ep);
            return Tr.tr("Ep %1 · airs %2").arg(w.ep).arg(Qt.formatDateTime(new Date(w.airAt), Units.twelveHourClock ? "ddd h:mm AP" : "ddd hh:mm"));
        }
        if (w.pos > 0 && w.dur > 0)
            return Tr.tr("Ep %1 · %2 min left").arg(w.ep).arg(Math.ceil((w.dur - w.pos) / 60));
        return w.total ? Tr.tr("Ep %1 of %2").arg(w.ep).arg(w.total) : Tr.tr("Ep %1").arg(w.ep);
    }

    // Original title and year tell seasons apart (AniList's "Gintama Season 3" is Gintama°, 2015)
    function details(show: var): string {
        const eps = show.total ? Tr.tr("%1 episodes").arg(show.total) : Tr.tr("Airing");
        return [show.romaji !== show.title ? show.romaji : "", show.year || "", eps].filter(Boolean).join(" · ");
    }

    onLibraryChanged: {
        field.text = "";
        AnimeHeaven.searchResults = [];
        if (library)
            field.forceActiveFocus();
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
                text: root.library ? "video_library" : "play_circle"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                visible: !root.library
                Layout.fillWidth: true
                text: Tr.tr("Continue watching")
                font: Tokens.font.title.medium
            }

            StyledTextField {
                id: field

                visible: root.library
                Layout.fillWidth: true
                verticalPadding: Tokens.padding.small
                placeholderText: Tr.tr("Search AniList to add a show")
                onTextEdited: searchTimer.restart()
                onAccepted: {
                    searchTimer.stop();
                    AnimeHeaven.search(text);
                }
                Keys.onEscapePressed: root.library = false
            }

            IconButton {
                visible: !root.library
                icon: "refresh"
                type: IconButton.Text
                onClicked: AnimeHeaven.refreshWatching()
            }

            IconButton {
                icon: root.library ? "close" : "video_library"
                type: IconButton.Text
                onClicked: root.library = !root.library
            }
        }

        StyledText {
            visible: !root.library && !AnimeHeaven.current
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Colours.palette.m3onSurfaceVariant
            text: Tr.tr("Nothing yet. Open the library to add a show, or play one from the calendar.")
        }

        AnimeShowRow {
            id: current

            visible: !root.library && AnimeHeaven.current
            show: AnimeHeaven.current ?? ({ title: "", image: "" })
            subtitle: AnimeHeaven.current ? root.subtitle(AnimeHeaven.current) : ""
            onClicked: Qt.openUrlExternally(Anime.anilistPage(show.id))

            IconButton {
                icon: "play_arrow"
                disabled: !AnimeHeaven.current || current.show.ep > current.show.aired || AnimeHeaven.starting === current.show.id
                onClicked: AnimeHeaven.watch(current.show.id)
            }
        }

        // Library: the shows being watched, or AniList search results while typing
        VerticalFadeFlickable {
            visible: root.library && list.implicitHeight > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(list.implicitHeight, 440)
            contentHeight: list.implicitHeight
            interactive: contentHeight > height
            clip: true

            ColumnLayout {
                id: list

                width: parent.width
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.library ? (field.text.trim() ? AnimeHeaven.searchResults : AnimeHeaven.continueList) : []

                    AnimeShowRow {
                        id: item

                        required property var modelData
                        readonly property bool added: AnimeHeaven.isWatching(modelData.id)

                        show: modelData
                        subtitle: added ? root.subtitle(AnimeHeaven.watching[modelData.id]) : root.details(modelData)
                        onClicked: {
                            if (added)
                                AnimeHeaven.select(modelData.id);
                            else
                                AnimeHeaven.add(modelData, modelData.progress + 1);
                            root.library = false;
                        }

                        MaterialIcon {
                            visible: item.added && AnimeHeaven.current?.id === item.modelData.id
                            text: "check"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        MaterialIcon {
                            visible: !item.added
                            text: "add_circle"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: searchTimer

        interval: 400
        onTriggered: AnimeHeaven.search(field.text)
    }
}
