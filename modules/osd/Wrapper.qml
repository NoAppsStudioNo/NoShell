pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.services

// Volume OSD on the right edge: the NoVolume half wheel, or the normal Caelestia sliders (NoVolume.s.style)
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property bool sidebarOrSessionVisible
    required property real borderThickness

    property bool hovered
    readonly property var s: NoVolume.s
    readonly property bool classic: s.style === 1
    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool shouldBeActive: screenState.osd && Config.osd.enabled && (classic || s.enabled) && !(screenState.utilities && Config.utilities.enabled)
    // The wheel drives wheelScale by hand (arc retracts first); the sliders just follow shouldBeActive
    property real wheelScale: 1
    property real sliderScale: shouldBeActive ? 0 : 1
    readonly property real offsetScale: classic ? sliderScale : wheelScale
    readonly property bool slides: classic || s.animation !== 1
    // For ContentWindow's osdBg: the face's left edge and radius, so the border can bulge out around the wheel
    readonly property bool bulge: !classic && dial.bulge
    readonly property real faceLeft: dial.x + dial.cx - dial.faceHalf
    readonly property real faceHalf: dial.faceHalf
    property real sidebarOffset: sidebarOrSessionVisible ? 12 : 0

    function show(): void {
        screenState.osd = true;
        timer.restart();
    }

    onClassicChanged: wheelScale = !classic && shouldBeActive ? 0 : 1

    // Like the app: the arc retracts first, then the wheel leaves
    onShouldBeActiveChanged: {
        if (classic)
            return;
        if (shouldBeActive) {
            retract.stop();
            wheelScale = 0;
        } else {
            retract.restart();
        }
    }

    visible: offsetScale < 1
    anchors.rightMargin: slides ? (-implicitWidth - 5 - sidebarOffset) * offsetScale : 0
    implicitWidth: classic ? content.implicitWidth : dial.implicitWidth + s.edgeInset - borderThickness
    implicitHeight: classic ? content.implicitHeight : dial.implicitHeight
    opacity: slides ? 1 - offsetScale : 1
    scale: slides ? 1 : 1 - offsetScale
    transformOrigin: Item.Right

    Behavior on sliderScale {
        Anim {}
    }

    Behavior on wheelScale {
        NumberAnimation {
            duration: root.shouldBeActive ? (root.s.animation === 1 ? 300 : 250) / root.s.revealSpeed : 250 / root.s.hideSpeed
            easing.type: root.s.animation === 1 ? (root.shouldBeActive ? Easing.OutBack : Easing.InBack) : (root.shouldBeActive ? Easing.OutQuad : Easing.InOutSine)
            easing.overshoot: root.shouldBeActive ? 1.5 : 1
        }
    }

    Connections {
        function onMutedChanged(): void {
            root.show();
        }

        function onVolumeChanged(): void {
            root.show();
        }

        function onSourceMutedChanged(): void {
            if (root.classic)
                root.show();
        }

        function onSourceVolumeChanged(): void {
            if (root.classic)
                root.show();
        }

        target: Audio
    }

    Connections {
        function onBrightnessChanged(): void {
            if (root.classic)
                root.show();
        }

        target: root.monitor
    }

    Timer {
        id: timer

        interval: root.s.hideDelay
        onTriggered: {
            if (!root.hovered)
                root.screenState.osd = false;
        }
    }

    Timer {
        id: retract

        interval: root.s.arcAnimation === 3 ? 0 : 200 / root.s.arcHideSpeed
        onTriggered: root.wheelScale = 1
    }

    Loader {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        asynchronous: true
        active: root.classic && (root.shouldBeActive || root.visible)

        sourceComponent: Content {
            monitor: root.monitor
            screenState: root.screenState
            volume: Audio.volume
            muted: Audio.muted
            sourceVolume: Audio.sourceVolume
            sourceMuted: Audio.sourceMuted
            brightness: root.monitor?.brightness ?? 0
        }
    }

    NoVolumeDial {
        id: dial

        visible: !root.classic

        anchors.right: parent.right
        anchors.rightMargin: root.s.edgeInset - root.borderThickness
        anchors.verticalCenter: parent.verticalCenter

        edgeGap: anchors.rightMargin
        shown: root.shouldBeActive && !root.classic
        volume: Audio.volume
        muted: Audio.muted
        onMoved: v => Audio.setVolume(v)
        onMuteToggled: {
            if (Audio.sink?.audio)
                Audio.sink.audio.muted = !Audio.muted;
        }
    }
}
