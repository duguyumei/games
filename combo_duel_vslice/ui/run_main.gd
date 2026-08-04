extends Control

const RunStateScript = preload("res://core/run_state.gd")
const MapViewScript = preload("res://ui/map_view.gd")
const BattleScene = preload("res://ui/main.tscn")
const ConsumableRepositoryScript = preload("res://core/consumable_repository.gd")

const COLORS := {
    "ink": Color("15191f"),
    "panel": Color("202730"),
    "cream": Color("f1e7cf"),
    "muted": Color("9eabad"),
    "gold": Color("e9bd51"),
    "green": Color("3d8a62"),
    "purple": Color("76509e"),
    "red": Color("ad463f"),
}

var run_state = RunStateScript.new()
var consumable_repository = ConsumableRepositoryScript.new()
var map_view
var act_label: Label
var experience_label: Label
var phase_label: Label
var hover_label: Label
var route_label: Label
var practice_button: Button
var practice_overlay: Control
var practice_experience_label: Label
var practice_inventory_label: Label
var offers_row: HBoxContainer
var node_overlay: Control
var node_title: Label
var node_description: Label
var battle_layer: Control
var current_battle
var toast_label: Label
var seed_value: int = 2308
var _interface_initialized: bool = false

func _ready() -> void:
    initialize_interface()

func initialize_interface() -> void:
    if _interface_initialized:
        return
    _interface_initialized = true
    consumable_repository.load_from_file()
    _build_interface()
    run_state.changed.connect(_refresh)
    run_state.setup(seed_value)

func _build_interface() -> void:
    var background := ColorRect.new()
    background.color = Color("0b1718")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 18)
    outer.add_theme_constant_override("margin_right", 18)
    outer.add_theme_constant_override("margin_top", 14)
    outer.add_theme_constant_override("margin_bottom", 14)
    add_child(outer)
    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 10)
    outer.add_child(page)
    page.add_child(_build_top_bar())

    var content := HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 12)
    var map_panel := PanelContainer.new()
    map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_panel.add_theme_stylebox_override("panel", _box(Color("111b21"), 14, Color("31535a"), 2, 8))
    map_view = MapViewScript.new()
    map_view.custom_minimum_size = Vector2(900, 760)
    map_view.node_selected.connect(_on_node_selected)
    map_view.node_hovered.connect(func(text: String): hover_label.text = text if text != "" else "选择金色边框节点继续路线")
    map_panel.add_child(map_view)
    content.add_child(map_panel)
    content.add_child(_build_side_panel())
    page.add_child(content)

    practice_button = Button.new()
    practice_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    practice_button.offset_left = -158
    practice_button.offset_top = -170
    practice_button.offset_right = -28
    practice_button.offset_bottom = -28
    practice_button.add_theme_font_size_override("font_size", 18)
    practice_button.add_theme_color_override("font_color", Color("fff1cb"))
    practice_button.add_theme_stylebox_override("normal", _box(Color("542f25"), 22, COLORS["gold"], 3, 9))
    practice_button.add_theme_stylebox_override("hover", _box(Color("75452e"), 22, Color("ffe08a"), 4, 13))
    practice_button.add_theme_stylebox_override("pressed", _box(Color("3f251f"), 22, Color("fff0b2"), 3, 4))
    practice_button.pressed.connect(_open_practice)
    practice_button.z_index = 50
    add_child(practice_button)

    toast_label = Label.new()
    toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    toast_label.offset_left = 300
    toast_label.offset_right = -300
    toast_label.offset_top = -62
    toast_label.offset_bottom = -24
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.add_theme_color_override("font_color", Color("ffe5a0"))
    toast_label.add_theme_stylebox_override("normal", _box(Color(0.08, 0.11, 0.12, 0.92), 10, Color("66552e"), 1, 2))
    toast_label.visible = false
    toast_label.z_index = 60
    add_child(toast_label)

    practice_overlay = _build_practice_overlay()
    add_child(practice_overlay)
    node_overlay = _build_node_overlay()
    add_child(node_overlay)
    battle_layer = Control.new()
    battle_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_layer.visible = false
    battle_layer.z_index = 300
    add_child(battle_layer)

