import QtQuick
import QtQuick.Shapes
import Caelestia.Config
import qs.components.effects
import qs.services

// The NoVolume half wheel (right side), ported from the app's VolumeDialView. Sizes are in the app's units
// (phone px at 3x density) so its constants (24px arc, 30px marker gap, ...) carry over; u converts to shell px.
// The wheel's centre is this item's right edge: a half wheel cut along its centre line.
// Only settings changes repaint the canvases: volume turns the marker ring and moves the arcs on the GPU.
Item {
    id: root

    property real volume // 0-1
    property bool muted
    property bool shown: true
    property bool preview // always fully revealed
    property string theme // preview a preset theme instead of the configured look

    signal moved(volume: real)
    signal muteToggled

    readonly property var s: NoVolume.s
    readonly property var pal: NoVolume.palette(theme)
    property real u: s.scale / 3 // shell px per app px
    readonly property real dialH: (180 + s.size / 100 * 205) * 3
    // VolumeDialView.dialRadii
    readonly property real arcGap: Math.max(20, Math.min(60, dialH * 0.1)) * s.arcGap
    readonly property real maxArcR: dialH / 2 - Math.max(4, dialH * 0.02)
    readonly property real faceR: dialH * 0.35 + arcGap <= maxArcR ? dialH * 0.35 : maxArcR - arcGap
    readonly property real arcR: faceR + arcGap
    readonly property real cx: width // shell px
    // Shell theme: the border's own blob is the face (exact bar colour, no double transparency), see ContentWindow's osdBg
    readonly property bool blobFace: !preview && s.showBackground && s.theme === "shell" && s.colours.background === undefined
    readonly property real faceHalf: faceR * u
    // Edge fade width (shell px). Over the blob face it masks the markers instead of painting the (translucent) border
    // colour on top, which would make the face darker than the border
    readonly property real fadeW: faceR * u / (21 - s.internalShadowWidth / 100 * 19.67)
    readonly property bool fadeMask: blobFace && s.internalShadow
    readonly property real cy: height / 2

    readonly property int target: muted ? 0 : Math.max(0, Math.min(100, Math.round(volume * 100)))
    property real animatedVolume: target
    property real reveal: preview ? 1 : 0
    property bool hiding
    property real touch: area.held ? 0.95 : 1

    // Arc window and progress (degrees, clockwise from the bottom)
    readonly property real arcStart: 105
    readonly property real arcTotal: Math.max(s.arcLength - 30, 30)
    readonly property real arcTarget: animatedVolume * arcTotal / 100
    readonly property real arcOffset: s.arcAnimation === 1 ? (hiding ? 180 : -180) * (1 - reveal) : s.arcAnimation === 0 && hiding ? arcTotal * (1 - reveal) : 0
    readonly property real arcSweep: s.arcAnimation === 0 || s.arcAnimation === 2 ? arcTotal * reveal : arcTotal
    readonly property real progressSweep: Math.min(arcTarget, arcSweep)

    // What each canvas draws from: they repaint only when their own inputs change
    readonly property string faceKey: JSON.stringify([s.showShadow, s.shadowRadius, `${pal.background}`, `${pal.shadow}`, u, faceR, width, height])
    readonly property string markersKey: JSON.stringify([s.markerStyle, s.minorMarkerStyle, s.markerThickness, s.minorMarkerThickness, s.markerSize, s.minorMarkerSize, s.showMarkers, s.showMinorMarkers, s.showWheelNumbers, s.wheelNumbersSize, s.wheelNumbersFont, s.wheelNumbersStroke, s.wheelNumbersStrokeWidth, `${pal.marker}`, `${pal.minorMarker}`, `${pal.numbers}`, `${pal.wheelNumbersStroke}`, u, faceR, NoVolume.fonts])
    readonly property string edgeKey: JSON.stringify([blobFace, s.internalShadow, s.internalShadowWidth, s.outline, s.outlineThickness, `${pal.background}`, `${pal.outline}`, u, faceR, width, height])

    function centerOffset(fm: FontMetrics, px: real): real {
        const r = fm.tightBoundingRect("8");
        return -(r.y + r.height / 2) / 100 * px;
    }

    function rad(deg: real): real {
        return deg * Math.PI / 180;
    }

    implicitWidth: Math.ceil(arcR * 1.1 * u)
    implicitHeight: Math.ceil(dialH * u)
    clip: true

    onFaceKeyChanged: face.requestPaint()
    onMarkersKeyChanged: markers.requestPaint()
    onEdgeKeyChanged: edge.requestPaint()
    onShownChanged: {
        if (preview)
            return;
        if (shown) {
            hiding = false;
            hideAnim.stop();
            if (s.arcAnimation === 3)
                reveal = 1;
            else
                revealAnim.restart();
        } else {
            revealAnim.stop();
            hiding = true;
            if (s.arcAnimation === 3)
                reveal = 0;
            else
                hideAnim.restart();
        }
    }
    Component.onCompleted: {
        if (shown && !preview)
            shownChanged();
    }

    Behavior on animatedVolume {
        enabled: !area.held

        NumberAnimation {
            duration: 90
        }
    }

    Behavior on touch {
        NumberAnimation {
            duration: area.held ? 100 : 150
            easing.type: Easing.OutQuad
        }
    }

    NumberAnimation {
        id: revealAnim

        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: 600 / root.s.arcRevealSpeed
        easing.type: Easing.OutBack
        easing.overshoot: 1.5
    }

    NumberAnimation {
        id: hideAnim

        target: root
        property: "reveal"
        to: 0
        duration: 200 / root.s.arcHideSpeed
        easing.type: Easing.InQuad
    }

    FontMetrics {
        id: wheelFm

        font.family: NoVolume.font(root.s.wheelNumbersFont).family
        font.weight: NoVolume.font(root.s.wheelNumbersFont).weight
        font.pixelSize: 100
    }

    FontMetrics {
        id: numberFm

        font.family: NoVolume.font(root.s.volumeNumberFont).family
        font.weight: NoVolume.font(root.s.volumeNumberFont).weight
        font.pixelSize: 100
    }

    // Everything but the volume number shrinks round the centre while pressed
    Item {
        anchors.fill: parent

        transform: Scale {
            origin.x: root.cx
            origin.y: root.cy
            xScale: root.touch
            yScale: root.touch
        }

        // Dial face and its shadow
        Canvas {
            id: face

            anchors.fill: parent
            visible: root.s.showBackground && !root.blobFace

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                const s = root.s, p = root.pal, u = root.u;
                const shadow = s.showShadow && s.shadowRadius > 0 && p.shadow.a > 0;
                if (p.background.a === 0 && !shadow)
                    return;
                if (shadow) {
                    ctx.shadowColor = p.shadow;
                    // Android's blur radius is sigma / 0.57735 - 0.5, canvas wants 2 sigma (in device px)
                    ctx.shadowBlur = (1.1547 * s.shadowRadius / 100 * 50 + 1) * u;
                }
                ctx.fillStyle = p.background.a > 0 ? p.background : Qt.rgba(0, 0, 0, 1 / 255);
                ctx.beginPath();
                ctx.arc(root.cx, root.cy, root.faceR * u, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        // Arcs: from the bottom, clockwise round the face
        Shape {
            anchors.fill: parent
            visible: root.s.showArc
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Math.abs(root.arcSweep) > 0.1 ? root.pal.arc : "transparent"
                strokeWidth: root.s.arcWidth * root.u
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.cx
                    centerY: root.cy
                    radiusX: root.arcR * root.u
                    radiusY: root.arcR * root.u
                    startAngle: root.arcStart + root.arcOffset
                    sweepAngle: root.arcSweep
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.s.showProgress && Math.abs(root.progressSweep) > 0.1 ? root.pal.progress : "transparent"
                strokeWidth: root.s.arcWidth * root.u
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.cx
                    centerY: root.cy
                    radiusX: root.arcR * root.u
                    radiusY: root.arcR * root.u
                    startAngle: root.arcStart + root.arcOffset
                    sweepAngle: root.progressSweep
                }
            }
        }

        // Markers and numbers, drawn once and turned so the current volume sits at the indicator
        Item {
            anchors.fill: parent
            layer.enabled: root.fadeMask
            layer.effect: Mask {
                maskSource: fadeMask
            }

            Canvas {
                id: markers

                readonly property bool at100: root.animatedVolume >= 99.5 // the app hides "100" when it's at the indicator

                x: root.cx - width / 2
                y: root.cy - height / 2
                width: Math.ceil(root.faceR * 2 * root.u)
                height: width
                rotation: -45 - root.animatedVolume * 2.7
                antialiasing: true

                onAt100Changed: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);
                    const s = root.s, p = root.pal, u = root.u;
                    const r = root.faceR;
                    ctx.translate(width / 2, height / 2);
                    ctx.scale(u, u);
                    const gap = 30;
                    const numbersR = r - gap - 60;
                    const drawMarkers = (values, style, thickness, size, circleLen, colour) => {
                        ctx.beginPath();
                        for (const v of values) {
                            const a = root.rad(-135 + v * 2.7);
                            const c = Math.cos(a), sn = Math.sin(a);
                            if (style === 0) {
                                const len = size * 3;
                                ctx.moveTo((r - len - gap) * c, (r - len - gap) * sn);
                                ctx.lineTo((r - gap) * c, (r - gap) * sn);
                            } else {
                                const mid = r - gap - circleLen / 2;
                                ctx.moveTo(mid * c + size, mid * sn);
                                ctx.arc(mid * c, mid * sn, size, 0, Math.PI * 2);
                            }
                        }
                        ctx.lineWidth = thickness;
                        ctx.lineCap = "butt";
                        if (style === 2) {
                            ctx.fillStyle = colour;
                            ctx.fill();
                        } else {
                            ctx.strokeStyle = colour;
                            ctx.stroke();
                        }
                    };
                    const majors = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
                    if (s.showMinorMarkers) {
                        const minors = [];
                        for (let v = 1; v < 100; v++)
                            if (v % 10)
                                minors.push(v);
                        drawMarkers(minors, s.minorMarkerStyle, s.minorMarkerThickness, s.minorMarkerSize, 10, p.minorMarker);
                    }
                    if (s.showMarkers)
                        drawMarkers(majors, s.markerStyle, s.markerThickness, s.markerSize, 15, p.marker);
                    if (s.showWheelNumbers && numbersR > 0) {
                        const px = 4 + s.wheelNumbersSize / 100 * 68;
                        const dy = root.centerOffset(wheelFm, px);
                        ctx.font = `${wheelFm.font.weight} ${Math.round(px)}px "${wheelFm.font.family}"`;
                        ctx.textAlign = "center";
                        ctx.textBaseline = "alphabetic";
                        ctx.lineJoin = "round";
                        ctx.lineWidth = s.wheelNumbersStrokeWidth * 9;
                        for (const v of majors) {
                            if (v === 100 && at100)
                                continue;
                            const angle = -135 + v * 2.7;
                            let rot = angle - 90;
                            if (rot > 90 && rot < 270)
                                rot += 180;
                            ctx.save();
                            ctx.translate(numbersR * Math.cos(root.rad(angle)), numbersR * Math.sin(root.rad(angle)));
                            ctx.rotate(root.rad(rot));
                            if (s.wheelNumbersStroke) {
                                ctx.strokeStyle = p.wheelNumbersStroke;
                                ctx.strokeText(String(v), 0, dy);
                            }
                            ctx.fillStyle = p.numbers;
                            ctx.fillText(String(v), 0, dy);
                            ctx.restore();
                        }
                    }
                }
            }
        }

        Rectangle {
            id: fadeMask

            anchors.fill: parent
            visible: false
            layer.enabled: root.fadeMask

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: Math.max(0, root.cx - root.fadeW) / Math.max(1, root.width)
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: root.cx / Math.max(1, root.width)
                    color: Qt.rgba(0, 0, 0, 0)
                }
            }
        }

        // Edge fade (fades the face into its colour at the screen edge) and outline
        Canvas {
            id: edge

            anchors.fill: parent
            visible: (root.s.internalShadow && !root.blobFace) || root.s.outline

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                const s = root.s, p = root.pal, u = root.u;
                const r = root.faceR * u;
                if (s.internalShadow && !root.blobFace) {
                    ctx.save();
                    ctx.beginPath();
                    ctx.arc(root.cx, root.cy, r, 0, Math.PI * 2);
                    ctx.clip();
                    const w = root.fadeW;
                    const g = ctx.createLinearGradient(root.cx, root.cy, root.cx - w, root.cy);
                    g.addColorStop(0, p.background);
                    g.addColorStop(1, Qt.rgba(p.background.r, p.background.g, p.background.b, 0));
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, width, height);
                    ctx.restore();
                }
                if (s.outline) {
                    ctx.strokeStyle = p.outline;
                    ctx.lineWidth = (2 + s.outlineThickness / 100 * 28) * u;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(root.cx, root.cy, r, Math.PI / 2, Math.PI * 3 / 2);
                    ctx.stroke();
                }
            }
        }

        // Indicator: a 30px round-capped line across the face edge
        Rectangle {
            visible: root.s.showIndicator
            x: root.cx - (root.faceR + 15 + 3.5) * root.u
            y: root.cy - 3.5 * root.u
            width: 37 * root.u
            height: 7 * root.u
            radius: height / 2
            color: root.pal.indicator
            antialiasing: true
        }
    }

    Text {
        id: number

        readonly property real px: (4 + root.s.volumeNumberSize / 100 * 92) * 3 * root.u
        readonly property real baseY: root.cy + (root.centerOffset(numberFm, px / root.u) + root.s.volumeNumberOffsetY) * root.u

        visible: root.s.showVolumeNumber
        x: root.cx - (30 + root.s.volumeNumberOffsetX) * root.u - width
        y: baseY - baselineOffset
        text: root.muted ? "0" : String(Math.round(root.volume * 100))
        color: root.pal.volumeNumber
        font.family: numberFm.font.family
        font.weight: numberFm.font.weight
        font.pixelSize: Math.max(1, px)
        style: root.s.volumeNumberStroke ? Text.Outline : Text.Normal
        styleColor: root.pal.volumeNumberStroke

        transform: [
            Rotation {
                origin.x: number.width - number.px * numberFm.advanceWidth("100") / 200
                origin.y: number.baselineOffset
                angle: root.s.volumeNumberRotation
            },
            Scale {
                origin.x: number.width
                origin.y: root.cy - number.y
                xScale: root.touch
                yScale: root.touch
            }
        ]
    }

    // Drag up/down like the app (and scroll), double click mutes
    MouseArea {
        id: area

        property bool held
        property real lastY
        property real acc
        property int dragVol

        anchors.fill: parent

        onPressed: mouse => {
            const d = Math.hypot(mouse.x - root.cx, mouse.y - root.cy) / root.u;
            if (d > root.faceR + 50) {
                mouse.accepted = false;
                return;
            }
            held = true;
            lastY = mouse.y;
            acc = 0;
            dragVol = root.target;
        }
        onReleased: held = false
        onCanceled: held = false
        onPositionChanged: mouse => {
            acc += (lastY - mouse.y) / root.u * root.s.sensitivity * 0.25;
            lastY = mouse.y;
            const steps = Math.trunc(acc);
            if (steps) {
                acc -= steps;
                const v = Math.max(0, Math.min(100, dragVol + (root.s.invertScrolling ? -steps : steps)));
                if (v !== dragVol) {
                    dragVol = v;
                    root.moved(v / 100);
                }
            }
        }
        onDoubleClicked: {
            if (root.s.doubleClickMute)
                root.muteToggled();
        }
        onWheel: wheel => {
            const up = (wheel.angleDelta.y > 0) !== root.s.invertScrolling;
            if (wheel.angleDelta.y)
                root.moved(Math.max(0, Math.min(GlobalConfig.services.maxVolume, root.volume + (up ? 1 : -1) * GlobalConfig.services.audioIncrement)));
        }
    }
}
