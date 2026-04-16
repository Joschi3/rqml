import QtQuick.Controls
import RQml.Fonts

RoundButton {
    property string iconOff
    property string iconOn
    property string tooltipTextOff
    property string tooltipTextOn

    ToolTip.delay: 500
    ToolTip.text: checked ? tooltipTextOn : tooltipTextOff
    ToolTip.visible: hovered && (checked && !!tooltipTextOn) || (!checked && !!tooltipTextOff)
    checkable: true
    font.family: IconFont.name
    font.pixelSize: 18
    implicitWidth: implicitHeight
    radius: 4
    text: checked ? iconOn : iconOff
}