func _build_top_bar() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 58
    panel.add_theme_stylebox_override("panel", _box(COLORS["ink"], 12, Color("39464f"), 2, 5))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    var mark := Label.new()
    mark.text = "◇"
    mark.add_theme_font_size_override("font_size", 28)
    mark.add_theme_color_override("font_color", COLORS["gold"])
    row.add_child(mark)
    var title := Label.new()
    title.text = "太吾行旅"
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", COLORS["cream"])
    row.add_child(title)
    act_label = Label.new()
    act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    act_label.add_theme_font_size_override("font_size", 14)
    act_label.add_theme_color_override("font_color", COLORS["muted"])
    row.add_child(act_label)
    experience_label = _pill("历练 0", COLORS["gold"])
    row.add_child(experience_label)
    var reset := Button.new()
    reset.text = "新路线"
    reset.tooltip_text = "以当前种子重新生成本局"
    reset.pressed.connect(_reset_run)
    _style_button(reset)
    row.add_child(reset)
    panel.add_child(row)
    return panel

func _build_side_panel() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.x = 278
    panel.add_theme_stylebox_override("panel", _box(COLORS["panel"], 14, Color("10161b"), 3, 8))
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 13)
    var title := Label.new()
    title.text = "路线情报"
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", COLORS["cream"])
    box.add_child(title)
    phase_label = Label.new()
    phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    phase_label.add_theme_font_size_override("font_size", 14)
    phase_label.add_theme_color_override("font_color", COLORS["gold"])
    box.add_child(phase_label)
    hover_label = Label.new()
    hover_label.text = "选择金色边框节点继续路线"
    hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hover_label.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(hover_label)
    box.add_child(_divider())
    route_label = Label.new()
    route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    route_label.add_theme_font_size_override("font_size", 13)
    route_label.add_theme_color_override("font_color", Color("cbd4d1"))
    box.add_child(route_label)
    box.add_child(_divider())
    var legend := Label.new()
    legend.text = "战  普通战斗\n精  精英战斗\n?   事件\n息  休息\n藏  宝箱／特殊奖励\n首  层末 Boss\n\n地图不生成商店节点。\n原商店比例已并入事件。"
    legend.add_theme_font_size_override("font_size", 13)
    legend.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(legend)
    var rule := Label.new()
    rule.text = "节点进行中：修习锁定\n返回地图待选：修习开放"
    rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule.add_theme_color_override("font_color", Color("8fb8a4"))
    box.add_child(rule)
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(spacer)
    panel.add_child(box)
    return panel

func _build_practice_overlay() -> Control:
    var overlay := ColorRect.new()
    overlay.color = Color(0.015, 0.02, 0.025, 0.9)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    overlay.z_index = 200
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(1040, 590)
    panel.add_theme_stylebox_override("panel", _box(Color("211d27"), 18, Color("7a5b91"), 3, 14))
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    panel.add_child(box)
    var header := HBoxContainer.new()
    var title := Label.new()
    title.text = "修 习"
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", Color("f7e8c5"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    practice_experience_label = _pill("历练 0", COLORS["gold"])
    header.add_child(practice_experience_label)
    var close := Button.new()
    close.text = "返回地图"
    close.pressed.connect(_close_practice)
    _style_button(close)
    header.add_child(close)
    box.add_child(header)
    var subtitle := Label.new()
    subtitle.text = "地图待选节点期间可随时打开 · 当前纵切使用固定代表选项"
    subtitle.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(subtitle)
    box.add_child(_divider())
    offers_row = HBoxContainer.new()
    offers_row.alignment = BoxContainer.ALIGNMENT_CENTER
    offers_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    offers_row.add_theme_constant_override("separation", 16)
    box.add_child(offers_row)
    practice_inventory_label = Label.new()
    practice_inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    practice_inventory_label.add_theme_font_size_override("font_size", 14)
    practice_inventory_label.add_theme_color_override("font_color", Color("d8c9e1"))
    box.add_child(practice_inventory_label)
    var note := Label.new()
    note.text = "冥想费用、商品数量与购买后补货规则尚未确认，本纵切不补设计。"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_color_override("font_color", Color("877f8b"))
    box.add_child(note)
    return overlay

