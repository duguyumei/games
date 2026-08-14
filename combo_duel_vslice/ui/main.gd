extends Control

signal battle_finished(outcome: String)

const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const FeltBackgroundScript = preload("res://ui/felt_background.gd")
const QiCardViewScript = preload("res://ui/qi_card_view.gd")
const UiDesignScript = preload("res://ui/ui_design.gd")
const ActorStatusScene = preload("res://ui/components/battle_actor_status.tscn")
const HandZoneScene = preload("res://ui/components/battle_hand_zone.tscn")
const LoadoutScene = preload("res://ui/components/battle_loadout_view.tscn")
const TechniqueSequenceScene = preload("res://ui/components/technique_sequence_view.tscn")
const TriggerLogScene = preload("res://ui/components/trigger_log_view.tscn")
const ValuePanelScript = preload("res://ui/components/battle_value_panel.gd")

const COLORS := UiDesignScript.COLORS

var battle_session: BattleSession = null
var run_progress: RunProgressSnapshot
var battle_configuration: Dictionary = {}
var selected_ids: Array[String] = []
var _battle_finish_emitted: bool = false

var seed_input: SpinBox
var player_actor_status
var enemy_actor_status
var enemy_hand_row: HBoxContainer
var enemy_hand_count_label: Label
var loadout_view
var active_consumable_slot: int = -1

var round_badge: Label
var value_panel: BattleValuePanel
var zone_counts_label: Label
var confirm_button: Button

var technique_sequence_view
var staging_row: HBoxContainer
var staging_hint: Label
var board_message: Label
var hand_zone
var active_log_channel: String = "battle"
var trigger_log_view
var resolution_strip: Label

func _ready() -> void:
    _ensure_battle_session()
    theme = UiDesignScript.create_theme()
    _build_interface()
    battle_session.state_changed.connect(_refresh)
    if not battle_configuration.is_empty():
        seed_input.value = int(battle_configuration.get("content_seed", seed_input.value))
    _reset_battle()

func _process(_delta: float) -> void:
    battle_session.poll_ai_timeout()

func configure_battle(configuration: Dictionary) -> void:
    battle_configuration = configuration.duplicate(true)

func configure_battle_session(session: BattleSession) -> void:
    if session != null:
        battle_session = session

func _ensure_battle_session() -> void:
    if battle_session == null:
        battle_session = BattleSessionScript.new(CombatEngineScript.new())

func configure_ai_provider(provider) -> void:
    battle_session.use_ai_provider(provider)

func configure_ai_provider_settings(config: Dictionary) -> void:
    battle_session.configure_ai_provider(config)

func configure_run_context(
        shared_game_log,
        progress_snapshot: RunProgressSnapshot) -> void:
    if shared_game_log == null:
        return
    battle_session.use_game_log(shared_game_log)
    run_progress = progress_snapshot

func player_progress_snapshot() -> RunProgressSnapshot:
    return battle_session.player_progress_snapshot()

func final_result():
    return battle_session.final_result()

func close_battle() -> bool:
    return battle_session.close_battle()

func _build_interface() -> void:
    var background = FeltBackgroundScript.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 14)
    outer.add_theme_constant_override("margin_right", 14)
    outer.add_theme_constant_override("margin_top", 8)
    outer.add_theme_constant_override("margin_bottom", 8)
    add_child(outer)

    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 6)
    outer.add_child(page)
    page.add_child(_build_top_bar())

    var content := HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    content.add_child(_build_left_console())
    content.add_child(_build_table())
    page.add_child(content)
    trigger_log_view = TriggerLogScene.instantiate()
    trigger_log_view.close_requested.connect(_toggle_log_overlay)
    trigger_log_view.channel_toggle_requested.connect(_toggle_log_channel)
    add_child(trigger_log_view)

