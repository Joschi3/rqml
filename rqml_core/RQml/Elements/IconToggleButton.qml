import QtQuick.Controls
import RQml.Fonts

RoundButton {
    property string iconOn
    property string iconOff
    property string tooltipTextOn
    property string tooltipTextOff

    implicitWidth: implicitHeight
    font.family: IconFont.name
    font.pixelSize: 18
    text: checked ? iconOn : iconOff
    checkable: true
    radius: 4

    ToolTip.visible: hovered && (checked && !!tooltipTextOn) || (!checked && !!tooltipTextOff)
    ToolTip.text: checked ? tooltipTextOn : tooltipTextOff
    ToolTip.delay: 500
}
