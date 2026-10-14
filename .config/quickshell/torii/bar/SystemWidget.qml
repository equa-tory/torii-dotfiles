import qs
import QtQuick
import qs.widgets
import qs.services

// CPU, RAM, GPU, VRAM and temperatures in one line; a click opens the process list in the launcher.
Item {
    id: root

    property bool shown: false
    readonly property bool active: shown && Sys.ok

    readonly property var parts: {
        const s = Sys.stats, out = [];
        if (s.cpu !== undefined) out.push({ k: "cpu", v: Math.round(s.cpu) + "%" + (s.cpuTemp != null ? " " + s.cpuTemp + "°" : "") });
        if (s.ram !== undefined) out.push({ k: "ram", v: Math.round(s.ram) + "%" });
        if (s.gpu != null) out.push({ k: "gpu", v: Math.round(s.gpu) + "%" + (s.gpuTemp != null ? " " + s.gpuTemp + "°" : "") });
        if (s.vram != null) out.push({ k: "vram", v: Math.round(s.vram) + "%" });
        return out;
    }

    height: 20
    width: active ? row.implicitWidth : 0
    opacity: active ? 1 : 0
    visible: width > 0.5
    clip: true
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Row {
        id: row
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: root.parts
            Row {
                spacing: 4
                Label { text: modelData.k; color: Theme.subtle; font.pixelSize: Config.font.size - 3; anchors.baseline: val.baseline }
                Label { id: val; text: modelData.v; color: Theme.fgDim; font.pixelSize: Config.font.size - 1 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.openLauncherAt(["processes"])
    }
}
