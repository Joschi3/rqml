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

Item {
    id: root
    property var direction: Qt.Vertical
    property alias value: slider.value
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    property alias from: minField.value
    property alias to: maxField.value

    GridLayout {
        id: layout
        anchors.fill: parent
        flow: direction == Qt.Vertical ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columns: 3
        rows: 3

        DecimalInputField {
            id: maxField
            Layout.column: direction == Qt.Vertical ? 0 : 2
            Layout.row: 0
            Layout.rowSpan: direction == Qt.Horizontal ? 3 : 1
            Layout.columnSpan: direction == Qt.Vertical ? 3 : 1
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            implicitWidth: 50
            from: 0.1
            to: 100.0
            decimals: 1
            value: 1
        }

        Button {
            Layout.alignment: direction == Qt.Vertical ? Qt.AlignLeft | Qt.AlignVCenter : Qt.AlignTop | Qt.AlignHCenter
            Layout.column: direction == Qt.Vertical ? 0 : 1
            Layout.row: direction == Qt.Horizontal ? 0 : 1
            Layout.fillWidth: direction == Qt.Vertical
            implicitWidth: 50
            text: "0"
            onClicked: {
                slider.value = 0;
            }
        }

        Slider {
            id: slider
            Layout.column: 1
            Layout.row: 1
            Layout.fillHeight: direction == Qt.Vertical
            Layout.fillWidth: direction == Qt.Horizontal
            from: Math.min(-0.1, parseFloat(minField.text) || -0.1)
            to: Math.max(0.1, parseFloat(maxField.text) || 0.1)
            stepSize: (to - from) / 1000
            value: 0
            orientation: direction
        }
        DecimalInputField {
            id: valueField
            Layout.alignment: direction == Qt.Vertical ? Qt.AlignLeft | Qt.AlignVCenter : Qt.AlignTop | Qt.AlignHCenter
            Layout.column: direction == Qt.Vertical ? 2 : 1
            Layout.row: direction == Qt.Horizontal ? 2 : 1
            Layout.fillWidth: direction == Qt.Vertical
            implicitWidth: 50
            from: root.from
            to: root.to
            decimals: 2
            value: slider.value
            onValueChanged: slider.value = value
        }

        DecimalInputField {
            id: minField
            Layout.column: 0
            Layout.row: direction == Qt.Horizontal ? 0 : 2
            Layout.rowSpan: direction == Qt.Horizontal ? 3 : 1
            Layout.columnSpan: direction == Qt.Vertical ? 3 : 1
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            implicitWidth: 50
            from: -100.0
            to: -0.1
            decimals: 1
            value: -1
        }
    }
}
