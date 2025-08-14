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

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.kdab.dockwidgets 2.0 as KDDW
import Ros2
import QtQml.Models
import "."

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 640
    height: 480
    minimumWidth: 480
    minimumHeight: 320
    title: "RQml" + (RQml.devMode ? " [DEV MODE]" : "")
    color: active ? palette.active.window : palette.inactive.window

    Component.onCompleted: {
        if (!Ros2.isInitialized()) {
            Ros2.init("rqml");
        }
    }

    menuBar: MenuBar {
        Menu {
            title: qsTr("&File")

            Action {
                text: qsTr("Save config")
                shortcut: "Ctrl+S"
                onTriggered: {
                    RQml.save();
                }
            }

            Action {
                text: qsTr("Save config as…")
                shortcut: "Ctrl+Shift+S"
                onTriggered: {
                    saveConfigDialog.openAndFocus();
                }
            }

            Action {
                text: qsTr("Load config")
                shortcut: "Ctrl+O"
                onTriggered: {
                    openConfigDialog.recent = false;
                    openConfigDialog.openAndFocus();
                }
            }

            Action {
                text: qsTr("Recent configs")
                shortcut: "Ctrl+R"
                onTriggered: {
                    openConfigDialog.recent = true;
                    openConfigDialog.openAndFocus();
                }
            }

            MenuSeparator {}

            Action {
                text: qsTr("Reload current config")
                onTriggered: {
                    RQml.load(RQml.currentConfig.path);
                }
            }

            Action {
                text: qsTr("Close All")
                onTriggered: {
                    KDDW.Singletons.dockRegistry.clear();
                }
            }

            Action {
                text: qsTr("Settings")
                onTriggered: {
                    settingsDialog.open();
                }
            }

            MenuSeparator {}
            Action {
                text: qsTr("&Quit")
                shortcut: "Ctrl+Q"
                onTriggered: {
                    Qt.quit();
                }
            }
        }

        MenuSeparator {}

        Menu {
            id: pluginsMenu
            title: qsTr("&Plugins")
            Instantiator {
                model: {
                    let groups = new Set();
                    RQml.plugins.forEach(plugin => {
                        if (plugin.group) {
                            groups.add(plugin.group);
                        }
                    });
                    return Array.from(groups);
                }
                onObjectAdded: (index, object) => pluginsMenu.insertMenu(index, object)
                onObjectRemoved: (index, object) => pluginsMenu.removeMenu(index, object)

                Menu {
                    title: modelData
                    Repeater {
                        model: RQml.plugins.filter(plugin => plugin.group === modelData)
                        MenuItem {
                            text: modelData.name
                            onTriggered: {
                                let instance = RQml.createPlugin(modelData.id);
                                if (!instance)
                                    return;
                                root.addDockWidget(instance, KDDW.KDDockWidgets.Location_OnRight);
                            }
                        }
                    }
                }
            }
            Repeater {
                model: RQml.plugins.filter(plugin => plugin.group === "")
                MenuItem {
                    text: modelData.name
                    onTriggered: {
                        let instance = RQml.createPlugin(modelData.id);
                        if (!instance)
                            return;
                        root.addDockWidget(instance, KDDW.KDDockWidgets.Location_OnRight);
                    }
                }
            }
        }

        Menu {
            title: qsTr("&Help")

            Action {
                text: qsTr("Dev Mode")
                checkable: true
                checked: RQml.devMode
                onToggled: RQml.devMode = checked
            }

            Action {
                text: qsTr("Create Desktop Entry")
                onTriggered: {
                    RQml.createDesktopEntry();
                }
                enabled: RQml.canCreateDesktopEntry()
            }

            Action {
                text: qsTr("About")
                onTriggered: {
                    aboutDialog.open();
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: -Qt.application.font.pixelSize * 2

        ColumnLayout {
            id: noPluginsLoadedMessage
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Qt.application.font.pixelSize * 2
            spacing: Qt.application.font.pixelSize / 2

            Label {
                text: qsTr("No plugins loaded.")
                font.bold: true
                font.pixelSize: Qt.application.font.pixelSize * 1.6
            }
            Label {
                text: qsTr("Load plugins from the 'Plugins' menu.")
                font.pixelSize: Qt.application.font.pixelSize * 1.2
            }
        }
        Image {
            source: "qrc:/assets/mascot/magnifying_glass.png"
            height: Qt.application.font.pixelSize * 12
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }
    }

    KDDW.DockingArea {
        id: root
        anchors.fill: parent
        // Each main layout needs a unique id
        uniqueName: "MainLayout-1"
    }

    AboutDialog {
        id: aboutDialog
    }

    SettingsDialog {
        id: settingsDialog
    }

    OpenConfigDialog {
        id: openConfigDialog
    }

    SaveConfigDialog {
        id: saveConfigDialog
    }
}
