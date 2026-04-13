import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ros2
import RQml.Elements
import "interfaces"

/**
 * MoveIt Controller Plugin
 *
 * Provides a UI for controlling robot motion through MoveIt's move_group action.
 * Features:
 * - Move group selection from SRDF
 * - Joint sliders for goal position control
 * - Predefined pose buttons from SRDF group_states
 * - Velocity scaling and planning time configuration
 */
Rectangle {
    id: root
    anchors.fill: parent
    property var kddockwidgets_min_size: Qt.size(500, 400)
    color: palette.base

    // ========================================================================
    // Initialization
    // ========================================================================

    Component.onCompleted: {
        // Initialize context defaults
        if (!context.action_server)
            context.action_server = "";
        if (!context.move_group)
            context.move_group = "";
        if (context.velocity_scale === undefined)
            context.velocity_scale = 0.1;
        if (context.acceleration_scale === undefined)
            context.acceleration_scale = 0.1;
        if (context.planning_time === undefined)
            context.planning_time = 5.0;
        if (context.planning_attempts === undefined)
            context.planning_attempts = 5;
    }

    // ========================================================================
    // Private Data
    // ========================================================================

    QtObject {
        id: d

        property string errorTitle: ""
        property string errorDetails: ""
        property bool showError: false

        property var moveItInterface: MoveItInterface {
            actionServer: context.action_server || ""
            moveGroupName: context.move_group || ""

            onMotionFailed: function(title, details) {
                d.errorTitle = title;
                d.errorDetails = details;
                d.showError = true;
                errorHideTimer.restart();
            }

            onGoalAccepted: {
                d.showError = false;
                errorHideTimer.stop();
            }
        }
    }

    // Timer to auto-hide error after 10 seconds
    Timer {
        id: errorHideTimer
        interval: 10000
        onTriggered: d.showError = false
    }

    // ========================================================================
    // Main Layout
    // ========================================================================

    GridLayout {
        anchors.fill: parent
        anchors.margins: 8
        columns: 3
        rowSpacing: 8
        columnSpacing: 8

        // --------------------------------------------------------------------
        // Action Server Selection
        // --------------------------------------------------------------------

        Label {
            text: "Action Server"
        }

        RowLayout {
            Layout.columnSpan: 2
            Layout.fillWidth: true

            ComboBox {
                id: actionServerComboBox
                objectName: "moveitActionServerComboBox"
                Layout.fillWidth: true
                model: d.moveItInterface.actionServers
                textRole: "name"

                currentIndex: {
                    for (let i = 0; i < d.moveItInterface.actionServers.count; i++) {
                        if (d.moveItInterface.actionServers.get(i).name === context.action_server)
                            return i;
                    }
                    return -1;
                }

                onCurrentTextChanged: {
                    if (currentText && currentText !== context.action_server) {
                        context.action_server = currentText;
                    }
                }
            }

            RefreshButton {
                objectName: "moveitRefreshButton"
                onClicked: {
                    animate = true;
                    d.moveItInterface.refresh();
                    animate = false;
                }
            }
        }

        // --------------------------------------------------------------------
        // Move Group Selection
        // --------------------------------------------------------------------

        Label {
            text: "Move Group"
        }

        ComboBox {
            id: moveGroupComboBox
            objectName: "moveitMoveGroupComboBox"
            Layout.columnSpan: 2
            Layout.fillWidth: true
            model: d.moveItInterface.moveGroups
            textRole: "name"

            currentIndex: {
                for (let i = 0; i < d.moveItInterface.moveGroups.count; i++) {
                    if (d.moveItInterface.moveGroups.get(i).name === context.move_group)
                        return i;
                }
                return -1;
            }

            onCurrentTextChanged: {
                if (currentText && currentText !== context.move_group) {
                    context.move_group = currentText;
                }
            }
        }

        // --------------------------------------------------------------------
        // Named Poses Section
        // --------------------------------------------------------------------

        Label {
            Layout.columnSpan: 3
            text: "Named Poses"
            font.bold: true
            visible: d.moveItInterface.namedPoses.count > 0
        }

        Flow {
            objectName: "moveitNamedPosesFlow"
            Layout.columnSpan: 3
            Layout.fillWidth: true
            spacing: 4
            visible: d.moveItInterface.namedPoses.count > 0

            Repeater {
                model: d.moveItInterface.namedPoses

                Button {
                    text: model.name
                    onClicked: {
                        d.moveItInterface.applyNamedPose(model.name);
                    }

                    ToolTip.visible: hovered
                    ToolTip.text: "Apply '" + model.name + "' pose to joint goals"
                    ToolTip.delay: 500
                }
            }
        }

        // --------------------------------------------------------------------
        // Error Banner (full width)
        // --------------------------------------------------------------------

        Rectangle {
            objectName: "moveitErrorBannerRect"
            Layout.columnSpan: 3
            Layout.fillWidth: true
            Layout.preferredHeight: errorBannerColumn.implicitHeight + 12
            color: palette.toolTipBase
            border.color: palette.toolTipText
            border.width: 1
            radius: 4
            visible: d.showError

            ColumnLayout {
                id: errorBannerColumn
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        objectName: "moveitErrorTitle"
                        text: d.errorTitle
                        font.bold: true
                        color: palette.toolTipText
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        implicitWidth: 20
                        implicitHeight: 20
                        flat: true
                        text: "x"
                        onClicked: d.showError = false
                    }
                }

                Label {
                    objectName: "moveitErrorDetails"
                    Layout.fillWidth: true
                    text: d.errorDetails
                    color: palette.toolTipText
                    wrapMode: Text.WordWrap
                    visible: d.errorDetails !== ""
                }
            }
        }

        // --------------------------------------------------------------------
        // Joint Sliders
        // --------------------------------------------------------------------

        Label {
            Layout.columnSpan: 3
            text: "Joint Goals"
            font.bold: true
            visible: d.moveItInterface.joints.count > 0
        }

        ListView {
            id: jointListView
            objectName: "moveitJointListView"
            Layout.columnSpan: 3
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            clip: true
            model: d.moveItInterface.joints

            ScrollBar.vertical: ScrollBar {
                policy: jointListView.contentHeight > jointListView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }

            delegate: RowLayout {
                width: jointListView.width - 16
                x: 8
                height: 48
                spacing: 8

                Label {
                    Layout.preferredWidth: 150
                    text: model.name
                    elide: Text.ElideRight
                }

                ChangeSlider {
                    id: positionSlider
                    Layout.fillWidth: true
                    stepSize: 0.01
                    from: model.limits.lower
                    to: model.limits.upper
                    value: model.goal
                    currentValue: model.position

                    onMoved: {
                        model.goal = Math.round(value * 100) / 100;
                    }
                }

                TextField {
                    implicitWidth: 70
                    selectByMouse: true
                    text: model.goal.toFixed(2)
                    horizontalAlignment: Text.AlignRight

                    validator: DoubleValidator {
                        bottom: model.limits.lower
                        top: model.limits.upper
                    }

                    onTextChanged: {
                        let value = parseFloat(text);
                        if (isNaN(value))
                            return;
                        value = Math.min(model.limits.upper, Math.max(value, model.limits.lower));
                        value = Math.round(value * 100) / 100;
                        if (Math.abs(value - model.goal) < 1e-9)
                            return;
                        model.goal = value;
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // Action Buttons (always visible)
        // --------------------------------------------------------------------

        RowLayout {
            Layout.columnSpan: 3
            Layout.fillWidth: true
            visible: !!moveGroupComboBox.currentText

            Button {
                objectName: "moveitResetButton"
                Layout.fillWidth: true
                Layout.margins: 4
                text: "Reset"
                onClicked: d.moveItInterface.resetGoals()

                ToolTip.visible: hovered
                ToolTip.text: "Reset all joint goals to current positions"
                ToolTip.delay: 500
            }

            Button {
                objectName: "moveitExecuteButton"
                Layout.fillWidth: true
                Layout.margins: 4
                text: d.moveItInterface.isGoalActive ? "Cancel" : "Execute"
                enabled: d.moveItInterface.actionReady

                onClicked: {
                    if (d.moveItInterface.isGoalActive) {
                        d.moveItInterface.cancelGoals();
                    } else {
                        d.moveItInterface.sendGoals(
                            planningTimeSlider.value,
                            velocitySlider.value,
                            accelerationSlider.value,
                            Math.round(planningAttemptsSlider.value)
                        );
                    }
                }

                ToolTip.visible: hovered
                ToolTip.text: d.moveItInterface.isGoalActive
                    ? "Cancel current motion"
                    : "Plan and execute motion to goal positions"
                ToolTip.delay: 500
            }
        }

        // --------------------------------------------------------------------
        // Planning Configuration (collapsible)
        // --------------------------------------------------------------------

        ColumnLayout {
            Layout.columnSpan: 3
            Layout.fillWidth: true
            visible: !!moveGroupComboBox.currentText
            spacing: 4

            // Collapsible header (styled like a button)
            Button {
                id: planningConfigHeaderButton
                objectName: "moveitPlanningConfigButton"
                Layout.fillWidth: true
                Layout.margins: 4
                flat: true

                onClicked: planningConfigExpanded.expanded = !planningConfigExpanded.expanded

                contentItem: RowLayout {
                    spacing: 8

                    Label {
                        text: planningConfigExpanded.expanded ? "\u25BC" : "\u25B6"
                        font.pixelSize: 10
                    }

                    Label {
                        text: "Planning Configuration"
                    }

                    Item { Layout.fillWidth: true }

                    Label {
                        text: "Vel: " + (velocitySlider.value * 100).toFixed(0) + "%, Acc: " + (accelerationSlider.value * 100).toFixed(0) + "%"
                        visible: !planningConfigExpanded.expanded
                    }
                }
            }

            // Collapsible content
            QtObject {
                id: planningConfigExpanded
                property bool expanded: false
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: planningConfigExpanded.expanded
                spacing: 4

                // Velocity scale slider
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.preferredWidth: 80
                        text: "Velocity:"
                    }

                    Slider {
                        id: velocitySlider
                        objectName: "moveitVelocitySlider"
                        Layout.fillWidth: true
                        from: 0.01
                        to: 1.0
                        Component.onCompleted: value = context.velocity_scale || 0.1
                        onMoved: context.velocity_scale = value
                    }

                    Label {
                        Layout.preferredWidth: 50
                        text: (velocitySlider.value * 100).toFixed(0) + "%"
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Acceleration scale slider
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.preferredWidth: 80
                        text: "Acceleration:"
                    }

                    Slider {
                        id: accelerationSlider
                        objectName: "moveitAccelerationSlider"
                        Layout.fillWidth: true
                        from: 0.01
                        to: 1.0
                        Component.onCompleted: value = context.acceleration_scale || 0.1
                        onMoved: context.acceleration_scale = value
                    }

                    Label {
                        Layout.preferredWidth: 50
                        text: (accelerationSlider.value * 100).toFixed(0) + "%"
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Planning time slider
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.preferredWidth: 80
                        text: "Plan time:"
                    }

                    Slider {
                        id: planningTimeSlider
                        objectName: "moveitPlanningTimeSlider"
                        Layout.fillWidth: true
                        from: 1.0
                        to: 30.0
                        Component.onCompleted: value = context.planning_time || 5.0
                        onMoved: context.planning_time = value
                    }

                    Label {
                        Layout.preferredWidth: 50
                        text: planningTimeSlider.value.toFixed(1) + "s"
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Planning attempts slider
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.preferredWidth: 80
                        text: "Attempts:"
                    }

                    Slider {
                        id: planningAttemptsSlider
                        objectName: "moveitPlanningAttemptsSlider"
                        Layout.fillWidth: true
                        from: 1
                        to: 20
                        stepSize: 1
                        Component.onCompleted: value = context.planning_attempts || 5
                        onMoved: context.planning_attempts = Math.round(value)
                    }

                    Label {
                        Layout.preferredWidth: 50
                        text: Math.round(planningAttemptsSlider.value).toString()
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // Status Bar
        // --------------------------------------------------------------------

        RowLayout {
            Layout.columnSpan: 3
            Layout.fillWidth: true
            spacing: 16

            Label {
                objectName: "moveitUrdfStatusLabel"
                text: "URDF: " + (d.moveItInterface.hasRobotDescription ? "Loaded" : "Waiting...")
            }

            Label {
                objectName: "moveitSrdfStatusLabel"
                text: "SRDF: " + (d.moveItInterface.hasSrdf ? "Loaded" : "Waiting...")
            }

            Item { Layout.fillWidth: true }

            Label {
                objectName: "moveitActionStatusLabel"
                text: "Action: " + (d.moveItInterface.actionReady ? "Ready" : "Connecting...")
            }
        }
    }
}