func _build_top_bar() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 46
    panel.add_theme_stylebox_override("panel", UiDesignScript.box(COLORS["ink"], 10, Color("3b4650"), 2, 6))
    var bar := HBoxContainer.new()
    bar.add_theme_constant_override("separation", 12)
    var mark := Label.new()
    mark.text = "◈"
    mark.add_theme_font_size_override("font_size", 25)
    mark.add_theme_color_override("font_color", COLORS["gold"])
    bar.add_child(mark)
    var title := Label.new()
    title.text = "组合出招"
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", COLORS["cream"])
    bar.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "真气牌型战斗 · 第一阶段纵切"
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", COLORS["muted"])
    subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(subtitle)
    var log_button := Button.new()
    log_button.text = "结算记录"
    log_button.tooltip_text = "展开调试用完整触发历史"
    log_button.pressed.connect(_toggle_log_overlay)
    UiDesignScript.style_button(log_button)
    bar.add_child(log_button)
    var seed_label := Label.new()
    seed_label.text = "种子"
    seed_label.add_theme_color_override("font_color", COLORS["muted"])
    bar.add_child(seed_label)
    seed_input = SpinBox.new()
    seed_input.min_value = 0
    seed_input.max_value = 99999999
    seed_input.value = 2308
    seed_input.custom_minimum_size.x = 120
    bar.add_child(seed_input)
    var reset := Button.new()
    reset.text = "↻  重置"
    reset.pressed.connect(_reset_battle)
    UiDesignScript.style_button(reset)
    bar.add_child(reset)
    panel.add_child(bar)
    return panel

func _build_left_console() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.x = 258
    panel.add_theme_stylebox_override("panel", UiDesignScript.box(COLORS["panel"], 13, Color("0b1216"), 3, 10))
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 9)

    round_badge = Label.new()
    round_badge.text = "第 1 回合"
    round_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    round_badge.add_theme_font_size_override("font_size", 14)
    round_badge.add_theme_color_override("font_color", COLORS["gold"])
    box.add_child(round_badge)
    box.add_child(UiDesignScript.divider())

    var player_title := Label.new()
    player_title.text = "太吾 · 战斗状态"
    player_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    player_title.add_theme_font_size_override("font_size", 17)
    box.add_child(player_title)
    player_actor_status = ActorStatusScene.instantiate()
    player_actor_status.configure({"meter_width": 166.0, "hide_name": true})
    box.add_child(player_actor_status)
    box.add_child(UiDesignScript.divider())

    value_panel = ValuePanelScript.new()
    box.add_child(value_panel)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(spacer)

    confirm_button = Button.new()
    confirm_button.text = "出  招"
    confirm_button.custom_minimum_size.y = 62
    confirm_button.add_theme_font_size_override("font_size", 24)
    confirm_button.add_theme_color_override("font_color", Color("fff4d2"))
    confirm_button.add_theme_stylebox_override("normal", UiDesignScript.box(COLORS["orange"], 12, Color("5f2c18"), 3, 7))
    confirm_button.add_theme_stylebox_override("hover", UiDesignScript.box(COLORS["orange"].lightened(0.12), 12, COLORS["gold"], 3, 10))
    confirm_button.add_theme_stylebox_override("pressed", UiDesignScript.box(COLORS["orange"].darkened(0.12), 12, Color("ffe8a6"), 3, 3))
    confirm_button.pressed.connect(_confirm_play)
    box.add_child(confirm_button)

    var turn_buttons := HBoxContainer.new()
    turn_buttons.add_theme_constant_override("separation", 6)
    var start_turn := Button.new()
    start_turn.text = "补牌"
    start_turn.tooltip_text = "回合开始：补至当前手牌上限"
    start_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start_turn.pressed.connect(_start_turn)
    UiDesignScript.style_button(start_turn)
    turn_buttons.add_child(start_turn)
    var end_turn := Button.new()
    end_turn.text = "结束回合"
    end_turn.tooltip_text = "结束玩家回合并推进延迟功法"
    end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    end_turn.pressed.connect(_end_turn)
    UiDesignScript.style_button(end_turn)
    turn_buttons.add_child(end_turn)
    box.add_child(turn_buttons)

    zone_counts_label = Label.new()
    zone_counts_label.text = "牌库 44   手牌 8   弃牌 0"
    zone_counts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    zone_counts_label.add_theme_font_size_override("font_size", 12)
    zone_counts_label.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(zone_counts_label)
    panel.add_child(box)
    return panel

