extends Control

signal return_to_menu_requested
signal new_run_requested

const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const MapViewScript = preload("res://ui/map_view.gd")
const BattleScene = preload("res://ui/main.tscn")
const UiDesignScript = preload("res://ui/ui_design.gd")
const PracticeOverlayScene = preload("res://ui/components/practice_overlay.tscn")
const RunBuildOverlayScene = preload(
    "res://ui/components/run_build_overlay.tscn")
const RunBuildDTOScript = preload("res://core/run_build_dto.gd")
const RewardOverlayScene = preload("res://ui/components/reward_overlay.tscn")
const PlaceholderPageScene = preload("res://ui/components/node_placeholder_page.tscn")
const ContentFailurePageScript = preload("res://ui/components/content_failure_page.gd")
const RunTerminalOverlayScript = preload(
    "res://ui/components/run_terminal_overlay.gd")
const RunAutosaveCoordinatorScript = preload(
    "res://core/run_autosave_coordinator.gd")
const AutosaveStatusScript = preload(
    "res://ui/components/autosave_status.gd")
const NodeInteractionOverlayScript = preload(
    "res://ui/components/node_interaction_overlay.gd")

const COLORS := UiDesignScript.COLORS

var run_session: RunSession = null
var ai_settings_service: AiSettingsService = null
var composition_root: GameCompositionRoot = null
var current_run: Dictionary = {}
var map_view
var map_scroll: ScrollContainer
var act_label: Label
var experience_label: Label
var life_label: Label
var phase_label: Label
var hover_label: Label
var route_label: Label
var practice_button: Button
var build_button: Button
var abandon_button: Button
var practice_overlay: Control
var run_build_overlay: RunBuildOverlay
var node_overlay: Control
var reward_overlay: Control
var boss_chest_overlay: Control
var battle_layer: Control
var current_battle
var terminal_overlay
var interaction_overlay
var abandon_confirmation: ConfirmationDialog
var toast_label: Label
var autosave_status
var autosave_coordinator
var seed_value: int = 2308
var starter_build_id: String = "standard_52"
var _interface_initialized: bool = false
var _displayed_act: int = 0
var _startup_mode: String = ""
var _resume_policy: String = ""
var _restore_metadata: Dictionary = {}
var _shutdown: bool = false

func _ready() -> void:
    initialize_interface()

func configure_new_run(configuration: Dictionary) -> bool:
    if _interface_initialized or _startup_mode != "":
        push_error("RunMain 新本局启动模式重复配置或配置过晚")
        return false
    _startup_mode = "new"
    seed_value = int(configuration.get("seed", seed_value))
    starter_build_id = str(configuration.get(
        "starter_build_id", starter_build_id))
    return true

func configure_restored_run(
        restored_session,
        resume_policy: String,
        restore_metadata: Dictionary) -> bool:
    if _interface_initialized or _startup_mode != "":
        push_error("RunMain 恢复启动模式重复配置或配置过晚")
        return false
    if restored_session == null:
        push_error("RunMain 恢复启动缺少 RunSession")
        return false
    _startup_mode = "restored"
    run_session = restored_session
    _resume_policy = resume_policy
    _restore_metadata = restore_metadata.duplicate(true)
    return true

func initialize_interface() -> void:
    if _interface_initialized:
        return
    _interface_initialized = true
    theme = UiDesignScript.create_theme()
    if _startup_mode == "":
        push_error("RunMain 必须在 initialize_interface() 前配置新本局或恢复本局")
        return
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
    autosave_coordinator = RunAutosaveCoordinatorScript.new(
        composition_root.run_save_application_service)
    autosave_coordinator.save_succeeded.connect(_on_autosave_succeeded)
    autosave_coordinator.save_failed.connect(_on_autosave_failed)
    autosave_coordinator.bind_session(run_session)
    if _startup_mode == "new":
        var setup := run_session.execute({
            "type": "setup_run",
            "seed": seed_value,
            "starter_build_id": starter_build_id,
        })
        if not setup.success:
            _show_toast(setup.reason_or("无法建立新本局"))
    else:
        autosave_status.present_idle("已载入存档")
        _refresh()
        _apply_resume_policy()

func configure_composition_root(root: GameCompositionRoot) -> void:
    if _interface_initialized:
        return
    composition_root = root

