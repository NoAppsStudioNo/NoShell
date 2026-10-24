pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// One show in the anime widgets (AnimeCalendar, ContinueWatching): cover, title, subtitle, trailing buttons
Item {
    id: row

    required property var show
    readonly property int coverHeight: 50
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

        ClipRect {
            implicitWidth: 36
            implicitHeight: row.coverHeight
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