func _build_table() -> Control:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UiDesignScript.box(Color(0.035, 0.19, 0.15, 0.58), 15, Color("2a6b58"), 2, 9))
    var board := VBoxContainer.new()
    board.add_theme_constant_override("separation", 5)
    board.add_child(_build_enemy_strip())
    board.add_child(_build_enemy_hand_strip())
    board.add_child(_build_loadout_strip())
    board.add_child(_build_technique_strip())
    resolution_strip = Label.new()
    resolution_strip.text = "结算播报 · 等待出招"
    resolution_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    resolution_strip.custom_minimum_size.y = 22
    resolution_strip.add_theme_font_size_override("font_size", 11)
    resolution_strip.add_theme_color_override("font_color", Color("e8d9a7"))
    resolution_strip.add_theme_stylebox_override("normal", UiDesignScript.box(Color(0.08, 0.12, 0.12, 0.74), 7, Color("3d5d57"), 1, 1))
    board.add_child(resolution_strip)
    board.add_child(_build_staging_zone())
    board.add_child(_build_hand_fan())
    panel.add_child(board)
    return panel

func _build_enemy_strip() -> Control:
    enemy_actor_status = ActorStatusScene.instantiate()
    enemy_actor_status.configure({
        "minimum_height": 92.0,
        "meter_width": 310.0,
        "portrait": "敌",
        "panel_style": UiDesignScript.box(Color(0.08, 0.12, 0.13, 0.88), 10, Color("25383d"), 1, 3),
    })
    return enemy_actor_status

func _build_enemy_hand_strip() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 50
    panel.add_theme_stylebox_override("panel", UiDesignScript.box(Color(0.045, 0.1, 0.1, 0.62), 9, Color("28443e"), 1, 2))
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 5)
    var caption := Label.new()
    caption.text = "手牌"
    caption.custom_minimum_size.x = 34
    caption.add_theme_font_size_override("font_size", 11)
    caption.add_theme_color_override("font_color", COLORS["muted"])
    row.add_child(caption)
    enemy_hand_row = HBoxContainer.new()
    enemy_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
    enemy_hand_row.add_theme_constant_override("separation", -12)
    row.add_child(enemy_hand_row)
    enemy_hand_count_label = UiDesignScript.chip("0 / 8", Color("485d69"))
    row.add_child(enemy_hand_count_label)
    panel.add_child(row)
    return panel

func _enemy_hand_back() -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(32, 42)
    card.rotation = deg_to_rad(-1.5)
    card.add_theme_stylebox_override("panel", UiDesignScript.box(Color("4f356f"), 6, Color("9c78c5"), 2, 2))
    var mark := Label.new()
    mark.text = "◇"
    mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mark.add_theme_font_size_override("font_size", 13)
    mark.add_theme_color_override("font_color", Color("e8d9f0"))
    card.add_child(mark)
    return card

func _build_loadout_strip() -> Control:
    loadout_view = LoadoutScene.instantiate()
    loadout_view.technique_slot_move_requested.connect(_move_technique_slot)
    loadout_view.consumable_selected.connect(_select_consumable_slot)
    loadout_view.consumable_use_requested.connect(_use_active_consumable)
    return loadout_view

func _build_technique_strip() -> Control:
    technique_sequence_view = TechniqueSequenceScene.instantiate()
    return technique_sequence_view

