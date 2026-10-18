import qs
import QtQuick

// Shell text: theme font + colour, grayscale antialiasing (subpixel fringes look wrong on a transparent layer).
Text {
    color: Theme.fg
    font.family: Config.font.family
    font.pixelSize: Config.font.size
    renderType: font.pixelSize < 17 ? Text.NativeRendering : Text.CurveRendering   // hinted text is sharper at small sizes on a 1080p screen
}
