class_name BattleActorStatus
extends PanelContainer

const UiDesignScript = preload("res://ui/ui_design.gd")

var _title_label: Label
var _portrait_label: Label
var _meter_root: Control
var _life_bar: ProgressBar
var _life_label: Label
var _defense_label: Label
var _status_row: HBoxContainer
var _plan_row: HBoxContainer
var _built := false

func _ready() -> void:
    _ensure_built()

func configure(options: Dictionary = {}) -> void:
    _ensure_built()
    custom_minimum_size.y = float(options.get("minimum_height", 0.0))
    _portrait_label.visible = str(options.get("portrait", "")) != ""
    _portrait_label.text = str(options.get("portrait", ""))
    _title_label.visible = not bool(options.get("hide_name", false))
    _meter_root.custom_minimum_size.x = float(options.get("meter_width", 220.0))
    if options.has("panel_style"):
        add_theme_stylebox_override("panel", options["panel_style"])

func present(data: Dictionary) -> void:
    _ensure_built()
    _title_label.text = str(data.get("name", ""))
    var life := int(data.get("life", 0))
    var max_life := int(data.get("max_life", 0))
    _life_bar.max_value = maxi(1, max_life)
    _life_bar.value = life
    _life_label.text = "♥  %d / %d" % [life, max_life]
    _defense_label.text = "盾 %d" % int(data.get("defense", 0))
    _populate_chips(_status_row, data.get("statuses", []))
    var plans: Array = data.get("plans", [])
    _plan_row.visible = not plans.is_empty()
    _populate_chips(_plan_row, plans)

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color.TRANSPARENT, 10, Color.TRANSPARENT, 0, 0, Vector2(0, 0)))
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    add_child(box)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    box.add_child(row)
    _portrait_label = Label.new()
    _portrait_label.custom_minimum_size = Vector2(34, 34)
    _portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _portrait_label.add_theme_font_size_override("font_size", 15)
    _portrait_label.add_theme_color_override("font_color", Color("ffe4d6"))
    _portrait_label.add_theme_stylebox_override(
        "normal", UiDesignScript.box(Color("6b2f2d"), 17, Color("cf6259"), 2, 2, Vector2(2, 2)))
    row.add_child(_portrait_label)
    _title_label = Label.new()
    _title_label.add_theme_font_size_override("font_size", 17)
    _title_label.add_theme_color_override("font_color", UiDesignScript.COLORS["cream"])
    row.add_child(_title_label)
    _meter_root = Control.new()
    _meter_root.custom_minimum_size = Vector2(220, 27)
    _life_bar = ProgressBar.new()
    _life_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _life_bar.show_percentage = false
    _life_bar.add_theme_stylebox_override(
        "background", UiDesignScript.box(Color("11161b"), 8, Color("080b0d"), 2, 0, Vector2.ZERO))
    _life_bar.add_theme_stylebox_override(
        "fill", UiDesignScript.box(UiDesignScript.COLORS["red"], 7, Color("f06b61"), 1, 0, Vector2.ZERO))
    _meter_root.add_child(_life_bar)
    _life_label = Label.new()
    _life_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _life_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _life_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _life_label.add_theme_font_size_override("font_size", 12)
    _life_label.add_theme_color_override("font_color", Color("fff4df"))
    _life_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _meter_root.add_child(_life_label)
    row.add_child(_meter_root)
    _defense_label = UiDesignScript.chip("盾 0", UiDesignScript.COLORS["blue"], 62)
    _defense_label.tooltip_text = "防御：受到普通伤害时先扣除，当前原型跨回合保留"
    row.add_child(_defense_label)
    _status_row = HBoxContainer.new()
    _status_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _status_row.add_theme_constant_override("separation", 6)
    box.add_child(_status_row)
    _plan_row = HBoxContainer.new()
    _plan_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _plan_row.add_theme_constant_override("separation", 6)
    box.add_child(_plan_row)

func _populate_chips(row: HBoxContainer, definitions: Array) -> void:
    for child in row.get_children():
        child.queue_free()
    for value in definitions:
        var definition: Dictionary = value
        var chip := UiDesignScript.chip(
            str(definition.get("text", "")),
            definition.get("color", UiDesignScript.COLORS["panel_3"]),
            float(definition.get("minimum_width", 68.0)))
        chip.tooltip_text = str(definition.get("tooltip", ""))
        row.add_child(chip)
