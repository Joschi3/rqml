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
import QtTest
import Ros2

Item {
    id: root
    width: 1024; height: 768

    property var context: contextObj
    QtObject {
        id: contextObj
        property bool enabled: true
        property string namespace: ""
        property string viewMode: "list"  // Use list view by default so delegates are realized
    }

    Utils { id: helpers }

    Loader {
        id: pluginLoader
        anchors.fill: parent
        function reload() { source = ""; source = "../qml/TfTreeViewer.qml"; }
    }

    property var plugin: pluginLoader.item

    function find(name) { return helpers.findChild(root, name); }

    Publisher {
        id: tfPublisher
        topic: "/tf"
        type: "tf2_msgs/msg/TFMessage"
    }

    Publisher {
        id: tfStaticPublisher
        topic: "/tf_static"
        type: "tf2_msgs/msg/TFMessage"
    }

    TestCase {
        name: "TfTreeViewerTest"
        when: windowShown

        // -----------------------------------------------------------------
        // Helpers
        // -----------------------------------------------------------------

        function makeTransform(parentFrame, childFrame, tx, ty, tz) {
            var t = Ros2.createEmptyMessage("geometry_msgs/msg/TransformStamped");
            t.header.frame_id = parentFrame;
            t.header.stamp = Ros2.now();
            t.child_frame_id = childFrame;
            t.transform.translation.x = tx;
            t.transform.translation.y = ty;
            t.transform.translation.z = tz;
            t.transform.rotation.x = 0.0;
            t.transform.rotation.y = 0.0;
            t.transform.rotation.z = 0.0;
            t.transform.rotation.w = 1.0;
            return t;
        }

        function publishTf(transformsList) {
            var msg = Ros2.createEmptyMessage("tf2_msgs/msg/TFMessage");
            msg.transforms = transformsList;
            return tfPublisher.publish(msg);
        }

        function publishTfStatic(transformsList) {
            var msg = Ros2.createEmptyMessage("tf2_msgs/msg/TFMessage");
            msg.transforms = transformsList;
            return tfStaticPublisher.publish(msg);
        }

        function modelHasFrame(listView, frameId) {
            for (var i = 0; i < listView.model.count; ++i) {
                if (listView.model.get(i).frameId === frameId)
                    return true;
            }
            return false;
        }

        // -----------------------------------------------------------------
        // Setup / Teardown
        // -----------------------------------------------------------------

        function init() {
            Ros2.reset();
            RQml.resetClipboard();
            // Register both /tf and /tf_static so subscriptions can find them
            Ros2.registerTopic("/tf", "tf2_msgs/msg/TFMessage");
            Ros2.registerTopic("/tf_static", "tf2_msgs/msg/TFMessage");

            contextObj.enabled = true;
            contextObj.namespace = "";
            contextObj.viewMode = "list";

            pluginLoader.reload();
            tryVerify(function() { return pluginLoader.status === Loader.Ready; }, 2000, "Loader should be ready");
            wait(50);
        }

        // -----------------------------------------------------------------
        // Tests
        // -----------------------------------------------------------------

        function test_plugin_loads() {
            verify(plugin !== null, "TfTreeViewer plugin should load");
        }

        function test_empty_state_message() {
            var emptyLabel = find("tfEmptyStateLabel");
            verify(emptyLabel !== null, "Empty state label should exist");
            verify(emptyLabel.visible, "Empty state should be visible with no data");
            verify(emptyLabel.text.indexOf("Waiting for TF data") !== -1,
                "Empty state should mention waiting for data");
        }

        function test_frame_display() {
            var listView = find("tfFrameListView");
            verify(listView !== null, "Frame list view should exist");

            publishTf([makeTransform("world", "base_link", 1.0, 2.0, 3.0)]);

            // Should add 2 frames: world (auto-created parent) and base_link
            tryCompare(listView.model, "count", 2, 2000, "List should contain world and base_link");
            verify(modelHasFrame(listView, "world"), "Model should contain 'world' frame");
            verify(modelHasFrame(listView, "base_link"), "Model should contain 'base_link' frame");

            var countLabel = find("tfFrameCountLabel");
            verify(countLabel !== null, "Frame count label should exist");
            compare(countLabel.text, "Frames: 2", "Frame count label should show 2");
        }

        function test_static_and_dynamic_frames() {
            var listView = find("tfFrameListView");

            publishTf([makeTransform("world", "base_link", 0, 0, 0)]);
            publishTfStatic([makeTransform("base_link", "lidar", 0.1, 0, 0.5)]);

            tryCompare(listView.model, "count", 3, 2000,
                "Should have world, base_link, and lidar");

            // Locate base_link and lidar entries to verify isStatic
            var baseLink = null, lidar = null;
            for (var i = 0; i < listView.model.count; ++i) {
                var item = listView.model.get(i);
                if (item.frameId === "base_link") baseLink = item;
                else if (item.frameId === "lidar") lidar = item;
            }
            verify(baseLink !== null, "base_link should be in model");
            verify(lidar !== null, "lidar should be in model");
            compare(baseLink.isStatic, false, "base_link should be dynamic");
            compare(lidar.isStatic, true, "lidar should be static");
        }

        function test_enable_disable() {
            var listView = find("tfFrameListView");
            var enableToggle = find("tfEnableToggle");
            verify(enableToggle !== null, "Enable toggle should exist");
            verify(enableToggle.checked, "Should be enabled initially");

            publishTf([makeTransform("world", "base_link", 0, 0, 0)]);
            tryCompare(listView.model, "count", 2, 2000);

            // Disable
            mouseClick(enableToggle);
            tryCompare(enableToggle, "checked", false, 1000, "Toggle should be off");
            compare(contextObj.enabled, false, "Context enabled should update");

            // Publish more frames - they should be ignored
            publishTf([makeTransform("base_link", "ignored_child", 0, 0, 0)]);
            wait(200);
            compare(listView.model.count, 2, "No new frames added when disabled");

            // Re-enable
            mouseClick(enableToggle);
            tryCompare(enableToggle, "checked", true, 1000, "Toggle should be on");
            compare(contextObj.enabled, true, "Context enabled should update");

            publishTf([makeTransform("base_link", "new_child", 0, 0, 0)]);
            tryCompare(listView.model, "count", 3, 2000, "Frame added after re-enabling");
        }

        function test_clear_button() {
            var listView = find("tfFrameListView");
            publishTf([makeTransform("world", "base_link", 0, 0, 0)]);
            publishTf([makeTransform("base_link", "lidar", 0, 0, 0)]);
            tryCompare(listView.model, "count", 3, 2000);

            var clearButton = find("tfClearButton");
            verify(clearButton !== null, "Clear button should exist");

            mouseClick(clearButton);
            tryCompare(listView.model, "count", 0, 2000, "Model should be empty after clear");

            var countLabel = find("tfFrameCountLabel");
            compare(countLabel.text, "Frames: 0", "Frame count label should reset to 0");

            var emptyLabel = find("tfEmptyStateLabel");
            verify(emptyLabel.visible, "Empty state should be visible again");

            publishTf([makeTransform("world", "base_link", 0, 0, 0)]);
            publishTf([makeTransform("base_link", "lidar", 0, 0, 0)]);
            tryCompare(listView.model, "count", 3, 2000, "After publishing again, they should reappear.");
        }

        function test_view_mode_switching() {
            var stack = find("tfViewStack");
            verify(stack !== null, "View stack should exist");

            // Initially set to list in init()
            compare(stack.currentIndex, 1, "List view should be active initially");

            var graphButton = find("tfGraphModeButton");
            var listButton = find("tfListModeButton");
            verify(graphButton !== null, "Graph mode button should exist");
            verify(listButton !== null, "List mode button should exist");

            // Switch to graph
            mouseClick(graphButton);
            tryCompare(stack, "currentIndex", 0, 1000, "Stack should switch to graph view");
            compare(contextObj.viewMode, "graph", "Context viewMode should be 'graph'");

            // Switch back to list
            mouseClick(listButton);
            tryCompare(stack, "currentIndex", 1, 1000, "Stack should switch back to list");
            compare(contextObj.viewMode, "list", "Context viewMode should be 'list'");
        }

        function test_namespace_discovery() {
            // Register additional TF topics in different namespaces
            Ros2.registerTopic("/robot1/tf", "tf2_msgs/msg/TFMessage");
            Ros2.registerTopic("/robot1/tf_static", "tf2_msgs/msg/TFMessage");
            Ros2.registerTopic("/robot2/tf", "tf2_msgs/msg/TFMessage");
            Ros2.registerTopic("/robot3/tf_static", "tf2_msgs/msg/TFMessage");

            // Reload so the plugin discovers them at construction time
            pluginLoader.reload();
            tryVerify(function() { return pluginLoader.status === Loader.Ready; }, 2000);

            var nsCombo = find("tfNamespaceComboBox");
            verify(nsCombo !== null, "Namespace ComboBox should exist");

            tryVerify(function() {
                var m = nsCombo.model || [];
                return Array.prototype.indexOf.call(m, "(global)") !== -1
                    && Array.prototype.indexOf.call(m, "/robot1") !== -1
                    && Array.prototype.indexOf.call(m, "/robot2") !== -1
                    && Array.prototype.indexOf.call(m, "/robot3") !== -1;
            }, 2000, "Namespace dropdown should list (global), /robot1, /robot2, /robot3");
        }

        function test_refresh_button() {
            var nsCombo = find("tfNamespaceComboBox");
            verify(nsCombo !== null);

            // Initially only the global namespace is registered
            tryVerify(function() {
                var m = nsCombo.model || [];
                return Array.prototype.indexOf.call(m, "(global)") !== -1;
            }, 2000, "Global namespace should be present initially");

            var beforeModel = nsCombo.model || [];
            verify(Array.prototype.indexOf.call(beforeModel, "/robot_late") === -1,
                "/robot_late should not be present before refresh");

            // Register a new TF topic AFTER load
            Ros2.registerTopic("/robot_late/tf", "tf2_msgs/msg/TFMessage");

            var refreshButton = find("tfRefreshButton");
            verify(refreshButton !== null, "Refresh button should exist");
            mouseClick(refreshButton);

            tryVerify(function() {
                var m = nsCombo.model || [];
                return Array.prototype.indexOf.call(m, "/robot_late") !== -1;
            }, 2000, "Refresh should pick up newly-registered namespace");
        }

        function test_collapse_expand() {
            var listView = find("tfFrameListView");

            // Build chain: world -> base_link -> sensor
            publishTf([
                makeTransform("world", "base_link", 0, 0, 0),
                makeTransform("base_link", "sensor", 0, 0, 1.0)
            ]);
            tryCompare(listView.model, "count", 3, 2000, "Should display 3 frames");

            // Force delegate realization for base_link
            listView.positionViewAtIndex(0, ListView.Beginning);

            // Find base_link's index in the model
            var baseLinkIndex = -1;
            for (var i = 0; i < listView.model.count; ++i) {
                if (listView.model.get(i).frameId === "base_link") {
                    baseLinkIndex = i;
                    break;
                }
            }
            verify(baseLinkIndex !== -1, "base_link should be in model");

            var item = listView.model.get(baseLinkIndex);
            compare(item.hasChildren, true, "base_link should have children");
            compare(item.isCollapsed, false, "base_link should not be collapsed initially");

            // Realize the delegate and find its branch indicator MouseArea
            var delegate = null;
            tryVerify(function() {
                delegate = listView.itemAtIndex(baseLinkIndex);
                return delegate !== null;
            }, 2000, "Delegate for base_link should be realized");

            var branchArea = helpers.findChild(delegate, "tfBranchIndicatorArea");
            verify(branchArea !== null, "Branch indicator MouseArea should exist");
            mouseClick(branchArea);

            tryCompare(listView.model, "count", 2, 2000,
                "Sensor should be hidden after collapsing base_link");
            verify(!modelHasFrame(listView, "sensor"),
                "sensor should not appear when base_link is collapsed");
            verify(listView.model.get(baseLinkIndex).isCollapsed,
                "base_link should be marked as collapsed");

            // Expand again - ListView recycles delegates across rebuild,
            // so re-fetch the delegate and branch area fresh.
            wait(50);
            listView.positionViewAtIndex(baseLinkIndex, ListView.Beginning);
            var delegate2 = null;
            var branchArea2 = null;
            tryVerify(function() {
                delegate2 = listView.itemAtIndex(baseLinkIndex);
                if (delegate2 === null) return false;
                branchArea2 = helpers.findChild(delegate2, "tfBranchIndicatorArea");
                return branchArea2 !== null;
            }, 2000, "Branch indicator should be realized again after collapse");
            mouseClick(branchArea2);

            tryCompare(listView.model, "count", 3, 2000,
                "Sensor should re-appear after expanding base_link");
            verify(modelHasFrame(listView, "sensor"),
                "sensor should be back in model");
        }

        function test_context_menu_copy() {
            var listView = find("tfFrameListView");
            publishTf([makeTransform("world", "base_link", 1.5, 2.5, 3.5)]);
            tryCompare(listView.model, "count", 2, 2000);

            // Find base_link index
            var baseLinkIndex = -1;
            for (var i = 0; i < listView.model.count; ++i) {
                if (listView.model.get(i).frameId === "base_link") {
                    baseLinkIndex = i;
                    break;
                }
            }
            verify(baseLinkIndex !== -1);

            listView.positionViewAtIndex(baseLinkIndex, ListView.Beginning);
            var delegate = null;
            tryVerify(function() {
                delegate = listView.itemAtIndex(baseLinkIndex);
                return delegate !== null;
            }, 2000, "Delegate for base_link should be realized");

            // Copy Frame ID
            RQml.resetClipboard();
            var copyFrameAction = helpers.findChild(delegate, "tfCopyFrameIdAction");
            verify(copyFrameAction, "Copy Frame ID action should be found");
            copyFrameAction.triggered();
            tryCompare(RQml, "clipboard", "base_link", 1000, "Clipboard should contain frame ID");

            // Copy Parent ID
            RQml.resetClipboard();
            var copyParentAction = helpers.findChild(delegate, "tfCopyParentIdAction");
            verify(copyParentAction, "Copy Parent ID action should be found");
            copyParentAction.triggered();
            tryCompare(RQml, "clipboard", "world", 1000, "Clipboard should contain parent ID");

            // Copy Transform - verify the action exists and writes something
            // containing translation and rotation info (exact format is internal).
            RQml.resetClipboard();
            var copyTransformAction = helpers.findChild(delegate, "tfCopyTransformAction");
            verify(copyTransformAction, "Copy Transform action should be found");
            copyTransformAction.triggered();
            tryVerify(function() {
                return RQml.clipboard.length > 0
                    && RQml.clipboard.indexOf("translation") !== -1
                    && RQml.clipboard.indexOf("rotation") !== -1;
            }, 1000, "Clipboard should contain translation and rotation");
        }
    }
}