func _ensure_services() -> void:
    if composition_root == null:
        composition_root = GameCompositionRootScript.new()
    composition_root.initialize()
    ai_settings_service = composition_root.ai_settings_service
    if _startup_mode == "new" and run_session == null:
        run_session = composition_root.create_run_session()

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
    map_panel.add_theme_stylebox_override("panel", UiDesignScript.box(Color("111b21"), 14, Color("31535a"), 2, 8))
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
    practice_button.add_theme_stylebox_override("normal", UiDesignScript.box(Color("542f25"), 22, COLORS["gold"], 3, 9))
    practice_button.add_theme_stylebox_override("hover", UiDesignScript.box(Color("75452e"), 22, Color("ffe08a"), 4, 13))
    practice_button.add_theme_stylebox_override("pressed", UiDesignScript.box(Color("3f251f"), 22, Color("fff0b2"), 3, 4))
    practice_button.pressed.connect(_open_practice)
    practice_button.z_index = 50
    add_child(practice_button)

    build_button = Button.new()
    build_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    build_button.offset_left = -350
    build_button.offset_top = -132
    build_button.offset_right = -176
    build_button.offset_bottom = -28
    build_button.add_theme_font_size_override("font_size", 16)
    build_button.add_theme_color_override("font_color", Color("d9f2ec"))
    build_button.add_theme_stylebox_override(
        "normal", UiDesignScript.box(
            Color("24434a"), 18, Color("75a9a7"), 2, 8))
    build_button.add_theme_stylebox_override(
        "hover", UiDesignScript.box(
            Color("315a60"), 18, Color("9bd0c9"), 3, 10))
    build_button.pressed.connect(_open_run_build)
    # 战斗层也允许只读查看构筑，因此入口保持在战斗场景之上。
    build_button.z_index = 350
    add_child(build_button)

    toast_label = Label.new()
    toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    toast_label.offset_left = 300
    toast_label.offset_right = -300
    toast_label.offset_top = -62
    toast_label.offset_bottom = -24
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.add_theme_color_override("font_color", Color("ffe5a0"))
    toast_label.add_theme_stylebox_override("normal", UiDesignScript.box(Color(0.08, 0.11, 0.12, 0.92), 10, Color("66552e"), 1, 2))
    toast_label.visible = false
    toast_label.z_index = 60
    add_child(toast_label)

    practice_overlay = PracticeOverlayScene.instantiate()
    practice_overlay.close_requested.connect(_close_practice)
    practice_overlay.purchase_requested.connect(_buy_consumable)
    practice_overlay.purchase_offer_requested.connect(_buy_practice_offer)
    practice_overlay.pack_selection_requested.connect(_confirm_pack_selection)
    practice_overlay.meditate_requested.connect(_meditate)
    add_child(practice_overlay)
    run_build_overlay = RunBuildOverlayScene.instantiate()
    run_build_overlay.close_requested.connect(_close_run_build)
    run_build_overlay.consumable_query_requested.connect(
        _query_run_consumable)
    run_build_overlay.consumable_use_requested.connect(
        _use_run_consumable)
    run_build_overlay.hand_loadout_save_requested.connect(
        _save_hand_technique_loadout)
    run_build_overlay.inner_skill_loadout_save_requested.connect(
        _save_inner_skill_loadout)
    run_build_overlay.inner_skill_forget_requested.connect(
        _forget_inner_skill)
    add_child(run_build_overlay)
    node_overlay = PlaceholderPageScene.instantiate()
    node_overlay.completed.connect(_complete_noncombat_node)
    node_overlay.configure({
        "title": "特殊节点",
        "description": "完成后返回地图。",
        "action_text": "完成节点并返回地图",
    })
    add_child(node_overlay)
    interaction_overlay = NodeInteractionOverlayScript.new()
    interaction_overlay.commit_requested.connect(_commit_node_interaction)
    interaction_overlay.finish_requested.connect(_finish_node_interaction)
    add_child(interaction_overlay)
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
        "panel_style": UiDesignScript.box(Color("2b2520"), 20, COLORS["gold"], 3, 14),
        "z_index": 190,
    })
    add_child(boss_chest_overlay)
    battle_layer = Control.new()
    battle_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_layer.visible = false
    battle_layer.z_index = 300
    add_child(battle_layer)
    terminal_overlay = RunTerminalOverlayScript.new()
    terminal_overlay.restart_requested.connect(_request_new_run)
    terminal_overlay.return_to_menu_requested.connect(_request_return_to_menu)
    add_child(terminal_overlay)
    abandon_confirmation = ConfirmationDialog.new()
    abandon_confirmation.title = "放弃本局"
    abandon_confirmation.dialog_text = "确定放弃当前本局吗？尚未领取的奖励不会发放。"
    abandon_confirmation.ok_button_text = "确认放弃"
    abandon_confirmation.cancel_button_text = "继续本局"
    abandon_confirmation.confirmed.connect(_confirm_abandon_run)
    add_child(abandon_confirmation)

