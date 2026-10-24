pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property bool dynamic: Colours.scheme === "dynamic"
    // [{ name, flavour, colours, flavours }] from `caelestia scheme list`, wallpaper scheme left out
    property var presets: []

    readonly property list<MenuItem> variantItems: [
        MenuItem {
            text: Tr.tr("Tonal spot")
            value: "tonalspot"
        },
        MenuItem {
            text: Tr.tr("Vibrant")
            value: "vibrant"
        },
        MenuItem {
            text: Tr.tr("Expressive")
            value: "expressive"
        },
        MenuItem {
            text: Tr.tr("Fidelity")
            value: "fidelity"
        },
        MenuItem {
            text: Tr.tr("Content")
            value: "content"
        },
        MenuItem {
            text: Tr.tr("Fruit salad")
            value: "fruitsalad"
        },
        MenuItem {
            text: Tr.tr("Rainbow")
            value: "rainbow"
        },
        MenuItem {
            text: Tr.tr("Neutral")
            value: "neutral"
        },
        MenuItem {
            text: Tr.tr("Monochrome")
            value: "monochrome"
        }
    ]

    function setScheme(args: var): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", ...args]);
    }

    title: Tr.tr("Colours")
    isSubPage: true

    readonly property Process listProc: Process {
        running: true
        command: ["caelestia", "scheme", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const [name, flavours] of Object.entries(JSON.parse(text))) {
                    if (name === "dynamic")
                        continue;
                    const names = Object.keys(flavours);
                    for (const flavour of names)
                        list.push({
                            name,
                            flavour,
                            colours: flavours[flavour],
                            flavours: names.length
                        });
                }
                root.presets = list;
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // The palette in use right now
        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: swatches.implicitHeight + Tokens.padding.large * 2
            first: true
            last: true

            RowLayout {
                id: swatches

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                Repeater {
                    model: ["m3primary", "m3secondary", "m3tertiary", "m3primaryContainer", "m3secondaryContainer", "m3tertiaryContainer", "m3surfaceContainerHighest"]

                    StyledRect {
                        required property string modelData

                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Tokens.rounding.medium
                        color: Colours.palette[modelData]
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Wallpaper colours")
        }

        ToggleRow {
            first: true
            last: !root.dynamic
            text: Tr.tr("Match wallpaper")
            subtext: Tr.tr("The whole shell, apps and NoVolume's Shell design take their colours from the wallpaper, live ones too")
            checked: root.dynamic
            onToggled: root.setScheme(["-n", checked ? "dynamic" : "caelestia"])
        }

        ToggleRow {
            visible: root.dynamic
            text: Tr.tr("Automatic style")
            subtext: Tr.tr("Pick the style and light or dark theme for each new wallpaper")
            checked: GlobalConfig.services.smartScheme
            onToggled: GlobalConfig.services.smartScheme = checked
        }

        SelectRow {
            visible: root.dynamic
            label: Tr.tr("Style")
            subtext: GlobalConfig.services.smartScheme ? Tr.tr("Changes again with the next wallpaper") : ""
            menuItems: root.variantItems
            active: root.variantItems.find(i => i.value === Colours.variant) ?? null
            onSelected: item => root.setScheme(["-v", item.value])
        }

        ToggleRow {
            visible: root.dynamic
            last: true
            text: Tr.tr("High contrast")
            checked: Colours.flavour === "hard"
            onToggled: root.setScheme(["-f", checked ? "hard" : "default"])
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.largeIncreased
            first: true
            last: true
            text: Tr.tr("Dark theme")
            checked: !Colours.light
            onToggled: Colours.setMode(checked ? "dark" : "light")
        }

        SectionHeader {
            text: Tr.tr("Premade schemes")
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(2, Math.floor(width / 200))
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.medium

            Repeater {
                model: root.presets

                SchemeCard {}
            }
        }
    }

    component SchemeCard: StyledRect {
        id: card

        required property var modelData
        readonly property var c: modelData.colours
        readonly property bool selected: Colours.scheme === modelData.name && Colours.flavour === modelData.flavour

        Layout.fillWidth: true
        implicitHeight: 96
        radius: Tokens.rounding.large
        color: `#${c.surfaceContainer}`
        border.width: selected ? 2 : 0
        border.color: Colours.palette.m3primary
        scale: selected ? 1 : 0.97

        Behavior on scale {
            Anim {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: {
                    const n = card.modelData.name;
                    const name = n.charAt(0).toUpperCase() + n.slice(1);
                    return card.modelData.flavours > 1 ? `${name} · ${card.modelData.flavour}` : name;
                }
                color: `#${card.c.onSurface}`
                font: Tokens.font.label.medium
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            Row {
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: ["primary", "secondary", "tertiary"]

                    StyledRect {
                        required property string modelData

                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: `#${card.c[modelData]}`
                    }
                }
            }
        }

        StateLayer {
            radius: card.radius
            onClicked: root.setScheme(["-n", card.modelData.name, "-f", card.modelData.flavour])
        }
    }
}
