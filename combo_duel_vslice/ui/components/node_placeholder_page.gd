class_name NodePlaceholderPage
extends ColorRect

signal completed

const UiDesignScript = preload("res://ui/ui_design.gd")

var _title: Label
var _description: Label
var _action: Button
var _built := false

func _ready() -> void:
    _ensure_built()

func configure(options: Dictionary) -> void:
    _ensure_built()
    _title.text = str(options.get("title", "特殊节点"))
    _description.text = str(options.get("description", "完成后返回地图。"))
    _action.text = str(options.get("action_text", "完成节点并返回地图"))
    _action.custom_minimum_size = options.get("action_size", Vector2(260, 54))
    var panel_size: Vector2 = options.get("panel_size", Vector2(620, 360))
    var panel := _title.get_parent().get_parent() as PanelContainer
    if panel != null:
        panel.custom_minimum_size = panel_size
    if options.has("panel_style") and panel != null:
        panel.add_theme_stylebox_override("panel", options["panel_style"])
    z_index = int(options.get("z_index", 180))

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    color = Color(0.02, 0.035, 0.035, 0.9)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visible = false
    z_index = 180
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(620, 360)
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color("202930"), 18, Color("4f7771"), 3, 12))
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 18)
    panel.add_child(box)
    _title = Label.new()
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 30)
    _title.add_theme_color_override("font_color", UiDesignScript.COLORS["cream"])
    box.add_child(_title)
    _description = Label.new()
    _description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _description.add_theme_font_size_override("font_size", 16)
    _description.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    box.add_child(_description)
    _action = Button.new()
    _action.pressed.connect(func(): completed.emit())
    UiDesignScript.style_button(_action)
    box.add_child(_action)
