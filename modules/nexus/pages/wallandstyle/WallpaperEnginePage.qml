pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Live wallpapers: setup status, Steam account, installed Workshop wallpapers and the live one's properties
PageBase {
    id: root

    // Wallpaper Engine labels can be HTML or its own localisation keys
    function plain(label: string): string {
        const s = String(label ?? "").replace(/<style[\s\S]*?<\/style>/gi, "").replace(/<[^>]*>/g, "").trim();
        if (!s.startsWith("ui_"))
            return s;
        const words = s.replace(/^ui_(browse_properties_|editor_properties_)?/, "").replace(/_/g, " ");
        return words.slice(0, 1).toUpperCase() + words.slice(1);
    }

    function value(key: string): string {
        return WallpaperEngine.overrides[key] ?? String(WallpaperEngine.schema[key]?.value ?? "");
    }

    // Only follows the list while shown: the stack hides this page under the Workshop page, and grid tiles created
    // while hidden all end up in the first cell
    property list<var> shown: []

    title: Tr.tr("Wallpaper Engine")
    isSubPage: true

    Component.onCompleted: {
        WallpaperEngine.refresh();
        WallpaperEngine.refreshAccount();
        WallpaperEngine.loadProps();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        Binding {
            target: root
            property: "shown"
            value: WallpaperEngine.projects
            when: root.visible
            restoreMode: Binding.RestoreNone
        }

        // Setup, until everything is installed
        ConnectedRect {
            Layout.fillWidth: true
            visible: !WallpaperEngine.ready
            first: true
            last: true
            implicitHeight: setup.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: setup

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    text: Tr.tr("Set up live wallpapers")
                    font: Tokens.font.title.small
                }

                Repeater {
                    model: [
                        {
                            done: !!WallpaperEngine.status.steam,
                            text: Tr.tr("Buy and install Wallpaper Engine in Steam. It's a Windows app, so in its Properties > Compatibility, tick \"Force the use of a specific Steam Play compatibility tool\" first.")
                        },
                        {
                            done: !!WallpaperEngine.status.engine,
                            text: Tr.tr("Run NoShell's install.sh again. It downloads the renderer once it finds Wallpaper Engine.")
                        }
                    ]

                    RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: parent.modelData.done ? "check_circle" : "radio_button_unchecked"
                            color: parent.modelData.done ? Colours.palette.m3primary : Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: parent.modelData.text
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                TextButton {
                    type: TextButton.Tonal
                    isRound: true
                    text: Tr.tr("Check again")
                    onClicked: WallpaperEngine.refresh()
                }
            }
        }

        ButtonRow {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Tokens.spacing.medium
            visible: WallpaperEngine.ready
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "travel_explore"
                text: Tr.tr("Get more")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: root.nState.openSubPage(5) // Workshop page
            }

            IconTextButton {
                icon: "stop"
                text: Tr.tr("Stop")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                type: IconTextButton.Tonal
                disabled: !WallpaperEngine.enabled
                onClicked: WallpaperEngine.stop()
            }
        }

        // Steam account, for browsing and subscribing from here
        SectionHeader {
            first: true
            visible: WallpaperEngine.ready
            text: Tr.tr("Steam account")
        }

        RowButton {
            Layout.fillWidth: true
            visible: WallpaperEngine.ready && !WallpaperEngine.login
            first: true
            last: true
            icon: "account_circle"
            text: WallpaperEngine.account.signedIn ? WallpaperEngine.account.name : Tr.tr("Sign in with Steam")
            subtext: WallpaperEngine.account.signedIn ? Tr.tr("Signed in. Press to sign out") : Tr.tr("To browse and subscribe to Workshop wallpapers from here")
            onClicked: WallpaperEngine.account.signedIn ? WallpaperEngine.signOut() : WallpaperEngine.signIn()
        }

        // QR login
        ConnectedRect {
            Layout.fillWidth: true
            visible: !!WallpaperEngine.login
            first: true
            last: true
            implicitHeight: qrLayout.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: qrLayout

                readonly property string state: WallpaperEngine.login?.state ?? ""

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.large

                StyledRect {
                    implicitWidth: 168
                    implicitHeight: 168
                    radius: Tokens.rounding.small
                    color: "white" // QR codes need a light background
                    visible: qrLayout.state === "scan" || qrLayout.state === "confirm"

                    Image {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small
                        source: WallpaperEngine.login?.qr ?? ""
                        sourceSize: Qt.size(width, height)
                        opacity: qrLayout.state === "confirm" ? 0.2 : 1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: ({
                                starting: Tr.tr("Asking Steam for a code…"),
                                scan: Tr.tr("Scan with the Steam mobile app"),
                                confirm: Tr.tr("Approve the sign in on your phone"),
                                done: Tr.tr("Signed in"),
                                expired: Tr.tr("The code expired"),
                                failed: Tr.tr("Sign in failed"),
                                cancelled: Tr.tr("Sign in cancelled")
                            })[qrLayout.state] ?? ""
                        font: Tokens.font.title.small
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: WallpaperEngine.login?.error || (qrLayout.state === "scan" ? Tr.tr("In the Steam app, open the shield (Steam Guard) tab and tap \"Scan a QR code\".") : "")
                        visible: text
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }

                    ButtonRow {
                        spacing: Tokens.spacing.small

                        TextButton {
                            type: TextButton.Tonal
                            isRound: true
                            visible: ["expired", "failed", "cancelled"].includes(qrLayout.state)
                            text: Tr.tr("Try again")
                            onClicked: WallpaperEngine.signIn()
                        }

                        TextButton {
                            type: TextButton.Tonal
                            isRound: true
                            text: qrLayout.state === "done" ? Tr.tr("Done") : Tr.tr("Cancel")
                            onClicked: WallpaperEngine.cancelSignIn()
                        }
                    }
                }
            }
        }

        // Installed
        SectionHeader {
            visible: WallpaperEngine.ready
            text: Tr.tr("Your wallpapers")
        }

        StyledText {
            Layout.fillWidth: true
            visible: WallpaperEngine.ready && WallpaperEngine.projects.length === 0
            text: Tr.tr("No Workshop wallpapers yet. Press \"Get more\", or subscribe to some in Steam's Wallpaper Engine Workshop.")
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            visible: WallpaperEngine.projects.length > 0

            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: {
                    const list = [...root.shown];
                    while (list.length < Config.nexus.wallpapersPerRow)
                        list.push(null);
                    return list;
                }

                WallItem {
                    required property var modelData

                    // Empty placeholders for sizing
                    opacity: modelData ? 1 : 0
                    enabled: modelData

                    source: modelData?.preview ? `file://${modelData.preview}` : ""
                    text: {
                        if (!modelData)
                            return "";
                        const live = WallpaperEngine.enabled && WallpaperEngine.current === modelData.id;
                        return live ? `● ${modelData.title}` : modelData.title;
                    }
                    onClicked: WallpaperEngine.apply(modelData.id)
                }
            }
        }

        // The live wallpaper's own settings
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.largeIncreased
            visible: WallpaperEngine.enabled

            SectionHeader {
                Layout.topMargin: 0
                text: Tr.tr("Customise %1").arg(WallpaperEngine.currentProject?.title ?? "")
            }

            TextButton {
                type: TextButton.Tonal
                isRound: true
                visible: Object.keys(WallpaperEngine.overrides).length > 0
                text: Tr.tr("Reset all")
                onClicked: Object.keys(WallpaperEngine.overrides).forEach(k => WallpaperEngine.resetProp(k))
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: WallpaperEngine.enabled && props.count === 0
            text: Tr.tr("Loading settings…")
            color: Colours.palette.m3outline
        }

        Repeater {
            id: props

            // file/directory/shortcut properties need Wallpaper Engine's own editor
            model: {
                const schema = WallpaperEngine.schema;
                return Object.keys(schema).filter(k => ["bool", "slider", "combo", "color", "textinput", "text"].includes(schema[k]?.type)).sort((a, b) => (schema[a].order ?? 0) - (schema[b].order ?? 0));
            }

            Loader {
                id: prop

                required property string modelData
                required property int index
                readonly property var info: WallpaperEngine.schema[modelData]
                readonly property string label: root.plain(info.text) || modelData
                readonly property bool first: index === 0 || WallpaperEngine.schema[props.model[index - 1]]?.type === "text"
                readonly property bool last: index === props.count - 1 || WallpaperEngine.schema[props.model[index + 1]]?.type === "text"
                readonly property string current: root.value(modelData)

                Layout.fillWidth: true
                sourceComponent: ({
                        bool: boolRow,
                        slider: sliderRow,
                        combo: comboRow,
                        color: colourRow,
                        textinput: textRow,
                        text: heading
                    })[info.type]

                Component {
                    id: heading

                    SectionHeader {
                        text: prop.label
                        visible: text
                    }
                }

                Component {
                    id: boolRow

                    ToggleRow {
                        first: prop.first
                        last: prop.last
                        text: prop.label
                        checked: prop.current === "true" || prop.current === "1"
                        onToggled: WallpaperEngine.setProp(prop.modelData, checked ? "true" : "false")
                    }
                }

                Component {
                    id: sliderRow

                    SliderRow {
                        readonly property real min: Number(prop.info.min ?? 0)
                        readonly property real max: Number(prop.info.max ?? 100)
                        readonly property int decimals: prop.info.fraction ? (prop.info.precision ?? 2) : (String(prop.info.step ?? 1).split(".")[1]?.length ?? 0)

                        first: prop.first
                        last: prop.last
                        icon: "tune"
                        label: prop.label
                        valueLabel: Number(prop.current).toFixed(decimals) + (prop.info.suffix ?? "")
                        value: max > min ? (Number(prop.current) - min) / (max - min) : 0
                        onMoved: v => {
                            let x = min + v * (max - min);
                            if (prop.info.step && !prop.info.fraction)
                                x = Math.round((x - min) / prop.info.step) * prop.info.step + min;
                            WallpaperEngine.setProp(prop.modelData, x.toFixed(decimals));
                        }
                    }
                }

                Component {
                    id: comboRow

                    SelectRow {
                        first: prop.first
                        last: prop.last
                        label: prop.label
                        menuItems: options.instances
                        active: options.instances.find(i => String(i.value) === prop.current) ?? null
                        onSelected: item => WallpaperEngine.setProp(prop.modelData, String(item.value))

                        Variants {
                            id: options

                            model: prop.info.options ?? []

                            MenuItem {
                                required property var modelData

                                text: root.plain(modelData.label)
                                value: modelData.value
                            }
                        }
                    }
                }

                Component {
                    id: textRow

                    TextFieldRow {
                        first: prop.first
                        last: prop.last
                        label: prop.label
                        value: prop.current
                        onEditingFinished: v => WallpaperEngine.setProp(prop.modelData, v)
                    }
                }

                // Wallpaper Engine colours are "r g b" from 0 to 1
                Component {
                    id: colourRow

                    ConnectedRect {
                        id: colour

                        readonly property list<real> rgb: prop.current.split(" ").map(Number)
                        readonly property color value: Qt.rgba(rgb[0] ?? 0, rgb[1] ?? 0, rgb[2] ?? 0, 1)
                        property bool open

                        function set(c: color): void {
                            WallpaperEngine.setProp(prop.modelData, [c.r, c.g, c.b].map(x => x.toFixed(5)).join(" "));
                        }

                        first: prop.first
                        last: prop.last
                        implicitHeight: colourLayout.implicitHeight + Tokens.padding.medium * 2
                        clip: true

                        Behavior on implicitHeight {
                            Anim {}
                        }

                        StateLayer {
                            anchors.fill: undefined
                            width: parent.width
                            height: colourHeader.implicitHeight + Tokens.padding.medium * 2
                            onClicked: colour.open = !colour.open
                        }

                        ColumnLayout {
                            id: colourLayout

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Tokens.padding.medium
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.largeIncreased
                            spacing: Tokens.spacing.medium

                            RowLayout {
                                id: colourHeader

                                Layout.fillWidth: true
                                spacing: Tokens.spacing.medium

                                StyledRect {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: Tokens.rounding.full
                                    color: colour.value
                                    border.width: 1
                                    border.color: Colours.palette.m3outlineVariant
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: prop.label
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                MaterialIcon {
                                    text: colour.open ? "expand_less" : "expand_more"
                                    color: Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.medium
                                }
                            }

                            StyledText {
                                visible: colour.open
                                text: Tr.tr("Shell colours")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }

                            Flow {
                                Layout.fillWidth: true
                                visible: colour.open
                                spacing: Tokens.spacing.small

                                Repeater {
                                    model: ["m3primary", "m3secondary", "m3tertiary", "m3error", "m3primaryContainer", "m3secondaryContainer", "m3tertiaryContainer", "m3onSurface", "m3surface", "m3inverseSurface", "#FFFFFF", "#000000"]

                                    StyledRect {
                                        required property string modelData
                                        readonly property color swatch: modelData.startsWith("#") ? modelData : Colours.palette[modelData]

                                        implicitWidth: 32
                                        implicitHeight: 32
                                        radius: Tokens.rounding.full
                                        color: swatch
                                        border.width: 1
                                        border.color: Colours.palette.m3outlineVariant

                                        StateLayer {
                                            radius: parent.radius
                                            onClicked: colour.set(parent.swatch)
                                        }
                                    }
                                }
                            }

                            StyledTextField {
                                Layout.fillWidth: true
                                visible: colour.open
                                placeholderText: Tr.tr("Hex, like #4080FF")
                                text: colour.value.toString().toUpperCase()
                                validate: /^#?[0-9a-fA-F]{6}$/
                                onAccepted: {
                                    if (valid)
                                        colour.set("#" + text.replace("#", ""));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
