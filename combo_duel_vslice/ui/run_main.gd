extends Control

const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const MapViewScript = preload("res://ui/map_view.gd")
const BattleScene = preload("res://ui/main.tscn")
const UiDesignScript = preload("res://ui/ui_design.gd")
const PracticeOverlayScene = preload("res://ui/components/practice_overlay.tscn")
const RewardOverlayScene = preload("res://ui/components/reward_overlay.tscn")
const PlaceholderPageScene = preload("res://ui/components/node_placeholder_page.tscn")
const ContentFailurePageScript = preload("res://ui/components/content_failure_page.gd")

const COLORS := UiDesignScript.COLORS

var run_session: RunSession = null
var ai_settings_service: AiSettingsService = null
var composition_root: GameCompositionRoot = null
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
var node_overlay: Control
var reward_overlay: Control
var boss_chest_overlay: Control
var battle_layer: Control
var current_battle
var toast_label: Label
var seed_value: int = 2308
var starter_build_id: String = "standard_52"
var _interface_initialized: bool = false
var _displayed_act: int = 0

func _ready() -> void:
    initialize_interface()

func configure_new_run(configuration: Dictionary) -> void:
    seed_value = int(configuration.get("seed", seed_value))
    starter_build_id = str(configuration.get(
        "starter_build_id", starter_build_id))
    if _interface_initialized:
        _ensure_services()
        if run_session == null:
            return
        run_session.execute({
            "type": "setup_run",
            "seed": seed_value,
            "starter_build_id": starter_build_id,
        })

func initialize_interface() -> void:
    if _interface_initialized:
        return
    _interface_initialized = true
    theme = UiDesignScript.create_theme()
    _ensure_services()
    if run_session == null:
        _build_content_failure_page()
        return
    var ai_settings_loaded := true
    if DisplayServer.get_name() != "headless":
        ai_settings_loaded = ai_settings_service.load_or_create()
    run_session.configure_ai_settings_service(ai_settings_service)
    if not ai_settings_loaded:
        run_session.game_log.record_system(
            "error",
            "ai_settings",
            "AI 配置载入失败",
            ai_settings_service.last_error)
    _build_interface()
    run_session.state_changed.connect(_refresh)
    run_session.execute({
        "type": "setup_run",
        "seed": seed_value,
        "starter_build_id": starter_build_id,
    })

func configure_composition_root(root: GameCompositionRoot) -> void:
    if _interface_initialized:
        return
    composition_root = root
    if composition_root == null:
        return
    run_session = composition_root.create_run_session()
    ai_settings_service = composition_root.ai_settings_service

func _ensure_services() -> void:
    if run_session != null:
        return
    composition_root = GameCompositionRootScript.new()
    composition_root.initialize()
    run_session = composition_root.create_run_session()
    ai_settings_service = composition_root.ai_settings_service

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

    practice_overlay = PracticeOverlayScene.instantiate()
    practice_overlay.close_requested.connect(_close_practice)
    practice_overlay.purchase_requested.connect(_buy_consumable)
    add_child(practice_overlay)
    node_overlay = PlaceholderPageScene.instantiate()
    node_overlay.completed.connect(_complete_noncombat_node)
    node_overlay.configure({
        "title": "特殊节点",
        "description": "完成后返回地图。",
        "action_text": "完成节点并返回地图",
    })
    add_child(node_overlay)
    reward_overlay = RewardOverlayScene.instantiate()
    reward_overlay.claim_requested.connect(_claim_reward)
    add_child(reward_overlay)
    boss_chest_overlay = PlaceholderPageScene.instantiate()
    boss_chest_overlay.completed.connect(_complete_boss_chest)
    boss_chest_overlay.configure({
        "title": "第 17 层 · Boss 宝箱",
        "description": "该楼层不显示在地图中。Boss 宝箱的正式奖励内容尚未确认；当前纵切只验证楼层与层间流程，不补写奖励规则。",
        "action_text": "完成宝箱流程并进入下一层",
        "action_size": Vector2(320, 58),
        "panel_size": Vector2(700, 410),
        "panel_style": _box(Color("2b2520"), 20, COLORS["gold"], 3, 14),
        "z_index": 190,
    })
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
    practice_button.visible = bool(current_run.get("debug_menu_enabled", false))
    practice_button.disabled = not bool(current_run.get("can_open_practice", false))
    practice_button.tooltip_text = (
        "打开修习页面" if bool(current_run.get("can_open_practice", false))
        else "当前节点尚未完成，不能修习")
    phase_label.text = {
        "awaiting_node": "当前：等待选择下一节点",
        "node_in_progress": "当前：节点进行中 · 修习已锁定",
        "awaiting_reward": "当前：等待领取节点奖励 · 修习已锁定",
        "boss_chest": "当前：第 17 层 Boss 宝箱 · 修习已锁定",
        "run_complete": "第三层 Boss 已击败 · 本局完成",
    }.get(phase, phase)
    route_label.text = "可选 %d　已完成 %d　消耗品 %d/3" % [
        int(current_run.get("available_node_count", 0)),
        int(current_run.get("completed_node_count", 0)),
        growth.get("consumable_ids", []).size()]
    _refresh_practice()

