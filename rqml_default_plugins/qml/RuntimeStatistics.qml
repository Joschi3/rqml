/*
 * RuntimeStatistics.qml - Controller Manager Execution Time Monitor
 *
 * This plugin visualizes execution time statistics for controllers and hardware
 * interfaces managed by a ROS 2 controller manager. It subscribes to the
 * statistics/full topic and displays boxplots showing the distribution of
 * execution times.
 *
 * Features:
 * - Automatic controller manager discovery
 * - Real-time boxplot visualization with smooth animations
 * - Configurable sample window size
 * - Pause/resume data collection
 * - Elements sorted by median execution time
 *
 * Data source: <controller_manager>/statistics/full topic
 * Message type: pal_statistics_msgs/msg/Statistics (or compatible)
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ros2
import RQml.Elements
import RQml.Fonts
import "elements"

Rectangle {
    id: root
    anchors.fill: parent
    color: palette.base

    //--------------------------------------------------------------------------
    // Constants
    //--------------------------------------------------------------------------

    readonly property var kddockwidgets_min_size: Qt.size(500, 400)
    readonly property string _statisticsTopicSuffix: "/statistics/full"
    readonly property string _executionTimeFilter: "/execution_time/current_value"
    readonly property int _defaultMaxSamples: 1000
    readonly property int _updateIntervalMs: 500

    //--------------------------------------------------------------------------
    // Initialization
    //--------------------------------------------------------------------------

    Component.onCompleted: {
        // Initialize context defaults
        if (context.enabled === undefined)
            context.enabled = true;
        if (context.maxSamples !== undefined)
            d.maxSamples = context.maxSamples;
        d.refresh();
    }

    // Triggers UI update from QtObject (timers can't be accessed directly from QtObject)
    function _triggerUpdate() {
        if (!updateTimer.running)
            updateTimer.start();
    }

    //--------------------------------------------------------------------------
    // Main Layout
    //--------------------------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Controller Manager selection
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label { text: "Controller Manager" }

            ComboBox {
                id: controllerManagerComboBox
                Layout.fillWidth: true
                model: d.controllerManagers

                onCurrentValueChanged: {
                    if (!currentValue || currentValue === context.controller_manager_namespace)
                        return;
                    context.controller_manager_namespace = currentValue;
                    d.clear();
                }
            }

            RefreshButton {
                onClicked: {
                    animate = true;
                    d.refresh();
                    animate = false;
                }
            }
        }

        // Status row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "Samples: " + d.totalSamples
                font.pixelSize: 11
                color: palette.mid
            }

            Rectangle { width: 1; height: 16; color: palette.mid; opacity: 0.5 }

            Label {
                text: d.elementsModel.count + " elements"
                font.pixelSize: 11
                color: palette.mid
            }

            Item { Layout.fillWidth: true }

            IconToggleButton {
                iconOn: IconFont.iconPause
                iconOff: IconFont.iconPlay
                tooltipTextOn: "Click to pause"
                tooltipTextOff: "Click to resume"
                checked: context.enabled ?? true
                onToggled: context.enabled = checked
            }

            IconButton {
                text: IconFont.iconTrash
                tooltipText: "Clear data"
                onClicked: d.clear()
            }
        }

        // Waiting indicator
        Label {
            Layout.fillWidth: true
            visible: !d.topicAvailable && !!context.controller_manager_namespace && d.messageCount === 0
            text: "Waiting for statistics topic: " + (context.controller_manager_namespace || "") + _statisticsTopicSuffix
            color: palette.mid
            font.italic: true
            wrapMode: Text.WordWrap
        }

        // Scale indicator
        RowLayout {
            Layout.fillWidth: true
            visible: d.elementsModel.count > 0
            spacing: 4

            Label {
                text: d.globalMin.toFixed(0) + " \u00b5s"
                font.pixelSize: 10
                color: palette.mid
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: palette.mid
                opacity: 0.3
            }

            Label {
                text: d.globalMax.toFixed(0) + " \u00b5s"
                font.pixelSize: 10
                color: palette.mid
            }
        }

        // Statistics list
        ListView {
            id: statsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: statsListView.contentHeight > statsListView.height
                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }

            model: d.elementsModel

            // Disable list animations to prevent flickering during updates
            displaced: Transition {}
            add: Transition {}
            remove: Transition {}

            delegate: Rectangle {
                id: delegateRoot
                required property var model
                required property int index

                width: statsListView.width -
                       (statsListView.ScrollBar.vertical.visible
                        ? statsListView.ScrollBar.vertical.width : 0)
                height: 64
                radius: 4
                color: index % 2 === 0 ? palette.base : palette.alternateBase

                // Subtle border
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    color: "transparent"
                    border.width: 1
                    border.color: palette.mid
                    opacity: 0.3
                    radius: 3
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 4

                    // Header: label and sample count
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: model.label
                            font.bold: true
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "n=" + model.count
                            font.pixelSize: 10
                            color: palette.mid
                        }
                    }

                    // Boxplot visualization
                    BoxPlotItem {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        minValue: model.min
                        q1Value: model.q1
                        medianValue: model.median
                        q3Value: model.q3
                        maxValue: model.max
                        displayMin: d.globalMin
                        displayMax: d.globalMax
                    }

                    // Statistics values
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            text: "min " + model.min.toFixed(1)
                            font.pixelSize: 9
                            color: palette.mid
                            Layout.preferredWidth: 70
                        }
                        Label {
                            text: "Q1 " + model.q1.toFixed(1)
                            font.pixelSize: 9
                            color: palette.mid
                            Layout.preferredWidth: 60
                        }
                        Label {
                            text: "med " + model.median.toFixed(1)
                            font.pixelSize: 9
                            font.bold: true
                            color: "#E74C3C"
                            Layout.preferredWidth: 70
                        }
                        Label {
                            text: "Q3 " + model.q3.toFixed(1)
                            font.pixelSize: 9
                            color: palette.mid
                            Layout.preferredWidth: 60
                        }
                        Label {
                            text: "max " + model.max.toFixed(1)
                            font.pixelSize: 9
                            color: palette.mid
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        // Empty state message
        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: d.elementsModel.count === 0 && d.messageCount > 0
            text: "No execution time data found in statistics messages."
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: palette.mid
        }

        // Sample window slider (at bottom)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "Window:"
                font.pixelSize: 11
                color: palette.mid
            }

            Slider {
                id: sampleSizeSlider
                Layout.fillWidth: true
                from: 100
                to: 10000
                stepSize: 100
                value: context.maxSamples ?? _defaultMaxSamples

                onMoved: {
                    context.maxSamples = value;
                    d.setMaxSamples(value);
                }
            }

            Label {
                text: d.maxSamples + " samples"
                font.pixelSize: 11
                color: palette.mid
                Layout.preferredWidth: 80
            }
        }
    }

    //--------------------------------------------------------------------------
    // ROS 2 Subscription
    //--------------------------------------------------------------------------

    Subscription {
        id: statisticsSubscription
        topic: context.controller_manager_namespace
               ? context.controller_manager_namespace + _statisticsTopicSuffix
               : ""
        throttleRate: 0
        enabled: !!(context.enabled ?? true) && topic !== ""
        onNewMessage: msg => d.processMessage(msg)
    }

    //--------------------------------------------------------------------------
    // Timers
    //--------------------------------------------------------------------------

    // Check if topic is available (only when waiting for first message)
    Timer {
        interval: 2000
        running: !!context.controller_manager_namespace && d.messageCount === 0
        repeat: true
        onTriggered: {
            const topic = context.controller_manager_namespace + _statisticsTopicSuffix;
            const topics = Ros2.queryTopics();
            d.topicAvailable = topics.indexOf(topic) !== -1;
        }
    }

    // Debounced UI update timer
    Timer {
        id: updateTimer
        interval: _updateIntervalMs
        repeat: false
        onTriggered: d.updateModel()
    }

    //--------------------------------------------------------------------------
    // Private Implementation
    //--------------------------------------------------------------------------

    QtObject {
        id: d

        // State
        property var controllerManagers: []
        property var elementData: ({})      // Map: label -> { samples: number[] }
        property var elementOrder: []       // Sorted list of labels
        property int messageCount: 0
        property int totalSamples: 0
        property int maxSamples: _defaultMaxSamples
        property bool topicAvailable: false
        property real globalMin: 0
        property real globalMax: 100

        // UI model
        property var elementsModel: ListModel {}

        /**
         * Discovers available controller managers by querying ListControllers services.
         */
        function refresh() {
            const prevControllerManager = context.controller_manager_namespace;
            const services = Ros2.queryServices("controller_manager_msgs/srv/ListControllers");

            let managers = prevControllerManager ? [prevControllerManager] : [];
            for (let i = 0; i < services.length; i++) {
                const parts = services[i].split("/");
                parts.pop(); // Remove service name to get namespace
                const ns = parts.join("/");
                if (ns && managers.indexOf(ns) === -1)
                    managers.push(ns);
            }

            managers.sort();
            d.controllerManagers = managers;

            // Restore selection
            if (prevControllerManager) {
                const index = managers.indexOf(prevControllerManager);
                controllerManagerComboBox.currentIndex = Math.max(0, index);
            }
        }

        /**
         * Processes incoming statistics message and accumulates samples.
         */
        function processMessage(msg) {
            if (!msg)
                return;

            const statistics = msg.statistics;
            if (!statistics || statistics.length === undefined)
                return;

            let hasNewData = false;
            const len = statistics.length;

            for (let i = 0; i < len; i++) {
                // Use .at() accessor for qml6_ros2_plugin arrays
                const stat = statistics.at(i);
                if (!stat)
                    continue;

                const name = stat.name;
                const value = stat.value;

                // Validate fields
                if (name === undefined || name === null)
                    continue;
                if (value === undefined || value === null || !isFinite(value))
                    continue;

                // Filter for execution_time/current_value entries only
                if (String(name).indexOf(_executionTimeFilter) === -1)
                    continue;

                // Parse and build label
                const label = _buildLabel(name);

                // Initialize or get existing data
                if (!elementData[label])
                    elementData[label] = { samples: [] };

                const samples = elementData[label].samples;
                samples.push(value);

                // Enforce sample limit (ring buffer behavior)
                if (samples.length > maxSamples)
                    samples.shift();

                hasNewData = true;
                totalSamples++;
            }

            messageCount++;
            topicAvailable = true;

            if (hasNewData)
                root._triggerUpdate();
        }

        /**
         * Parses a statistics name and builds a display label.
         * Examples:
         *   "joint_state_broadcaster.stats/execution_time/current_value" -> "joint_state_broadcaster"
         *   "arm_interface.stats/read_cycle/execution_time/current_value" -> "arm_interface (read)"
         */
        function _buildLabel(fullName) {
            let element = fullName;
            let cycleKind = null;

            // Extract element name (before ".stats")
            const statsIndex = fullName.indexOf(".stats");
            if (statsIndex !== -1) {
                element = fullName.substring(0, statsIndex);
            } else {
                // Fallback: take first segment
                const slashIndex = fullName.indexOf("/");
                const dotIndex = fullName.indexOf(".");
                if (dotIndex !== -1 && (slashIndex === -1 || dotIndex < slashIndex)) {
                    element = fullName.substring(0, dotIndex);
                } else if (slashIndex !== -1) {
                    element = fullName.substring(0, slashIndex);
                }
            }

            // Detect read/write cycle for hardware interfaces
            if (fullName.indexOf("/read_cycle/") !== -1)
                cycleKind = "read";
            else if (fullName.indexOf("/write_cycle/") !== -1)
                cycleKind = "write";

            return cycleKind ? element + " (" + cycleKind + ")" : element;
        }

        /**
         * Calculates boxplot statistics for an array of samples.
         * Returns null if samples array is empty.
         */
        function _calculateStats(samples) {
            if (!samples || samples.length === 0)
                return null;

            // Sort for percentile calculation
            const sorted = samples.slice().sort((a, b) => a - b);
            const n = sorted.length;

            return {
                min: sorted[0],
                q1: sorted[Math.floor(n * 0.25)],
                median: sorted[Math.floor(n * 0.5)],
                q3: sorted[Math.floor(n * 0.75)],
                max: sorted[n - 1],
                count: n
            };
        }

        /**
         * Updates the UI model with current statistics.
         * Uses in-place updates when possible to avoid flickering.
         */
        function updateModel() {
            const labels = Object.keys(elementData);
            if (labels.length === 0)
                return;

            // Calculate stats for all elements
            const statsMap = {};
            let newMin = Infinity;
            let newMax = -Infinity;

            for (let i = 0; i < labels.length; i++) {
                const label = labels[i];
                const data = elementData[label];
                if (!data || !data.samples)
                    continue;

                const stats = _calculateStats(data.samples);
                if (!stats)
                    continue;

                statsMap[label] = stats;
                newMin = Math.min(newMin, stats.min);
                newMax = Math.max(newMax, stats.max);
            }

            // Update global range with padding
            const statsCount = Object.keys(statsMap).length;
            if (statsCount > 0) {
                const range = newMax - newMin;
                const padding = range * 0.05;
                globalMin = Math.max(0, newMin - padding);
                globalMax = newMax + padding;
            }

            // Re-sort alphabetically only when element count changes
            const currentLabels = Object.keys(statsMap);
            if (currentLabels.length !== elementOrder.length) {
                currentLabels.sort((a, b) => a.localeCompare(b));
                elementOrder = currentLabels;
            }

            // Update model (in-place when possible)
            for (let i = 0; i < elementOrder.length; i++) {
                const label = elementOrder[i];
                const stats = statsMap[label];
                if (!stats)
                    continue;

                const entry = {
                    label: label,
                    min: stats.min,
                    q1: stats.q1,
                    median: stats.median,
                    q3: stats.q3,
                    max: stats.max,
                    count: stats.count
                };

                if (i < elementsModel.count) {
                    const existing = elementsModel.get(i);
                    if (existing.label === label) {
                        elementsModel.set(i, entry);
                    } else {
                        // Order mismatch - rebuild entire model
                        _rebuildModel(statsMap);
                        return;
                    }
                } else {
                    elementsModel.append(entry);
                }
            }
        }

        /**
         * Rebuilds the entire model from scratch.
         */
        function _rebuildModel(statsMap) {
            elementsModel.clear();
            for (let i = 0; i < elementOrder.length; i++) {
                const label = elementOrder[i];
                const stats = statsMap[label];
                if (!stats)
                    continue;

                elementsModel.append({
                    label: label,
                    min: stats.min,
                    q1: stats.q1,
                    median: stats.median,
                    q3: stats.q3,
                    max: stats.max,
                    count: stats.count
                });
            }
        }

        /**
         * Updates max samples and trims existing data if needed.
         */
        function setMaxSamples(newMax) {
            maxSamples = newMax;

            // Trim existing samples if they exceed new limit
            const labels = Object.keys(elementData);
            let trimmedCount = 0;

            for (let i = 0; i < labels.length; i++) {
                const samples = elementData[labels[i]].samples;
                if (samples && samples.length > newMax) {
                    const excess = samples.length - newMax;
                    samples.splice(0, excess);
                    trimmedCount += excess;
                }
            }

            if (trimmedCount > 0) {
                totalSamples = Math.max(0, totalSamples - trimmedCount);
                root._triggerUpdate();
            }
        }

        /**
         * Clears all collected data and resets state.
         */
        function clear() {
            elementData = {};
            elementOrder = [];
            messageCount = 0;
            totalSamples = 0;
            globalMin = 0;
            globalMax = 100;
            elementsModel.clear();
        }
    }
}
