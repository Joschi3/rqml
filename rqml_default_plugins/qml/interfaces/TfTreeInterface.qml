import QtQuick
import Ros2
import RQml.Utils

/**
 * Backend interface for TF tree visualization.
 * Subscribes to /tf and /tf_static topics and builds a hierarchical frame tree.
 */
Object {
    id: root

    //! The namespace to use for TF topics (e.g., "/robot1" -> "/robot1/tf")
    property string namespace: ""

    //! Whether data collection is enabled
    property bool enabled: true

    //! ListModel containing all frames with their properties
    property var frames: ListModel {}

    //! The root frame IDs (frames with no parent)
    property var rootFrames: []

    //! Total number of frames in the tree
    property int frameCount: 0

    //! Whether any TF data has been received
    readonly property bool hasData: frameCount > 0

    //! Signal emitted when the frame tree structure changes
    signal treeChanged()

    // ========================================================================
    // Formatting Helpers
    // ========================================================================

    //! Format an age value (seconds) for display
    function formatAge(age) {
        if (age < 0)
            return "N/A";
        if (age < 1)
            return (age * 1000).toFixed(0) + " ms";
        if (age < 60)
            return age.toFixed(1) + " s";
        return (age / 60).toFixed(1) + " min";
    }

    //! Format a frequency value for display
    function formatFrequency(freq, isStatic) {
        if (isStatic)
            return "static";
        if (freq <= 0)
            return "-";
        if (freq < 1)
            return freq.toFixed(2) + " Hz";
        if (freq < 10)
            return freq.toFixed(1) + " Hz";
        return freq.toFixed(0) + " Hz";
    }

    // ========================================================================
    // Public Functions
    // ========================================================================

    /**
     * Clear all collected TF data and reset the tree.
     * Also triggers re-subscription to receive transient_local messages again.
     */
    function clear() {
        d.resetData();
        // Force re-subscription to receive transient_local static transforms
        d.triggerResubscribe();
    }

    /**
     * Get frame data by frame ID.
     */
    function getFrame(frameId) {
        return d.frameData[frameId] || null;
    }

    /**
     * Get children of a frame.
     */
    function getChildren(frameId) {
        const frame = d.frameData[frameId];
        return frame ? frame.children : [];
    }

    /**
     * Toggle the collapsed state of a frame in the list view.
     */
    function toggleCollapse(frameId) {
        if (d.collapsedFrames[frameId]) {
            delete d.collapsedFrames[frameId];
        } else {
            d.collapsedFrames[frameId] = true;
        }
        d.rebuildModel();
    }

    // ========================================================================
    // Namespace Change Handling
    // ========================================================================

    onNamespaceChanged: {
        // Reset data without triggering re-subscription (topic bindings handle that)
        d.resetData();
    }

    // ========================================================================
    // Private Implementation
    // ========================================================================

    QtObject {
        id: d

        property var frameData: ({})
        property var frameIds: []
        property var staticFrames: ({})
        property var collapsedFrames: ({})  // Tracks which frames are collapsed in list view
        property var frameToModelIndex: ({})  // Maps frameId to model index for in-place updates

        //! Flag to temporarily disable static subscription for re-subscription
        property bool resubscribing: false

        // Frequency calculation constants
        readonly property int frequencyWindowMs: 3000      // Sliding window duration for frequency calculation
        readonly property int frequencyMinSamplesMs: 500   // Minimum elapsed time before reporting frequency

        /**
         * Reset all internal data structures.
         */
        function resetData() {
            d.frameData = {};
            d.frameIds = [];
            d.staticFrames = {};
            d.frameToModelIndex = {};
            root.frames.clear();
            root.rootFrames = [];
            root.frameCount = 0;
            root.treeChanged();
        }

        /**
         * Force re-subscription by briefly disabling and re-enabling the subscription.
         * This is needed to receive transient_local messages again after clearing data.
         */
        function triggerResubscribe() {
            d.resubscribing = true;
            resubscribeTimer.restart();
        }

        function getTfTopic() {
            if (!root.namespace || root.namespace === "/")
                return "/tf";
            return root.namespace + "/tf";
        }

        function getTfStaticTopic() {
            if (!root.namespace || root.namespace === "/")
                return "/tf_static";
            return root.namespace + "/tf_static";
        }

        function processTransforms(transforms, isStatic) {
            const now = Date.now();
            let structureChanged = false;

            for (let i = 0; i < transforms.length; ++i) {
                const tf = transforms.at(i);
                const childFrame = tf.child_frame_id;
                const parentFrame = tf.header.frame_id;

                if (!childFrame || childFrame === "")
                    continue;

                if (isStatic) {
                    d.staticFrames[childFrame] = true;
                }

                const isNewFrame = !d.frameData[childFrame];

                if (isNewFrame) {
                    structureChanged = true;
                    d.frameIds.push(childFrame);
                    d.frameData[childFrame] = {
                        frameId: childFrame,
                        parentId: parentFrame,
                        isStatic: isStatic,
                        children: [],
                        lastUpdate: now,
                        frequency: 0,
                        updateCount: 1,
                        // Sliding window for frequency calculation (3 second window)
                        frequencyWindowStart: now,
                        frequencyWindowCount: 1,
                        translation: {
                            x: tf.transform.translation.x,
                            y: tf.transform.translation.y,
                            z: tf.transform.translation.z
                        },
                        rotation: {
                            x: tf.transform.rotation.x,
                            y: tf.transform.rotation.y,
                            z: tf.transform.rotation.z,
                            w: tf.transform.rotation.w
                        }
                    };
                } else {
                    const frame = d.frameData[childFrame];
                    const prevParent = frame.parentId;

                    if (prevParent !== parentFrame) {
                        structureChanged = true;
                        if (d.frameData[prevParent]) {
                            const oldParent = d.frameData[prevParent];
                            const idx = oldParent.children.indexOf(childFrame);
                            if (idx !== -1) {
                                oldParent.children.splice(idx, 1);
                            }
                        }
                    }

                    // Calculate frequency using sliding window
                    frame.frequencyWindowCount++;
                    const windowElapsed = now - frame.frequencyWindowStart;

                    if (windowElapsed >= d.frequencyWindowMs) {
                        // Calculate frequency from window and reset
                        frame.frequency = (frame.frequencyWindowCount - 1) / (windowElapsed / 1000.0);
                        frame.frequencyWindowStart = now;
                        frame.frequencyWindowCount = 1;
                    } else if (windowElapsed > d.frequencyMinSamplesMs && frame.frequencyWindowCount > 2) {
                        // Update frequency estimate after minimum elapsed time and 2 samples
                        frame.frequency = (frame.frequencyWindowCount - 1) / (windowElapsed / 1000.0);
                    }

                    frame.parentId = parentFrame;
                    frame.isStatic = d.staticFrames[childFrame] || false;
                    frame.lastUpdate = now;
                    frame.updateCount++;
                    frame.translation = {
                        x: tf.transform.translation.x,
                        y: tf.transform.translation.y,
                        z: tf.transform.translation.z
                    };
                    frame.rotation = {
                        x: tf.transform.rotation.x,
                        y: tf.transform.rotation.y,
                        z: tf.transform.rotation.z,
                        w: tf.transform.rotation.w
                    };

                    // Update model in place if structure hasn't changed
                    if (!structureChanged) {
                        d.updateModelItem(childFrame);
                    }
                }

                if (parentFrame && parentFrame !== "" && !d.frameData[parentFrame]) {
                    structureChanged = true;
                    d.frameIds.push(parentFrame);
                    d.frameData[parentFrame] = {
                        frameId: parentFrame,
                        parentId: "",
                        isStatic: false,
                        children: [],
                        lastUpdate: 0,
                        frequency: 0,
                        updateCount: 0,
                        frequencyWindowStart: 0,
                        frequencyWindowCount: 0,
                        translation: { x: 0, y: 0, z: 0 },
                        rotation: { x: 0, y: 0, z: 0, w: 1 }
                    };
                }

                if (parentFrame && parentFrame !== "" && d.frameData[parentFrame]) {
                    const parent = d.frameData[parentFrame];
                    if (parent.children.indexOf(childFrame) === -1) {
                        structureChanged = true;
                        parent.children.push(childFrame);
                    }
                }
            }

            // Only rebuild model when structure changes (new frames, reparenting)
            if (structureChanged) {
                d.rebuildModel();
            }
        }

        function updateModelItem(frameId) {
            const idx = d.frameToModelIndex[frameId];
            if (idx === undefined)
                return;

            const frame = d.frameData[frameId];
            if (!frame)
                return;

            const now = Date.now();
            const age = frame.lastUpdate > 0 ? (now - frame.lastUpdate) / 1000.0 : -1;

            root.frames.setProperty(idx, "lastUpdate", frame.lastUpdate);
            root.frames.setProperty(idx, "age", age);
            root.frames.setProperty(idx, "frequency", frame.frequency);
            root.frames.setProperty(idx, "updateCount", frame.updateCount);
            root.frames.setProperty(idx, "isStatic", frame.isStatic);
            root.frames.setProperty(idx, "translationX", frame.translation.x);
            root.frames.setProperty(idx, "translationY", frame.translation.y);
            root.frames.setProperty(idx, "translationZ", frame.translation.z);
            root.frames.setProperty(idx, "rotationX", frame.rotation.x);
            root.frames.setProperty(idx, "rotationY", frame.rotation.y);
            root.frames.setProperty(idx, "rotationZ", frame.rotation.z);
            root.frames.setProperty(idx, "rotationW", frame.rotation.w);
        }

        function rebuildModel() {
            let roots = [];
            for (let i = 0; i < d.frameIds.length; ++i) {
                const frameId = d.frameIds[i];
                const frame = d.frameData[frameId];
                if (!frame.parentId || frame.parentId === "" || !d.frameData[frame.parentId]) {
                    roots.push(frameId);
                }
            }
            roots.sort();
            root.rootFrames = roots;

            root.frames.clear();
            d.frameToModelIndex = {};
            for (let i = 0; i < roots.length; ++i) {
                d.addFrameToModel(roots[i], 0);
            }

            root.frameCount = d.frameIds.length;
            root.treeChanged();
        }

        function addFrameToModel(frameId, depth) {
            const frame = d.frameData[frameId];
            if (!frame)
                return;

            const now = Date.now();
            const age = frame.lastUpdate > 0 ? (now - frame.lastUpdate) / 1000.0 : -1;
            const isCollapsed = d.collapsedFrames[frameId] === true;

            d.frameToModelIndex[frameId] = root.frames.count;
            root.frames.append({
                frameId: frame.frameId,
                parentId: frame.parentId,
                depth: depth,
                isStatic: frame.isStatic,
                hasChildren: frame.children.length > 0,
                isCollapsed: isCollapsed,
                lastUpdate: frame.lastUpdate,
                age: age,
                frequency: frame.frequency,
                updateCount: frame.updateCount,
                translationX: frame.translation.x,
                translationY: frame.translation.y,
                translationZ: frame.translation.z,
                rotationX: frame.rotation.x,
                rotationY: frame.rotation.y,
                rotationZ: frame.rotation.z,
                rotationW: frame.rotation.w
            });

            // Skip children if this frame is collapsed
            if (isCollapsed)
                return;

            const children = frame.children.slice().sort();
            for (let i = 0; i < children.length; ++i) {
                d.addFrameToModel(children[i], depth + 1);
            }
        }
    }

    // ========================================================================
    // TF Subscriptions
    // ========================================================================

    Subscription {
        id: tfSubscription
        topic: root.enabled ? d.getTfTopic() : ""
        messageType: "tf2_msgs/msg/TFMessage"
        onNewMessage: function(msg) {
            if (!root.enabled)
                return;
            d.processTransforms(msg.transforms, false);
        }
    }

    Subscription {
        id: tfStaticSubscription
        topic: root.enabled && !d.resubscribing ? d.getTfStaticTopic() : ""
        messageType: "tf2_msgs/msg/TFMessage"
        qos: Ros2.QoS().reliable().transient_local().keep_last(500)
        // Disable throttling to receive all latched messages from multiple publishers
        throttleRate: 0
        onNewMessage: function(msg) {
            if (!root.enabled)
                return;
            d.processTransforms(msg.transforms, true);
        }
    }

    // Timer to complete the re-subscription cycle.
    // A short delay forces the subscription to disconnect and reconnect,
    // which triggers re-delivery of transient_local messages.
    Timer {
        id: resubscribeTimer
        interval: 50
        repeat: false
        onTriggered: d.resubscribing = false
    }

    // ========================================================================
    // Periodic Model Update (for age values)
    // ========================================================================

    Timer {
        interval: 1000
        running: root.enabled && root.hasData
        repeat: true
        onTriggered: {
            const now = Date.now();
            for (let i = 0; i < root.frames.count; ++i) {
                const item = root.frames.get(i);
                if (item.lastUpdate > 0) {
                    root.frames.setProperty(i, "age", (now - item.lastUpdate) / 1000.0);
                }
            }
        }
    }
}
