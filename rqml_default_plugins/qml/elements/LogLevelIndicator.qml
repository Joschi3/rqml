import QtQuick
import QtQuick.Controls.Material
import RQml.Fonts

Text {
    required property int level

    color: {
        switch (parseInt(level)) {
        case 10:
            return Material.color(Material.Green, Material.Shade500);
        case 20:
            return Material.color(Material.Blue);
        case 30:
            return Material.color(Material.Orange);
        case 40:
            return Material.color(Material.Red);
        case 50:
            return Material.color(Material.Red, Material.Shade900);
        default:
            return palette.text;
        }
    }
    font.family: IconFont.name
    font.pixelSize: 18
    horizontalAlignment: Text.AlignHCenter
    text: {
        switch (parseInt(level)) {
        case 10:
            return IconFont.iconDebug;
        case 20:
            return IconFont.iconInfo;
        case 30:
            return IconFont.iconWarning;
        case 40:
            return IconFont.iconError;
        case 50:
            return IconFont.iconFatal;
        default:
            return "";
        }
    }
    verticalAlignment: Text.AlignVCenter

    MouseArea {
        ToolTip.delay: 500
        ToolTip.text: {
            switch (parseInt(level)) {
            case 10:
                return "Debug";
            case 20:
                return "Info";
            case 30:
                return "Warning";
            case 40:
                return "Error";
            case 50:
                return "Fatal";
            default:
                return "Unknown log level";
            }
        }
        ToolTip.visible: containsMouse || pressed
        acceptedButtons: Qt.NoButton
        anchors.fill: parent
        hoverEnabled: true
    }
}
