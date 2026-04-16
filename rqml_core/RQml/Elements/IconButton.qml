import QtQuick.Controls
import RQml.Fonts

RoundButton {
    property string tooltipText

    ToolTip.delay: 500
    ToolTip.text: tooltipText
    ToolTip.visible: !!tooltipText && hovered
    font.family: IconFont.name
    font.pixelSize: 18
    implicitWidth: implicitHeight
    radius: 4
}