func _refresh_practice() -> void:
    if practice_overlay == null:
        return
    practice_overlay.present(current_run)

func _on_node_selected(node_id: String) -> void:
    var result: Dictionary = run_session.execute({"type": "begin_node", "node_id": node_id})
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
    var result: Dictionary = run_session.execute({"type": "complete_node"})
    if not result.get("success", false):
        _show_toast(result.get("reason", "无法建立节点奖励"))
        return
    _show_reward_overlay()

func _open_noncombat_node(dispatch_result: Dictionary) -> void:
    node_overlay.configure({
        "title": str(dispatch_result.get("title", "特殊节点")),
        "description": str(dispatch_result.get("description", "完成后返回地图。")),
        "action_text": "完成节点并返回地图",
    })
    node_overlay.visible = true

func _complete_noncombat_node() -> void:
    node_overlay.visible = false
    var result: Dictionary = run_session.execute({"type": "complete_node"})
    if not result.get("success", false):
        _show_toast(result.get("reason", "无法建立节点奖励"))
        return
    _show_reward_overlay()

func _show_reward_overlay() -> void:
    var reward: Dictionary = run_session.snapshot().section("reward")
    var bundle: Dictionary = reward.get("bundle", {})
    reward_overlay.present(bundle)

func _claim_reward(bundle_id: String = "") -> void:
    if bundle_id == "":
        var reward: Dictionary = run_session.snapshot().section("reward")
        bundle_id = str(reward.get("bundle", {}).get("id", ""))
    var result: Dictionary = run_session.execute({
        "type": "claim_reward",
        "bundle_id": bundle_id,
    })
    if not result.get("success", false):
        _show_toast(result.get("reason", "无法领取奖励"))
        return
    reward_overlay.visible = false
    match str(result.get("phase", "")):
        "boss_chest":
            boss_chest_overlay.visible = true
            _show_toast("Boss 奖励已领取 · 进入第 17 层 Boss 宝箱")
        "run_complete":
            _show_toast("节点奖励已领取 · 本局完成")
        _:
            _show_toast("节点奖励已领取 · 当前历练 %d" % int(result.get("experience", 0)))

func _complete_boss_chest() -> void:
    var result: Dictionary = run_session.execute({"type": "complete_boss_chest"})
    if not result.get("success", false):
        _show_toast(result.get("reason", "无法完成 Boss 宝箱"))
        return
    boss_chest_overlay.visible = false
    _show_toast("Boss 宝箱流程完成 · 进入第 %d 层地图" % int(result.get("act", 1)))

func _open_practice() -> void:
    var result: Dictionary = run_session.execute({"type": "open_practice"})
    if not result.get("success", false):
        _show_toast(result.get("reason", "当前不能修习"))
        return
    practice_overlay.visible = true
    _refresh_practice()

func _close_practice() -> void:
    run_session.execute({"type": "close_practice"})
    practice_overlay.visible = false

func _buy_consumable(consumable_id: String) -> void:
    var result: Dictionary = run_session.execute({
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
    reward_overlay.visible = false
    boss_chest_overlay.visible = false
    run_session.execute({
        "type": "setup_run",
        "seed": seed_value,
        "starter_build_id": starter_build_id,
    })
    _show_toast("已按种子 %d 生成新路线" % seed_value)

func _scroll_map_to_bottom() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if map_scroll != null:
        map_scroll.scroll_vertical = 100000

func _build_content_failure_page() -> void:
    var page := ContentFailurePageScript.new()
    add_child(page)
    page.present(
        "内容校验失败，无法进入本局",
        composition_root.content_errors()
        if composition_root != null
        else ["组合根未创建"] as Array[String])

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
    UiDesignScript.style_button(button)

func _divider() -> HSeparator:
    return UiDesignScript.divider()

func _box(fill: Color, radius: int, border: Color, border_width: int, shadow: int) -> StyleBoxFlat:
    return UiDesignScript.box(fill, radius, border, border_width, shadow)
