import qs
import QtQuick
import qs.services

// A row of the widgets named in config.json (widgets.left / widgets.right). They only take room while `shown`
// (the launcher or the control panel is open).
Row {
    id: root

    property var names: []
    property bool shown: false

    spacing: 10
    height: 22

    Repeater {
        model: root.names
        Loader {
            required property string modelData
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: modelData === "system" ? (Config.features.systemInfo ? system : null) : modelData === "claude" ? claude : modelData === "battery" ? battery : null
        }
    }

    Component { id: system; SystemWidget { shown: root.shown } }
    Component { id: claude; ClaudeWidget { shown: root.shown } }
    Component { id: battery; BatteryWidget { shown: root.shown } }
}