func _build_top_bar() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 58
    panel.add_theme_stylebox_override("panel", UiDesignScript.box(COLORS["ink"], 12, Color("39464f"), 2, 5))
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
    experience_label = UiDesignScript.pill("历练 0", COLORS["gold"])
    row.add_child(experience_label)
    life_label = UiDesignScript.pill("生命 0/0", Color("d98673"))
    row.add_child(life_label)
    autosave_status = AutosaveStatusScript.new()
    autosave_status.custom_minimum_size.x = 235
    autosave_status.retry_requested.connect(_retry_autosave)
    row.add_child(autosave_status)
    var menu := Button.new()
    menu.text = "返回主菜单"
    menu.tooltip_text = "战斗中返回后，将从当前节点开头继续"
    menu.pressed.connect(_request_return_to_menu)
    UiDesignScript.style_button(menu)
    row.add_child(menu)
    abandon_button = Button.new()
    abandon_button.text = "放弃本局"
    abandon_button.tooltip_text = "结束当前本局（需要二次确认）"
    abandon_button.pressed.connect(_request_abandon_run)
    UiDesignScript.style_button(abandon_button)
    row.add_child(abandon_button)
    panel.add_child(row)
    return panel

func _build_map_status_strip() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 58
    panel.add_theme_stylebox_override("panel", UiDesignScript.box(COLORS["panel"], 12, Color("10161b"), 2, 5))
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
    UiDesignScript.style_button(legend)
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
    life_label.text = "生命 %d/%d" % [
        int(growth.get("life", 0)),
        int(growth.get("max_life", 0))]
    practice_button.text = "♨\n修 习\n历练 %d" % experience
    practice_button.visible = true
    practice_button.disabled = not bool(current_run.get("can_open_practice", false))
    practice_button.tooltip_text = (
        "打开修习页面" if bool(current_run.get("can_open_practice", false))
        else "当前节点尚未完成，不能修习")
    build_button.text = "构 筑\n真气 %d · 消耗品 %d/3" % [
        int(growth.get("run_deck_count", 0)),
        growth.get("consumable_ids", []).size()]
    build_button.visible = (
        not practice_overlay.visible and not run_build_overlay.visible)
    build_button.disabled = false
    build_button.tooltip_text = (
        "查看并编辑本局构筑"
        if phase == "awaiting_node"
        else "查看本局构筑（当前阶段只读）")
    abandon_button.disabled = phase in ["run_complete", "run_terminated"]
    phase_label.text = {
        "awaiting_node": "当前：等待选择下一节点",
        "node_in_progress": "当前：节点进行中 · 修习已锁定",
        "awaiting_reward": "当前：等待领取节点奖励 · 修习已锁定",
        "boss_chest": "当前：第 17 层 Boss 宝箱 · 修习已锁定",
        "run_complete": "第三层 Boss 已击败 · 本局完成",
        "run_terminated": "本局已经终止",
    }.get(phase, phase)
    route_label.text = "可选 %d　已完成 %d　消耗品 %d/3" % [
        int(current_run.get("available_node_count", 0)),
        int(current_run.get("completed_node_count", 0)),
        growth.get("consumable_ids", []).size()]
    _refresh_practice()
    if phase in ["run_complete", "run_terminated"] \
            and not run_build_overlay.visible:
        _show_terminal_overlay()

func _refresh_practice() -> void:
    if practice_overlay == null:
        return
    practice_overlay.present(current_run)

func _on_node_selected(node_id: String) -> void:
    var result := run_session.execute({"type": "begin_node", "node_id": node_id})
    if not result.success:
        _show_toast(result.reason_or("无法进入节点"))
        return
    var dispatch_result: Dictionary = result.payload_value("dispatch", {})
    _open_dispatched_content(dispatch_result)

func _open_dispatched_content(dispatch_result: Dictionary) -> void:
    match str(dispatch_result.get("route", "")):
        "battle":
            _open_battle(dispatch_result)
        "interaction":
            _open_node_interaction()
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

