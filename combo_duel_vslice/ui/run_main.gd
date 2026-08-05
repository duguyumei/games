extends Control

const RunSessionScript = preload("res://core/run_session.gd")
const MapViewScript = preload("res://ui/map_view.gd")
const BattleScene = preload("res://ui/main.tscn")

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

var run_session = RunSessionScript.new()
var current_run: Dictionary = {}
var map_view
var map_scroll: ScrollContainer
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
var boss_chest_overlay: Control
var battle_layer: Control
var current_battle
var toast_label: Label
var seed_value: int = 2308
var _interface_initialized: bool = false
var _displayed_act: int = 0

func _ready() -> void:
    initialize_interface()

func initialize_interface() -> void:
    if _interface_initialized:
        return
    _interface_initialized = true
    _build_interface()
    run_session.state_changed.connect(_refresh)
    run_session.execute({"type": "setup_run", "seed": seed_value})

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

    var content := VBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    content.add_child(_build_map_status_strip())
    var map_panel := PanelContainer.new()
    map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    map_panel.add_theme_stylebox_override("panel", _box(Color("111b21"), 14, Color("31535a"), 2, 8))
    map_scroll = ScrollContainer.new()
    map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    map_view = MapViewScript.new()
    map_view.custom_minimum_size = Vector2(1100, 1700)
    map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_view.node_selected.connect(_on_node_selected)
    map_view.node_hovered.connect(func(text: String): hover_label.text = text if text != "" else "选择金色边框节点继续路线")
    map_scroll.add_child(map_view)
    map_panel.add_child(map_scroll)
    content.add_child(map_panel)
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
    boss_chest_overlay = _build_boss_chest_overlay()
    add_child(boss_chest_overlay)
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

func _build_map_status_strip() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 58
    panel.add_theme_stylebox_override("panel", _box(COLORS["panel"], 12, Color("10161b"), 2, 5))
    var box := HBoxContainer.new()
    box.add_theme_constant_override("separation", 18)
    phase_label = Label.new()
    phase_label.custom_minimum_size.x = 260
    phase_label.add_theme_font_size_override("font_size", 14)
    phase_label.add_theme_color_override("font_color", COLORS["gold"])
    box.add_child(phase_label)
    hover_label = Label.new()
    hover_label.text = "选择金色边框节点继续路线"
    hover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hover_label.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(hover_label)
    route_label = Label.new()
    route_label.custom_minimum_size.x = 260
    route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    route_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    route_label.add_theme_font_size_override("font_size", 13)
    route_label.add_theme_color_override("font_color", Color("cbd4d1"))
    box.add_child(route_label)
    var legend := Button.new()
    legend.text = "图例"
    legend.tooltip_text = "始 旅程起点｜战 普通战斗｜精 精英战斗｜? 事件｜息 休息｜藏 宝箱｜首 Boss\n地图不生成商店节点；原商店节点进入事件。"
    _style_button(legend)
    box.add_child(legend)
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

func _build_boss_chest_overlay() -> Control:
    var overlay := ColorRect.new()
    overlay.color = Color(0.018, 0.026, 0.03, 0.94)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    overlay.z_index = 190
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(700, 410)
    panel.add_theme_stylebox_override("panel", _box(Color("2b2520"), 20, COLORS["gold"], 3, 14))
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 20)
    panel.add_child(box)
    var title := Label.new()
    title.text = "第 17 层 · Boss 宝箱"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", Color("ffe4a2"))
    box.add_child(title)
    var description := Label.new()
    description.text = "该楼层不显示在地图中。Boss 宝箱的正式奖励内容尚未确认；当前纵切只验证楼层与层间流程，不补写奖励规则。"
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.add_theme_font_size_override("font_size", 16)
    description.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(description)
    var finish := Button.new()
    finish.text = "完成宝箱流程并进入下一层"
    finish.custom_minimum_size = Vector2(320, 58)
    finish.pressed.connect(_complete_boss_chest)
    _style_button(finish)
    box.add_child(finish)
    return overlay

func _refresh() -> void:
    if map_view == null:
        return
    current_run = run_session.snapshot().to_dict()
    map_view.set_snapshot(current_run)
    var act := int(current_run.get("act", 1))
    var experience := int(current_run.get("experience", 0))
    var phase := str(current_run.get("phase", ""))
    var growth: Dictionary = current_run.get("growth", {})
    if _displayed_act != act:
        _displayed_act = act
        call_deferred("_scroll_map_to_bottom")
    act_label.text = "第 %d / %d 层 · 种子 %d" % [
        act,
        int(current_run.get("act_count", 3)),
        int(current_run.get("seed", 0))]
    experience_label.text = "历练 %d" % experience
    practice_button.text = "♨\n修 习\n历练 %d" % experience
    practice_button.disabled = not bool(current_run.get("can_open_practice", false))
    practice_button.tooltip_text = (
        "打开修习页面" if bool(current_run.get("can_open_practice", false))
        else "当前节点尚未完成，不能修习")
    phase_label.text = {
        "awaiting_node": "当前：等待选择下一节点",
        "node_in_progress": "当前：节点进行中 · 修习已锁定",
        "boss_chest": "当前：第 17 层 Boss 宝箱 · 修习已锁定",
        "run_complete": "第三层 Boss 已击败 · 本局完成",
    }.get(phase, phase)
    route_label.text = "可选 %d　已完成 %d　消耗品 %d/3" % [
        int(current_run.get("available_node_count", 0)),
        int(current_run.get("completed_node_count", 0)),
        growth.get("consumable_ids", []).size()]
    _refresh_practice()

