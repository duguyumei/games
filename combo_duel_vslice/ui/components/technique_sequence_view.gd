class_name TechniqueSequenceView
extends PanelContainer

const UiDesignScript = preload("res://ui/ui_design.gd")

var _current_name: Label
var _next_name: Label
var _pips: Label
var _description: Label
var _built := false

func _ready() -> void:
    _ensure_built()

func present(data: Dictionary) -> void:
    _ensure_built()
    _current_name.text = str(data.get("current_name", "等待选牌"))
    _next_name.text = str(data.get("next_name", "—"))
    _pips.text = str(data.get("pips", "○ ○"))
    _description.text = str(data.get("description", ""))

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    custom_minimum_size.y = 36
    add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color(0.08, 0.12, 0.13, 0.7), 8, Color("314a45"), 1, 2))
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    add_child(row)
    var caption := Label.new()
    caption.text = "功法轮转"
    caption.add_theme_font_size_override("font_size", 11)
    caption.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    row.add_child(caption)
    _current_name = Label.new()
    _current_name.add_theme_font_size_override("font_size", 15)
    _current_name.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    row.add_child(_current_name)
    var arrow := Label.new()
    arrow.text = "➜"
    arrow.add_theme_font_size_override("font_size", 16)
    arrow.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    row.add_child(arrow)
    _next_name = Label.new()
    _next_name.add_theme_font_size_override("font_size", 13)
    row.add_child(_next_name)
    _pips = Label.new()
    _pips.add_theme_font_size_override("font_size", 13)
    _pips.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    row.add_child(_pips)
    _description = Label.new()
    _description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _description.add_theme_font_size_override("font_size", 10)
    _description.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    row.add_child(_description)
