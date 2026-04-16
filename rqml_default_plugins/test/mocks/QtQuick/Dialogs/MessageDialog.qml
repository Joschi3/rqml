import QtQuick

QtObject {
    id: root

    // Standard button flag for Ok
    enum StandardButtons {
        Ok = 1024
    }

    property int buttons: 0
    property string detailedText: ""
    property string informativeText: ""
    property int modality: Qt.NonModal
    property string text: ""
    property string title: ""

    signal accepted
    signal rejected

    function close() {
    }
    function open() {
    }
}
