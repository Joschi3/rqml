import QtQuick

QtObject {
    id: root

    property string defaultTransport: "raw"
    property bool enabled: true
    property string encoding: "rgb8"
    property real framerate: 0.0
    property bool hasAlpha: false
    property bool isColor: false
    property int latency: 0
    property int networkLatency: 0
    property int processingLatency: 0
    property bool subscribed: true
    property int timeout: 0
    property string topic: ""
    property var videoSink: null
}
