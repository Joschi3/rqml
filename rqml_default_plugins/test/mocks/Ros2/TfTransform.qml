import QtQuick

QtObject {
    id: root

    property var buffer: null
    property bool enabled: true
    property var message: ({})
    property real rate: 60.0
    property var rotation: ({
            "x": 0,
            "y": 0,
            "z": 0,
            "w": 1
        })
    property string sourceFrame: ""
    property string targetFrame: ""

    // Test-controllable transform output. Tests mutate these directly.
    property var translation: ({
            "x": 0,
            "y": 0,
            "z": 0
        })
    property bool valid: true
}
