import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ros2
import RQml.Elements
import RQml.Fonts

Rectangle {
    id: root
    anchors.fill: parent
    property var kddockwidgets_min_size: Qt.size(350, 500)
    color: palette.base

    Component.onCompleted: {
        if (context.enabled === undefined)
            context.enabled = true;
        if (context.stamped === undefined)
            context.stamped = false;
        if (!context.topic)
            context.topic = "cmd_vel";
        if (context.rate === undefined)
            context.rate = 10;
        if (!context.linear)
            context.linear = {};
        if (!context.linear.min)
            context.linear.min = -1;
        if (!context.linear.max)
            context.linear.max = 1;
        if (!context.angular)
            context.angular = {};
        if (!context.angular.min)
            context.angular.min = -1;
        if (!context.angular.max)
            context.angular.max = 1;
    }

    QtObject {
        id: d
        property var publisher: {
            if (!context.topic || !Ros2.isValidTopic(context.topic))
                return null;
            return Ros2.createPublisher(context.topic, context.stamped ? "geometry_msgs/msg/TwistStamped" : "geometry_msgs/msg/Twist", 1);
        }

        function publish() {
            if (!context.enabled || !publisher)
                return;
            if (stampedCheckBox.checked) {
                publisher.publish({
                    header: {
                        stamp: Ros2.now()
                    },
                    twist: {
                        linear: {
                            x: linearSlider.value,
                            y: 0,
                            z: 0
                        },
                        angular: {
                            x: 0,
                            y: 0,
                            z: angularSlider.value
                        }
                    }
                });
            } else {
                publisher.publish({
                    linear: {
                        x: linearSlider.value,
                        y: 0,
                        z: 0
                    },
                    angular: {
                        x: 0,
                        y: 0,
                        z: angularSlider.value
                    }
                });
            }
        }
    }

    Timer {
        interval: rate.value == 0 ? 0 : 1000 / rate.value
        repeat: true
        running: rate.value > 0
        onTriggered: d.publish()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8

        RowLayout {
            spacing: 10
            CheckBox {
                id: stampedCheckBox
                display: AbstractButton.TextUnderIcon
                text: "Stamped"
                checked: context.stamped
                onCheckedChanged: context.stamped = checked
            }

            Label {
                text: "Rate (Hz):"
            }
            SpinBox {
                id: rate
                editable: true
                from: 0
                to: 100
                stepSize: 1
                value: context.rate
                onValueChanged: {
                    context.rate = value;
                }
            }
        }
        GridLayout {
            columns: width > 300 ? 2 : 1
            TextField {
                id: topic
                Layout.fillWidth: true
                selectByMouse: true
                text: context.topic
                onTextChanged: {
                    context.enabled = false;
                    context.topic = text;
                }
            }
            Button {
                id: playButton
                implicitHeight: 48
                implicitWidth: 48
                checkable: true
                checked: context.enabled
                onCheckedChanged: context.enabled = checked
                ToolTip.visible: hovered
                ToolTip.text: checked ? "Click to pause" : "Click to start"
                ToolTip.delay: 500
                font.family: IconFont.name
                font.pixelSize: 20
                text: checked ? IconFont.iconPause : IconFont.iconPlay
            }
        }

        SpeedSlider {
            id: linearSlider
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            from: context.linear.min ?? -1.0
            onFromChanged: context.linear.min = from
            to: context.linear.max ?? 1.0
            onToChanged: context.linear.max = to
            onValueChanged: {
                if (rate.value == 0)
                    publish();
            }
        }

        SpeedSlider {
            id: angularSlider
            Layout.fillWidth: true
            direction: Qt.Horizontal
            from: context.angular.min ?? -1.0
            onFromChanged: context.angular.min = from
            to: context.angular.max ?? 1.0
            onToChanged: context.angular.max = to
            onValueChanged: {
                if (rate.value == 0)
                    publish();
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Stop"
            onClicked: {
                linearSlider.value = 0;
                angularSlider.value = 0;
            }
        }
    }
}
