import QtQuick
import QtQuick.Controls

Item {
    id: control
    property alias text: headerLabel.text
    property color textColor: palette.highlightedText ?? "#ffffff"
    width: parent.width
    height: 40
    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 8
        color: palette.highlight ?? "#424242"
        Label {
            id: headerLabel
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            color: control.textColor
            font.bold: true
        }
    }
    z: 2
}
