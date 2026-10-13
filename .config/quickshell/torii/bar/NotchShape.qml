import qs
import QtQuick
import QtQuick.Shapes

// The black body. attached: flat top that melts into the screen edge (concave ears + rounded bottom);
// floating: a rounded pill. Width/height include the ears.
Item {
    id: root

    property color color: "black"
    property real radius: 16
    property bool floating: false

    readonly property real ear: floating ? 0 : radius
    readonly property real rb: Math.min(radius, height / 2)

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        // attached
        ShapePath {
            id: attached
            fillColor: root.floating ? "transparent" : root.color
            strokeWidth: -1
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathArc {
                x: root.width - root.ear; y: root.ear
                radiusX: root.ear; radiusY: root.ear
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.width - root.ear; y: root.height - root.rb }
            PathArc {
                x: root.width - root.ear - root.rb; y: root.height
                radiusX: root.rb; radiusY: root.rb
                direction: PathArc.Clockwise
            }
            PathLine { x: root.ear + root.rb; y: root.height }
            PathArc {
                x: root.ear; y: root.height - root.rb
                radiusX: root.rb; radiusY: root.rb
                direction: PathArc.Clockwise
            }
            PathLine { x: root.ear; y: root.ear }
            PathArc {
                x: 0; y: 0
                radiusX: root.ear; radiusY: root.ear
                direction: PathArc.Counterclockwise
            }
        }

        // floating
        ShapePath {
            id: pill
            fillColor: root.floating ? root.color : "transparent"
            strokeWidth: -1
            startX: root.rb
            startY: 0
            PathLine { x: root.width - root.rb; y: 0 }
            PathArc {
                x: root.width; y: root.rb
                radiusX: root.rb; radiusY: root.rb
                direction: PathArc.Clockwise
            }
            PathLine { x: root.width; y: root.height - root.rb }
            PathArc {
                x: root.width - root.rb; y: root.height
                radiusX: root.rb; radiusY: root.rb
                direction: PathArc.Clockwise
            }
            PathLine { x: root.rb; y: root.height }
            PathArc {
                x: 0; y: root.height - root.rb
                radiusX: root.rb; radiusY: root.rb
                direction: PathArc.Clockwise
            }
            PathLine { x: 0; y: root.rb }
            PathArc {
                x: root.rb; y: 0
                radiusX: root.rb; radiusY: root.rb
                direction: PathArc.Clockwise
            }
        }
    }
}