func _build_staging_zone() -> Control:
    var panel := PanelContainer.new()
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size.y = 165
    panel.add_theme_stylebox_override("panel", UiDesignScript.box(Color(0.03, 0.15, 0.12, 0.5), 14, Color(0.36, 0.76, 0.62, 0.18), 2, 3))
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    var title := Label.new()
    title.text = "待 出 区"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", Color(0.7, 0.9, 0.82, 0.72))
    box.add_child(title)
    var center := CenterContainer.new()
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    staging_row = HBoxContainer.new()
    staging_row.alignment = BoxContainer.ALIGNMENT_CENTER
    staging_row.add_theme_constant_override("separation", 7)
    center.add_child(staging_row)
    box.add_child(center)
    staging_hint = Label.new()
    staging_hint.text = "从手牌选择 1～5 张真气"
    staging_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    staging_hint.add_theme_color_override("font_color", Color(0.76, 0.86, 0.81, 0.5))
    box.add_child(staging_hint)
    board_message = Label.new()
    board_message.text = "选牌后即时识别精确牌型"
    board_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    board_message.add_theme_font_size_override("font_size", 12)
    board_message.add_theme_color_override("font_color", COLORS["gold"])
    box.add_child(board_message)
    panel.add_child(box)
    return panel

func _build_hand_fan() -> Control:
    hand_zone = HandZoneScene.instantiate()
    hand_zone.card_pressed.connect(_on_card_pressed)
    return hand_zone

func _toggle_log_overlay() -> void:
    trigger_log_view.visible = not trigger_log_view.visible

func _toggle_log_channel() -> void:
    active_log_channel = "system" if active_log_channel == "battle" else "battle"
    _refresh()

func _reset_battle() -> void:
    selected_ids.clear()
    active_consumable_slot = -1
    _battle_finish_emitted = false
    var configuration := battle_configuration.duplicate(true)
    configuration["content_seed"] = int(seed_input.value)
    battle_session.setup_battle(configuration, run_progress)
    battle_session.execute({"type": "start_turn"})
    _refresh()

func _start_turn() -> void:
    selected_ids.clear()
    var current := battle_session.snapshot()
    if current.battle_state != "active":
        _refresh()
        return
    if current.actions_available > 0 or current.enemy_actions_available > 0:
        board_message.text = "当前击仍有出牌机会；先出招或结束回合"
        return
    if not current.round_ended:
        battle_session.execute({"type": "end_turn"})
    battle_session.execute({"type": "start_turn"})
    _refresh()

func _end_turn() -> void:
    selected_ids.clear()
    var result := battle_session.execute({"type": "end_turn"})
    if not result.success:
        board_message.text = str(result.reason_or("暂时不能结束回合"))
    _refresh()

func _confirm_play() -> void:
    var result := battle_session.execute({
        "type": "play_cards",
        "card_ids": selected_ids.duplicate(),
    })
    if not result.success:
        board_message.text = str(result.reason_or("无法出招"))
    selected_ids.clear()
    _refresh()

func _select_consumable_slot(slot_index: int) -> void:
    var player_state := battle_session.snapshot().player
    if slot_index < 0 or slot_index >= player_state.consumables.size():
        return
    if active_consumable_slot == slot_index:
        active_consumable_slot = -1
    else:
        active_consumable_slot = slot_index
        selected_ids.clear()
    _refresh()

func _use_active_consumable() -> void:
    if active_consumable_slot < 0:
        return
    var result := battle_session.execute({
        "type": "use_consumable",
        "slot_index": active_consumable_slot,
        "card_ids": selected_ids.duplicate(),
    })
    if not result.success:
        board_message.text = str(result.reason_or("无法使用消耗品"))
    else:
        var retained: Array[String] = []
        var hand: Array = battle_session.snapshot().player.hand
        for card_id in selected_ids:
            if not _find_card_snapshot(hand, card_id).is_empty():
                retained.append(card_id)
        selected_ids = retained
        active_consumable_slot = -1
        run_progress = battle_session.player_progress_snapshot()
    _refresh()

