class_name BattleValuePanel
extends HBoxContainer

const UiDesignScript = preload("res://ui/ui_design.gd")

var _qi: Label
var _multiplier: Label
var _technique_name: Label
var _technique_value: Label
var _description: Label
var _built := false

func _ready() -> void:
    _ensure_built()

func present(data: Dictionary, unknown: bool = false) -> void:
    _ensure_built()
    if unknown:
        _qi.text = "?"
        _multiplier.text = "?"
        _technique_name.text = "?"
        _technique_value.text = "?"
        _description.text = "点击意图查看可能方向"
        return
    _qi.text = str(data.get("qi", 0))
    _multiplier.text = str(data.get("multiplier", 0))
    _technique_name.text = str(data.get("technique_name", "?"))
    _technique_value.text = str(data.get("technique_value", 0))
    _description.text = str(data.get("description", ""))

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    name = "BattleCombatReadout"
    custom_minimum_size = Vector2(330, 132)
    add_theme_constant_override("separation", UiDesignScript.SPACE_MD)
    var values := PanelContainer.new()
    values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    values.add_theme_stylebox_override("panel", UiDesignScript.box(
        UiDesignScript.COLORS["panel"], UiDesignScript.RADIUS_LG,
        UiDesignScript.COLORS["green"], UiDesignScript.BORDER_REGULAR, 10))
    var equation := HBoxContainer.new()
    equation.alignment = BoxContainer.ALIGNMENT_CENTER
    values.add_child(equation)
    _qi = _number_column(equation, "真气", UiDesignScript.COLORS["green"], 38)
    var times := Label.new()
    times.text = "×"
    times.add_theme_font_size_override("font_size", 22)
    times.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    equation.add_child(times)
    _multiplier = _number_column(equation, "倍率", UiDesignScript.COLORS["gold"], 34)
    add_child(values)
    var technique := PanelContainer.new()
    technique.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    technique.add_theme_stylebox_override("panel", UiDesignScript.box(
        UiDesignScript.COLORS["panel"], UiDesignScript.RADIUS_LG,
        UiDesignScript.COLORS["copper"], UiDesignScript.BORDER_REGULAR, 10))
    var column := VBoxContainer.new()
    technique.add_child(column)
    var caption := Label.new()
    caption.text = "功法"
    caption.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
    caption.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    column.add_child(caption)
    _technique_name = Label.new()
    _technique_name.text = "?"
    _technique_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _technique_name.add_theme_font_size_override("font_size", UiDesignScript.FONT_SUBTITLE)
    _technique_name.add_theme_color_override("font_color", UiDesignScript.COLORS["cream"])
    column.add_child(_technique_name)
    _technique_value = Label.new()
    _technique_value.text = "0"
    _technique_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _technique_value.add_theme_font_size_override("font_size", 30)
    _technique_value.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    column.add_child(_technique_value)
    _description = Label.new()
    _description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _description.add_theme_font_size_override("font_size", 9)
    _description.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    column.add_child(_description)
    add_child(technique)

func _number_column(parent: HBoxContainer, caption_text: String, color: Color, font_size: int) -> Label:
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(column)
    var caption := Label.new()
    caption.text = caption_text
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
    caption.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    column.add_child(caption)
    var value := Label.new()
    value.text = "0"
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value.add_theme_font_size_override("font_size", font_size)
    value.add_theme_color_override("font_color", color)
    column.add_child(value)
    return value
