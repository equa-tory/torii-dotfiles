pragma Singleton
import Quickshell

// TORII_MOCK=1 (torii-shell mock) swaps the hardware services for fake data so every UI state can be seen in a VM.
Singleton {
    readonly property bool on: Quickshell.env("TORII_MOCK") === "1"
}
