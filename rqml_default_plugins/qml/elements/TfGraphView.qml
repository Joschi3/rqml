import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import Ros2
import RQml.Elements
import RQml.Fonts

/**
 * Interactive graph visualization for TF frames.
 * Displays frames as nodes connected by edges representing parent-child relationships.
 * Supports panning, zooming, and automatic hierarchical layout.
 */
Item {
    id: root

    //! The TfTreeInterface providing frame data
    property var tfInterface: null

    //! Age threshold (in seconds) after which a dynamic transform is considered stale
    property real staleThreshold: 5.0

    //! Semantic status colors (set by parent to avoid duplication)
    property color freshColor: Material.color(Material.Green)
    property color staticColor: Material.color(Material.Blue)
    property color staleColor: Material.color(Material.Red)

    //! Layout direction: true = left-to-right, false = top-to-bottom
    property bool horizontal: true

    //! Node styling derived from palette
    property color edgeColor: Material.color(Material.Orange)
    property int nodeWidth: 160
    property int nodeHeight: 28
    property int levelSpacing: 30
    property int nodeSpacing: 4

    // ========================================================================
    // Public Functions
    // ========================================================================

    /**
     * Reset the view to fit all nodes.
     */
    function fitToView() {
        if (d.nodePositions.length === 0)
            return;
        if (root.width <= 0 || root.height <= 0)
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
         * Calculate layout for all frames.
         * Horizontal mode: root frames on the left, children extend to the right.
         * Vertical mode: root frames on top, children extend downward.
         * Uses bottom-up subtree size calculation so children are centered
         * relative to their parent.
         */
        function calculateLayout() {
            if (!root.tfInterface || root.tfInterface.frameCount === 0) {
                d.nodePositions = [];
                d.edges = [];
                return;
            }

            const positions = [];
            const edgeList = [];
            const framePos = {};     // frameId -> {x, y}
            const subtreeSpan = {};  // frameId -> cross-axis span in pixels
            const horiz = root.horizontal;

            // The "cross-axis" is the axis perpendicular to the tree growth direction.
            // Horizontal: cross = vertical (height), Vertical: cross = horizontal (width).
            const nodeMainSize = horiz ? nodeWidth : nodeHeight;
            const nodeCrossSize = horiz ? nodeHeight : nodeWidth;

            // Calculate the cross-axis span each subtree needs (bottom-up)
            function calcSpan(frameId) {
                const children = root.tfInterface.getChildren(frameId).slice().sort();
                if (children.length === 0) {
                    subtreeSpan[frameId] = nodeCrossSize;
                    return nodeCrossSize;
                }
                let total = 0;
                for (let i = 0; i < children.length; ++i) {
                    if (i > 0)
                        total += nodeSpacing;
                    total += calcSpan(children[i]);
                }
                subtreeSpan[frameId] = Math.max(total, nodeCrossSize);
                return subtreeSpan[frameId];
            }

            // Place a node and its children recursively.
            // mainPos: position along tree growth axis, crossPos: start of allocated cross-axis space.
            function placeNode(frameId, mainPos, crossPos) {
                const mySpan = subtreeSpan[frameId];
                const centeredCross = crossPos + (mySpan - nodeCrossSize) / 2;
                const x = horiz ? mainPos : centeredCross;
                const y = horiz ? centeredCross : mainPos;
                framePos[frameId] = { x: x, y: y };

                const frame = root.tfInterface.getFrame(frameId);
                positions.push({
                    frameId: frameId,
                    x: x,
                    y: y,
                    isStatic: frame ? frame.isStatic : false,
                    age: frame ? (Date.now() - frame.lastUpdate) / 1000.0 : -1,
                    updateCount: frame ? frame.updateCount : 0
                });

                const children = root.tfInterface.getChildren(frameId).slice().sort();
                const childMain = mainPos + nodeMainSize + levelSpacing;
                let childCross = crossPos;
                for (let i = 0; i < children.length; ++i) {
                    placeNode(children[i], childMain, childCross);
                    childCross += subtreeSpan[children[i]] + nodeSpacing;
                }
            }

            // Layout each root tree stacked along the cross axis
            const rootFrames = root.tfInterface.rootFrames;
            for (let i = 0; i < rootFrames.length; ++i) {
                calcSpan(rootFrames[i]);
            }

            let totalCross = 0;
            for (let i = 0; i < rootFrames.length; ++i) {
                if (i > 0)
                    totalCross += nodeSpacing * 5;
                totalCross += subtreeSpan[rootFrames[i]];
            }

            let curCross = -totalCross / 2;
            for (let i = 0; i < rootFrames.length; ++i) {
                if (i > 0)
                    curCross += nodeSpacing * 5;
                placeNode(rootFrames[i], 0, curCross);
                curCross += subtreeSpan[rootFrames[i]];
            }

            // Create edges
            for (let i = 0; i < positions.length; ++i) {
                const node = positions[i];
                const frame = root.tfInterface.getFrame(node.frameId);
                if (frame && frame.parentId && framePos[frame.parentId]) {
                    const pp = framePos[frame.parentId];
                    if (horiz) {
                        // Right side of parent → left side of child
                        edgeList.push({
                            from: frame.parentId, to: node.frameId,
                            fromX: pp.x + nodeWidth,   fromY: pp.y + nodeHeight / 2,
                            toX: node.x,                toY: node.y + nodeHeight / 2
                        });
                    } else {
                        // Bottom of parent → top of child
                        edgeList.push({
                            from: frame.parentId, to: node.frameId,
                            fromX: pp.x + nodeWidth / 2, fromY: pp.y + nodeHeight,
                            toX: node.x + nodeWidth / 2, toY: node.y
                        });
                    }
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
                return Material.color(Material.Purple);
            if (!node.isStatic && node.age > root.staleThreshold)
                return root.staleColor;
            if (node.isStatic)
                return root.staticColor;
            return root.freshColor;
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
            // Auto-fit when new frames are added
            if (d.nodePositions.length > prevCount) {
                root.fitToView();
            }
        }
    }

    onHorizontalChanged: {
        d.calculateLayout();
        root.fitToView();
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

            // Draw edges with arrows
            ctx.strokeStyle = edgeColor;
            ctx.lineWidth = 2 / d.scale;
            const arrowSize = 7;
            const arrowWidth = arrowSize * 0.5;

            for (let i = 0; i < d.edges.length; ++i) {
                const edge = d.edges[i];

                if (root.horizontal) {
                    // Horizontal: arrow pointing right
                    const arrowBaseX = edge.toX - arrowSize;
                    ctx.beginPath();
                    ctx.moveTo(edge.fromX, edge.fromY);
                    const midX = (edge.fromX + arrowBaseX) / 2;
                    ctx.bezierCurveTo(midX, edge.fromY, midX, edge.toY, arrowBaseX, edge.toY);
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.moveTo(edge.toX, edge.toY);
                    ctx.lineTo(arrowBaseX, edge.toY - arrowWidth);
                    ctx.lineTo(arrowBaseX, edge.toY + arrowWidth);
                    ctx.closePath();
                    ctx.fillStyle = edgeColor;
                    ctx.fill();
                } else {
                    // Vertical: arrow pointing down
                    const arrowBaseY = edge.toY - arrowSize;
                    ctx.beginPath();
                    ctx.moveTo(edge.fromX, edge.fromY);
                    const midY = (edge.fromY + arrowBaseY) / 2;
                    ctx.bezierCurveTo(edge.fromX, midY, edge.toX, midY, edge.toX, arrowBaseY);
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.moveTo(edge.toX, edge.toY);
                    ctx.lineTo(edge.toX - arrowWidth, arrowBaseY);
                    ctx.lineTo(edge.toX + arrowWidth, arrowBaseY);
                    ctx.closePath();
                    ctx.fillStyle = edgeColor;
                    ctx.fill();
                }
            }

            // Draw nodes
            for (let i = 0; i < d.nodePositions.length; ++i) {
                const node = d.nodePositions[i];
                const isHovered = node.frameId === d.hoveredNode;
                const isSelected = node.frameId === d.selectedNode;

                // Node background - manual rounded rectangle (roundRect not available in QML Canvas)
                const r = 4;  // corner radius
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
                    ctx.strokeStyle = isSelected ? Material.color(Material.Yellow) : "#ffffff";
                    ctx.lineWidth = 3 / d.scale;
                    ctx.stroke();
                }

                // Node text (fixed size in graph coordinates, scales with zoom)
                const nodeColor = Qt.color(ctx.fillStyle);
                ctx.fillStyle = nodeColor.hslLightness > 0.5 ? "#000000" : "#ffffff";
                ctx.font = "bold 11px sans-serif";
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

        // Cache the selected frame to avoid repeated lookups
        property var selectedFrame: d.selectedNode && root.tfInterface
            ? root.tfInterface.getFrame(d.selectedNode)
            : null

        Action {
            text: "Copy Frame ID"
            onTriggered: RQml.copyTextToClipboard(d.selectedNode)
        }

        Action {
            text: "Copy Parent ID"
            enabled: nodeContextMenu.selectedFrame && nodeContextMenu.selectedFrame.parentId !== ""
            onTriggered: {
                if (nodeContextMenu.selectedFrame)
                    RQml.copyTextToClipboard(nodeContextMenu.selectedFrame.parentId);
            }
        }
    }

    // ========================================================================
    // Tooltip
    // ========================================================================

    ToolTip {
        id: tooltip
        delay: 0
        timeout: -1
        x: mouseArea.mouseX + 15
        y: mouseArea.mouseY + 15

        // Show/hide immediately without fade animation
        enter: Transition {}
        exit: Transition {}

        // Cache the hovered frame to avoid repeated lookups
        property var hoveredFrame: d.hoveredNode && root.tfInterface
            ? root.tfInterface.getFrame(d.hoveredNode)
            : null

        // Open/close explicitly so no ghost rectangle lingers
        Connections {
            target: d
            function onHoveredNodeChanged() {
                if (d.hoveredNode !== "")
                    tooltip.open();
                else
                    tooltip.close();
            }
        }

        contentItem: Column {
            spacing: 4

            Label {
                text: d.hoveredNode
                font.bold: true
                font.pixelSize: 14
            }

            Label {
                visible: tooltip.hoveredFrame && tooltip.hoveredFrame.parentId !== ""
                text: tooltip.hoveredFrame ? "Parent: " + tooltip.hoveredFrame.parentId : ""
                font.pixelSize: 13
            }

            Label {
                text: {
                    if (!tooltip.hoveredFrame)
                        return "";
                    if (tooltip.hoveredFrame.isStatic)
                        return "Static transform";
                    const age = (Date.now() - tooltip.hoveredFrame.lastUpdate) / 1000.0;
                    return "Age: " + root.tfInterface.formatAge(age);
                }
            }
        }
    }

    // ========================================================================
    // Zoom Controls Overlay
    // ========================================================================

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 4

        IconButton {
            text: IconFont.iconMagnifyingGlassPlus
            tooltipText: "Zoom in"
            onClicked: {
                d.scale = Math.min(3.0, d.scale * 1.2);
                canvas.requestPaint();
            }
        }

        IconButton {
            text: IconFont.iconMagnifyingGlassMinus
            tooltipText: "Zoom out"
            onClicked: {
                d.scale = Math.max(0.1, d.scale / 1.2);
                canvas.requestPaint();
            }
        }

        IconButton {
            text: IconFont.iconExpand
            tooltipText: "Fit to view"
            onClicked: root.fitToView()
        }

        IconButton {
            text: root.horizontal ? IconFont.iconArrowsUpDown : IconFont.iconArrowsLeftRight
            tooltipText: root.horizontal ? "Switch to vertical layout" : "Switch to horizontal layout"
            onClicked: root.horizontal = !root.horizontal
        }
    }

    // ========================================================================
    // Legend
    // ========================================================================

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: legendColumn.width + 24
        height: legendColumn.height + 24
        color: Qt.rgba(palette.base.r, palette.base.g, palette.base.b, 0.9)
        radius: 4
        border.color: palette.mid
        border.width: 1

        Column {
            id: legendColumn
            anchors.centerIn: parent
            spacing: 8

            Row {
                spacing: 8
                Rectangle { width: 16; height: 16; radius: 3; color: root.freshColor; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Dynamic"; anchors.verticalCenter: parent.verticalCenter }
            }

            Row {
                spacing: 8
                Rectangle { width: 16; height: 16; radius: 3; color: root.staticColor; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Static"; anchors.verticalCenter: parent.verticalCenter }
            }

            Row {
                spacing: 8
                Rectangle { width: 16; height: 16; radius: 3; color: root.staleColor; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Stale (>" + root.staleThreshold + "s)"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
