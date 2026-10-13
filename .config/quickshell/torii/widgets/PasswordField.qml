import qs
import QtQuick
import QtQuick.Layouts

// Inline password prompt: Enter submits, Esc cancels (and does not close the panel).
Rectangle {
    id: root

    property string placeholder: "Password"
    property bool failed: false
    signal accepted(string text)
    signal cancelled()

    implicitHeight: 38
    radius: 10
    color: Theme.surface
    border.width: 1
    border.color: failed ? Theme.red : (input.activeFocus ? Theme.accentDim : Theme.border)

    // created hidden inside a list: take the keyboard whenever it is shown
    onVisibleChanged: if (visible) { input.text = ""; focusTimer.restart(); }
    Timer { id: focusTimer; interval: 40; onTriggered: input.forceActiveFocus() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 4
        spacing: 8

        TextInput {
            id: input
            Layout.fillWidth: true
            echoMode: TextInput.Password
            color: Theme.fg
            font.family: Config.font.family
            font.pixelSize: Config.font.size
            renderType: Text.CurveRendering
            clip: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentFg
            onTextChanged: root.failed = false
            onAccepted: if (text.length) root.accepted(text)
            Keys.onEscapePressed: event => { root.cancelled(); event.accepted = true; }

            Label {
                visible: !input.text.length
                text: root.placeholder
                color: Theme.muted
            }
        }
        IconButton {
            glyph: Icons.check
            accent: input.text.length > 0
            onClicked: if (input.text.length) root.accepted(input.text)
        }
    }
}