func _on_card_pressed(card_id: String) -> void:
    if selected_ids.has(card_id):
        selected_ids.erase(card_id)
    elif active_consumable_slot >= 0:
        var consumables: Array = battle_session.snapshot().player.consumables
        if active_consumable_slot >= consumables.size():
            return
        var limits: Dictionary = consumables[active_consumable_slot].get("targeting_limits", {})
        if limits["zone"] == "none":
            board_message.text = "该消耗品不需要选择真气"
            return
        if selected_ids.size() >= int(limits["maximum"]):
            board_message.text = "该消耗品至多选择 %d 张真气" % int(limits["maximum"])
            return
        selected_ids.append(card_id)
    elif selected_ids.size() < 5:
        selected_ids.append(card_id)
    else:
        board_message.text = "一次最多选择 5 张真气"
        return
    _refresh()

func _refresh() -> void:
    if player_actor_status == null:
        return
    var current := battle_session.snapshot()
    var player_state := current.player
    var enemy_state := current.enemy
    var possible_intents: Array = current.possible_enemy_intents
    var ai_decision: Dictionary = current.ai_decision
    var ai_state := str(ai_decision.get("state", "disabled"))
    var ai_state_label: String = {
        "thinking": "思考中…",
        "ready": "已准备",
        "fallback_ready": "本地接管",
        "no_enemy_action": "本击不出手",
        "failed": "行动失败",
        "local_utility": "本地策略",
        "disabled": "固定行动",
        "idle": "等待窗口",
    }.get(ai_state, ai_state)
    var player_statuses: Array = [{
        "text": "连势 %d" % player_state.momentum_value,
        "color": COLORS["orange"],
    }, {
        "text": "同气 %d/%d" % [
            player_state.same_qi_value, player_state.same_qi_capacity],
        "color": COLORS["blue"],
    }, {
        "text": "毒量 %d · 手牌%d/%d · 牌库%d/%d" % [
            player_state.poison_total_amount,
            player_state.poison_hand_count, player_state.poison_hand_amount,
            player_state.poison_draw_pile_count, player_state.poison_draw_pile_amount],
        "color": COLORS["green"],
    }]
    if player_state.current_reflection_percent > 0:
        player_statuses.append({
            "text": "反震 %d%%" % player_state.current_reflection_percent,
            "color": COLORS["purple"],
        })
    if not player_state.block_sources.is_empty():
        player_statuses.append({
            "text": "格挡 %d" % player_state.block_sources.size(),
            "color": COLORS["blue"],
        })
    if not player_state.challenge_records.is_empty():
        player_statuses.append({
            "text": "邀战 %d" % player_state.challenge_records.size(),
            "color": COLORS["red"],
        })
    var enemy_statuses: Array = [
        {"text": "连势 %d" % enemy_state.momentum_value, "color": COLORS["orange"]},
        {"text": "同气 %d/%d" % [
            enemy_state.same_qi_value, enemy_state.same_qi_capacity],
            "color": COLORS["blue"]},
        {"text": "毒量 %d · 手牌%d/%d · 牌库%d/%d" % [
            enemy_state.poison_total_amount,
            enemy_state.poison_hand_count, enemy_state.poison_hand_amount,
            enemy_state.poison_draw_pile_count, enemy_state.poison_draw_pile_amount],
            "color": COLORS["green"]},
    ]
    if enemy_state.current_reflection_percent > 0:
        enemy_statuses.append({
            "text": "反震 %d%%" % enemy_state.current_reflection_percent,
            "color": COLORS["purple"],
        })
    if not enemy_state.block_sources.is_empty():
        enemy_statuses.append({
            "text": "格挡 %d" % enemy_state.block_sources.size(),
            "color": COLORS["blue"],
        })
    if not enemy_state.challenge_records.is_empty():
        enemy_statuses.append({
            "text": "邀战 %d" % enemy_state.challenge_records.size(),
            "color": COLORS["red"],
        })
    player_actor_status.present({
        "name": "太吾 · 战斗状态",
        "life": player_state.life,
        "max_life": player_state.max_life,
        "defense": player_state.defense,
        "statuses": player_statuses,
    })
    enemy_actor_status.present({
        "name": enemy_state.name,
        "life": enemy_state.life,
        "max_life": enemy_state.max_life,
        "defense": enemy_state.defense,
        "statuses": enemy_statuses,
        "plans": _enemy_intent_chips(ai_state_label, possible_intents),
    })
    enemy_hand_count_label.text = "%d / %d%s" % [
        enemy_state.hand_count,
        enemy_state.hand_limit,
        " · 已计划" if ai_state in ["ready", "fallback_ready"] else "",
    ]
    round_badge.text = "第 %d 回合 · 我方 %d / 对手 %d 次" % [
        current.turn_number,
        current.actions_available,
        current.enemy_actions_available]
    if current.battle_state != "active":
        round_badge.text = current.battle_state_detail
    zone_counts_label.text = "牌库 %d   手牌 %d/%d   弃牌 %d" % [
        player_state.draw_count,
        player_state.hand_count,
        player_state.hand_limit,
        player_state.discard_count,
    ]
    var consumables: Array = player_state.consumables
    if active_consumable_slot >= consumables.size():
        active_consumable_slot = -1
    hand_zone.present(player_state, selected_ids)
    _refresh_enemy_hand(enemy_state)
    loadout_view.present(
        player_state, active_consumable_slot, _active_consumable_targets_valid(player_state))
    _refresh_preview_and_staging(current, player_state)
    _refresh_log(current)
    confirm_button.disabled = (
        selected_ids.is_empty()
        or active_consumable_slot >= 0
        or current.actions_available <= 0
        or not bool(ai_decision.get("can_player_confirm", true))
        or current.battle_state != "active")
    if current.battle_state != "active" and not _battle_finish_emitted:
        _battle_finish_emitted = true
        run_progress = battle_session.player_progress_snapshot()
        battle_finished.emit.call_deferred(current.battle_state)

