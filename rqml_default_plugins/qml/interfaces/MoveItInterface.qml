import QtQuick
import Ros2
import RQml.Utils

/**
 * Backend interface for MoveIt move_group action client.
 * Handles SRDF/URDF parsing, joint state tracking, and motion execution.
 */
Object {
    id: root

    // ========================================================================
    // Public Properties
    // ========================================================================

    //! The selected MoveGroup action server (e.g., "/move_action" or "/athena/fold_manager_action")
    property string actionServer: ""

    //! Available MoveGroup action servers discovered via Ros2.queryActions()
    property var actionServers: ListModel {}

    //! The currently selected move group name
    property string moveGroupName: ""

    //! List of available move groups from SRDF
    property var moveGroups: ListModel {}

    //! List of joints for the current move group
    property var joints: ListModel {}

    //! List of named poses for the current move group
    property var namedPoses: ListModel {}

    //! Whether the MoveGroup action server is ready
    property bool actionReady: d.moveGroupClient && d.moveGroupClient.ready

    //! Whether a goal is currently being executed
    property bool isGoalActive: false

    //! Whether we have received robot description
    property bool hasRobotDescription: false

    //! Whether we have received SRDF
    property bool hasSrdf: false

    // ========================================================================
    // Public Functions
    // ========================================================================

    /**
     * Reset all joint goals to their current positions.
     */
    function resetGoals() {
        for (let i = 0; i < root.joints.count; ++i) {
            let joint = root.joints.get(i);
            joint.goal = joint.position;
        }
    }

    /**
     * Apply a named pose to the joint goals.
     * @param poseName The name of the pose from SRDF
     */
    function applyNamedPose(poseName) {
        for (let i = 0; i < root.namedPoses.count; ++i) {
            let pose = root.namedPoses.get(i);
            if (pose.name !== poseName)
                continue;

            // Apply joint values from the pose
            for (let j = 0; j < pose.jointValues.count; ++j) {
                let jv = pose.jointValues.get(j);
                let joint = _getJoint(jv.name);
                if (joint) {
                    joint.goal = jv.value;
                }
            }
            return;
        }
    }

    //! Signal emitted when motion fails (for UI to display error)
    signal motionFailed(string errorTitle, string errorDetails)

    //! Signal emitted when a new goal is accepted (to clear previous errors)
    signal goalAccepted()

    /**
     * Send joint goals to the MoveGroup action server.
     * @param planningTime Maximum planning time in seconds
     * @param velocityScale Velocity scaling factor (0-1)
     * @param accelerationScale Acceleration scaling factor (0-1)
     * @param numPlanningAttempts Number of planning attempts (default 1)
     */
    function sendGoals(planningTime, velocityScale, accelerationScale, numPlanningAttempts) {
        if (!d.moveGroupClient || !d.moveGroupClient.ready) {
            Ros2.warn("MoveIt: Action server not connected");
            return;
        }

        let msg = Ros2.createEmptyActionGoal("moveit_msgs/action/MoveGroup");

        // Set the group name
        msg.request.group_name = root.moveGroupName;

        // Configure planning options
        msg.request.allowed_planning_time = planningTime;
        msg.request.max_velocity_scaling_factor = velocityScale;
        msg.request.max_acceleration_scaling_factor = accelerationScale;
        msg.request.num_planning_attempts = numPlanningAttempts || 1;

        // Build joint constraints for goal
        let goalConstraints = {
            name: "goal_constraints",
            joint_constraints: []
        };

        for (let i = 0; i < root.joints.count; i++) {
            let joint = root.joints.get(i);
            if (!joint.active)
                continue;

            goalConstraints.joint_constraints.push({
                joint_name: joint.name,
                position: joint.goal,
                tolerance_above: 0.01,
                tolerance_below: 0.01,
                weight: 1.0
            });
        }

        msg.request.goal_constraints.push(goalConstraints);

        // Planning and execution options
        msg.planning_options.plan_only = false;
        msg.planning_options.look_around = false;
        msg.planning_options.replan = false;

        root.isGoalActive = true;

        d.moveGroupClient.sendGoalAsync(msg, {
            onGoalResponse: function(goalHandle) {
                if (!goalHandle) {
                    Ros2.warn("MoveIt: Goal rejected by action server");
                    root.isGoalActive = false;
                    root.motionFailed("Goal Rejected", "The action server rejected the goal request.");
                    return;
                }
                root.goalAccepted();
            },
            onResult: function(result) {
                root.isGoalActive = false;

                let errorCode = 0;
                try {
                    if (result && result.result && result.result.error_code) {
                        errorCode = result.result.error_code.val;
                    } else {
                        Ros2.warn("MoveIt: Unexpected result structure");
                        return;
                    }
                } catch (e) {
                    Ros2.error("MoveIt: Error parsing result: " + e);
                    return;
                }

                if (errorCode !== 1) { // SUCCESS = 1
                    const errorName = _getErrorString(errorCode);
                    const errorDescription = _getErrorDescription(errorCode);

                    if (errorCode === -4) { // CONTROL_FAILED
                        root.motionFailed("Controller Error", "Motion execution failed. The trajectory controller may not be loaded or active.");
                    } else {
                        root.motionFailed("Motion failed: " + errorName, errorDescription);
                    }
                }
            }
        });
    }

    /**
     * Cancel any active goal.
     */
    function cancelGoals() {
        if (!d.moveGroupClient || !d.moveGroupClient.ready) {
            Ros2.warn("MoveIt: Action server not connected");
            return;
        }
        d.moveGroupClient.cancelAllGoals();
        root.isGoalActive = false;
    }

    /**
     * Refresh by re-querying topics.
     */
    function refresh() {
        // Trigger topic re-discovery
        d.updateTopics();
    }

    // ========================================================================
    // Private Functions
    // ========================================================================

    function _getJoint(jointName) {
        for (let i = 0; i < root.joints.count; i++) {
            let joint = root.joints.get(i);
            if (joint.name === jointName)
                return joint;
        }
        return null;
    }

    function _getErrorString(errorCode) {
        const errorStrings = {
            1: "SUCCESS",
            "-1": "PLANNING_FAILED",
            "-2": "INVALID_MOTION_PLAN",
            "-3": "MOTION_PLAN_INVALIDATED_BY_ENVIRONMENT_CHANGE",
            "-4": "CONTROL_FAILED",
            "-5": "UNABLE_TO_AQUIRE_SENSOR_DATA",
            "-6": "TIMED_OUT",
            "-7": "PREEMPTED",
            "-10": "START_STATE_IN_COLLISION",
            "-11": "START_STATE_VIOLATES_PATH_CONSTRAINTS",
            "-12": "GOAL_IN_COLLISION",
            "-13": "GOAL_VIOLATES_PATH_CONSTRAINTS",
            "-14": "GOAL_CONSTRAINTS_VIOLATED",
            "-15": "INVALID_GROUP_NAME",
            "-16": "INVALID_GOAL_CONSTRAINTS",
            "-17": "INVALID_ROBOT_STATE",
            "-18": "INVALID_LINK_NAME",
            "-19": "INVALID_OBJECT_NAME",
            "-21": "FRAME_TRANSFORM_FAILURE",
            "-22": "COLLISION_CHECKING_UNAVAILABLE",
            "-23": "ROBOT_STATE_STALE",
            "-24": "SENSOR_INFO_STALE",
            "-25": "COMMUNICATION_FAILURE",
            "-26": "START_STATE_INVALID",
            "-27": "GOAL_STATE_INVALID",
            "-28": "UNRECOGNIZED_GOAL_TYPE",
            "-29": "CRASH",
            "-30": "ABORT",
            "-31": "NO_IK_SOLUTION"
        };
        return errorStrings[errorCode.toString()] || "UNKNOWN_ERROR";
    }

    function _getErrorDescription(errorCode) {
        const descriptions = {
            "-1": "The planner could not find a valid motion plan.",
            "-2": "The computed motion plan is invalid.",
            "-3": "The environment changed during planning.",
            "-4": "Trajectory execution failed. Check if the trajectory controller is loaded and active.",
            "-5": "Could not acquire sensor data.",
            "-6": "Planning or execution timed out.",
            "-7": "Motion was preempted.",
            "-10": "The robot's start state is in collision.",
            "-11": "The start state violates path constraints.",
            "-12": "The goal position is in collision.",
            "-13": "The goal violates path constraints.",
            "-14": "Goal constraints were violated.",
            "-15": "Invalid move group name.",
            "-16": "Invalid goal constraints.",
            "-17": "Invalid robot state.",
            "-18": "Invalid link name.",
            "-19": "Invalid object name.",
            "-21": "Frame transform failure.",
            "-22": "Collision checking unavailable.",
            "-23": "Robot state is stale.",
            "-24": "Sensor info is stale.",
            "-25": "Communication failure.",
            "-26": "Start state is invalid.",
            "-27": "Goal state is invalid.",
            "-28": "Unrecognized goal type.",
            "-29": "MoveIt crashed during execution.",
            "-30": "Motion was aborted.",
            "-31": "No inverse kinematics solution found for the goal pose."
        };
        return descriptions[errorCode.toString()] || "An unknown error occurred.";
    }

    // ========================================================================
    // Subscriptions
    // ========================================================================

    Subscription {
        id: jointStateSubscription
        topic: d.jointStateTopic
        messageType: "sensor_msgs/msg/JointState"
        throttleRate: 5

        onNewMessage: msg => {
            for (let i = 0; i < msg.name.length; i++) {
                const name = msg.name.at(i);
                let joint = _getJoint(name);
                if (!joint)
                    continue;

                let position = msg.position.at(i);
                if (joint.type === "continuous") {
                    position = (position + Math.PI) % (2 * Math.PI) - Math.PI;
                }
                position = Math.round(position * 100) / 100 || 0.0;
                joint.position = position;

                if (!joint.initialized) {
                    joint.goal = position;
                    joint.initialized = true;
                }
            }
        }
    }

    Subscription {
        id: urdfSubscription
        topic: d.urdfTopic
        messageType: "std_msgs/msg/String"
        qos: Ros2.QoS().transient_local().reliable()

        onNewMessage: msg => {
            if (!msg.data)
                return;
            parser.parseURDF(msg.data);
        }
    }

    Subscription {
        id: srdfSubscription
        topic: d.srdfTopic
        messageType: "std_msgs/msg/String"
        qos: Ros2.QoS().transient_local().reliable()

        onNewMessage: msg => {
            if (!msg.data)
                return;
            parser.parseSRDF(msg.data);
        }
    }

    // ========================================================================
    // Topic Discovery Timer
    // ========================================================================

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: d.updateTopics()
    }

    // ========================================================================
    // Private Data
    // ========================================================================

    QtObject {
        id: d

        property string jointStateTopic: ""
        property string urdfTopic: ""
        property string srdfTopic: ""

        //! All joint data from URDF (not filtered by move group)
        property var allJoints: ({})

        //! All move group data from SRDF
        property var allMoveGroups: ({})

        //! All named poses from SRDF
        property var allNamedPoses: ({})

        //! List of move group names (since Object.keys doesn't work in QML)
        property var moveGroupNames: []

        //! Map of pose names per group (since Object.keys doesn't work in QML)
        property var poseNamesPerGroup: ({})

        //! Kinematic chain: maps child_link -> { joint_name, joint_type, parent_link }
        property var kinematicChain: ({})

        property var moveGroupClient: root.actionServer
            ? Ros2.createActionClient(root.actionServer, "moveit_msgs/action/MoveGroup")
            : null

        //! Namespace derived from the selected action server path
        property string namespace: {
            if (!root.actionServer)
                return "";
            const lastSlash = root.actionServer.lastIndexOf("/");
            if (lastSlash <= 0)
                return "";
            return root.actionServer.substring(0, lastSlash);
        }

        function updateTopics() {
            // Discover MoveGroup action servers
            const allActions = Ros2.queryActions();
            let moveGroupActions = [];
            for (let i = 0; i < allActions.length; i++) {
                const types = Ros2.getActionTypes(allActions[i]);
                for (let j = 0; j < types.length; j++) {
                    if (types[j] === "moveit_msgs/action/MoveGroup") {
                        moveGroupActions.push(allActions[i]);
                        break;
                    }
                }
            }
            moveGroupActions.sort();

            // Update action servers model if changed
            let changed = moveGroupActions.length !== root.actionServers.count;
            if (!changed) {
                for (let i = 0; i < moveGroupActions.length; i++) {
                    if (root.actionServers.get(i).name !== moveGroupActions[i]) {
                        changed = true;
                        break;
                    }
                }
            }
            if (changed) {
                root.actionServers.clear();
                for (let i = 0; i < moveGroupActions.length; i++) {
                    root.actionServers.append({ name: moveGroupActions[i] });
                }
            }

            if (!root.actionServer)
                return;

            // Find topics using namespace derived from the action server path
            const ns = namespace;

            // Find joint_states topic
            const jointStateTopics = Ros2.queryTopics("sensor_msgs/msg/JointState");
            let bestJointState = _findBestTopic(jointStateTopics, "/joint_states", ns);
            if (bestJointState !== jointStateTopic) {
                jointStateTopic = bestJointState;
            }

            // Find robot_description topic
            const stringTopics = Ros2.queryTopics("std_msgs/msg/String");
            let bestUrdf = _findBestTopic(stringTopics, "/robot_description", ns);
            if (bestUrdf && bestUrdf !== urdfTopic) {
                root.joints.clear();
                root.hasRobotDescription = false;
                urdfTopic = bestUrdf;
            }

            // Find robot_description_semantic (SRDF) topic
            let bestSrdf = _findBestTopic(stringTopics, "/robot_description_semantic", ns);
            if (bestSrdf && bestSrdf !== srdfTopic) {
                root.moveGroups.clear();
                root.namedPoses.clear();
                root.hasSrdf = false;
                srdfTopic = bestSrdf;
            }
        }

        /**
         * Find the best matching topic for a given suffix.
         * When namespace is set, only matches topics within that namespace (no fallback).
         * When namespace is empty, prefers the shortest matching topic.
         * @param topics Array of available topic names
         * @param suffix The topic suffix to match (e.g., "/joint_states")
         * @param ns The namespace to search within (e.g., "/athena")
         */
        function _findBestTopic(topics, suffix, ns) {
            let bestMatch = "";

            for (let i = 0; i < topics.length; i++) {
                const topic = topics[i];
                if (!topic.endsWith(suffix))
                    continue;

                if (ns) {
                    // With namespace: only accept topics in that namespace
                    if (topic === ns + suffix || topic.startsWith(ns + "/")) {
                        // Prefer exact namespace match
                        if (topic === ns + suffix) {
                            return topic;
                        }
                        if (bestMatch === "" || topic.length < bestMatch.length) {
                            bestMatch = topic;
                        }
                    }
                } else {
                    // No namespace: accept any matching topic, prefer shorter ones
                    if (bestMatch === "" || topic.length < bestMatch.length) {
                        bestMatch = topic;
                    }
                }
            }

            return bestMatch;
        }

        /**
         * Get all joints for a group, resolving chains and subgroups recursively.
         * @param groupName The name of the move group
         * @param visited Array of already visited group names (for cycle detection)
         * @returns Array of joint names
         */
        function _getJointsForGroup(groupName, visited) {
            if (!visited) visited = [];
            if (visited.indexOf(groupName) !== -1) {
                return []; // Circular reference
            }
            visited.push(groupName);

            const group = allMoveGroups[groupName];
            if (!group) {
                return [];
            }

            let joints = group.joints ? group.joints.slice() : [];

            // Traverse kinematic chains
            const chains = group.chains || [];
            for (let i = 0; i < chains.length; i++) {
                const chainJoints = parser.getJointsInChain(chains[i].base_link, chains[i].tip_link);
                for (let k = 0; k < chainJoints.length; k++) {
                    if (joints.indexOf(chainJoints[k]) === -1) {
                        joints.push(chainJoints[k]);
                    }
                }
            }

            // Resolve subgroups recursively
            const subgroups = group.subgroups || [];
            for (let i = 0; i < subgroups.length; i++) {
                const subgroupJoints = _getJointsForGroup(subgroups[i], visited);
                for (let k = 0; k < subgroupJoints.length; k++) {
                    if (joints.indexOf(subgroupJoints[k]) === -1) {
                        joints.push(subgroupJoints[k]);
                    }
                }
            }

            return joints;
        }

        function addJoint(joint) {
            allJoints[joint.name] = joint;
            _rebuildJointsModel();
        }

        /**
         * Rebuild the joints ListModel for the currently selected move group.
         */
        function _rebuildJointsModel() {
            if (!root.moveGroupName || !allMoveGroups[root.moveGroupName]) {
                return;
            }

            // Get all joints for the current group (resolves chains and subgroups)
            const groupJoints = _getJointsForGroup(root.moveGroupName);

            root.joints.clear();

            for (let i = 0; i < groupJoints.length; i++) {
                const jointName = groupJoints[i];
                const sourceData = allJoints[jointName];

                let jointData;
                if (!sourceData) {
                    // Joint not in URDF yet, create placeholder
                    jointData = {
                        name: jointName,
                        type: "unknown",
                        limits: { upper: Math.PI, lower: -Math.PI },
                        position: 0.0,
                        goal: 0.0,
                        initialized: false,
                        active: true
                    };
                } else {
                    jointData = {
                        name: sourceData.name,
                        type: sourceData.type,
                        limits: sourceData.limits,
                        position: sourceData.position || 0.0,
                        goal: sourceData.goal || sourceData.position || 0.0,
                        initialized: sourceData.initialized || false,
                        active: true
                    };
                }

                // Insert in sorted order by joint name
                let insertIdx = 0;
                for (; insertIdx < root.joints.count; insertIdx++) {
                    if (root.joints.get(insertIdx).name > jointData.name)
                        break;
                }
                root.joints.insert(insertIdx, jointData);
            }
        }

        function _rebuildNamedPosesModel() {
            root.namedPoses.clear();

            if (!root.moveGroupName || !allNamedPoses[root.moveGroupName])
                return;

            const poses = allNamedPoses[root.moveGroupName];
            const poseNames = poseNamesPerGroup[root.moveGroupName] || [];

            for (let i = 0; i < poseNames.length; i++) {
                const poseName = poseNames[i];
                const poseData = poses[poseName];

                let jointValuesModel = Qt.createQmlObject('import QtQuick; ListModel {}', root);
                for (let j = 0; j < poseData.length; j++) {
                    jointValuesModel.append(poseData[j]);
                }

                root.namedPoses.append({
                    name: poseName,
                    jointValues: jointValuesModel
                });
            }
        }
    }

    onActionServerChanged: {
        // Clear all state when action server changes
        root.joints.clear();
        root.moveGroups.clear();
        root.namedPoses.clear();
        root.hasRobotDescription = false;
        root.hasSrdf = false;
        d.allJoints = {};
        d.allMoveGroups = {};
        d.allNamedPoses = {};
        d.moveGroupNames = [];
        d.poseNamesPerGroup = {};
        d.kinematicChain = {};
        d.urdfTopic = "";
        d.srdfTopic = "";
        d.jointStateTopic = "";
        // Trigger immediate topic discovery for new action server
        d.updateTopics();
    }

    onMoveGroupNameChanged: {
        d._rebuildJointsModel();
        d._rebuildNamedPosesModel();
    }

    // ========================================================================
    // XML Parser
    // ========================================================================

    QtObject {
        id: parser

        /**
         * Parse URDF XML to extract joint definitions and build the kinematic chain.
         */
        function parseURDF(urdfString) {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "data:text/xml," + encodeURIComponent(urdfString));

            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return;
                if (xhr.status !== 200 && xhr.status !== 0) {
                    Ros2.error("MoveIt: Error loading URDF XML data. Status: " + xhr.status);
                    return;
                }

                let xmlDoc = xhr.responseXML.documentElement;
                if (!xmlDoc) {
                    Ros2.error("MoveIt: Failed to parse URDF.");
                    return;
                }

                let jointElements = _findElementsByTagName(xmlDoc, "joint");

                d.allJoints = {};
                d.kinematicChain = {};

                for (let i = 0; i < jointElements.length; i++) {
                    let jointElement = jointElements[i];
                    const type = _getAttributeValue(jointElement, "type");
                    const name = _getAttributeValue(jointElement, "name");

                    // Get parent and child links for kinematic chain
                    const parentLink = _getChildByTagName(jointElement, "parent");
                    const childLink = _getChildByTagName(jointElement, "child");
                    const parentLinkName = parentLink ? _getAttributeValue(parentLink, "link") : "";
                    const childLinkName = childLink ? _getAttributeValue(childLink, "link") : "";

                    // Build kinematic chain (including fixed joints for traversal)
                    if (childLinkName && parentLinkName) {
                        d.kinematicChain[childLinkName] = {
                            joint_name: name,
                            joint_type: type,
                            parent_link: parentLinkName
                        };
                    }

                    // Skip fixed joints for the joint list
                    if (!type || type === "fixed")
                        continue;

                    const limits = _getChildByTagName(jointElement, "limit");
                    let limitUpper = Math.PI;
                    let limitLower = -Math.PI;

                    if (limits) {
                        limitUpper = parseFloat(_getAttributeValue(limits, "upper"));
                        if (isNaN(limitUpper))
                            limitUpper = Math.PI;
                        limitLower = parseFloat(_getAttributeValue(limits, "lower"));
                        if (isNaN(limitLower))
                            limitLower = -Math.PI;
                    }

                    d.addJoint({
                        name: name,
                        type: type,
                        limits: { upper: limitUpper, lower: limitLower },
                        position: 0.0,
                        goal: 0.0,
                        initialized: false,
                        active: false
                    });
                }

                root.hasRobotDescription = true;

                // If SRDF was already parsed, rebuild joints model now that we have the chain
                if (root.hasSrdf) {
                    d._rebuildJointsModel();
                }
            };
            xhr.send();
        }

        /**
         * Get all movable joints in the kinematic chain between base_link and tip_link.
         * Traverses from tip to base, collecting non-fixed joints.
         */
        function getJointsInChain(baseLink, tipLink) {
            let joints = [];
            let currentLink = tipLink;
            let iterations = 0;
            const maxIterations = 100; // Safety limit

            while (currentLink && currentLink !== baseLink && iterations < maxIterations) {
                const chainEntry = d.kinematicChain[currentLink];
                if (!chainEntry) {
                    break;
                }

                // Only add non-fixed joints
                if (chainEntry.joint_type && chainEntry.joint_type !== "fixed") {
                    joints.unshift(chainEntry.joint_name); // Add to front to maintain order
                }

                currentLink = chainEntry.parent_link;
                iterations++;
            }

            return joints;
        }

        /**
         * Parse SRDF XML to extract move groups and named poses.
         */
        function parseSRDF(srdfString) {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "data:text/xml," + encodeURIComponent(srdfString));

            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return;
                if (xhr.status !== 200 && xhr.status !== 0) {
                    Ros2.error("MoveIt: Error loading SRDF XML data. Status: " + xhr.status);
                    return;
                }

                let xmlDoc = xhr.responseXML.documentElement;
                if (!xmlDoc) {
                    Ros2.error("MoveIt: Failed to parse SRDF.");
                    return;
                }

                // Parse move groups - only direct children of <robot>, not nested <group> refs
                d.allMoveGroups = {};
                d.moveGroupNames = [];
                let groupElements = _getChildrenByTagName(xmlDoc, "group");

                for (let i = 0; i < groupElements.length; i++) {
                    let groupElement = groupElements[i];
                    const groupName = _getAttributeValue(groupElement, "name");
                    if (!groupName)
                        continue;

                    let joints = [];
                    let chains = [];
                    let subgroups = [];

                    // Get direct joint references
                    let jointRefs = _getChildrenByTagName(groupElement, "joint");
                    for (let j = 0; j < jointRefs.length; j++) {
                        const jointName = _getAttributeValue(jointRefs[j], "name");
                        if (jointName && joints.indexOf(jointName) === -1) {
                            joints.push(jointName);
                        }
                    }

                    // Store chain references for later traversal (after URDF is parsed)
                    let chainRefs = _getChildrenByTagName(groupElement, "chain");
                    for (let j = 0; j < chainRefs.length; j++) {
                        const baseLink = _getAttributeValue(chainRefs[j], "base_link");
                        const tipLink = _getAttributeValue(chainRefs[j], "tip_link");
                        if (baseLink && tipLink) {
                            chains.push({ base_link: baseLink, tip_link: tipLink });
                        }
                    }

                    // Get subgroup references
                    let subgroupRefs = _getChildrenByTagName(groupElement, "group");
                    for (let j = 0; j < subgroupRefs.length; j++) {
                        const subgroupName = _getAttributeValue(subgroupRefs[j], "name");
                        if (subgroupName && subgroups.indexOf(subgroupName) === -1) {
                            subgroups.push(subgroupName);
                        }
                    }

                    d.allMoveGroups[groupName] = {
                        name: groupName,
                        joints: joints,
                        chains: chains,
                        subgroups: subgroups
                    };

                    if (d.moveGroupNames.indexOf(groupName) === -1) {
                        d.moveGroupNames.push(groupName);
                    }
                }

                // Update move groups model
                d.moveGroupNames.sort();
                root.moveGroups.clear();
                for (let i = 0; i < d.moveGroupNames.length; i++) {
                    root.moveGroups.append({ name: d.moveGroupNames[i] });
                }

                // Parse named poses (group_state elements)
                d.allNamedPoses = {};
                d.poseNamesPerGroup = {};
                let stateElements = _findElementsByTagName(xmlDoc, "group_state");

                for (let i = 0; i < stateElements.length; i++) {
                    let stateElement = stateElements[i];
                    const stateName = _getAttributeValue(stateElement, "name");
                    const groupName = _getAttributeValue(stateElement, "group");

                    if (!stateName || !groupName)
                        continue;

                    if (!d.allNamedPoses[groupName]) {
                        d.allNamedPoses[groupName] = {};
                        d.poseNamesPerGroup[groupName] = [];
                    }

                    let jointValues = [];
                    let jointRefs = _getChildrenByTagName(stateElement, "joint");
                    for (let j = 0; j < jointRefs.length; j++) {
                        const jointName = _getAttributeValue(jointRefs[j], "name");
                        const jointValue = parseFloat(_getAttributeValue(jointRefs[j], "value"));
                        if (jointName && !isNaN(jointValue)) {
                            jointValues.push({ name: jointName, value: jointValue });
                        }
                    }

                    d.allNamedPoses[groupName][stateName] = jointValues;
                    if (d.poseNamesPerGroup[groupName].indexOf(stateName) === -1) {
                        d.poseNamesPerGroup[groupName].push(stateName);
                    }
                }

                // Sort pose names per group
                for (let i = 0; i < d.moveGroupNames.length; i++) {
                    const gn = d.moveGroupNames[i];
                    if (d.poseNamesPerGroup[gn]) {
                        d.poseNamesPerGroup[gn].sort();
                    }
                }

                root.hasSrdf = true;

                // Rebuild models for current group
                d._rebuildJointsModel();
                d._rebuildNamedPosesModel();
            };
            xhr.send();
        }

        function _findElementsByTagName(element, tagName) {
            let result = [];
            if (element.nodeName === tagName) {
                result.push(element);
            }
            const children = element.childNodes || [];
            for (let i = 0; i < children.length; i++) {
                result = result.concat(_findElementsByTagName(children[i], tagName));
            }
            return result;
        }

        function _getChildByTagName(element, tagName) {
            const children = element.childNodes || [];
            for (let i = 0; i < children.length; i++) {
                if (children[i].nodeName === tagName) {
                    return children[i];
                }
            }
            return null;
        }

        function _getChildrenByTagName(element, tagName) {
            let result = [];
            const children = element.childNodes || [];
            for (let i = 0; i < children.length; i++) {
                if (children[i].nodeName === tagName) {
                    result.push(children[i]);
                }
            }
            return result;
        }

        function _getAttributeValue(element, attributeName) {
            if (element && element.attributes) {
                for (let i = 0; i < element.attributes.length; i++) {
                    const attr = element.attributes[i];
                    if (attr.nodeName === attributeName) {
                        return attr.nodeValue;
                    }
                }
            }
            return "";
        }
    }
}
