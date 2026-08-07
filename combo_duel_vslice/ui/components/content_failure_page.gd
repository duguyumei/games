class_name ContentFailurePage
extends ColorRect

## 内容校验失败时的终止页。
##
## 内容缺失或校验失败时不进入游戏，而是列出可定位的错误。静默降级会把内容缺陷
## 推迟到战斗中段才以默认值形式暴露，定位成本远高于在入口直接失败。

const UiDesignScript = preload("res://ui/ui_design.gd")

var _column: VBoxContainer
var _built: bool = false

func _ready() -> void:
    _ensure_built()

## 展示一组内容校验错误。
func present(title_text: String, errors: Array[String]) -> void:
    _ensure_built()
    for child in _column.get_children():
        child.queue_free()

    var title := Label.new()
    title.text = title_text
    title.add_theme_font_size_override("font_size", UiDesignScript.FONT_TITLE)
    title.add_theme_color_override("font_color", UiDesignScript.COLORS["red"])
    _column.add_child(title)

    if errors.is_empty():
        _column.add_child(_error_line("未提供具体错误信息"))
        return
    for message in errors:
        _column.add_child(_error_line(message))

func _error_line(message: String) -> Label:
    var line := Label.new()
    line.text = "· %s" % message
    line.add_theme_font_size_override("font_size", UiDesignScript.FONT_BODY)
    line.add_theme_color_override("font_color", UiDesignScript.COLORS["cream"])
    line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return line

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    color = Color("1a0e0e")
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_%s" % side, UiDesignScript.SPACE_LG * 2)
    add_child(margin)

    _column = VBoxContainer.new()
    _column.add_theme_constant_override("separation", UiDesignScript.SPACE_MD)
    margin.add_child(_column)