func _build_node_overlay() -> Control:
    var overlay := ColorRect.new()
    overlay.color = Color(0.02, 0.035, 0.035, 0.88)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    overlay.z_index = 180
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(620, 360)
    panel.add_theme_stylebox_override("panel", _box(Color("202930"), 18, Color("4f7771"), 3, 12))
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 18)
    panel.add_child(box)
    node_title = Label.new()
    node_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    node_title.add_theme_font_size_override("font_size", 30)
    node_title.add_theme_color_override("font_color", COLORS["cream"])
    box.add_child(node_title)
    node_description = Label.new()
    node_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    node_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    node_description.add_theme_font_size_override("font_size", 16)
    node_description.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(node_description)
    var finish := Button.new()
    finish.text = "完成节点并返回地图"
    finish.custom_minimum_size = Vector2(260, 54)
    finish.pressed.connect(_complete_noncombat_node)
    _style_button(finish)
    box.add_child(finish)
    return overlay

func _refresh() -> void:
    if map_view == null:
        return
    map_view.set_run_state(run_state)
    act_label.text = "第 %d / 3 层 · 种子 %d" % [run_state.act, run_state.seed]
    experience_label.text = "历练 %d" % run_state.experience
    practice_button.text = "♨\n修 习\n历练 %d" % run_state.experience
    practice_button.disabled = not run_state.can_open_practice()
    practice_button.tooltip_text = (
        "打开修习页面" if run_state.can_open_practice()
        else "当前节点尚未完成，不能修习")
    phase_label.text = {
        "awaiting_node": "当前：等待选择下一节点",
        "node_in_progress": "当前：节点进行中 · 修习已锁定",
        "run_complete": "第三层 Boss 已击败 · 本局完成",
    }.get(run_state.phase, run_state.phase)
    route_label.text = "可选节点：%d\n已完成节点：%d\n当前消耗品：%d / 3" % [
        run_state.available_node_ids().size(),
        run_state.completed_node_ids.size(),
        run_state.consumable_ids.size()]
    _refresh_practice()

func _refresh_practice() -> void:
    if offers_row == null:
        return
    practice_experience_label.text = "历练 %d" % run_state.experience
    practice_inventory_label.text = "共享消耗品栏  %d / 3  ·  %s" % [
        run_state.consumable_ids.size(),
        "、".join(_consumable_names()) if not run_state.consumable_ids.is_empty() else "当前为空"]
    for child in offers_row.get_children():
        child.queue_free()
    for consumable_id in ["high_card_insight", "hierophant", "aura"]:
        offers_row.add_child(_practice_offer(consumable_id))

func _practice_offer(consumable_id: String) -> Button:
    var definition := consumable_repository.get_consumable(consumable_id)
    var price: int = int(definition.get("price", 0))
    var button := Button.new()
    button.custom_minimum_size = Vector2(290, 330)
    button.text = "%s\n\n%s\n\n%d 历练\n\n%s" % [
        {"insight": "心 得", "pill": "丹 药", "treasure": "天材地宝"}.get(definition.get("kind", ""), "修习物"),
        definition.get("name", "未命名"),
        price,
        "已获得" if run_state.practice_purchases.has(consumable_id) else "点击购入共享栏"]
    button.tooltip_text = definition.get("description", "")
    button.add_theme_font_size_override("font_size", 18)
    var sold: bool = run_state.practice_purchases.has(consumable_id)
    button.disabled = sold or run_state.experience < price or run_state.consumable_ids.size() >= 3
    button.add_theme_stylebox_override("normal", _box(Color("30283a"), 15, COLORS["purple"], 3, 9))
    button.add_theme_stylebox_override("hover", _box(Color("44344f"), 15, COLORS["gold"], 4, 13))
    button.add_theme_stylebox_override("disabled", _box(Color("25262b"), 15, Color("4c4f55"), 2, 2))
    button.pressed.connect(_buy_consumable.bind(consumable_id, price))
    return button

func _on_node_selected(node_id: String) -> void:
    var result := run_state.begin_node(node_id)
    if not result.get("success", false):
        _show_toast(result.get("reason", "无法进入节点"))
        return
    var node: Dictionary = result["node"]
    var type_id: String = node.get("type", "")
    if type_id in ["combat", "elite", "boss"]:
        _open_battle(type_id)
    else:
        _open_noncombat_node(type_id)