func _on_battle_finished(_outcome: String) -> void:
    if current_battle == null:
        return
    var battle_result = current_battle.final_result()
    var progress_snapshot = current_battle.player_progress_snapshot()
    var result := run_session.execute({
        "type": "resolve_battle_result",
        "battle_result": battle_result,
        "progress_snapshot": progress_snapshot,
    })
    _release_current_battle()
    if not result.success:
        _show_toast(result.reason_or("无法结算战斗结果"))
        return
    match result.phase:
        "awaiting_reward":
            _show_reward_overlay()
        "run_terminated", "run_complete":
            _show_terminal_overlay()

func _open_noncombat_node(dispatch_result: Dictionary) -> void:
    node_overlay.configure({
        "title": str(dispatch_result.get("title", "特殊节点")),
        "description": str(dispatch_result.get("description", "完成后返回地图。")),
        "action_text": "完成节点并返回地图",
    })
    node_overlay.visible = true

func _open_node_interaction() -> void:
    var result := run_session.execute({"type": "query_node_interaction"})
    if not result.success:
        _show_toast(result.reason_or("无法读取节点选择"))
        return
    interaction_overlay.present(
        result.payload_value("interaction", {}))

func _commit_node_interaction(
        interaction_token: String,
        choice_id: String,
        choice_payload: Dictionary) -> void:
    var result := run_session.execute({
        "type": "commit_node_interaction",
        "interaction_token": interaction_token,
        "choice_id": choice_id,
        "choice_payload": choice_payload.duplicate(true),
    })
    if not result.success:
        _show_toast(result.reason_or("无法提交节点选择"))
        return
    if result.phase == "node_in_progress":
        interaction_overlay.present(result.payload_value("interaction", {}))
        return
    interaction_overlay.visible = false
    _show_reward_overlay()

func _finish_node_interaction(interaction_token: String) -> void:
    var result := run_session.execute({
        "type": "finish_node_interaction",
        "interaction_token": interaction_token,
    })
    if not result.success:
        _show_toast(result.reason_or("无法结束节点选择"))
        return
    interaction_overlay.visible = false
    _show_reward_overlay()

func _complete_noncombat_node() -> void:
    node_overlay.visible = false
    var result := run_session.execute({"type": "complete_node"})
    if not result.success:
        _show_toast(result.reason_or("无法建立节点奖励"))
        return
    _show_reward_overlay()

func _show_reward_overlay() -> void:
    var bundle: Dictionary = run_session.snapshot().reward.get("bundle", {})
    reward_overlay.present(bundle)

func _claim_reward(bundle_id: String = "") -> void:
    if bundle_id == "":
        var reward: Dictionary = run_session.snapshot().reward
        bundle_id = str(reward.get("bundle", {}).get("id", ""))
    var result := run_session.execute({
        "type": "claim_reward",
        "bundle_id": bundle_id,
    })
    if not result.success:
        _show_toast(result.reason_or("无法领取奖励"))
        return
    reward_overlay.visible = false
    match result.phase:
        "boss_chest":
            boss_chest_overlay.visible = true
            _show_toast(_interest_toast(
                "Boss 奖励已领取 · 进入第 17 层 Boss 宝箱",
                result.payload_value("experience_interest", {})))
        "run_complete":
            _show_terminal_overlay()
        _:
            _show_toast(_interest_toast(
                "节点奖励已领取 · 当前历练 %d" % int(result.payload_value("experience", 0)),
                result.payload_value("experience_interest", {})))

func _complete_boss_chest() -> void:
    var result := run_session.execute({"type": "complete_boss_chest"})
    if not result.success:
        _show_toast(result.reason_or("无法完成 Boss 宝箱"))
        return
    boss_chest_overlay.visible = false
    _show_toast(_interest_toast(
        "Boss 宝箱流程完成 · 进入第 %d 层地图" % int(result.payload_value("act", 1)),
        result.payload_value("experience_interest", {})))

func _interest_toast(message: String, interest: Dictionary) -> String:
    return "%s · 功行生息 +%d 历练" % [message, int(interest.get("amount", 0))]

func _open_practice() -> void:
    var result := run_session.execute({"type": "open_practice"})
    if not result.success:
        _show_toast(result.reason_or("当前不能修习"))
        return
    practice_overlay.visible = true
    build_button.visible = false
    _refresh_practice()

func _close_practice() -> void:
    run_session.execute({"type": "close_practice"})
    practice_overlay.visible = false
    build_button.visible = true