func _refresh_practice() -> void:
    if offers_row == null:
        return
    var practice: Dictionary = current_run.get("practice", {})
    var growth: Dictionary = current_run.get("growth", {})
    var consumables: Array = growth.get("consumables", [])
    practice_experience_label.text = "历练 %d" % int(current_run.get("experience", 0))
    practice_inventory_label.text = "共享消耗品栏  %d / 3  ·  %s" % [
        consumables.size(),
        "、".join(_consumable_names(consumables)) if not consumables.is_empty() else "当前为空"]
    for child in offers_row.get_children():
        child.queue_free()
    for offer_value in practice.get("offers", []):
        offers_row.add_child(_practice_offer(offer_value))

func _practice_offer(offer_value: Dictionary) -> Button:
    var definition := offer_value.duplicate(true)
    var consumable_id := str(definition.get("id", ""))
    var price: int = int(definition.get("price", 0))
    var button := Button.new()
    button.custom_minimum_size = Vector2(290, 330)
    button.text = "%s\n\n%s\n\n%d 历练\n\n%s" % [
        {"insight": "心 得", "pill": "丹 药", "treasure": "天材地宝"}.get(definition.get("kind", ""), "修习物"),
        definition.get("name", "未命名"),
        price,
        "已获得" if bool(definition.get("purchased", false)) else "点击购入共享栏"]
    button.tooltip_text = definition.get("description", "")
    button.add_theme_font_size_override("font_size", 18)
    button.disabled = not bool(definition.get("can_purchase", false))
    button.add_theme_stylebox_override("normal", _box(Color("30283a"), 15, COLORS["purple"], 3, 9))
    button.add_theme_stylebox_override("hover", _box(Color("44344f"), 15, COLORS["gold"], 4, 13))
    button.add_theme_stylebox_override("disabled", _box(Color("25262b"), 15, Color("4c4f55"), 2, 2))
    button.pressed.connect(_buy_consumable.bind(consumable_id))
    return button

func _on_node_selected(node_id: String) -> void:
    var result := run_session.execute({"type": "begin_node", "node_id": node_id})
    if not result.get("success", false):
        _show_toast(result.get("reason", "无法进入节点"))
        return
    var dispatch_result: Dictionary = result.get("dispatch", {})
    _open_dispatched_content(dispatch_result)

func _open_dispatched_content(dispatch_result: Dictionary) -> void:
    match str(dispatch_result.get("route", "")):
        "battle":
            _open_battle(dispatch_result)
        "placeholder":
            _open_noncombat_node(dispatch_result)
        _:
            _show_toast("无法打开节点内容：未知路由")

func _open_battle(dispatch_result: Dictionary) -> void:
    battle_layer.visible = true
    current_battle = BattleScene.instantiate()
    current_battle.configure_battle_session(run_session.create_battle_session())
    current_battle.configure_battle(dispatch_result)
    current_battle.configure_run_context(
        run_session.game_log,
        run_session.progress_snapshot())
    current_battle.battle_finished.connect(_on_battle_finished)
    battle_layer.add_child(current_battle)
    _show_toast(str(dispatch_result.get("message", "进入战斗")))

func _on_battle_finished(outcome: String) -> void:
    if outcome != "player_victory":
        return
    run_session.sync_progress_snapshot(current_battle.player_progress_snapshot())
    current_battle.queue_free()
    current_battle = null
    battle_layer.visible = false
    var result := run_session.execute({"type": "complete_node"})
    if str(result.get("phase", "")) == "boss_chest":
        boss_chest_overlay.visible = true
        _show_toast("Boss 战胜利 · 进入第 17 层 Boss 宝箱")
    else:
        _show_toast("战斗胜利 · 获得 %d 点历练 · 已返回地图" % int(result.get("reward", 0)))

func _open_noncombat_node(dispatch_result: Dictionary) -> void:
    node_title.text = str(dispatch_result.get("title", "特殊节点"))
    node_description.text = str(dispatch_result.get("description", "完成后返回地图。"))
    node_overlay.visible = true

func _complete_noncombat_node() -> void:
    node_overlay.visible = false
    var result := run_session.execute({"type": "complete_node"})
    _show_toast("节点完成 · 返回地图%s" % (
        " · 获得 %d 点历练" % int(result.get("reward", 0)) if int(result.get("reward", 0)) > 0 else ""))

func _complete_boss_chest() -> void:
    var result := run_session.execute({"type": "complete_boss_chest"})
    if not result.get("success", false):
        _show_toast(result.get("reason", "无法完成 Boss 宝箱"))
        return
    boss_chest_overlay.visible = false
    _show_toast("Boss 宝箱流程完成 · 进入第 %d 层地图" % int(result.get("act", 1)))

func _open_practice() -> void:
    var result := run_session.execute({"type": "open_practice"})
    if not result.get("success", false):
        _show_toast(result.get("reason", "当前不能修习"))
        return
    practice_overlay.visible = true
    _refresh_practice()

func _close_practice() -> void:
    run_session.execute({"type": "close_practice"})
    practice_overlay.visible = false

func _buy_consumable(consumable_id: String) -> void:
    var result := run_session.execute({
        "type": "purchase_consumable",
        "consumable_id": consumable_id,
    })
    if result.get("success", false):
        _show_toast("修习完成 · %s进入共享消耗品栏" % result.get("definition", {}).get("name", consumable_id))
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
    boss_chest_overlay.visible = false
    run_session.execute({"type": "setup_run", "seed": seed_value})
    _show_toast("已按种子 %d 生成新路线" % seed_value)

func _consumable_names(consumables: Array) -> Array[String]:
    var names: Array[String] = []
    for consumable_value in consumables:
        var definition: Dictionary = consumable_value
        names.append(str(definition.get("name", definition.get("id", "未命名"))))
    return names

func _scroll_map_to_bottom() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if map_scroll != null:
        map_scroll.scroll_vertical = 100000

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
