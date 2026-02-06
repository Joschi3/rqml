/*
 * BoxPlotItem.qml - Horizontal boxplot visualization component
 *
 * Displays a boxplot (min, Q1, median, Q3, max) with smooth animations.
 * Used by RuntimeStatistics plugin to visualize execution time distributions.
 *
 * Usage:
 *   BoxPlotItem {
 *       minValue: 10; q1Value: 25; medianValue: 50; q3Value: 75; maxValue: 100
 *       displayMin: 0; displayMax: 120  // Shared scale across multiple plots
 *   }
 */
import QtQuick

Item {
    id: root

    //--------------------------------------------------------------------------
    // Public Properties
    //--------------------------------------------------------------------------

    // Statistics values (will be animated when changed)
    property real minValue: 0
    property real q1Value: 0
    property real medianValue: 0
    property real q3Value: 0
    property real maxValue: 0

    // Display range for consistent scaling across multiple boxplots
    property real displayMin: 0
    property real displayMax: 100

    // Styling (can be overridden)
    property color boxColor: Qt.rgba(0.29, 0.56, 0.85, 0.8)
    property color boxBorderColor: Qt.rgba(0.2, 0.4, 0.7, 1.0)
    property color medianColor: "#E74C3C"
    property color whiskerColor: palette.text

    //--------------------------------------------------------------------------
    // Private Properties
    //--------------------------------------------------------------------------

    readonly property real _boxHeight: 18
    readonly property real _marginH: 8
    readonly property int _animationDuration: 300

    // Animated values for smooth transitions
    property real _animMin: minValue
    property real _animQ1: q1Value
    property real _animMedian: medianValue
    property real _animQ3: q3Value
    property real _animMax: maxValue

    //--------------------------------------------------------------------------
    // Size Hints
    //--------------------------------------------------------------------------

    implicitHeight: _boxHeight + 12
    implicitWidth: 200

    //--------------------------------------------------------------------------
    // Animations
    //--------------------------------------------------------------------------

    Behavior on _animMin { NumberAnimation { duration: _animationDuration; easing.type: Easing.OutQuad } }
    Behavior on _animQ1 { NumberAnimation { duration: _animationDuration; easing.type: Easing.OutQuad } }
    Behavior on _animMedian { NumberAnimation { duration: _animationDuration; easing.type: Easing.OutQuad } }
    Behavior on _animQ3 { NumberAnimation { duration: _animationDuration; easing.type: Easing.OutQuad } }
    Behavior on _animMax { NumberAnimation { duration: _animationDuration; easing.type: Easing.OutQuad } }

    onMinValueChanged: _animMin = minValue
    onQ1ValueChanged: _animQ1 = q1Value
    onMedianValueChanged: _animMedian = medianValue
    onQ3ValueChanged: _animQ3 = q3Value
    onMaxValueChanged: _animMax = maxValue

    //--------------------------------------------------------------------------
    // Visual Elements
    //--------------------------------------------------------------------------

    // Background track
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: _marginH
        anchors.rightMargin: _marginH
        height: 2
        radius: 1
        color: palette.mid
        opacity: 0.3
    }

    // Boxplot canvas
    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.leftMargin: _marginH
        anchors.rightMargin: _marginH

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const range = root.displayMax - root.displayMin;
            if (range <= 0)
                return;

            const drawWidth = width;
            const centerY = height / 2;
            const halfBox = root._boxHeight / 2;

            // Map value to x coordinate, clamped to drawable area
            function mapX(val) {
                const normalized = (val - root.displayMin) / range;
                return Math.max(1, Math.min(normalized * drawWidth, drawWidth - 1));
            }

            const minX = mapX(root._animMin);
            const q1X = mapX(root._animQ1);
            const medX = mapX(root._animMedian);
            const q3X = mapX(root._animQ3);
            const maxX = mapX(root._animMax);

            // Whisker lines
            ctx.strokeStyle = root.whiskerColor;
            ctx.lineWidth = 1.5;
            ctx.lineCap = "round";

            ctx.beginPath();
            ctx.moveTo(minX, centerY);
            ctx.lineTo(q1X, centerY);
            ctx.moveTo(q3X, centerY);
            ctx.lineTo(maxX, centerY);
            ctx.stroke();

            // Whisker end caps
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(minX, centerY - halfBox * 0.5);
            ctx.lineTo(minX, centerY + halfBox * 0.5);
            ctx.moveTo(maxX, centerY - halfBox * 0.5);
            ctx.lineTo(maxX, centerY + halfBox * 0.5);
            ctx.stroke();

            // Box (Q1 to Q3)
            const boxWidth = Math.max(q3X - q1X, 4);
            const boxRadius = 3;

            ctx.fillStyle = root.boxColor;
            ctx.beginPath();
            ctx.roundedRect(q1X, centerY - halfBox, boxWidth, root._boxHeight, boxRadius, boxRadius);
            ctx.fill();

            ctx.strokeStyle = root.boxBorderColor;
            ctx.lineWidth = 1.5;
            ctx.stroke();

            // Median line
            ctx.strokeStyle = root.medianColor;
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.moveTo(medX, centerY - halfBox + 2);
            ctx.lineTo(medX, centerY + halfBox - 2);
            ctx.stroke();
        }
    }

    //--------------------------------------------------------------------------
    // Repaint Triggers
    //--------------------------------------------------------------------------

    // Repaint when animated values change (for smooth animation)
    Connections {
        target: root
        function on_AnimMinChanged() { canvas.requestPaint(); }
        function on_AnimQ1Changed() { canvas.requestPaint(); }
        function on_AnimMedianChanged() { canvas.requestPaint(); }
        function on_AnimQ3Changed() { canvas.requestPaint(); }
        function on_AnimMaxChanged() { canvas.requestPaint(); }
    }

    // Repaint when display range or size changes
    onDisplayMinChanged: canvas.requestPaint()
    onDisplayMaxChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
}
