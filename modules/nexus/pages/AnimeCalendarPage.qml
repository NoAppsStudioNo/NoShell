import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Anime calendar")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Desktop widget")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show today's tracked anime in the bottom-right corner")
            checked: AnimeHeaven.enabled
            onToggled: AnimeHeaven.setSetting("enabled", checked)
        }

        SliderRow {
            last: true
            icon: "opacity"
            label: Tr.tr("Background opacity")
            valueLabel: Strings.percentOne(value)
            value: AnimeHeaven.opacity
            onMoved: v => AnimeHeaven.setSetting("opacity", v)
        }

        SectionHeader {
            text: Tr.tr("AniList sync")
        }

        RowButton {
            readonly property bool loggedIn: AnimeHeaven.anilistToken !== ""

            first: true
            last: true
            icon: loggedIn ? "logout" : "login"
            text: loggedIn ? Tr.tr("Log out of AniList") : AnimeHeaven.loggingIn ? Tr.tr("Waiting for AniList…") : Tr.tr("Log in to AniList")
            subtext: AnimeHeaven.anilistUser ? Tr.tr("Logged in as %1. Finished episodes update your list.").arg(AnimeHeaven.anilistUser) : loggedIn ? Tr.tr("Checking login…") : Tr.tr("Opens AniList in your browser, press Approve there")
            disabled: AnimeHeaven.loggingIn
            onClicked: loggedIn ? AnimeHeaven.setAnilistToken("") : AnimeHeaven.login()
        }
    }
}
