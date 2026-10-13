import qs
import QtQuick

// Shell text: theme font + colour, grayscale antialiasing (subpixel fringes look wrong on a transparent layer).
Text {
    color: Theme.fg
    font.family: Config.font.family
    font.pixelSize: Config.font.size
    renderType: Text.CurveRendering
}
