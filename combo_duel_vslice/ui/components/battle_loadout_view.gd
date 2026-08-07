class_name BattleLoadoutView
extends HBoxContainer

signal technique_slot_move_requested(direction: int)
signal consumable_selected(slot_index: int)
signal consumable_use_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var _inner_count: Label
var _inner_slots: HBoxContainer
var _move_left: Button
var _move_right: Button
var _consumable_count: Label
var _consumable_slots: HBoxContainer
var _active_consumable_slot := -1
var _built := false

func _ready() -> void:
    _ensure_built()

func present(data: Dictionary, active_consumable_slot: int, can_use_consumable: bool) -> void:
    _ensure_built()
    _active_consumable_slot = active_consumable_slot
    var equipped: Array = data.get("equipped_inner_skills", [])
    var inner_limit := int(data.get("inner_skill_limit", 6))
    var slot_index := int(data.get("technique_slot_index", 0))
    _inner_count.text = "%d / %d" % [equipped.size(), inner_limit]
    _move_left.disabled = slot_index <= 0
    _move_right.disabled = slot_index >= equipped.size()
    _clear(_inner_slots)
    for index in range(inner_limit):
        if index < equipped.size():
            _inner_slots.add_child(_equipped_inner_slot(equipped[index], index + 1))
        else:
            _inner_slots.add_child(_empty_slot("内功", index + 1, Color("485461"), Vector2(84, 58)))
    var consumables: Array = data.get("consumables", [])
    var consumable_limit := int(data.get("consumable_limit", 0))
    _consumable_count.text = "%d / %d" % [consumables.size(), consumable_limit]
    _clear(_consumable_slots)
    for index in range(consumable_limit):
        if index < consumables.size():
            _consumable_slots.add_child(_consumable_slot(consumables[index], index))
        else:
            _consumable_slots.add_child(_empty_slot(
                "消耗品", index + 1, UiDesignScript.COLORS["purple"], Vector2(58, 58)))
    var use_button := Button.new()
    use_button.text = "使用"
    use_button.custom_minimum_size = Vector2(62, 58)
    use_button.tooltip_text = "使用当前选中的消耗品"
    use_button.pressed.connect(func(): consumable_use_requested.emit())
    UiDesignScript.style_button(use_button)
    use_button.disabled = not can_use_consumable
    _consumable_slots.add_child(use_button)

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    custom_minimum_size.y = 90
    add_theme_constant_override("separation", 9)
    var inner_panel := PanelContainer.new()
    inner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inner_panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color(0.08, 0.12, 0.13, 0.78), 10, Color("31434a"), 1, 3))
    var inner_box := VBoxContainer.new()
    inner_box.add_theme_constant_override("separation", 4)
    inner_panel.add_child(inner_box)
    var inner_header := HBoxContainer.new()
    inner_box.add_child(inner_header)
    var inner_title := Label.new()
    inner_title.text = "内功"
    inner_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inner_header.add_child(inner_title)
    _move_left = Button.new()
    _move_left.text = "◀ 功法位"
    _move_left.tooltip_text = "将动态功法结算位向左移动"
    _move_left.pressed.connect(func(): technique_slot_move_requested.emit(-1))
    UiDesignScript.style_button(_move_left)
    inner_header.add_child(_move_left)
    _move_right = Button.new()
    _move_right.text = "功法位 ▶"
    _move_right.tooltip_text = "将动态功法结算位向右移动"
    _move_right.pressed.connect(func(): technique_slot_move_requested.emit(1))
    UiDesignScript.style_button(_move_right)
    inner_header.add_child(_move_right)
    _inner_count = Label.new()
    _inner_count.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    inner_header.add_child(_inner_count)
    _inner_slots = HBoxContainer.new()
    _inner_slots.alignment = BoxContainer.ALIGNMENT_CENTER
    _inner_slots.add_theme_constant_override("separation", 6)
    inner_box.add_child(_inner_slots)
    add_child(inner_panel)
    var consumable_panel := PanelContainer.new()
    consumable_panel.custom_minimum_size.x = 296
    consumable_panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color(0.08, 0.12, 0.13, 0.78), 10, Color("4b3e59"), 1, 3))
    var consumable_box := VBoxContainer.new()
    consumable_box.add_theme_constant_override("separation", 4)
    consumable_panel.add_child(consumable_box)
    var consumable_header := HBoxContainer.new()
    consumable_box.add_child(consumable_header)
    var consumable_title := Label.new()
    consumable_title.text = "消耗品"
    consumable_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    consumable_header.add_child(consumable_title)
    _consumable_count = Label.new()
    _consumable_count.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    consumable_header.add_child(_consumable_count)
    _consumable_slots = HBoxContainer.new()
    _consumable_slots.alignment = BoxContainer.ALIGNMENT_CENTER
    _consumable_slots.add_theme_constant_override("separation", 6)
    consumable_box.add_child(_consumable_slots)
    add_child(consumable_panel)

func _empty_slot(kind: String, number: int, color: Color, slot_size: Vector2) -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = slot_size
    panel.tooltip_text = "%s槽 %d：当前为空" % [kind, number]
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color("20262e"), 8, color.darkened(0.12), 2, 2))
    var label := Label.new()
    label.text = "+"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 23)
    label.add_theme_color_override("font_color", Color(0.62, 0.67, 0.7, 0.48))
    panel.add_child(label)
    return panel

func _equipped_inner_slot(definition: Dictionary, number: int) -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(118, 58)
    panel.tooltip_text = "%s\n%s\n纵切调试装备；正式名称与开局配置尚未确认" % [
        definition.get("name", "内功"), definition.get("description", "")]
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color("253b42"), 8, UiDesignScript.COLORS["blue"], 2, 3))
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(box)
    var caption := Label.new()
    caption.text = "槽 %d · 已装备" % number
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 9)
    caption.add_theme_color_override("font_color", Color("8fb9ce"))
    box.add_child(caption)
    var name := Label.new()
    name.text = str(definition.get("name", "内功"))
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.add_theme_font_size_override("font_size", 12)
    box.add_child(name)
    return panel

func _consumable_slot(definition: Dictionary, index: int) -> Button:
    var button := Button.new()
    var kind_name: String = {
        "insight": "心得", "pill": "丹药", "treasure": "天材",
    }.get(definition.get("kind", ""), "物品")
    button.text = "%s\n%s" % [kind_name, definition.get("name", "未命名")]
    button.custom_minimum_size = Vector2(66, 58)
    button.add_theme_font_size_override("font_size", 10)
    button.tooltip_text = "%s\n%s\n点击后选择使用目标；纵切调试入口" % [
        definition.get("name", "消耗品"), definition.get("description", "")]
    var active := index == _active_consumable_slot
    var border := UiDesignScript.COLORS["gold"] if active else UiDesignScript.COLORS["purple"]
    var fill := Color("3b3120") if active else Color("29243a")
    button.add_theme_stylebox_override(
        "normal", UiDesignScript.box(fill, 8, border, 3 if active else 2, 3))
    button.add_theme_stylebox_override(
        "hover", UiDesignScript.box(fill.lightened(0.1), 8, UiDesignScript.COLORS["gold"], 2, 5))
    button.add_theme_stylebox_override(
        "pressed", UiDesignScript.box(fill.darkened(0.08), 8, Color("ffe3a0"), 2, 1))
    button.pressed.connect(func(): consumable_selected.emit(index))
    return button

func _clear(container: Container) -> void:
    for child in container.get_children():
        child.queue_free()