func _enemy_intent_chips(ai_state_label: String, intents: Array) -> Array:
    var result: Array = [{
        "text": ai_state_label,
        "color": COLORS["purple"],
        "tooltip": "敌方决策状态；已准备只表示内部选择完成，不公开实际选择",
    }]
    for intent_value in intents.slice(0, 5):
        var intent: Dictionary = intent_value
        var detail := "预计伤害 %d｜预计防御 %d｜预计同气 +%d｜打出约 %d 张" % [
            int(intent.get("damage", 0)), int(intent.get("defense", 0)),
            int(intent.get("same_qi_gain", 0)),
            int(intent.get("played_count", 0))]
        var tags: Array = intent.get("public_tags", [])
        if not tags.is_empty():
            detail += "｜" + "｜".join(tags)
        result.append({
            "text": str(intent.get("display_name", "可能意图")),
            "color": _intent_color(str(intent.get("direction", "prepare"))),
            "tooltip": detail,
            "minimum_width": 58.0,
        })
    return result

func _intent_color(direction: String) -> Color:
    match direction:
        "assault": return COLORS["red"]
        "survival": return COLORS["blue"]
        "cycle": return COLORS["green"]
        "develop": return COLORS["orange"]
        "control": return COLORS["purple"]
    return COLORS["gold"]

func _count_card_anomaly(cards: Array, category: String, anomaly_id: String) -> int:
    var count := 0
    for card_value in cards:
        var card: Dictionary = card_value
        var anomalies: Dictionary = card.get("anomalies", {})
        var matched := false
        if category in ["poison", "state"]:
            matched = str(anomalies.get(category, "")) == anomaly_id
        elif category == "mark":
            matched = anomalies.get("marks", {}).has(anomaly_id)
        elif category == "other":
            matched = anomalies.get("others", {}).has(anomaly_id)
        if matched:
            count += 1
    return count