func _open_run_build() -> void:
    if practice_overlay.visible:
        return
    if _refresh_run_build(false):
        if terminal_overlay != null and terminal_overlay.visible:
            terminal_overlay.visible = false
        run_build_overlay.z_index = 600
        build_button.visible = false

func _close_run_build() -> void:
    run_build_overlay.visible = false
    build_button.visible = true
    if run_session.snapshot().phase in ["run_complete", "run_terminated"]:
        _show_terminal_overlay()

func _refresh_run_build(preserve_drafts: bool) -> bool:
    var result := run_session.execute({"type": "get_run_build"})
    if not result.success:
        _show_toast(result.reason_or("无法读取本局构筑"))
        return false
    var build = RunBuildDTOScript.new().configure(
        result.payload_value("build", {}))
    run_build_overlay.present(build, preserve_drafts)
    return true

func _query_run_consumable(slot_index: int) -> void:
    var result := run_session.execute({
        "type": "query_consumable_use",
        "slot_index": slot_index,
    })
    if not result.success:
        _show_toast(result.reason_or("无法查询消耗品"))
        return
    run_build_overlay.present_consumable_query(
        slot_index, result.payload.duplicate(true))

func _use_run_consumable(
        slot_index: int,
        selected_instance_ids: Array,
        choice_payload: Dictionary) -> void:
    var result := run_session.execute({
        "type": "use_consumable",
        "slot_index": slot_index,
        "selected_instance_ids": selected_instance_ids.duplicate(),
        "choice_payload": choice_payload.duplicate(true),
    })
    if result.success:
        run_build_overlay.close_consumable_dialog()
        _refresh_run_build(false)
        _show_toast(str(result.payload_value(
            "detail", "消耗品已使用")))
        return
    _show_toast(result.reason_or("无法使用消耗品"))
    _refresh_run_build(true)
    _query_run_consumable(slot_index)

func _save_hand_technique_loadout(
        hand_id: String,
        technique_ids: Array) -> void:
    var result := run_session.execute({
        "type": "set_hand_technique_loadout",
        "hand_id": hand_id,
        "technique_ids": technique_ids.duplicate(),
    })
    if result.success:
        run_build_overlay.mark_hand_saved(hand_id)
        _refresh_run_build(false)
        _show_toast("功法序列已保存")
        return
    _show_toast(result.reason_or("无法保存功法序列"))
    _refresh_run_build(true)

func _save_inner_skill_loadout(
        equipped_inner_skill_ids: Array,
        technique_slot_index: int) -> void:
    var result := run_session.execute({
        "type": "set_inner_skill_loadout",
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(),
        "technique_slot_index": technique_slot_index,
    })
    if result.success:
        run_build_overlay.mark_inner_skill_saved()
        _refresh_run_build(false)
        _show_toast("内功配装已保存")
        return
    _show_toast(result.reason_or("无法保存内功配装"))
    _refresh_run_build(true)

func _forget_inner_skill(inner_skill_id: String) -> void:
    var result := run_session.execute({
        "type": "forget_inner_skill",
        "inner_skill_id": inner_skill_id,
    })
    if result.success:
        _refresh_run_build(false)
        _show_toast("遗忘一份内功 · 历练 +%d" % int(
            result.payload_value("forget_value", 0)))
        return
    _show_toast(result.reason_or("无法普通遗忘内功"))
    _refresh_run_build(true)

func _buy_consumable(consumable_id: String) -> void:
    var result := run_session.execute({
        "type": "purchase_consumable",
        "consumable_id": consumable_id,
    })
    if result.success:
        _show_toast("修习完成 · %s进入共享消耗品栏" % result.payload_value("definition", {}).get("name", consumable_id))
    else:
        _show_toast(result.reason_or("无法购买"))
    _refresh()

func _buy_practice_offer(group: String, slot_index: int) -> void:
    if group == "packs":
        var preview := run_session.execute({
            "type": "open_practice_pack",
            "group": group,
            "slot_index": slot_index,
            "selected_ids": [],
        })
        var offered: Array = preview.payload_value("preview", []) if preview.success else []
        if preview.success and not offered.is_empty():
            practice_overlay.present_pack_choices(
                group,
                slot_index,
                offered,
                int(preview.payload_value("minimum_choose_count", 1)),
                int(preview.payload_value("max_choose_count", 0)),
                str(preview.payload_value("preparation_token", "")))
        else:
            _show_toast(preview.reason_or("无法开启补充包"))
        _refresh()
        return
    var result := run_session.execute({
        "type": "purchase_practice_offer",
        "group": group,
        "slot_index": slot_index,
    })
    if result.success:
        _show_toast("修习完成 · 历练 -%d" % int(result.payload_value("price", 0)))
    else:
        _show_toast(result.reason_or("无法购买"))
    _refresh()

