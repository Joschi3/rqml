import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RQml.Elements

Dialog {
    id: root
    property var component: null

    anchors.centerIn: parent
    title: qsTr("Hardware Component Information")
    width: 600
    height: Math.min(parent.height * 0.8, implicitHeight)
    standardButtons: Dialog.Close

    function openHardwareComponentInfo(component) {
        root.component = component;
        root.open();
    }

    QtObject {
        id: d
        property var attributes: {
            if (!root.component)
                return [];
            return [
                {
                    "name": "Name",
                    "data": root.component.name
                },
                {
                    "name": "State",
                    "data": root.component.state.label
                },
                {
                    "name": "Type",
                    "data": root.component.type
                },
                {
                    "name": "Is Async",
                    "data": root.component.is_async
                },
                {
                    "name": "R/W Rate",
                    "data": root.component.rw_rate
                },
                {
                    "name": "Class Type",
                    "data": root.component.class_type
                },
                {
                    "name": "Plugin Name",
                    "data": root.component.plugin_name
                }
            ];
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        GridLayout {
            id: mainLayout
            width: scrollView.availableWidth
            columns: 2
            rowSpacing: 8

            Repeater {
                model: d.attributes
                Label {
                    Layout.row: index + 2
                    Layout.column: 0
                    Layout.rightMargin: 8
                    text: modelData.name + ":"
                    font.bold: true
                }
            }
            Repeater {
                model: d.attributes

                TruncatedLabel {
                    Layout.row: index + 2
                    Layout.column: 1
                    Layout.fillWidth: true
                    text: modelData.data ?? qsTr("N/A")
                    elide: Text.ElideMiddle
                }
            }

            ListView {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight + headerItem.implicitHeight
                model: root.component?.command_interfaces ?? []
                clip: true
                header: ListHeader {
                    text: "Command Interfaces"
                }
                headerPositioning: ListView.OverlayHeader
                delegate: interfaceDelegate
            }

            ListView {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight + headerItem.implicitHeight
                model: root.component?.state_interfaces ?? []
                clip: true
                header: ListHeader {
                    text: "State Interfaces"
                }
                headerPositioning: ListView.OverlayHeader
                delegate: interfaceDelegate
            }

            Component {
                id: interfaceDelegate
                Rectangle {
                    width: mainLayout.width
                    height: 32
                    color: index % 2 === 0 ? "transparent" : root.palette.alternateBase
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        TruncatedLabel {
                            Layout.fillWidth: true
                            text: model.name
                            elide: Text.ElideMiddle
                        }
                        TruncatedLabel {
                            Layout.preferredWidth: 80
                            text: model.data_type
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                        }
                        Label {
                            Layout.preferredWidth: 80
                            text: model.is_available ? qsTr("Available") : qsTr("Not Available")
                            color: model.is_available ? root.palette.highlight : root.palette.text
                            font.bold: model.is_available
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            Layout.preferredWidth: 80
                            text: model.is_claimed ? qsTr("Claimed") : qsTr("Unclaimed")
                            color: model.is_claimed ? root.palette.highlight : root.palette.text
                            font.bold: model.is_claimed
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