func _active_consumable_targets_valid(player_state: BattleSideSnapshot = null) -> bool:
    if player_state == null:
        player_state = battle_session.snapshot().player
    if active_consumable_slot < 0 \
            or active_consumable_slot >= player_state.consumables.size():
        return false
    return bool(battle_session.validate_consumable_targets(
        active_consumable_slot,
        selected_ids).get("ok", false))

func _refresh_enemy_hand(enemy_state: BattleSideSnapshot) -> void:
    for child in enemy_hand_row.get_children():
        child.queue_free()
    var visible_cards := mini(enemy_state.hand_count, 10)
    for _index in range(visible_cards):
        enemy_hand_row.add_child(_enemy_hand_back())

func _move_technique_slot(direction: int) -> void:
    battle_session.execute({
        "type": "move_technique_slot",
        "direction": direction,
    })
    _refresh()

func _refresh_preview_and_staging(
        current: BattleSnapshot,
        player_state: BattleSideSnapshot) -> void:
    for child in staging_row.get_children():
        child.queue_free()
    if active_consumable_slot >= 0 \
            and active_consumable_slot < player_state.consumables.size():
        _refresh_consumable_targeting(player_state)
        return
    if selected_ids.is_empty():
        value_panel.present_idle()
        technique_sequence_view.present({
            "current_name": "等待选牌",
            "description": "结算顺序：%s" % " → ".join(battle_session.combat_order_labels()),
            "next_name": "—",
            "pips": "○ ○",
        })
        if not current.last_player_action_cards.is_empty() \
                or not current.last_enemy_action_cards.is_empty():
            staging_hint.visible = false
            _show_last_synchronized_reveal(current)
        else:
            staging_hint.visible = true
            board_message.text = (
                current.battle_state_detail
                if current.battle_state != "active"
                else "对手计划已公开 · 牌型与真气保持隐藏")
        return

    var preview: Dictionary = battle_session.preview(selected_ids)
    if not preview.get("valid", false):
        value_panel.present_invalid()
        board_message.text = preview.get("reason", "选择无效")
        return
    staging_hint.visible = false
    var contributing_ids: Array = preview["hand"].get("contributing_card_ids", [])
    for card in preview["cards"]:
        var compact_view = QiCardViewScript.new()
        compact_view.setup(card, contributing_ids.has(card.get("id", "")), true, false)
        staging_row.add_child(compact_view)

    var hand: Dictionary = preview["hand"]
    var values: Dictionary = preview["values"]
    var technique: Dictionary = preview["technique"]
    var next_technique: Dictionary = preview["next_technique"]
    var condition_ok: bool = preview["condition"]["ok"]
    var inner_defense: int = int(preview.get("intent", {}).get("inner_skill_defense", 0))
    value_panel.present_preview(
        hand, values, technique, inner_defense,
        int(preview.get("same_qi_gain", 0)))
    var technique_name: String = technique.get("name", "空序列")
    var condition_text := "条件满足" if condition_ok else "条件失败：%s" % preview["condition"]["reason"]
    var next_name: String = next_technique.get("name", "空序列")
    technique_sequence_view.present({
        "current_name": technique_name,
        "description": "%s · 顺序：%s" % [
            condition_text, " → ".join(battle_session.combat_order_labels(technique_name))],
        "next_name": next_name,
        "pips": "●  ○" if technique_name != next_name else "●",
    })
    var contributing_count: int = hand.get("contributing_card_ids", []).size()
    board_message.text = "%s · %d 张参与数值计算 · P = %d · 同气 +%d · 内功防御 +%d · 对手计划已锁定" % [
        hand["name"], contributing_count, values["technique_value"],
        int(preview.get("same_qi_gain", 0)), inner_defense]

