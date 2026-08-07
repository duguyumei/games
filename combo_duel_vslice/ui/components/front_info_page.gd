class_name FrontInfoPage
extends Control

signal back_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var _title: Label
var _body: Label
var _built := false

func _ready() -> void:
    _ensure_built()

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := PanelContainer.new()
    panel.position = Vector2(245, 145)
    panel.size = Vector2(950, 610)
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color(0.055, 0.11, 0.12, 0.98), 24, Color("3b5758"), 2, 20))
    add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 55)
    margin.add_theme_constant_override("margin_right", 55)
    margin.add_theme_constant_override("margin_top", 48)
    margin.add_theme_constant_override("margin_bottom", 48)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 24)
    margin.add_child(box)
    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 36)
    _title.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    box.add_child(_title)
    box.add_child(UiDesignScript.divider(8))
    _body = Label.new()
    _body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _body.add_theme_font_size_override("font_size", 20)
    box.add_child(_body)
    var back := Button.new()
    back.text = "返回主菜单"
    back.custom_minimum_size = Vector2(230, 58)
    back.size_flags_horizontal = Control.SIZE_SHRINK_END
    back.pressed.connect(func(): back_requested.emit())
    UiDesignScript.style_button(back)
    box.add_child(back)

func present(title: String, body: String) -> void:
    _ensure_built()
    _title.text = title
    _body.text = body
