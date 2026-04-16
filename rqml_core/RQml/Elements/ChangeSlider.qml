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

Slider {
    id: control

    property real currentValue: 0
    property real currentValueVisualPosition: {
        const percent = Math.min(1, Math.max(0, (currentValue - from) / (to - from)));
        return LayoutMirroring.enabled ? 1 - percent : percent;
    }

    stepSize: (to - from) / 1000

    background: Rectangle {
        clip: true
        color: "#bdbebf"
        height: implicitHeight
        implicitHeight: 8
        implicitWidth: 200
        radius: 4
        width: control.availableWidth
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2

        Rectangle {
            color: "#4cce54"
            height: parent.height
            radius: parent.radius
            width: Math.max(control.visualPosition, control.currentValueVisualPosition) * parent.width
        }
        Rectangle {
            color: "#35833a"
            height: parent.height
            radius: parent.radius
            width: Math.min(control.visualPosition, control.currentValueVisualPosition) * parent.width
        }
    }
    handle: Rectangle {
        color: control.pressed ? "#15b3af" : "#21be2b"
        implicitHeight: 26
        implicitWidth: 8
        radius: 4
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
    }
}
