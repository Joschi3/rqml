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
import QtQuick.Layouts

Dialog {
    id: root
    x: (parent.width - width) / 2
    y: 0
    focus: true
    standardButtons: Dialog.NoButton
    padding: 12
    width: Math.min(mainWindow.width * 0.8, 640)
    height: Math.min(mainWindow.height * 0.6, 480)
    title: recent ? qsTr("Recent Configurations") : qsTr("Configurations")

    property bool recent: false

    function openAndFocus() {
        open();
        // reset filter and selection
        filterInput.text = "";
        configsList.currentIndex = 0;
        d.updateFilteredModel();
        filterInput.forceActiveFocus();
    }

    QtObject {
        id: d

        function updateFilteredModel() {
            filteredModel.clear();
            const q = filterInput.text.trim().toLowerCase();
            let input = recent ? RQml.recentConfigs : RQml.configs;
            input = input || [];
            input.forEach(cfg => {
                const name = cfg.path.split("/").pop().split(".").slice(0, -1).join(".");
                const path = cfg.path;
                if (!q || name.toLowerCase().indexOf(q) !== -1 || path.toLowerCase().indexOf(q) !== -1) {
                    filteredModel.append({
                        "name": name,
                        "path": path
                    });
                }
            });
            // clamp selection within bounds
            configsList.currentIndex = Math.min(Math.max(0, filteredModel.count > 0 ? 0 : -1), filteredModel.count - 1);
        }

        function loadSelected() {
            if (configsList.currentIndex >= 0 && configsList.currentIndex < filteredModel.count) {
                const item = filteredModel.get(configsList.currentIndex);
                if (item && item.path) {
                    RQml.load(item.path);
                    root.close();
                }
            }
        }
    }

    ListModel {
        id: filteredModel
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextField {
            id: filterInput
            Layout.fillWidth: true
            placeholderText: qsTr("Type to filter configs…")
            focus: true
            onTextChanged: d.updateFilteredModel()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    configsList.moveDown();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    configsList.moveUp();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    d.loadSelected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }
        }

        ListView {
            id: configsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: filteredModel
            delegate: ItemDelegate {
                width: configsList.width
                text: (model.name || model.path)
                highlighted: index === configsList.currentIndex
                onClicked: {
                    configsList.currentIndex = index;
                    d.loadSelected();
                }
                contentItem: Column {
                    x: 8
                    width: parent.width - 16
                    spacing: 2
                    Label {
                        Layout.topMargin: 4
                        width: parent.width
                        text: model.name || model.path
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.bottomMargin: 4
                        width: parent.width
                        text: model.path
                        font.pixelSize: Math.round(Qt.application.font.pixelSize * 0.9)
                        opacity: 0.7
                        elide: Text.ElideMiddle
                    }
                }
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    configsList.moveDown();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    configsList.moveUp();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    d.loadSelected();
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
