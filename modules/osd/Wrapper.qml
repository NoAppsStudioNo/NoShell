pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// Volume OSD on the right edge: the NoVolume half wheel (replaces the volume/mic/brightness sliders)
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property bool sidebarOrSessionVisible
    required property real borderThickness

    property bool hovered
    readonly property var s: NoVolume.s
    readonly property bool shouldBeActive: screenState.osd && Config.osd.enabled && s.enabled && !(screenState.utilities && Config.utilities.enabled)
    property real offsetScale: 1
    property real sidebarOffset: sidebarOrSessionVisible ? 12 : 0

    function show(): void {
        screenState.osd = true;
        timer.restart();
    }

    // Like the app: the arc retracts first, then the wheel leaves
    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            retract.stop();
            offsetScale = 0;
        } else {
            retract.restart();
        }
    }

    visible: offsetScale < 1
    anchors.rightMargin: s.animation === 1 ? 0 : (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: dial.implicitWidth - borderThickness
    implicitHeight: dial.implicitHeight
    opacity: s.animation === 1 ? 1 : 1 - offsetScale
    scale: s.animation === 1 ? 1 - offsetScale : 1
    transformOrigin: Item.Right

    Behavior on offsetScale {
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

        target: Audio
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
        onTriggered: root.offsetScale = 1
    }

    NoVolumeDial {
        id: dial

        anchors.right: parent.right
        anchors.rightMargin: -root.borderThickness
        anchors.verticalCenter: parent.verticalCenter

        shown: root.shouldBeActive
        volume: Audio.volume
        muted: Audio.muted
        onMoved: v => Audio.setVolume(v)
        onMuteToggled: {
            if (Audio.sink?.audio)
                Audio.sink.audio.muted = !Audio.muted;
        }
    }
}
