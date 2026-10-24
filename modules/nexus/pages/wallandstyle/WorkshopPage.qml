pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Steam Workshop search. Subscribing makes the Steam client download the wallpaper, which then shows up under
// "Your wallpapers" (WallpaperEngine.downloading).
PageBase {
    id: root

    property string sort: "trend_week"

    function search(page: int): void {
        WallpaperEngine.search(searchField.text, sort, page);
    }

    title: Tr.tr("Workshop")
    isSubPage: true

    Component.onCompleted: {
        if (WallpaperEngine.account.signedIn && WallpaperEngine.results.length === 0)
            search(1);
    }

    readonly property list<MenuItem> sorts: [
        MenuItem {
            text: Tr.tr("Trending this week")
            value: "trend_week"
        },
        MenuItem {
            text: Tr.tr("Trending this month")
            value: "trend_month"
        },
        MenuItem {
            text: Tr.tr("Trending this year")
            value: "trend_year"
        },
        MenuItem {
            text: Tr.tr("Most subscribed")
            value: "most_subscribed"
        },
        MenuItem {
            text: Tr.tr("Top rated")
            value: "top_rated"
        },
        MenuItem {
            text: Tr.tr("Most recent")
            value: "recent"
        }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            visible: !WallpaperEngine.account.signedIn
            text: Tr.tr("Sign in with Steam on the previous page to browse the Workshop here.")
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        SearchBar {
            id: searchField

            Layout.fillWidth: true
            visible: WallpaperEngine.account.signedIn
            placeholderText: Tr.tr("Search the Workshop")
            font: Tokens.font.body.large
            bg.color: Colours.tPalette.m3surfaceContainer
            onAccepted: root.search(1)
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.small
            visible: WallpaperEngine.account.signedIn
            first: true
            last: true
            label: Tr.tr("Sort by")
            menuItems: root.sorts
            active: root.sorts.find(i => i.value === root.sort) ?? null
            onSelected: item => {
                root.sort = item.value;
                root.search(1);
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            visible: WallpaperEngine.account.signedIn
            text: Tr.tr("Press a wallpaper to subscribe. Steam downloads it while it's running, then it appears under \"Your wallpapers\".")
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: !!WallpaperEngine.searchError
            text: WallpaperEngine.searchError
            color: Colours.palette.m3error
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            visible: WallpaperEngine.account.signedIn

            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: {
                    const list = [...WallpaperEngine.results];
                    while (list.length < Config.nexus.wallpapersPerRow)
                        list.push(null);
                    return list;
                }

                WallItem {
                    id: item

                    required property var modelData
                    readonly property bool installed: !!modelData && WallpaperEngine.projects.some(p => p.id === modelData.id)

                    // Empty placeholders for sizing
                    opacity: modelData ? 1 : 0
                    enabled: modelData

                    source: modelData?.preview ?? ""
                    text: modelData?.title ?? ""
                    onClicked: WallpaperEngine.setSubscribed(modelData.id, !modelData.subscribed)

                    StyledRect {
                        x: Tokens.padding.small
                        y: Tokens.padding.small
                        visible: !!item.modelData?.subscribed
                        implicitWidth: badge.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: badge.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primaryContainer

                        StyledText {
                            id: badge

                            anchors.centerIn: parent
                            text: item.installed ? Tr.tr("Installed") : Tr.tr("Subscribed")
                            color: Colours.palette.m3onPrimaryContainer
                            font: Tokens.font.label.small
                        }
                    }
                }
            }
        }

        LoadingIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: WallpaperEngine.searching
            implicitSize: 48
        }

        TextButton {
            Layout.alignment: Qt.AlignHCenter
            visible: WallpaperEngine.moreResults && !WallpaperEngine.searching
            type: TextButton.Tonal
            isRound: true
            text: Tr.tr("Load more")
            onClicked: WallpaperEngine.search(WallpaperEngine.lastSearch.query, WallpaperEngine.lastSearch.sort, WallpaperEngine.lastSearch.page + 1)
        }
    }
}
