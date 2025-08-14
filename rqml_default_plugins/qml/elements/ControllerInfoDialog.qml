import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RQml.Elements

Dialog {
    id: root
    property var controller: null

    anchors.centerIn: parent
    title: qsTr("Controller Information")
    width: 600
    height: Math.min(parent.height * 0.8, implicitHeight)
    standardButtons: Dialog.Close

    function openControllerInfo(controller) {
        root.controller = controller;
        root.open();
    }

    QtObject {
        id: d
        property var attributes: {
            if (!root.controller || root.controller.state == "unloaded")
                return [];
            return [
                {
                    "name": "Type",
                    "data": root.controller.type
                },
                {
                    "name": "Is Async",
                    "data": root.controller.is_async
                },
                {
                    "name": "Update Rate",
                    "data": root.controller.update_rate
                },
                {
                    "name": "Is Chainable",
                    "data": root.controller.is_chainable
                },
                {
                    "name": "Is Chained",
                    "data": root.controller.is_chained
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

            Label {
                text: qsTr("Name:")
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: root.controller?.name ?? qsTr("N/A")
            }

            Label {
                text: qsTr("State:")
                font.bold: true
            }
            Label {
                text: root.controller?.state ?? qsTr("N/A")
            }

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

            Repeater {
                model: {
                    if (!root.controller || root.controller.state == "unloaded")
                        return [];
                    return [
                        {
                            "name": "Claimed Interfaces",
                            "data": root.controller.claimed_interfaces
                        },
                        {
                            "name": "Required Command Interfaces",
                            "data": root.controller.required_command_interfaces
                        },
                        {
                            "name": "Required State Interfaces",
                            "data": root.controller.required_state_interfaces
                        },
                        {
                            "name": "Exported State Interfaces",
                            "data": root.controller.exported_state_interfaces
                        },
                        {
                            "name": "Reference Interfaces",
                            "data": root.controller.reference_interfaces
                        }
                    ];
                }

                ListView {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: contentHeight + headerItem.implicitHeight
                    model: modelData.data
                    spacing: 8
                    clip: true
                    header: ListHeader {
                        text: modelData.name
                    }
                    headerPositioning: ListView.OverlayHeader
                    delegate: TruncatedLabel {
                        width: mainLayout.width
                        height: 24
                        text: model.display
                        elide: Text.ElideMiddle
                    }
                }
            }

            ListView {
                visible: root.controller?.state != "unloaded"
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight + headerItem.implicitHeight
                model: root.controller?.chain_connections ?? []
                clip: true
                header: ListHeader {
                    text: "Chain Connections"
                }
                headerPositioning: ListView.OverlayHeader
                delegate: Rectangle {
                    width: mainLayout.width
                    height: layout.implicitHeight
                    color: index % 2 === 0 ? "transparent" : palette.alternateBase
                    RowLayout {
                        id: layout
                        anchors.fill: parent
                        property var reference_interfaces: model.reference_interfaces

                        TruncatedLabel {
                            Layout.fillWidth: true
                            text: model.name
                            elide: Text.ElideMiddle
                        }
                        Column {
                            Layout.fillWidth: true
                            Repeater {
                                model: reference_interfaces
                                TruncatedLabel {
                                    width: parent.width
                                    height: 24
                                    text: model.display
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