func _confirm_pack_selection(
        group: String,
        slot_index: int,
        selected_ids: Array,
        preparation_token: String) -> void:
    var opened := run_session.execute({
        "type": "open_practice_pack",
        "group": group,
        "slot_index": slot_index,
        "selected_ids": selected_ids,
        "preparation_token": preparation_token,
    })
    if opened.success:
        _show_toast("补充包已开启 · 获得 %s" % "、".join(selected_ids))
    else:
        _show_toast(opened.reason_or("无法开启补充包"))
    _refresh()

func _meditate() -> void:
    var result := run_session.execute({"type": "meditate"})
    if result.success:
        _show_toast("冥想完成 · 历练 -%d" % int(result.payload_value("cost", 0)))
    else:
        _show_toast(result.reason_or("无法冥想"))
    _refresh()

func _apply_resume_policy() -> void:
    var phase := str(run_session.snapshot().phase)
    match _resume_policy:
        "resume_boundary":
            match phase:
                "awaiting_node":
                    pass
                "awaiting_reward":
                    _show_reward_overlay()
                "boss_chest":
                    boss_chest_overlay.visible = true
                _:
                    _show_toast("存档阶段与 resume_boundary 不匹配：%s" % phase)
        "restart_node_from_start":
            var resumed := run_session.execute({"type": "resume_current_node"})
            if resumed.success:
                _open_dispatched_content(resumed.payload_value("dispatch", {}))
                _show_toast("战斗从节点开头重新开始")
            else:
                _show_toast(resumed.reason_or("无法从节点开头恢复"))
        "resume_interaction":
            _open_node_interaction()
        "show_terminal":
            _show_terminal_overlay()
        _:
            _show_toast("未知恢复策略：%s" % _resume_policy)
    _present_restore_notice()

func _present_restore_notice() -> void:
    if str(_restore_metadata.get("source", "primary")) != "backup":
        return
    var message := "主存档损坏，已从上一份有效备份恢复。"
    if not bool(_restore_metadata.get("recovery_restored_primary", false)):
        var warning := str(_restore_metadata.get(
            "recovery_warning", "未能恢复主存档文件"))
        message += "\n%s" % warning
    _show_toast(message)

func _request_new_run() -> void:
    new_run_requested.emit()

func _request_return_to_menu() -> void:
    shutdown_interface()
    return_to_menu_requested.emit()

func shutdown_interface() -> void:
    if _shutdown:
        return
    _shutdown = true
    if autosave_coordinator != null:
        autosave_coordinator.unbind_session()
    _release_current_battle()
    if run_session != null:
        run_session.close_active_battle()

func _exit_tree() -> void:
    shutdown_interface()

func _retry_autosave() -> void:
    if autosave_coordinator != null:
        autosave_coordinator.retry_last_save()

func _on_autosave_succeeded(reason: String) -> void:
    autosave_status.present_success(reason)

func _on_autosave_failed(reason: String, detail: String) -> void:
    autosave_status.present_failure(reason, detail)

func _request_abandon_run() -> void:
    if run_session.snapshot().phase in ["run_complete", "run_terminated"]:
        return
    abandon_confirmation.popup_centered()

func _confirm_abandon_run() -> void:
    var result := run_session.execute({"type": "abandon_run"})
    if not result.success:
        _show_toast(result.reason_or("无法放弃本局"))
        return
    _release_current_battle()
    _show_terminal_overlay()

func _release_current_battle() -> void:
    if current_battle != null:
        current_battle.close_battle()
        current_battle.queue_free()
        current_battle = null
    if battle_layer != null:
        battle_layer.visible = false
    if run_session != null:
        run_session.close_active_battle()

func _show_terminal_overlay() -> void:
    var snapshot: Dictionary = run_session.snapshot().to_dict()
    var terminal_result: Dictionary = snapshot.get("terminal_result", {})
    if terminal_result.is_empty():
        return
    practice_overlay.visible = false
    run_build_overlay.visible = false
    node_overlay.visible = false
    interaction_overlay.visible = false
    reward_overlay.visible = false
    boss_chest_overlay.visible = false
    _release_current_battle()
    build_button.visible = true
    build_button.z_index = 550
    terminal_overlay.present(terminal_result, snapshot)

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
