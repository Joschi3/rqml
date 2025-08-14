import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ros2

Rectangle {
    id: root
    // Set the minimum size for this plugin's dock widget
    property var kddockwidgets_min_size: Qt.size(300, 300)
    color: palette.base

    property string lastMessage: "No message received yet"

    Subscription {
        id: chatterSub
        topic: "/chatter"
        onNewMessage: msg => {
            lastMessage = msg.data;
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        // Use Label instead of Text for better styling and support of different themes
        Label {
            text: "ROS 2 Example Plugin"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Listening on: " + chatterSub.topic
            font.pixelSize: 16
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: lastMessage
            font.pixelSize: 18
            color: "green"
            Layout.alignment: Qt.AlignHCenter
        }

        Button {
            text: "Publish Hello"
            onClicked: {
                // Simple publisher example
                let msg = Ros2.createEmptyMessage("std_msgs/msg/String");
                msg.data = "Hello from RQml!";
                d.pub.publish(msg);
            }
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // I like using a private object for internal logic and properties
    QtObject {
        id: d
        property var pub: Ros2.createPublisher("/chatter", "std_msgs/msg/String")
    }
}
