import QtQuick.Controls
import RQml.Fonts

RoundButton {
    implicitWidth: implicitHeight
    property string tooltipText
    font.family: IconFont.name
    font.pixelSize: 18
    radius: 4

    ToolTip.visible: !!tooltipText && hovered
    ToolTip.text: tooltipText
    ToolTip.delay: 500
}
