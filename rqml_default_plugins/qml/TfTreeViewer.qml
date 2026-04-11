import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ros2
import RQml.Elements
import RQml.Fonts
import QtQuick.Controls.Material
import "interfaces"
import "elements"

/**
 * TF Tree Viewer plugin for visualizing the ROS 2 TF frame hierarchy.
 * Supports both a list view (tree) and an interactive graph visualization.
 */
Rectangle {
    id: root
    anchors.fill: parent
    property var kddockwidgets_min_size: Qt.size(400, 300)
    color: palette.base

    Component.onCompleted: {
        if (context.enabled === undefined)
            context.enabled = true;
        if (!context.namespace)
            context.namespace = "";
        if (context.viewMode === undefined)
            context.viewMode = "graph";  // Default to graph view
        d.refresh();
    }

    // ========================================================================
    // Constants
    // ========================================================================

    //! Indentation per tree depth level in pixels
    readonly property int indentPerLevel: 16

    //! Age threshold (in seconds) after which a dynamic transform is considered stale
    readonly property real staleThreshold: 5.0

    //! Semantic status colors shared with sub-components
    readonly property color freshColor: Material.color(Material.Green)
    readonly property color staticColor: Material.color(Material.Blue)
    readonly property color staleColor: Material.color(Material.Red)
    readonly property color warningColor: Material.color(Material.Orange)

    // ========================================================================
    // Private Data
    // ========================================================================

    QtObject {
        id: d

        property var namespaces: []
        property var tfInterface: TfTreeInterface {
            namespace: context.namespace || ""
            enabled: context.enabled ?? true
        }

        /**
         * Discover available TF namespaces by querying /tf topics.
         */
        function refresh() {
            const prevNamespace = context.namespace;

            // Query all tf topics
            const tfTopics = Ros2.queryTopics("tf2_msgs/msg/TFMessage");
            let namespaceSet = {};

            for (let i = 0; i < tfTopics.length; ++i) {
                const topic = tfTopics[i];
                // Extract namespace from topic path
                // /tf -> "" (global)
                // /robot1/tf -> "/robot1"
                // /ns1/ns2/tf -> "/ns1/ns2"
                if (topic.endsWith("/tf") || topic.endsWith("/tf_static")) {
                    let ns = "";
                    if (topic !== "/tf" && topic !== "/tf_static") {
                        const parts = topic.split("/");
                        parts.pop(); // Remove "tf" or "tf_static"
                        ns = parts.join("/");
                    }
                    namespaceSet[ns] = true;
                }
            }

            // Convert to sorted array
            let nsList = [];
            for (let ns in namespaceSet) {
                nsList.push(ns);
            }
            nsList.sort();

            // Add "(global)" label for empty namespace
            let displayList = [];
            for (let i = 0; i < nsList.length; ++i) {
                displayList.push(nsList[i] === "" ? "(global)" : nsList[i]);
            }

            d.namespaces = displayList;

            // Restore previous selection
            if (prevNamespace !== undefined) {
                const displayNs = prevNamespace === "" ? "(global)" : prevNamespace;
                const index = displayList.indexOf(displayNs);
                if (index !== -1) {
                    namespaceComboBox.currentIndex = index;
                }
            }
        }

        /**
         * Convert display namespace back to actual namespace.
         */
        function displayToNamespace(display) {
            return display === "(global)" ? "" : display;
        }

        //! Get color based on frame age (stale detection)
        function getAgeColor(age, isStatic) {
            if (isStatic)
                return palette.text;
            if (age < 0)
                return palette.mid;
            if (age < 1)
                return root.freshColor;
            if (age < root.staleThreshold)
                return root.warningColor;
            return root.staleColor;
        }
    }

    // ========================================================================
    // UI Layout
    // ========================================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // --------------------------------------------------------------------
        // Header Row: Namespace Selection
        // --------------------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "Namespace:"
            }

            ComboBox {
                id: namespaceComboBox
                objectName: "tfNamespaceComboBox"
                Layout.fillWidth: true
                model: d.namespaces

                onCurrentTextChanged: {
                    if (!currentText)
                        return;
                    const ns = d.displayToNamespace(currentText);
                    if (ns === context.namespace)
                        return;
                    context.namespace = ns;
                }
            }

            RefreshButton {
                objectName: "tfRefreshButton"
                onClicked: {
                    animate = true;
                    d.refresh();
                    animate = false;
                }
            }
        }

        // --------------------------------------------------------------------
        // Toolbar Row: Controls
        // --------------------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                objectName: "tfFrameCountLabel"
                text: "Frames: " + d.tfInterface.frameCount
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            // View mode toggle
            ButtonGroup {
                id: viewModeGroup
            }

            Button {
                objectName: "tfGraphModeButton"
                text: "Graph"
                checkable: true
                checked: context.viewMode === "graph"
                ButtonGroup.group: viewModeGroup
                onClicked: context.viewMode = "graph"
            }

            Button {
                objectName: "tfListModeButton"
                text: "List"
                checkable: true
                checked: context.viewMode === "list"
                ButtonGroup.group: viewModeGroup
                onClicked: context.viewMode = "list"
            }

            Item { width: 8 }

            IconToggleButton {
                objectName: "tfEnableToggle"
                iconOn: IconFont.iconPause
                iconOff: IconFont.iconPlay
                tooltipTextOn: "Click to pause"
                tooltipTextOff: "Click to resume"
                checked: context.enabled ?? true
                onToggled: {
                    context.enabled = checked;
                }
            }

            IconButton {
                objectName: "tfClearButton"
                text: IconFont.iconTrash
                tooltipText: "Clear all data"
                onClicked: d.tfInterface.clear()
            }
        }

        // --------------------------------------------------------------------
        // Main Content: Graph or List View
        // --------------------------------------------------------------------

        StackLayout {
            objectName: "tfViewStack"
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: context.viewMode === "graph" ? 0 : 1

            // Graph View
            TfGraphView {
                id: graphView
                tfInterface: d.tfInterface
                staleThreshold: root.staleThreshold
                freshColor: root.freshColor
                staticColor: root.staticColor
                staleColor: root.staleColor
            }

            // List View
            ListView {
                id: frameListView
                objectName: "tfFrameListView"
                clip: true
                model: d.tfInterface.frames
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                // Improve scrolling by caching more delegates
                cacheBuffer: 400

                ScrollBar.vertical: ScrollBar {
                    policy: frameListView.contentHeight > frameListView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }

                header: Rectangle {
                    width: frameListView.width
                    height: 32
                    color: palette.mid
                    z: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 20
                        spacing: 0

                        Label {
                            Layout.fillWidth: true
                            height: parent.height
                            text: "Frame"
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        Label {
                            Layout.preferredWidth: 60
                            height: parent.height
                            text: "Freq"
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                        }

                        Label {
                            Layout.preferredWidth: 60
                            height: parent.height
                            text: "Age"
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                        }

                        Label {
                            Layout.preferredWidth: 200
                            Layout.rightMargin: 4
                            height: parent.height
                            text: "Transform"
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
                headerPositioning: ListView.OverlayHeader

                delegate: Rectangle {
                    id: delegateRoot
                    required property var model
                    required property int index
                    width: frameListView.width
                    height: 36
                    color: index % 2 === 0 ? palette.base : palette.alternateBase

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 20
                        spacing: 0

                        // Frame column (fill available width)
                        Item {
                            Layout.fillWidth: true
                            height: parent.height

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: model.depth * root.indentPerLevel
                                spacing: 4

                                // Tree branch indicator (clickable for collapse/expand)
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    // ▶ for collapsed (pointing right), ▼ for expanded (pointing down), • for leaf
                                    text: model.hasChildren ? (model.isCollapsed ? "\u25B6" : "\u25BC") : "\u2022"
                                    font.pixelSize: model.hasChildren ? 10 : 8
                                    color: model.hasChildren ? palette.text : palette.mid
                                    opacity: model.hasChildren ? 0.8 : 0.6
                                    width: 16
                                    horizontalAlignment: Text.AlignHCenter

                                    MouseArea {
                                        objectName: "tfBranchIndicatorArea"
                                        anchors.fill: parent
                                        anchors.margins: -4  // Larger click area
                                        enabled: model.hasChildren
                                        cursorShape: model.hasChildren ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            d.tfInterface.toggleCollapse(model.frameId);
                                        }
                                    }
                                }

                                // Static indicator
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: model.isStatic ? root.staticColor : root.freshColor
                                    visible: model.updateCount > 0

                                    ToolTip.visible: staticMouseArea.containsMouse
                                    ToolTip.text: model.isStatic ? "Static transform" : "Dynamic transform"

                                    MouseArea {
                                        id: staticMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }

                                // Frame name
                                TruncatedLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 16 - 12 - model.depth * root.indentPerLevel
                                    text: model.frameId
                                }
                            }
                        }

                        // Frequency column (fixed width, right aligned)
                        Label {
                            Layout.preferredWidth: 60
                            height: parent.height
                            text: d.tfInterface.formatFrequency(model.frequency, model.isStatic)
                            color: model.isStatic ? palette.mid : palette.text
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: 12
                        }

                        // Age column (fixed width, right aligned)
                        Label {
                            Layout.preferredWidth: 60
                            height: parent.height
                            text: d.tfInterface.formatAge(model.age)
                            color: d.getAgeColor(model.age, model.isStatic)
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                        }

                        // Transform column (fixed width, right aligned)
                        Label {
                            Layout.preferredWidth: 200
                            Layout.rightMargin: 4
                            height: parent.height
                            text: model.updateCount > 0
                                ? "t: [" + model.translationX.toFixed(3) + ", " +
                                           model.translationY.toFixed(3) + ", " +
                                           model.translationZ.toFixed(3) + "]"
                                : "waiting..."
                            color: model.updateCount > 0 ? palette.text : palette.mid
                            elide: Text.ElideLeft
                            font.family: "monospace"
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // Context menu for copying frame info
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                contextMenu.popup();
                            }
                        }

                        Menu {
                            id: contextMenu
                            objectName: "tfContextMenu"

                            MenuItem {
                                objectName: "tfCopyFrameIdAction"
                                text: "Copy Frame ID"
                                onTriggered: RQml.copyTextToClipboard(model.frameId)
                            }

                            MenuItem {
                                objectName: "tfCopyParentIdAction"
                                text: "Copy Parent ID"
                                enabled: model.parentId !== ""
                                onTriggered: RQml.copyTextToClipboard(model.parentId)
                            }

                            MenuSeparator {}

                            MenuItem {
                                objectName: "tfCopyTransformAction"
                                text: "Copy Transform"
                                enabled: model.updateCount > 0
                                onTriggered: {
                                    const tf = "translation: [" + model.translationX + ", " +
                                               model.translationY + ", " + model.translationZ + "]\n" +
                                               "rotation: [" + model.rotationX + ", " +
                                               model.rotationY + ", " + model.rotationZ + ", " +
                                               model.rotationW + "]";
                                    RQml.copyTextToClipboard(tf);
                                }
                            }
                        }
                    }
                }

                // Empty state
                Label {
                    objectName: "tfEmptyStateLabel"
                    anchors.centerIn: parent
                    visible: d.tfInterface.frameCount === 0
                    text: context.enabled
                        ? "Waiting for TF data...\nSubscribed to: " + (context.namespace || "") + "/tf"
                        : "Paused"
                    horizontalAlignment: Text.AlignHCenter
                    color: palette.mid
                }
            }
        }

        // --------------------------------------------------------------------
        // Status Bar
        // --------------------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "Root frames: " + d.tfInterface.rootFrames.length
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "Topics: " + (context.namespace || "") + "/tf, " + (context.namespace || "") + "/tf_static"
            }
        }
    }
}
