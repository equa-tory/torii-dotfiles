import qs
import qs.widgets
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

// Alt+Tab: a card per open window with a live picture, most recently used first. Tab / Shift+Tab / arrows move,
// letting go of Alt (or Enter, or a click) focuses the window, Esc cancels. Works the same with tiled and floating windows.
Item {
    id: root

    property real maxWidth: 1000
    property real maxHeight: 700
    readonly property bool multiRow: Config.notch.windowGrid
    readonly property int columns: Math.max(1, Math.floor((maxWidth - 40) / (cardW + 14)))
    readonly property int rows: multiRow ? Math.max(1, Math.ceil(count / columns)) : 1
    readonly property real cardW: 200
    readonly property real cardH: 128
    readonly property var wins: Windows.list
    readonly property int count: wins.length

    implicitWidth: multiRow ? Math.min(maxWidth, Math.max(360, Math.min(count, columns) * (cardW + 14) + 40))
                            : Math.min(maxWidth, Math.max(360, count * (cardW + 14) + 40))
    implicitHeight: multiRow ? Math.min(rows, Math.max(1, Math.floor((maxHeight - 26) / (cardH + 56)))) * (cardH + 56) + 26 : cardH + 82

    opacity: 0
    focus: true
    Component.onCompleted: { opacity = 1; forceActiveFocus(); }
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    function accept() {
        const t = wins[Windows.index];
        Panels.close();
        Windows.focus(t);
    }

    Keys.onTabPressed: event => Windows.step(event.modifiers & Qt.ShiftModifier ? -1 : 1)
    Keys.onBacktabPressed: Windows.step(-1)
    Keys.onRightPressed: Windows.step(1)
    Keys.onLeftPressed: Windows.step(-1)
    Keys.onUpPressed: if (multiRow) Windows.index = Math.max(0, Windows.index - columns)
    Keys.onDownPressed: if (multiRow) Windows.index = Math.min(count - 1, Windows.index + columns)
    Keys.onReturnPressed: accept()
    Keys.onEnterPressed: accept()
    Keys.onEscapePressed: Panels.close()
    Keys.onReleased: event => { if (event.key === Qt.Key_Alt) { accept(); event.accepted = true; } }

    GridView {
        id: list
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 12; leftMargin: 20; rightMargin: 20 }
        height: root.implicitHeight - 26
        cellWidth: root.cardW + 14
        cellHeight: root.cardH + 56
        flow: root.multiRow ? GridView.FlowLeftToRight : GridView.FlowTopToBottom
        clip: true
        model: root.wins
        currentIndex: Windows.index
        highlightMoveDuration: 140
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
        Component.onCompleted: positionViewAtIndex(currentIndex, GridView.Contain)
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: card
            required property int index
            required property var modelData
            readonly property bool selected: index === Windows.index
            readonly property var obj: modelData.lastIpcObject || ({})
            readonly property bool minimised: Windows.minimised(modelData)

            width: root.cardW
            height: list.cellHeight

            Rectangle {
                id: frame
                width: root.cardW
                height: root.cardH
                radius: 12
                color: Theme.surface
                border.width: card.selected ? 2 : 0
                border.color: Theme.accent
                clip: true
                opacity: card.selected ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: 120 } }

                ScreencopyView {
                    anchors.fill: parent
                    anchors.margins: frame.border.width
                    captureSource: card.modelData.wayland
                    live: card.selected
                    visible: !card.minimised || hasContent
                }
                Label {
                    anchors.centerIn: parent
                    visible: card.minimised
                    text: "minimised"
                    color: Theme.muted
                }
            }
            Row {
                anchors { top: frame.bottom; topMargin: 8; left: frame.left; right: frame.right }
                spacing: 8
                Image {
                    width: 20; height: 20
                    source: Quickshell.iconPath(String(card.obj["class"] || "").toLowerCase(), "application-x-executable")
                    sourceSize: Qt.size(40, 40)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width - 28
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.modelData.title || card.obj["class"] || ""
                    color: card.selected ? Theme.fg : Theme.subtle
                    elide: Text.ElideRight
                }
            }
            Label {
                anchors { top: frame.bottom; topMargin: 30; left: frame.left }
                text: "workspace " + (card.obj.workspace ? card.obj.workspace.name : "")
                color: Theme.muted
                font.pixelSize: 11
                visible: card.selected && !!card.obj.workspace
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: Windows.index = card.index
                onClicked: { Windows.index = card.index; root.accept(); }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.count === 0
        text: "No open windows"
        color: Theme.muted
    }
}