func _open_battle(type_id: String) -> void:
    battle_layer.visible = true
    current_battle = BattleScene.instantiate()
    current_battle.run_state = run_state
    current_battle.battle_finished.connect(_on_battle_finished)
    battle_layer.add_child(current_battle)
    _show_toast({"combat": "进入普通战斗", "elite": "进入精英战斗", "boss": "进入层末 Boss"}.get(type_id, "进入战斗"))

func _on_battle_finished(outcome: String) -> void:
    if outcome != "player_victory":
        return
    run_state.sync_from_battle_side(current_battle.engine.player)
    current_battle.queue_free()
    current_battle = null
    battle_layer.visible = false
    var result := run_state.complete_current_node()
    _show_toast("战斗胜利 · 获得 %d 点历练 · 已返回地图" % int(result.get("reward", 0)))

func _open_noncombat_node(type_id: String) -> void:
    var names := {"event": "事件", "rest": "休息", "treasure": "宝箱／特殊奖励"}
    node_title.text = names.get(type_id, "特殊节点")
    node_description.text = {
        "event": "事件内容池尚未录入；当前纵切用于验证路线、节点锁定与返回地图。",
        "rest": "休息的正式恢复与升级选项尚未确认；当前纵切只完成节点流程。",
        "treasure": "奖励内容尚未确认；当前纵切保留固定宝箱行与节点完成流程。",
    }.get(type_id, "完成后返回地图。")
    node_overlay.visible = true

func _complete_noncombat_node() -> void:
    node_overlay.visible = false
    var result := run_state.complete_current_node()
    _show_toast("节点完成 · 返回地图%s" % (
        " · 获得 %d 点历练" % int(result.get("reward", 0)) if int(result.get("reward", 0)) > 0 else ""))

func _open_practice() -> void:
    if not run_state.can_open_practice():
        _show_toast("当前节点尚未完成，不能修习")
        return
    practice_overlay.visible = true
    _refresh_practice()

func _close_practice() -> void:
    practice_overlay.visible = false

func _buy_consumable(consumable_id: String, price: int) -> void:
    var result := run_state.purchase_consumable(consumable_id, price)
    if result.get("success", false):
        _show_toast("修习完成 · %s进入共享消耗品栏" % consumable_repository.get_consumable(consumable_id).get("name", consumable_id))
    else:
        _show_toast(result.get("reason", "无法购买"))
    _refresh()

func _reset_run() -> void:
    if current_battle != null:
        current_battle.queue_free()
        current_battle = null
    battle_layer.visible = false
    practice_overlay.visible = false
    node_overlay.visible = false
    run_state.setup(seed_value)
    _show_toast("已按种子 %d 生成新路线" % seed_value)

func _consumable_names() -> Array[String]:
    var names: Array[String] = []
    for consumable_id in run_state.consumable_ids:
        names.append(str(consumable_repository.get_consumable(consumable_id).get("name", consumable_id)))
    return names

func _show_toast(text: String) -> void:
    toast_label.text = text
    toast_label.visible = true
    var tween := create_tween()
    tween.tween_interval(2.2)
    tween.tween_callback(func(): toast_label.visible = false)

func _pill(text_value: String, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.custom_minimum_size = Vector2(112, 34)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", Color("fff4d5"))
    label.add_theme_stylebox_override("normal", _box(color.darkened(0.42), 10, color, 2, 2))
    return label

func _style_button(button: Button) -> void:
    button.add_theme_color_override("font_color", COLORS["cream"])
    button.add_theme_stylebox_override("normal", _box(Color("303944"), 9, Color("596773"), 2, 3))
    button.add_theme_stylebox_override("hover", _box(Color("3d4854"), 9, COLORS["gold"], 2, 6))
    button.add_theme_stylebox_override("pressed", _box(Color("252d35"), 9, Color("f4d987"), 2, 1))

func _divider() -> HSeparator:
    var divider := HSeparator.new()
    divider.add_theme_color_override("separator", Color("465159"))
    return divider

func _box(fill: Color, radius: int, border: Color, border_width: int, shadow: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    style.shadow_color = Color(0, 0, 0, 0.42)
    style.shadow_size = shadow
    style.shadow_offset = Vector2(2, 4)
    return style