func _refresh_consumable_targeting(player_state: BattleSideSnapshot) -> void:
    var definition: Dictionary = player_state.consumables[active_consumable_slot]
    var limits: Dictionary = definition.get("targeting_limits", {})
    var hand: Array = player_state.hand
    for card_id in selected_ids:
        var card := _find_card_snapshot(hand, card_id)
        if card.is_empty():
            continue
        var compact_view = QiCardViewScript.new()
        compact_view.setup(card, true, true, false)
        staging_row.add_child(compact_view)
    value_panel.present_consumable(definition)
    technique_sequence_view.present({
        "current_name": definition.get("name", "消耗品"),
        "description": "纵切调试构筑入口",
        "next_name": "使用后释放槽位",
        "pips": "◆",
    })
    staging_hint.visible = selected_ids.is_empty() and limits["zone"] != "none"
    if limits["zone"] == "none":
        staging_hint.text = "无需选择真气，直接点击使用"
    else:
        staging_hint.text = "选择 %d～%d 张当前手牌" % [limits["minimum"], limits["maximum"]]
    board_message.text = "%s · 已选 %d / %d 张%s" % [
        definition.get("description", ""), selected_ids.size(), limits["maximum"],
        " · 可以使用" if _active_consumable_targets_valid(player_state) else ""]

func _show_last_synchronized_reveal(current: BattleSnapshot) -> void:
    var player_action_cards: Array = current.last_player_action_cards
    var enemy_action_cards: Array = current.last_enemy_action_cards
    var player_preview: Dictionary = current.last_preview
    var enemy_preview: Dictionary = current.last_enemy_preview
    if not player_action_cards.is_empty():
        staging_row.add_child(UiDesignScript.caption("我方"))
        var player_contributing: Array = player_preview.get("hand", {}).get("contributing_card_ids", [])
        for card in player_action_cards:
            var player_view = QiCardViewScript.new()
            player_view.setup(card, player_contributing.has(card.get("id", "")), true, false)
            staging_row.add_child(player_view)
    if not enemy_action_cards.is_empty():
        var divider := Label.new()
        divider.text = "  对  "
        divider.add_theme_font_size_override("font_size", 14)
        divider.add_theme_color_override("font_color", COLORS["gold"])
        staging_row.add_child(divider)
        staging_row.add_child(UiDesignScript.caption("对手"))
        var enemy_contributing: Array = enemy_preview.get("hand", {}).get("contributing_card_ids", [])
        for card in enemy_action_cards:
            var enemy_view = QiCardViewScript.new()
            enemy_view.setup(card, enemy_contributing.has(card.get("id", "")), true, false)
            staging_row.add_child(enemy_view)
    var player_hand_name: String = player_preview.get("hand", {}).get("name", "未出牌")
    board_message.text = "同步结算 · 我方 %s / 对手已出招" % player_hand_name
    if current.battle_state != "active":
        board_message.text += " · %s" % current.battle_state_detail

func _refresh_log(current: BattleSnapshot) -> void:
    var battle_history: Array = current.battle_log
    trigger_log_view.present({
        "channel": active_log_channel,
        "history": current.log_channel(active_log_channel),
        "delayed_count": current.delayed_count,
    })
    if battle_history.is_empty():
        resolution_strip.text = "结算播报 · 等待出招"
    else:
        var latest: Dictionary = battle_history[battle_history.size() - 1]
        var latest_status := str(latest.get("context", {}).get("status", ""))
        var latest_detail: String = latest.get("detail", "")
        resolution_strip.text = "结算播报 · %s · %s%s" % [
            latest.get("message", ""),
            latest_status,
            " · %s" % latest_detail if latest_detail != "" else "",
        ]

func _find_card_snapshot(cards: Array, card_id: String) -> Dictionary:
    for card_value in cards:
        var card: Dictionary = card_value
        if str(card.get("id", "")) == card_id:
            return card
    return {}
