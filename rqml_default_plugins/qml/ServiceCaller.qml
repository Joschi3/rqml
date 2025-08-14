import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ros2
import RQml.Elements

Rectangle {
    id: root
    anchors.fill: parent
    property var kddockwidgets_min_size: Qt.size(350, 500)
    color: palette.base

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8

        GridLayout {
            Layout.fillWidth: true
            columns: 3

            Label {
                text: "Service:"
                font.bold: true
            }
            ComboBox {
                id: serviceSelect
                Layout.fillWidth: true
                editable: true
                selectTextByMouse: true
                editText: context.service
                onEditTextChanged: {
                    if (editText == null || editText == context.service)
                        return;
                    context.service = editText;
                    typeSelect.refresh();
                }
                function refresh() {
                    let services = Ros2.queryServices();
                    if (!!context.service) {
                        const index = services.indexOf(context.service);
                        if (index != -1)
                            services.splice(index, 1);
                        services.unshift(context.service);
                    }
                    model = services;
                }
                Component.onCompleted: refresh()
            }
            RefreshButton {
                id: refreshServicesButton
                onClicked: {
                    animate = true;
                    serviceSelect.refresh();
                    animate = false;
                }
            }
            Label {
                text: "Type:"
                font.bold: true
            }
            ComboBox {
                id: typeSelect
                Layout.fillWidth: true
                editable: true
                selectTextByMouse: true
                editText: context.type
                onEditTextChanged: {
                    if (editText == null || editText == context.type)
                        return;
                    context.type = editText;
                    if (!context.type)
                        return;
                    if (requestModel.message && requestModel.message["#messageType"] == context.type + "_Request")
                        return;
                    context.request = Ros2.createEmptyServiceRequest(context.type);
                    requestModel.message = context.request;
                    tabBar.currentIndex = 0;
                }
                function refresh() {
                    let types = Ros2.getServiceTypes(context.service);
                    if (types.length == 0)
                        return context.type && [context.type] || [];
                    typeSelect.model = types;
                }
                Component.onCompleted: refresh()
            }
            RefreshButton {
                onClicked: {
                    animate = true;
                    typeSelect.refresh();
                    animate = false;
                }
            }
        }
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton {
                text: qsTr("Request")
            }
            TabButton {
                text: qsTr("Response")
                enabled: d.response !== null || d.isActive
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // Request Tab
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                MessageContentEditor {
                    id: requestEditor
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: MessageItemModel {
                        id: requestModel
                        onModified: {
                            if (message == context.request)
                                return;
                            context.request = message;
                        }
                        Component.onCompleted: message = context.request ?? null
                    }
                    readonly: false
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        enabled: !!context.type
                        implicitWidth: 120
                        text: "Reset"
                        onClicked: {
                            context.request = Ros2.createEmptyServiceRequest(context.type);
                            requestModel.message = context.request;
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    } // Spacer

                    Button {
                        enabled: (d.client?.ready && !d.isActive) ?? false
                        implicitWidth: 120
                        text: "Send"
                        onClicked: {
                            d.resetState();
                            d.isActive = true;
                            tabBar.currentIndex = 1;
                            d.client.sendRequestAsync(requestEditor.model.message, function (response) {
                                tabBar.currentIndex = 1;
                                d.response = response;
                                d.isActive = false;
                            });
                        }
                    }
                }
            }

            // Response Tab
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    visible: !responseEditor.visible
                    anchors.fill: parent
                    color: root.palette.base
                    Label {
                        anchors.centerIn: parent
                        text: d.response === null ? "Waiting for response..." : "Service call failed."
                    }
                }
                MessageContentEditor {
                    id: responseEditor
                    anchors.fill: parent
                    visible: d.client && !!d.response || false
                    readonly: true
                    model: MessageItemModel {
                        message: d.response || null
                        onMessageChanged: responseEditor.expandRecursively()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Status: "
            }
            Label {
                id: statusText
                Layout.fillWidth: true
                text: {
                    if (!d.client)
                        return "None";
                    if (d.isActive)
                        return "Waiting for response...";
                    if (d.client.ready)
                        return "Ready";
                    return "Connecting...";
                }
            }
        }
    }

    QtObject {
        id: d
        property var client: {
            d.resetState();
            if (!context.service || !context.type || !Ros2.isValidTopic(context.service))
                return null;
            return Ros2.createServiceClient(context.service, context.type);
        }
        property bool isActive: false
        property var response: null

        function resetState() {
            isActive = false;
            response = null;
        }
    }
}
