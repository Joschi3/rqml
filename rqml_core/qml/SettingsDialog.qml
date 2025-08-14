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

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RQml.Elements

Dialog {
    title: qsTr("Settings")
    modal: true
    visible: false
    standardButtons: Dialog.Ok
    anchors.centerIn: parent
    width: Math.min(mainWindow.width * 0.8, 400)

    padding: 20

    GridLayout {
        anchors.fill: parent
        columns: 2

        Label {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            text: qsTr("Configuration Directories")
            font.bold: true
        }

        Rectangle {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            height: 216
            color: "#22aaaaaa"

            ListView {
                anchors.fill: parent
                anchors.margins: 8
                model: RQml.configDirectories
                clip: true
                delegate: RowLayout {
                    width: parent.width
                    TruncatedLabel {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: modelData
                    }
                    Button {
                        id: removeButton
                        text: qsTr("Remove")
                        onClicked: RQml.removeConfigDirectory(modelData)
                        enabled: RQml.configDirectories.length > 1
                    }
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignRight
            Layout.columnSpan: 2
            text: qsTr("Add")
            onClicked: {
                let dirDialog = Qt.createQmlObject('import QtQuick.Dialogs; FolderDialog { title: "Select Configuration Directory"; }', parent);
                dirDialog.onAccepted.connect(function () {
                    if (!dirDialog.selectedFolder)
                        return;
                    RQml.addConfigDirectory(dirDialog.selectedFolder);
                });
                dirDialog.open();
            }
        }
    }
}
