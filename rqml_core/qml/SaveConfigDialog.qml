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

import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Dialog {
    id: root
    x: (parent.width - width) / 2
    y: 0
    focus: true
    standardButtons: Dialog.NoButton
    padding: 12
    width: Math.min(mainWindow.width * 0.6, 640)
    height: Math.min(mainWindow.height * 0.6, 480)
    title: qsTr("Save Configuration")

    function openAndFocus() {
        open();
        nameInput.forceActiveFocus();
    }

    QtObject {
        id: d
        function save() {
            let name = nameInput.text.trim();
            if (name.length === 0 || name.indexOf("/") !== -1) {
                return;
            }
            let directory = RQml.configDirectories[configDirectoriesList.currentIndex];
            let path = directory + "/" + name + ".rqml";
            // Check if file exists
            if (RQml.fileExists(path)) {
                let overwrite = Qt.createQmlObject('import QtQuick.Dialogs; MessageDialog { title: "Overwrite Confirmation"; text: "A configuration named \\"' + name + '\\" already exists in the selected directory. Do you want to overwrite it?"; buttons: MessageDialog.Yes | MessageDialog.Cancel; }', root);
                overwrite.buttonClicked.connect(function (button) {
                    if (button === MessageDialog.Yes) {
                        RQml.save(path);
                        nameInput.text = "";
                        root.close();
                    }
                    overwrite.destroy();
                });
                overwrite.open();
                return;
            }
            RQml.save(path);
            nameInput.text = "";
            root.close();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextField {
            id: nameInput
            Layout.fillWidth: true
            placeholderText: qsTr("Enter name for configuration")
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    configDirectoriesList.moveDown();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    configDirectoriesList.moveUp();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    d.save();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }
        }

        Label {
            text: qsTr("Select directory to save configuration:")
            font.bold: true
        }

        ListView {
            id: configDirectoriesList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: RQml.configDirectories
            currentIndex: 0
            delegate: ItemDelegate {
                width: configDirectoriesList.width
                highlighted: ListView.isCurrentItem
                onClicked: {
                    configDirectoriesList.currentIndex = index;
                    nameInput.forceActiveFocus();
                }
                contentItem: Column {
                    x: 8
                    width: parent.width - 16
                    spacing: 2
                    Label {
                        Layout.topMargin: 4
                        width: parent.width
                        text: modelData.split("/").pop()
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.bottomMargin: 4
                        width: parent.width
                        text: modelData
                        font.pixelSize: Math.round(Qt.application.font.pixelSize * 0.9)
                        opacity: 0.7
                        elide: Text.ElideMiddle
                    }
                }
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    moveDown();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    moveUp();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    d.save();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }

            function moveUp() {
                let newCurrentIndex = currentIndex - 1;
                if (newCurrentIndex < 0)
                    newCurrentIndex = model.count - 1;
                currentIndex = newCurrentIndex;
            }

            function moveDown() {
                let newCurrentIndex = currentIndex + 1;
                if (newCurrentIndex >= model.count)
                    newCurrentIndex = 0;
                currentIndex = newCurrentIndex;
            }
        }
    }
}
