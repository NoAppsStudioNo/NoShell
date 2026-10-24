pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

// Settings for the NoVolume half wheel (modules/osd/NoVolumeDial.qml), the volume OSD on the right screen edge.
// Option names and defaults follow the NoVolume app. Saved in ~/.local/state/caelestia/novolume.json.
Singleton {
    id: root

    readonly property var defaults: ({
            style: 0, // 0 half wheel, 1 the normal Caelestia sliders (volume, mic, brightness)
            enabled: true,
            theme: "shell", // shell | dark | light; colours overrides any element on top of it
            colours: ({}),
            size: 54, // 0-100 -> 180-385 dp tall, the app's overlay size
            scale: 1, // shell px per dp
            offsetY: 0,
            edgeInset: 34, // px from the screen edge to the wheel's centre (its cut edge); the face fills the gap to the border
            arcLength: 180,
            arcGap: 1,
            arcWidth: 24,
            arcAnimation: 0, // 0 grow, 1 circle around, 2 retract, 3 static
            animation: 0, // 0 slide, 1 scale (the app's "Pro")
            revealSpeed: 1,
            hideSpeed: 1,
            arcRevealSpeed: 1,
            arcHideSpeed: 1,
            markerStyle: 0, // 0 line, 1 hollow circle, 2 filled circle
            minorMarkerStyle: 0,
            markerThickness: 3,
            minorMarkerThickness: 1.5,
            markerSize: 5.5,
            minorMarkerSize: 3.5,
            wheelNumbersSize: 50,
            wheelNumbersFont: "ntype",
            wheelNumbersStroke: false,
            wheelNumbersStrokeWidth: 1,
            volumeNumberSize: 27,
            volumeNumberFont: "ntype",
            volumeNumberStroke: false,
            volumeNumberStrokeWidth: 1,
            volumeNumberOffsetX: 0,
            volumeNumberOffsetY: 0,
            volumeNumberRotation: 0,
            shadowRadius: 30,
            outline: false,
            outlineThickness: 50,
            internalShadow: false,
            internalShadowWidth: 75,
            showBackground: true,
            showShadow: true,
            showArc: true,
            showProgress: true,
            showMarkers: true,
            showMinorMarkers: true,
            showWheelNumbers: true,
            showVolumeNumber: true,
            showIndicator: true,
            hideDelay: 3000,
            sensitivity: 0.5,
            invertScrolling: false,
            doubleClickMute: true
        })

    // Element colours: a "#rrggbb"/"#aarrggbb" string or a Colours.palette name (follows the wallpaper); "t:name" is a Colours.tPalette one
    readonly property var colourKeys: ["background", "shadow", "arc", "progress", "marker", "minorMarker", "indicator", "numbers", "volumeNumber", "outline", "volumeNumberStroke", "wheelNumbersStroke"]
    readonly property var themes: ({
            shell: {
                background: "t:m3surface", // the border/bar colour, transparency included
                shadow: "#32000000",
                arc: "m3surfaceContainerHighest",
                progress: "m3primary",
                marker: "m3primary",
                minorMarker: "m3outline",
                indicator: "m3primary",
                numbers: "m3onSurfaceVariant",
                volumeNumber: "m3onSurface",
                outline: "m3outline",
                volumeNumberStroke: "m3shadow",
                wheelNumbersStroke: "m3shadow"
            },
            dark: {
                background: "#1C1C1E",
                shadow: "#32000000",
                arc: "#2C2C2E",
                progress: "#FF0000",
                marker: "#FF0000",
                minorMarker: "#8A8A8E",
                indicator: "#FF0000",
                numbers: "#8A8A8E",
                volumeNumber: "#FFFFFF",
                outline: "#FFFFFF",
                volumeNumberStroke: "#000000",
                wheelNumbersStroke: "#000000"
            },
            light: {
                background: "#F5F5F5",
                shadow: "#32000000",
                arc: "#7D7D7D",
                progress: "#FFFFFF",
                marker: "#FF0000",
                minorMarker: "#8A8A8E",
                indicator: "#1C1C1E",
                numbers: "#000000",
                volumeNumber: "#000000",
                outline: "#1C1C1E",
                volumeNumberStroke: "#000000",
                wheelNumbersStroke: "#000000"
            }
        })

    property var settings: ({})
    readonly property var s: Object.assign({}, defaults, settings)

    // Both NType files register as "NType 82": regular is the weight 100 face, bold (Headline) the 400 one
    readonly property var fonts: ({
            ntype: {
                family: ntype.name,
                weight: 100
            },
            ntypebold: {
                family: ntypeBold.name,
                weight: 400
            },
            ndot: {
                family: ndot.name,
                weight: 400
            }
        })

    function set(key: string, value: var): void {
        const next = Object.assign({}, settings);
        next[key] = value;
        settings = next;
        saveTimer.restart();
    }

    function setColour(key: string, value: string): void {
        const c = Object.assign({}, s.colours);
        if (value)
            c[key] = value;
        else
            delete c[key];
        set("colours", c);
    }

    function resetAll(): void {
        settings = {};
        saveTimer.restart();
    }

    function resolve(value: string): color {
        if (value.startsWith("t:"))
            return Colours.tPalette[value.slice(2)] ?? "transparent";
        return value.startsWith("#") ? value : (Colours.palette[value] ?? "transparent");
    }

    // The configured colour of an element: its override, else the theme's
    function spec(key: string): string {
        return s.colours[key] ?? (themes[s.theme] ?? themes.shell)[key];
    }

    // Resolved colours: a preset theme as is, or the configured look when theme is empty
    function palette(theme: string): var {
        const p = {};
        for (const k of colourKeys)
            p[k] = resolve(theme ? themes[theme][k] : spec(k));
        return p;
    }

    function font(name: string): var {
        return fonts[name] ?? {
            family: Tokens.font.body.small.family,
            weight: 400
        };
    }

    FontLoader {
        id: ntype

        source: Quickshell.shellPath("assets/novolume/ntype.otf")
    }

    FontLoader {
        id: ntypeBold

        source: Quickshell.shellPath("assets/novolume/ntypebold.otf")
    }

    FontLoader {
        id: ndot

        source: Quickshell.shellPath("assets/novolume/ndot.otf")
    }

    // Sliders set on every move, so write once they settle
    Timer {
        id: saveTimer

        interval: 500
        onTriggered: storage.setText(JSON.stringify(root.settings))
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/novolume.json`
        onLoaded: {
            try {
                root.settings = JSON.parse(text());
            } catch (e) {
                console.warn("NoVolume: bad settings file:", e);
            }
        }
    }
}
