pragma Singleton
import qs
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs.services.mock

// Background apps (status-notifier items). The shell is the only tray host.
Singleton {
    id: root

    readonly property list<MockTrayItem> mockItems: [
        MockTrayItem { id: "steam"; title: "Steam"; icon: Quickshell.iconPath("steam", true); hasMenu: true },
        MockTrayItem { id: "v2rayn"; title: "v2rayN"; icon: Quickshell.iconPath("network-vpn", true) },
        MockTrayItem { id: "discord"; title: "Discord"; icon: Quickshell.iconPath("discord", true) }
    ]

    readonly property var items: Mock.on ? mockItems : SystemTray.items.values
}
