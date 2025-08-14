/*
 * Copyright (C) 2025  Stefan Fabian
 *
 * This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import QtQuick.Controls
import QtQuick.Layouts
import Ros2
import RQml.Utils

Dialog {
    id: control
    title: "Edit Message Content"
    standardButtons: Dialog.Ok | Dialog.Cancel
    property alias message: messageModel.message
    property alias messageType: messageModel.messageType

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton {
                text: qsTr("Visual")
            }
            TabButton {
                text: qsTr("Text")
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex
            MessageContentEditor {
                id: messageContentEditor
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: MessageItemModel {
                    id: messageModel
                    onModified: {
                        textArea.text = Qt.binding(() => JSON.stringify(MessageUtils.toJavaScriptObject(control.message) ?? {}, null, 2));
                    }
                    onMessageChanged: {
                        messageContentEditor.expandRecursively();
                    }
                }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                TextArea {
                    id: textArea
                    anchors.fill: parent
                    text: JSON.stringify(MessageUtils.toJavaScriptObject(control.message) ?? {}, null, 2)

                    onEditingFinished: {
                        try {
                            control.message = JSON.parse(text);
                        } catch (e) {
                            // ignore parse errors
                        }
                    }
                }
            }
        }
    }
}
