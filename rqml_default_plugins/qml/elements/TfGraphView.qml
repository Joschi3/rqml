import QtQuick
import QtQuick.Controls
import Ros2

/**
 * Interactive graph visualization for TF frames.
 * Displays frames as nodes connected by edges representing parent-child relationships.
 * Supports panning, zooming, and automatic hierarchical layout.
 */
Item {
    id: root

    //! The TfTreeInterface providing frame data
    property var tfInterface: null

    //! Node styling
    property color nodeColor: "#3498db"
    property color staticNodeColor: "#9b59b6"
    property color nodeTextColor: "#ffffff"
    property color edgeColor: "#7f8c8d"
    property color staleNodeColor: "#e74c3c"
    property int nodeWidth: 220
    property int nodeHeight: 32
    property int levelSpacing: 90
    property int nodeSpacing: 25

    // ========================================================================
    // Public Functions
    // ========================================================================

    /**
     * Reset the view to fit all nodes.
     */
    function fitToView() {
        if (d.nodePositions.length === 0)
            return;

        // Find bounding box
        let minX = Infinity, minY = Infinity;
        let maxX = -Infinity, maxY = -Infinity;

        for (let i = 0; i < d.nodePositions.length; ++i) {
            const pos = d.nodePositions[i];
            minX = Math.min(minX, pos.x);
            minY = Math.min(minY, pos.y);
            maxX = Math.max(maxX, pos.x + nodeWidth);
            maxY = Math.max(maxY, pos.y + nodeHeight);
        }

        // Add padding
        const padding = 50;
        minX -= padding;
        minY -= padding;
        maxX += padding;
        maxY += padding;

        // Calculate scale to fit
        const scaleX = root.width / (maxX - minX);
        const scaleY = root.height / (maxY - minY);
        const newScale = Math.min(scaleX, scaleY, 1.5);

        // Center the view
        d.scale = Math.max(0.1, Math.min(2.0, newScale));
        d.offsetX = -minX * d.scale + (root.width - (maxX - minX) * d.scale) / 2;
        d.offsetY = -minY * d.scale + (root.height - (maxY - minY) * d.scale) / 2;

        canvas.requestPaint();
    }

    /**
     * Reset zoom to 100%.
     */
    function resetZoom() {
        d.scale = 1.0;
        canvas.requestPaint();
    }

    // ========================================================================
    // Private Implementation
    // ========================================================================

    QtObject {
        id: d

        property real scale: 1.0
        property real offsetX: 50
        property real offsetY: 50
        property var nodePositions: []  // Array of {frameId, x, y, level, isStatic, age}
        property var edges: []          // Array of {from, to, fromX, fromY, toX, toY}
        property string hoveredNode: ""
        property string selectedNode: ""

        /**
         * Calculate hierarchical layout for all frames.
         */
        function calculateLayout() {
            if (!root.tfInterface) {
                d.nodePositions = [];
                d.edges = [];
                return;
            }

            if (root.tfInterface.frameCount === 0) {
                d.nodePositions = [];
                d.edges = [];
                return;
            }

            const positions = [];
            const edgeList = [];
            const levelNodes = {};  // level -> [frameIds]
            const frameLevel = {};  // frameId -> level
            const framePos = {};    // frameId -> {x, y}

            // Calculate levels using BFS from root frames
            const rootFrames = root.tfInterface.rootFrames;
            const queue = [];

            for (let i = 0; i < rootFrames.length; ++i) {
                queue.push({ frameId: rootFrames[i], level: 0 });
                frameLevel[rootFrames[i]] = 0;
            }

            while (queue.length > 0) {
                const current = queue.shift();
                const frameId = current.frameId;
                const level = current.level;

                if (!levelNodes[level])
                    levelNodes[level] = [];
                levelNodes[level].push(frameId);

                const children = root.tfInterface.getChildren(frameId);
                for (let i = 0; i < children.length; ++i) {
                    const child = children[i];
                    if (frameLevel[child] === undefined) {
                        frameLevel[child] = level + 1;
                        queue.push({ frameId: child, level: level + 1 });
                    }
                }
            }

            // Position nodes at each level
            let maxLevel = 0;
            for (let level in levelNodes) {
                maxLevel = Math.max(maxLevel, parseInt(level));
            }

            for (let level = 0; level <= maxLevel; ++level) {
                const nodes = levelNodes[level] || [];
                const totalWidth = nodes.length * nodeWidth + (nodes.length - 1) * nodeSpacing;
                let startX = -totalWidth / 2 + nodeWidth / 2;

                for (let i = 0; i < nodes.length; ++i) {
                    const frameId = nodes[i];
                    const x = startX + i * (nodeWidth + nodeSpacing);
                    const y = level * (nodeHeight + levelSpacing);

                    framePos[frameId] = { x: x, y: y };

                    const frame = root.tfInterface.getFrame(frameId);
                    positions.push({
                        frameId: frameId,
                        x: x,
                        y: y,
                        level: level,
                        isStatic: frame ? frame.isStatic : false,
                        age: frame ? (Date.now() - frame.lastUpdate) / 1000.0 : -1,
                        updateCount: frame ? frame.updateCount : 0
                    });
                }
            }

            // Create edges
            for (let i = 0; i < positions.length; ++i) {
                const node = positions[i];
                const frame = root.tfInterface.getFrame(node.frameId);
                if (frame && frame.parentId && framePos[frame.parentId]) {
                    const parentPos = framePos[frame.parentId];
                    edgeList.push({
                        from: frame.parentId,
                        to: node.frameId,
                        fromX: parentPos.x + nodeWidth / 2,
                        fromY: parentPos.y + nodeHeight,
                        toX: node.x + nodeWidth / 2,
                        toY: node.y
                    });
                }
            }

            d.nodePositions = positions;
            d.edges = edgeList;
        }

        /**
         * Get node color based on state.
         */
        function getNodeColor(node) {
            if (node.updateCount === 0)
                return "#95a5a6";  // Gray for nodes without data
            if (!node.isStatic && node.age > 5)
                return staleNodeColor;
            if (node.isStatic)
                return staticNodeColor;
            return nodeColor;
        }

        /**
         * Transform screen coordinates to graph coordinates.
         */
        function screenToGraph(screenX, screenY) {
            return {
                x: (screenX - d.offsetX) / d.scale,
                y: (screenY - d.offsetY) / d.scale
            };
        }

        /**
         * Find node at graph coordinates.
         */
        function findNodeAt(graphX, graphY) {
            for (let i = d.nodePositions.length - 1; i >= 0; --i) {
                const node = d.nodePositions[i];
                if (graphX >= node.x && graphX <= node.x + nodeWidth &&
                    graphY >= node.y && graphY <= node.y + nodeHeight) {
                    return node.frameId;
                }
            }
            return "";
        }
    }

    // ========================================================================
    // Layout Update
    // ========================================================================

    Connections {
        target: root.tfInterface
        function onTreeChanged() {
            const prevCount = d.nodePositions.length;
            d.calculateLayout();
            canvas.requestPaint();
            // Auto-fit when frame count changes (new frames added)
            if (d.nodePositions.length > prevCount) {
                root.fitToView();
            }
        }
        function onFrameCountChanged() {
            d.calculateLayout();
            canvas.requestPaint();
        }
    }

    onTfInterfaceChanged: {
        d.calculateLayout();
        canvas.requestPaint();
        if (d.nodePositions.length > 0) {
            root.fitToView();
        }
    }

    Component.onCompleted: {
        if (tfInterface) {
            d.calculateLayout();
            canvas.requestPaint();
            if (d.nodePositions.length > 0) {
                root.fitToView();
            }
        }
    }

    Timer {
        interval: 1000
        running: root.tfInterface && root.tfInterface.hasData
        repeat: true
        onTriggered: {
            d.calculateLayout();
            canvas.requestPaint();
        }
    }

    // ========================================================================
    // Canvas Rendering
    // ========================================================================

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = palette.base;
            ctx.fillRect(0, 0, width, height);

            if (d.nodePositions.length === 0) {
                // Draw empty state message
                ctx.fillStyle = palette.mid;
                ctx.font = "14px sans-serif";
                ctx.textAlign = "center";
                ctx.fillText("No TF data", width / 2, height / 2);
                return;
            }

            ctx.save();
            ctx.translate(d.offsetX, d.offsetY);
            ctx.scale(d.scale, d.scale);

            // Draw edges
            ctx.strokeStyle = edgeColor;
            ctx.lineWidth = 2 / d.scale;
            for (let i = 0; i < d.edges.length; ++i) {
                const edge = d.edges[i];
                ctx.beginPath();
                ctx.moveTo(edge.fromX, edge.fromY);

                // Bezier curve for smoother edges
                const midY = (edge.fromY + edge.toY) / 2;
                ctx.bezierCurveTo(
                    edge.fromX, midY,
                    edge.toX, midY,
                    edge.toX, edge.toY
                );
                ctx.stroke();

                // Draw arrow
                const arrowSize = 8 / d.scale;
                const angle = Math.atan2(edge.toY - midY, edge.toX - edge.toX);
                ctx.beginPath();
                ctx.moveTo(edge.toX, edge.toY);
                ctx.lineTo(edge.toX - arrowSize, edge.toY - arrowSize);
                ctx.lineTo(edge.toX + arrowSize, edge.toY - arrowSize);
                ctx.closePath();
                ctx.fillStyle = edgeColor;
                ctx.fill();
            }

            // Draw nodes
            for (let i = 0; i < d.nodePositions.length; ++i) {
                const node = d.nodePositions[i];
                const isHovered = node.frameId === d.hoveredNode;
                const isSelected = node.frameId === d.selectedNode;

                // Node background - manual rounded rectangle (roundRect not available in QML Canvas)
                const r = 5;  // corner radius
                const x = node.x;
                const y = node.y;
                const w = nodeWidth;
                const h = nodeHeight;

                ctx.fillStyle = d.getNodeColor(node);
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.lineTo(x + w - r, y);
                ctx.arcTo(x + w, y, x + w, y + r, r);
                ctx.lineTo(x + w, y + h - r);
                ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                ctx.lineTo(x + r, y + h);
                ctx.arcTo(x, y + h, x, y + h - r, r);
                ctx.lineTo(x, y + r);
                ctx.arcTo(x, y, x + r, y, r);
                ctx.closePath();
                ctx.fill();

                // Highlight border
                if (isHovered || isSelected) {
                    ctx.strokeStyle = isSelected ? "#f1c40f" : "#ffffff";
                    ctx.lineWidth = 3 / d.scale;
                    ctx.stroke();
                }

                // Node text
                ctx.fillStyle = nodeTextColor;
                ctx.font = "bold " + (12 / d.scale) + "px sans-serif";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";

                // Truncate text if needed
                let text = node.frameId;
                const maxWidth = nodeWidth - 20;
                while (ctx.measureText(text).width > maxWidth && text.length > 3) {
                    text = text.slice(0, -4) + "...";
                }
                ctx.fillText(text, node.x + nodeWidth / 2, node.y + nodeHeight / 2);
            }

            ctx.restore();
        }
    }

    // ========================================================================
    // Mouse Interaction
    // ========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real lastX: 0
        property real lastY: 0
        property bool isPanning: false

        onPressed: mouse => {
            lastX = mouse.x;
            lastY = mouse.y;

            const graphPos = d.screenToGraph(mouse.x, mouse.y);
            const nodeId = d.findNodeAt(graphPos.x, graphPos.y);

            if (mouse.button === Qt.LeftButton) {
                if (nodeId === "") {
                    isPanning = true;
                } else {
                    d.selectedNode = nodeId;
                    canvas.requestPaint();
                }
            } else if (mouse.button === Qt.RightButton && nodeId !== "") {
                d.selectedNode = nodeId;
                canvas.requestPaint();
                nodeContextMenu.popup();
            }
        }

        onReleased: {
            isPanning = false;
        }

        onPositionChanged: mouse => {
            // Update hover state
            const graphPos = d.screenToGraph(mouse.x, mouse.y);
            const nodeId = d.findNodeAt(graphPos.x, graphPos.y);
            if (nodeId !== d.hoveredNode) {
                d.hoveredNode = nodeId;
                canvas.requestPaint();
            }

            // Pan
            if (isPanning) {
                d.offsetX += mouse.x - lastX;
                d.offsetY += mouse.y - lastY;
                lastX = mouse.x;
                lastY = mouse.y;
                canvas.requestPaint();
            }
        }

        onWheel: wheel => {
            const zoomFactor = wheel.angleDelta.y > 0 ? 1.1 : 0.9;
            const newScale = Math.max(0.1, Math.min(3.0, d.scale * zoomFactor));

            // Zoom towards mouse position
            const mouseX = wheel.x;
            const mouseY = wheel.y;
            d.offsetX = mouseX - (mouseX - d.offsetX) * (newScale / d.scale);
            d.offsetY = mouseY - (mouseY - d.offsetY) * (newScale / d.scale);
            d.scale = newScale;

            canvas.requestPaint();
        }

        onDoubleClicked: mouse => {
            const graphPos = d.screenToGraph(mouse.x, mouse.y);
            const nodeId = d.findNodeAt(graphPos.x, graphPos.y);
            if (nodeId === "") {
                root.fitToView();
            }
        }
    }

    // ========================================================================
    // Context Menu
    // ========================================================================

    Menu {
        id: nodeContextMenu

        Action {
            text: "Copy Frame ID"
            onTriggered: RQml.copyTextToClipboard(d.selectedNode)
        }

        Action {
            text: "Copy Parent ID"
            enabled: {
                const frame = root.tfInterface ? root.tfInterface.getFrame(d.selectedNode) : null;
                return frame && frame.parentId !== "";
            }
            onTriggered: {
                const frame = root.tfInterface.getFrame(d.selectedNode);
                if (frame)
                    RQml.copyTextToClipboard(frame.parentId);
            }
        }
    }

    // ========================================================================
    // Tooltip
    // ========================================================================

    ToolTip {
        id: tooltip
        visible: d.hoveredNode !== ""
        x: mouseArea.mouseX + 15
        y: mouseArea.mouseY + 15

        contentItem: Column {
            spacing: 4

            Label {
                text: d.hoveredNode
                font.bold: true
            }

            Label {
                visible: {
                    const frame = root.tfInterface ? root.tfInterface.getFrame(d.hoveredNode) : null;
                    return frame && frame.parentId !== "";
                }
                text: {
                    const frame = root.tfInterface ? root.tfInterface.getFrame(d.hoveredNode) : null;
                    return frame ? "Parent: " + frame.parentId : "";
                }
                font.pixelSize: 11
            }

            Label {
                text: {
                    const frame = root.tfInterface ? root.tfInterface.getFrame(d.hoveredNode) : null;
                    if (!frame)
                        return "";
                    if (frame.isStatic)
                        return "Static transform";
                    const age = (Date.now() - frame.lastUpdate) / 1000.0;
                    if (age < 1)
                        return "Age: " + (age * 1000).toFixed(0) + " ms";
                    return "Age: " + age.toFixed(1) + " s";
                }
                font.pixelSize: 11
            }
        }
    }

    // ========================================================================
    // Zoom Controls Overlay
    // ========================================================================

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        spacing: 4

        Button {
            width: 32
            height: 32
            text: "+"
            onClicked: {
                d.scale = Math.min(3.0, d.scale * 1.2);
                canvas.requestPaint();
            }
        }

        Button {
            width: 32
            height: 32
            text: "-"
            onClicked: {
                d.scale = Math.max(0.1, d.scale / 1.2);
                canvas.requestPaint();
            }
        }

        Button {
            width: 32
            height: 32
            text: "\u2302"  // Home symbol
            onClicked: root.fitToView()

            ToolTip.visible: hovered
            ToolTip.text: "Fit to view"
        }
    }

    // ========================================================================
    // Legend
    // ========================================================================

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8
        width: legendColumn.width + 16
        height: legendColumn.height + 16
        color: Qt.rgba(palette.base.r, palette.base.g, palette.base.b, 0.9)
        radius: 4
        border.color: palette.mid
        border.width: 1

        Column {
            id: legendColumn
            anchors.centerIn: parent
            spacing: 4

            Row {
                spacing: 8
                Rectangle { width: 12; height: 12; radius: 2; color: nodeColor }
                Label { text: "Dynamic"; font.pixelSize: 11 }
            }

            Row {
                spacing: 8
                Rectangle { width: 12; height: 12; radius: 2; color: staticNodeColor }
                Label { text: "Static"; font.pixelSize: 11 }
            }

            Row {
                spacing: 8
                Rectangle { width: 12; height: 12; radius: 2; color: staleNodeColor }
                Label { text: "Stale (>5s)"; font.pixelSize: 11 }
            }
        }
    }
}
