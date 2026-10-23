import qs
import QtQuick

// A row of the widgets named in the notch layout (Config.leftNames / rightNames, set in Setup > Widgets). system, claude and battery only take
// room while `shown` (the launcher or the control panel is open); language, letters, workspaces, special and weather are always there.
Row {
    id: root

    property var names: []
    property bool shown: false
    property var screen: null

    spacing: 16
    height: 22

    Repeater {
        model: root.names
        Loader {
            id: ld
            required property string modelData
            anchors.verticalCenter: parent.verticalCenter
            visible: item ? (item.present === undefined ? true : item.present) : false
            sourceComponent: modelData === "system" ? (Config.features.systemInfo ? system : null)
                           : modelData === "claude" ? claude : modelData === "battery" ? battery
                           : modelData === "language" ? language : modelData === "letters" ? letters
                           : modelData === "workspaces" ? workspaces : modelData === "special" ? special
                           : modelData === "weather" ? weather : null
        }
    }

    Component { id: system; SystemWidget { shown: root.shown } }
    Component { id: claude; ClaudeWidget { shown: root.shown } }
    Component { id: battery; BatteryWidget { shown: root.shown } }
    Component { id: language; LangWidget {} }
    Component { id: letters; Letters { screen: root.screen } }
    Component { id: workspaces; Workspaces { screen: root.screen; specialsOn: false } }
    Component { id: special; Workspaces { screen: root.screen; numbers: false } }
    Component { id: weather; Weather { open: Panels.panel === "weather" && Panels.panelScreen === (root.screen ? root.screen.name : "") } }
}
