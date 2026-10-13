import QtQuick

// Same surface as a SystemTrayItem (the parts the panel uses), for the VM.
QtObject {
    property string id: ""
    property string title: ""
    property string icon: ""
    property bool hasMenu: false
    property bool onlyMenu: false

    function activate() { console.log("mock tray: activate", title); }
    function secondaryActivate() { console.log("mock tray: secondary", title); }
}
