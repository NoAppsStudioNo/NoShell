pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.osd

// Settings for the NoVolume half wheel volume OSD, laid out like the NoVolume app
PageBase {
    id: root

    property string openColour // colour row with its picker open

    readonly property list<MenuItem> markerStyles: [
        MenuItem {
            text: Tr.tr("Line")
            value: 0
        },
        MenuItem {
            text: Tr.tr("Hollow circle")
            value: 1
        },
        MenuItem {
            text: Tr.tr("Filled circle")
            value: 2
        }
    ]

    readonly property list<MenuItem> fontItems: [
        MenuItem {
            text: "NType"
            value: "ntype"
        },
        MenuItem {
            text: "NType Headline"
            value: "ntypebold"
        },
        MenuItem {
            text: "NDot"
            value: "ndot"
        },
        MenuItem {
            text: Tr.tr("Shell font")
            value: "shell"
        }
    ]

    readonly property list<MenuItem> arcAnimItems: [
        MenuItem {
            text: Tr.tr("Grow")
            value: 0
        },
        MenuItem {
            text: Tr.tr("Circle around")
            value: 1
        },
        MenuItem {
            text: Tr.tr("Retract")
            value: 2
        },
        MenuItem {
            text: Tr.tr("Static")
            value: 3
        }
    ]

    readonly property list<MenuItem> animItems: [
        MenuItem {
            text: Tr.tr("Slide")
            value: 0
        },
        MenuItem {
            text: Tr.tr("Scale")
            value: 1
        }
    ]

    readonly property var colourLabels: ({
            background: Tr.tr("Dial background"),
            shadow: Tr.tr("Shadow"),
            arc: Tr.tr("Arc"),
            progress: Tr.tr("Progress bar"),
            marker: Tr.tr("Markers"),
            minorMarker: Tr.tr("Minor markers"),
            indicator: Tr.tr("Indicator"),
            numbers: Tr.tr("Wheel numbers"),
            volumeNumber: Tr.tr("Volume number"),
            outline: Tr.tr("Dial outline"),
            volumeNumberStroke: Tr.tr("Volume number outline"),
            wheelNumbersStroke: Tr.tr("Wheel numbers outline")
        })

    title: Tr.tr("NoVolume")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Live preview, drag or scroll it
        ConnectedRect {
            id: previewCard

            property real volume: 0.58
            property bool muted

            Layout.fillWidth: true
            implicitHeight: previewDial.implicitHeight + Tokens.padding.large * 2
            first: true
            last: true
            clip: true
            color: Colours.palette.m3surfaceContainerLowest

            NoVolumeDial {
                id: previewDial

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                preview: true
                volume: previewCard.volume
                muted: previewCard.muted
                onMoved: v => {
                    previewCard.volume = Math.min(1, v);
                    previewCard.muted = false;
                }
                onMuteToggled: previewCard.muted = !previewCard.muted
            }

            StyledText {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.padding.largeIncreased
                text: Tr.tr("Preview: drag or scroll the wheel")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }

        SectionHeader {
            text: Tr.tr("General")
        }

        Toggle {
            first: true
            key: "enabled"
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show the half wheel on the right edge when the volume changes or on hover")
        }

        Num {
            key: "hideDelay"
            icon: "timer"
            label: Tr.tr("Auto-hide duration")
            from: 500
            to: 10000
            step: 100
            unit: "ms"
        }

        Num {
            key: "sensitivity"
            icon: "swipe_vertical"
            label: Tr.tr("Drag sensitivity")
            from: 0.1
            to: 2
            step: 0.05
        }

        Toggle {
            key: "invertScrolling"
            text: Tr.tr("Invert scrolling")
            subtext: Tr.tr("Drag and scroll down to turn the volume up")
        }

        Toggle {
            last: true
            key: "doubleClickMute"
            text: Tr.tr("Double click to mute")
        }

        SectionHeader {
            text: Tr.tr("Premade designs")
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: themeRow.implicitHeight + Tokens.padding.medium * 2
            first: true
            last: true

            RowLayout {
                id: themeRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                ThemeCard {
                    key: "shell"
                    label: Tr.tr("Shell")
                }
                ThemeCard {
                    key: "dark"
                    label: Tr.tr("Dark")
                }
                ThemeCard {
                    key: "light"
                    label: Tr.tr("Light")
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Colours")
        }

        Repeater {
            model: NoVolume.colourKeys

            ColourRow {
                required property string modelData
                required property int index

                key: modelData
                first: index === 0
            }
        }

        RowButton {
            last: true
            icon: "format_color_reset"
            text: Tr.tr("Reset colours")
            subtext: Tr.tr("Use the premade design's colours for every element")
            disabled: Object.keys(NoVolume.s.colours).length === 0
            onClicked: NoVolume.set("colours", {})
        }

        SectionHeader {
            text: Tr.tr("Elements")
        }

        Toggle {
            first: true
            key: "showBackground"
            text: Tr.tr("Dial background")
        }
        Toggle {
            key: "showShadow"
            text: Tr.tr("Shadow")
        }
        Toggle {
            key: "showArc"
            text: Tr.tr("Arc")
        }
        Toggle {
            key: "showProgress"
            text: Tr.tr("Progress bar")
        }
        Toggle {
            key: "showMarkers"
            text: Tr.tr("Markers")
        }
        Toggle {
            key: "showMinorMarkers"
            text: Tr.tr("Minor markers")
        }
        Toggle {
            key: "showWheelNumbers"
            text: Tr.tr("Wheel numbers")
        }
        Toggle {
            key: "showVolumeNumber"
            text: Tr.tr("Volume number")
        }
        Toggle {
            last: true
            key: "showIndicator"
            text: Tr.tr("Indicator")
        }

        SectionHeader {
            text: Tr.tr("Size & position")
        }

        Num {
            first: true
            key: "size"
            icon: "height"
            label: Tr.tr("Size")
        }
        Num {
            key: "scale"
            icon: "zoom_in"
            label: Tr.tr("Scale")
            from: 0.4
            to: 2.5
            step: 0.05
            unit: "×"
        }
        Num {
            last: true
            key: "offsetY"
            icon: "vertical_align_center"
            label: Tr.tr("Vertical offset")
            from: -500
            to: 500
            unit: "px"
        }

        SectionHeader {
            text: Tr.tr("Arc")
        }

        Num {
            first: true
            key: "arcLength"
            icon: "line_curve"
            label: Tr.tr("Arc length")
            from: 60
            to: 180
            unit: "°"
        }
        Num {
            key: "arcGap"
            icon: "settings_ethernet"
            label: Tr.tr("Arc distance")
            from: 0
            to: 2
            step: 0.05
            unit: "×"
        }
        Num {
            last: true
            key: "arcWidth"
            icon: "line_weight"
            label: Tr.tr("Arc thickness")
            from: 4
            to: 60
        }

        SectionHeader {
            text: Tr.tr("Markers")
        }

        Choice {
            first: true
            key: "markerStyle"
            label: Tr.tr("Marker style")
            menuItems: root.markerStyles
        }
        Num {
            key: "markerSize"
            icon: "straighten"
            label: Tr.tr("Marker size")
            from: 1
            to: 15
            step: 0.5
        }
        Num {
            key: "markerThickness"
            icon: "line_weight"
            label: Tr.tr("Marker thickness")
            from: 0.5
            to: 8
            step: 0.5
        }
        Choice {
            key: "minorMarkerStyle"
            label: Tr.tr("Minor marker style")
            menuItems: root.markerStyles
        }
        Num {
            key: "minorMarkerSize"
            icon: "straighten"
            label: Tr.tr("Minor marker size")
            from: 1
            to: 10
            step: 0.5
        }
        Num {
            last: true
            key: "minorMarkerThickness"
            icon: "line_weight"
            label: Tr.tr("Minor marker thickness")
            from: 0.5
            to: 5
            step: 0.5
        }

        SectionHeader {
            text: Tr.tr("Volume number")
        }

        Choice {
            first: true
            key: "volumeNumberFont"
            label: Tr.tr("Font")
            menuItems: root.fontItems
        }
        Num {
            key: "volumeNumberSize"
            icon: "format_size"
            label: Tr.tr("Size")
        }
        Num {
            key: "volumeNumberOffsetX"
            icon: "swap_horiz"
            label: Tr.tr("Horizontal offset")
            from: -300
            to: 300
        }
        Num {
            key: "volumeNumberOffsetY"
            icon: "swap_vert"
            label: Tr.tr("Vertical offset")
            from: -300
            to: 300
        }
        Num {
            key: "volumeNumberRotation"
            icon: "rotate_right"
            label: Tr.tr("Rotation")
            from: -180
            to: 180
            unit: "°"
        }
        Toggle {
            key: "volumeNumberStroke"
            text: Tr.tr("Outline")
        }
        Num {
            last: true
            enabled: NoVolume.s.volumeNumberStroke
            key: "volumeNumberStrokeWidth"
            icon: "border_style"
            label: Tr.tr("Outline width")
            from: 0.5
            to: 5
            step: 0.5
        }

        SectionHeader {
            text: Tr.tr("Wheel numbers")
        }

        Choice {
            first: true
            key: "wheelNumbersFont"
            label: Tr.tr("Font")
            menuItems: root.fontItems
        }
        Num {
            key: "wheelNumbersSize"
            icon: "format_size"
            label: Tr.tr("Size")
        }
        Toggle {
            key: "wheelNumbersStroke"
            text: Tr.tr("Outline")
        }
        Num {
            last: true
            enabled: NoVolume.s.wheelNumbersStroke
            key: "wheelNumbersStrokeWidth"
            icon: "border_style"
            label: Tr.tr("Outline width")
            from: 0.5
            to: 5
            step: 0.5
        }

        SectionHeader {
            text: Tr.tr("Effects")
        }

        Num {
            first: true
            key: "shadowRadius"
            icon: "blur_on"
            label: Tr.tr("Shadow radius")
        }
        Toggle {
            key: "outline"
            text: Tr.tr("Dial outline")
        }
        Num {
            enabled: NoVolume.s.outline
            key: "outlineThickness"
            icon: "line_weight"
            label: Tr.tr("Outline thickness")
        }
        Toggle {
            key: "internalShadow"
            text: Tr.tr("Edge fade")
            subtext: Tr.tr("Fades the dial into its background colour at the screen edge")
        }
        Num {
            last: true
            enabled: NoVolume.s.internalShadow
            key: "internalShadowWidth"
            icon: "gradient"
            label: Tr.tr("Edge fade width")
        }

        SectionHeader {
            text: Tr.tr("Animation")
        }

        Choice {
            first: true
            key: "animation"
            label: Tr.tr("Reveal animation")
            menuItems: root.animItems
        }
        Choice {
            key: "arcAnimation"
            label: Tr.tr("Arc animation")
            menuItems: root.arcAnimItems
        }
        Num {
            key: "revealSpeed"
            icon: "fast_forward"
            label: Tr.tr("Reveal speed")
            from: 0.25
            to: 3
            step: 0.05
            unit: "×"
        }
        Num {
            key: "hideSpeed"
            icon: "fast_rewind"
            label: Tr.tr("Hide speed")
            from: 0.25
            to: 3
            step: 0.05
            unit: "×"
        }
        Num {
            key: "arcRevealSpeed"
            icon: "fast_forward"
            label: Tr.tr("Arc reveal speed")
            from: 0.25
            to: 3
            step: 0.05
            unit: "×"
        }
        Num {
            last: true
            key: "arcHideSpeed"
            icon: "fast_rewind"
            label: Tr.tr("Arc hide speed")
            from: 0.25
            to: 3
            step: 0.05
            unit: "×"
        }

        RowButton {
            Layout.topMargin: Tokens.spacing.largeIncreased
            first: true
            last: true
            icon: "restart_alt"
            text: Tr.tr("Reset everything")
            subtext: Tr.tr("Back to the default NoVolume look and behaviour")
            onClicked: NoVolume.resetAll()
        }
    }

    component Toggle: ToggleRow {
        required property string key

        checked: NoVolume.s[key]
        onToggled: NoVolume.set(key, checked)
    }

    component Num: SliderRow {
        required property string key
        property real from: 0
        property real to: 100
        property real step: 1
        property string unit
        readonly property real current: NoVolume.s[key]

        value: (current - from) / (to - from)
        valueLabel: `${Math.round(current * 100) / 100}${unit}`
        onMoved: v => NoVolume.set(key, Math.round((from + v * (to - from)) / step) * step)
    }

    component Choice: SelectRow {
        required property string key

        active: menuItems.find(i => i.value === NoVolume.s[key]) ?? null
        onSelected: item => NoVolume.set(key, item.value)
    }

    component ThemeCard: StyledRect {
        id: card

        required property string key
        required property string label
        readonly property bool selected: NoVolume.s.theme === key

        Layout.fillWidth: true
        implicitHeight: 200
        radius: Tokens.rounding.large
        color: key === "light" ? "#E9E9EC" : key === "dark" ? "#111113" : Colours.palette.m3surface
        border.width: selected ? 2 : 0
        border.color: Colours.palette.m3primary
        clip: true
        scale: selected ? 1 : 0.97

        Behavior on scale {
            Anim {}
        }

        NoVolumeDial {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            u: (card.height - 30) / dialH
            preview: true
            theme: card.key
            volume: 0.58
        }

        StyledText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            text: card.label
            color: card.key === "light" ? "#1C1C1E" : card.key === "dark" ? "#FFFFFF" : Colours.palette.m3onSurface
            font: Tokens.font.label.medium
        }

        StateLayer {
            radius: card.radius
            onClicked: NoVolume.set("theme", card.key)
        }
    }

    // An element's colour: shell palette colours (follow the wallpaper), the app's classics, or any colour
    component ColourRow: ConnectedRect {
        id: row

        required property string key
        readonly property string spec: NoVolume.spec(key)
        readonly property color current: NoVolume.resolve(spec)
        readonly property bool custom: NoVolume.s.colours[key] !== undefined
        readonly property bool open: root.openColour === key

        // Picker state, so dragging saturation to 0 keeps the hue
        property real h
        property real sat
        property real val
        property real alpha

        function load(): void {
            h = Math.max(0, current.hsvHue);
            sat = current.hsvSaturation;
            val = current.hsvValue;
            alpha = current.a;
        }

        function apply(): void {
            NoVolume.setColour(key, Qt.hsva(h, sat, val, alpha).toString());
        }

        onOpenChanged: {
            if (open)
                load();
        }

        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + Tokens.padding.medium * 2
        clip: true

        Behavior on implicitHeight {
            Anim {}
        }

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            Item {
                Layout.fillWidth: true
                implicitHeight: header.implicitHeight

                StateLayer {
                    anchors.fill: undefined
                    x: -Tokens.padding.largeIncreased
                    y: -Tokens.padding.medium
                    width: parent.width + Tokens.padding.largeIncreased * 2
                    height: parent.height + Tokens.padding.medium * 2
                    onClicked: root.openColour = row.open ? "" : row.key
                }

                RowLayout {
                    id: header

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Tokens.spacing.medium

                    Swatch {
                        colour: row.current
                        implicitWidth: 28
                        implicitHeight: 28
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.colourLabels[row.key]
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: (row.custom ? Tr.tr("Custom: %1") : Tr.tr("Design: %1")).arg(row.spec.startsWith("#") ? row.spec.toUpperCase() : row.spec.replace(/^m3/, ""))
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    MaterialIcon {
                        text: row.open ? "expand_less" : "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                active: row.open
                visible: active

                sourceComponent: ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: Tr.tr("Shell colours (follow the wallpaper)")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: ["m3primary", "m3secondary", "m3tertiary", "m3error", "m3primaryContainer", "m3secondaryContainer", "m3tertiaryContainer", "m3onSurface", "m3onSurfaceVariant", "m3outline", "m3outlineVariant", "m3surface", "m3surfaceContainer", "m3surfaceContainerHighest", "m3inverseSurface", "m3shadow"]

                            Swatch {
                                required property string modelData

                                colour: Colours.palette[modelData]
                                selected: row.spec === modelData
                                onClicked: NoVolume.setColour(row.key, modelData)
                            }
                        }
                    }

                    StyledText {
                        text: Tr.tr("NoVolume classics")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: ["#FF0000", "#FFFFFF", "#000000", "#1C1C1E", "#2C2C2E", "#636366", "#7D7D7D", "#8A8A8E", "#F5F5F5", "#32000000", "#00000000"]

                            Swatch {
                                required property string modelData

                                colour: modelData
                                selected: row.spec.toUpperCase() === modelData
                                onClicked: {
                                    NoVolume.setColour(row.key, modelData);
                                    row.load();
                                }
                            }
                        }
                    }

                    // Saturation/value square and hue strip
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 160
                            radius: Tokens.rounding.small
                            color: Qt.hsva(row.h, 1, 1, 1)

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal

                                    GradientStop {
                                        position: 0
                                        color: "#FFFFFFFF"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: "#00FFFFFF"
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: "#00000000"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: "#FF000000"
                                    }
                                }
                            }

                            Knob {
                                x: row.sat * parent.width - width / 2
                                y: (1 - row.val) * parent.height - height / 2
                            }

                            MouseArea {
                                function pick(mouse: MouseEvent): void {
                                    row.sat = Math.max(0, Math.min(1, mouse.x / width));
                                    row.val = 1 - Math.max(0, Math.min(1, mouse.y / height));
                                    row.apply();
                                }

                                anchors.fill: parent
                                onPressed: mouse => pick(mouse)
                                onPositionChanged: mouse => pick(mouse)
                            }
                        }

                        Rectangle {
                            implicitWidth: 24
                            Layout.fillHeight: true
                            radius: Tokens.rounding.small
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: "#FF0000"
                                }
                                GradientStop {
                                    position: 1 / 6
                                    color: "#FFFF00"
                                }
                                GradientStop {
                                    position: 2 / 6
                                    color: "#00FF00"
                                }
                                GradientStop {
                                    position: 3 / 6
                                    color: "#00FFFF"
                                }
                                GradientStop {
                                    position: 4 / 6
                                    color: "#0000FF"
                                }
                                GradientStop {
                                    position: 5 / 6
                                    color: "#FF00FF"
                                }
                                GradientStop {
                                    position: 1
                                    color: "#FF0000"
                                }
                            }

                            Knob {
                                x: (parent.width - width) / 2
                                y: row.h * parent.height - height / 2
                            }

                            MouseArea {
                                function pick(mouse: MouseEvent): void {
                                    row.h = Math.max(0, Math.min(0.9999, mouse.y / height));
                                    row.apply();
                                }

                                anchors.fill: parent
                                onPressed: mouse => pick(mouse)
                                onPositionChanged: mouse => pick(mouse)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        StyledText {
                            text: Tr.tr("Opacity")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            implicitHeight: Tokens.padding.medium * 2
                            value: row.alpha
                            onInteraction: v => {
                                row.alpha = v;
                                row.apply();
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        StyledTextField {
                            Layout.fillWidth: true
                            verticalPadding: Tokens.padding.small
                            text: row.spec
                            placeholderText: "#AARRGGBB"
                            validate: /^(#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})|m3[A-Za-z]+)$/
                            onEditingFinished: {
                                if (valid && text && text !== row.spec) {
                                    NoVolume.setColour(row.key, text);
                                    row.load();
                                }
                            }
                        }

                        TextButton {
                            type: TextButton.Tonal
                            isRound: true
                            disabled: !row.custom
                            text: Tr.tr("Reset")
                            onClicked: {
                                NoVolume.setColour(row.key, "");
                                row.load();
                            }
                        }
                    }
                }
            }
        }
    }

    component Swatch: StyledRect {
        id: swatch

        property color colour
        property bool selected

        signal clicked

        implicitWidth: 32
        implicitHeight: 32
        radius: Tokens.rounding.full
        color: "#808080"
        border.width: selected ? 3 : 1
        border.color: selected ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

        // Checkerboard-ish backing so see-through colours read as such
        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.border.width
            radius: width / 2
            color: "#FFFFFF"

            Rectangle {
                anchors.fill: parent
                anchors.margins: parent.width / 4
                radius: width / 2
                color: "#BBBBBB"
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.border.width
            radius: width / 2
            color: swatch.colour
        }

        StateLayer {
            radius: swatch.radius
            onClicked: swatch.clicked()
        }
    }

    component Knob: Rectangle {
        implicitWidth: 16
        implicitHeight: 16
        radius: 8
        color: "transparent"
        border.width: 3
        border.color: "#FFFFFF"

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: "#80000000"
        }
    }
}
