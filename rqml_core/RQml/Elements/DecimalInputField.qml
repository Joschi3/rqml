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

TextField {
    selectByMouse: true
    property var from: null
    property var to: null
    property real value: 0.0
    property var decimals: undefined
    text: value.toPrecision(decimals)
    onEditingFinished: {
        if (text.length == 0) {
            text = Qt.binding(() => value.toPrecision(decimals));
            return;
        }
        let newValue = parseFloat(text);
        if (isNaN(newValue)) {
            text = Qt.binding(() => value.toPrecision(decimals));
            return;
        }
        if (from != null && newValue < from) {
            newValue = from;
            text = newValue.toPrecision(decimals);
        } else if (to != null && newValue > to) {
            newValue = to;
            text = newValue.toPrecision(decimals);
        }
        if (newValue == value)
            return;
        value = newValue;
    }
    validator: RegularExpressionValidator {
        regularExpression: /^-?[0-9]*$|^-?([0-9]+\.[0-9]*)$/
    }
}
