import QtQuick

QtObject {
    id: root

    property var _frameIds: []

    // Internal frame state, keyed by frameId
    property var _frameStates: ({})
    property Subscription _tfStaticSub: Subscription {
        messageType: "tf2_msgs/msg/TFMessage"
        topic: root._getTfStaticTopic()

        onNewMessage: function (msg) {
            root._processTransforms(msg.transforms, true);
        }
    }
    property Subscription _tfSub: Subscription {
        messageType: "tf2_msgs/msg/TFMessage"
        topic: root._getTfTopic()

        onNewMessage: function (msg) {
            root._processTransforms(msg.transforms, false);
        }
    }
    property string ns: ""

    function _getTfStaticTopic() {
        if (!root.ns || root.ns === "/")
            return "/tf_static";
        return root.ns + "/tf_static";
    }
    function _getTfTopic() {
        if (!root.ns || root.ns === "/")
            return "/tf";
        return root.ns + "/tf";
    }
    function _processTransforms(transforms, isStatic) {
        const states = root._frameStates;
        for (let i = 0; i < transforms.length; ++i) {
            const tf = transforms.at(i);
            const childFrame = tf.child_frame_id;
            const parentFrame = tf.header.frame_id;
            if (!childFrame || childFrame === "")
                continue;
            if (!states[childFrame]) {
                root._frameIds.push(childFrame);
                states[childFrame] = {
                    "frameId": childFrame,
                    "parentId": parentFrame,
                    "isStatic": isStatic,
                    "children": [],
                    "lastUpdate": Date.now(),
                    "frequency": isStatic ? 0 : 10,
                    "tx": tf.transform.translation.x,
                    "ty": tf.transform.translation.y,
                    "tz": tf.transform.translation.z,
                    "rx": tf.transform.rotation.x,
                    "ry": tf.transform.rotation.y,
                    "rz": tf.transform.rotation.z,
                    "rw": tf.transform.rotation.w
                };
            } else {
                const frame = states[childFrame];
                // Check for reparenting
                if (frame.parentId !== parentFrame) {
                    if (states[frame.parentId]) {
                        const oldParent = states[frame.parentId];
                        const idx = oldParent.children.indexOf(childFrame);
                        if (idx !== -1)
                            oldParent.children.splice(idx, 1);
                    }
                }
                frame.parentId = parentFrame;
                frame.isStatic = isStatic;
                frame.lastUpdate = Date.now();
                frame.tx = tf.transform.translation.x;
                frame.ty = tf.transform.translation.y;
                frame.tz = tf.transform.translation.z;
                frame.rx = tf.transform.rotation.x;
                frame.ry = tf.transform.rotation.y;
                frame.rz = tf.transform.rotation.z;
                frame.rw = tf.transform.rotation.w;
            }

            // Ensure parent frame exists
            if (parentFrame && parentFrame !== "" && !states[parentFrame]) {
                root._frameIds.push(parentFrame);
                states[parentFrame] = {
                    "frameId": parentFrame,
                    "parentId": "",
                    "isStatic": false,
                    "children": [],
                    "lastUpdate": 0,
                    "frequency": 0,
                    "tx": 0,
                    "ty": 0,
                    "tz": 0,
                    "rx": 0,
                    "ry": 0,
                    "rz": 0,
                    "rw": 1
                };
            }

            // Add child to parent's children list
            if (parentFrame && parentFrame !== "" && states[parentFrame]) {
                const parent = states[parentFrame];
                if (parent.children.indexOf(childFrame) === -1) {
                    parent.children.push(childFrame);
                }
            }
        }

        // Trigger reactivity by reassigning
        root._frameStates = states;
    }
    function clear() {
        root._frameStates = {};
        root._frameIds = [];
    }
    function getAllFrames() {
        const result = [];
        for (let i = 0; i < root._frameIds.length; ++i) {
            const f = getFrame(root._frameIds[i]);
            if (f)
                result.push(f);
        }
        return result;
    }
    function getFrame(frameId) {
        const state = root._frameStates[frameId];
        if (!state)
            return null;
        return {
            "frameId": state.frameId,
            "parentId": state.parentId,
            "authority": getFrameAuthority(frameId),
            "translation": {
                "x": state.tx,
                "y": state.ty,
                "z": state.tz
            },
            "rotation": {
                "x": state.rx,
                "y": state.ry,
                "z": state.rz,
                "w": state.rw
            },
            "isStatic": state.isStatic,
            "children": state.children.slice(),
            "frequency": state.frequency
        };
    }
    function getFrameAuthority(frame) {
        return frame + "_authority";
    }
    function getTransformAge(frameId) {
        const state = root._frameStates[frameId];
        if (!state || state.lastUpdate <= 0)
            return -1.0;
        return (Date.now() - state.lastUpdate) / 1000.0;
    }
}
