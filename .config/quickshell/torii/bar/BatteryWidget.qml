import qs
import QtQuick
import Quickshell.Services.UPower
import qs.widgets
import qs.services

// Battery level, only on a machine that has one.
Item {
    id: root

    property bool shown: false
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.isPresent && dev.isLaptopBattery
    readonly property bool active: shown && present
    readonly property real pct: present ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
    readonly property bool charging: present && dev.state === UPowerDeviceState.Charging
    readonly property color tint: pct <= 15 && !charging ? Theme.red : Theme.accent

    height: 20
    width: active ? 18 + 5 + label.implicitWidth : 0
    opacity: active ? 1 : 0
    visible: width > 0.5
    clip: true
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Glyph {
        width: 18
        anchors.verticalCenter: parent.verticalCenter
        // battery-charging / battery-N glyphs from the Material Design icon set
        text: String.fromCodePoint(root.charging ? 0xF0084 : root.pct >= 95 ? 0xF0079 : 0xF007A + Math.max(0, Math.min(8, Math.floor(root.pct / 10) - 1)))
        size: 15
        color: root.tint
    }
    Label {
        id: label
        x: 23
        anchors.verticalCenter: parent.verticalCenter
        text: root.pct + "%"
        color: Theme.fgDim
    }
}
