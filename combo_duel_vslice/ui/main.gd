extends Control

signal battle_finished(outcome: String)

const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const FeltBackgroundScript = preload("res://ui/felt_background.gd")
const QiCardViewScript = preload("res://ui/qi_card_view.gd")

const COLORS := {
    "ink": Color("15171c"),
    "panel": Color("1b2028"),
    "panel_2": Color("252c36"),
    "panel_3": Color("303844"),
    "cream": Color("f3ead2"),
    "muted": Color("a7b1b2"),
    "gold": Color("f0bd4e"),
    "orange": Color("d97832"),
    "red": Color("d64d48"),
    "blue": Color("3c82bb"),
    "green": Color("3f9c67"),
    "purple": Color("835bb4"),
}

var battle_session = BattleSessionScript.new(CombatEngineScript.new())
var run_progress
var battle_configuration: Dictionary = {}
var selected_ids: Array[String] = []
var hand_card_nodes: Array = []
var _battle_finish_emitted: bool = false

var seed_input: SpinBox
var player_hp_bar: ProgressBar
var player_hp_text: Label
var player_defense_text: Label
var player_momentum_text: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_text: Label
var enemy_defense_text: Label
var enemy_gu_text: Label
var enemy_momentum_text: Label
var enemy_poison_text: Label
var enemy_name_label: Label
var enemy_hand_row: HBoxContainer
var enemy_hand_count_label: Label
var enemy_plan_damage_text: Label
var enemy_plan_defense_text: Label
var enemy_plan_combo_text: Label
var inner_count_label: Label
var inner_slots_row: HBoxContainer
var technique_slot_left_button: Button
var technique_slot_right_button: Button
var consumable_count_label: Label
var consumable_slots_row: HBoxContainer
var use_consumable_button: Button
var active_consumable_slot: int = -1

var round_badge: Label
var hand_name_label: Label
var base_value_label: Label
var multiplier_label: Label
var power_value_label: Label
var baseline_label: Label
var left_technique_name: Label
var left_technique_description: Label
var zone_counts_label: Label
var confirm_button: Button

var current_technique_name: Label
var current_technique_description: Label
var next_technique_name: Label
var sequence_pips: Label
var staging_row: HBoxContainer
var staging_hint: Label
var board_message: Label
var hand_fan: Control
var log_label: RichTextLabel
var log_channel_button: Button
var log_subtitle: Label
var active_log_channel: String = "battle"
var delayed_badge: Label
var log_overlay: PanelContainer
var resolution_strip: Label
var draw_pile_widget: Control
var discard_pile_widget: Control
var draw_count_label: Label
var discard_count_label: Label

func _ready() -> void:
    _build_interface()
    battle_session.state_changed.connect(_refresh)
    if not battle_configuration.is_empty():
        seed_input.value = int(battle_configuration.get("content_seed", seed_input.value))
    _reset_battle()

func configure_battle(configuration: Dictionary) -> void:
    battle_configuration = configuration.duplicate(true)

func configure_battle_session(session) -> void:
    if session != null:
        battle_session = session

func configure_run_context(shared_game_log, progress_snapshot) -> void:
    if shared_game_log == null:
        return
    battle_session.use_game_log(shared_game_log)
    run_progress = progress_snapshot

func player_progress_snapshot():
    return battle_session.player_progress_snapshot()

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
    log_overlay = _build_log_overlay()
    add_child(log_overlay)

func _build_top_bar() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 46
    panel.add_theme_stylebox_override("panel", _box(COLORS["ink"], 10, Color("3b4650"), 2, 6))
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
    _style_small_button(log_button)
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
    _style_small_button(reset)
    bar.add_child(reset)
    panel.add_child(bar)
    return panel

func _build_left_console() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.x = 258
    panel.add_theme_stylebox_override("panel", _box(COLORS["panel"], 13, Color("0b1216"), 3, 10))
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 9)

    round_badge = Label.new()
    round_badge.text = "第 1 回合"
    round_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    round_badge.add_theme_font_size_override("font_size", 14)
    round_badge.add_theme_color_override("font_color", COLORS["gold"])
    box.add_child(round_badge)
    box.add_child(_divider())

    var player_title := Label.new()
    player_title.text = "太吾 · 战斗状态"
    player_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    player_title.add_theme_font_size_override("font_size", 17)
    player_title.add_theme_color_override("font_color", COLORS["cream"])
    box.add_child(player_title)
    var health_row := HBoxContainer.new()
    health_row.add_theme_constant_override("separation", 7)
    var player_meter := _make_life_meter(COLORS["red"], 166)
    player_hp_bar = player_meter["bar"]
    player_hp_text = player_meter["text"]
    health_row.add_child(player_meter["root"])
    player_defense_text = _shield_badge("0")
    health_row.add_child(player_defense_text)
    box.add_child(health_row)
    var player_status_row := HBoxContainer.new()
    player_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
    player_status_row.add_theme_constant_override("separation", 6)
    var player_status_caption := Label.new()
    player_status_caption.text = "状态"
    player_status_caption.add_theme_font_size_override("font_size", 11)
    player_status_caption.add_theme_color_override("font_color", COLORS["muted"])
    player_status_row.add_child(player_status_caption)
    player_momentum_text = _status_chip("连势 0", COLORS["orange"])
    player_status_row.add_child(player_momentum_text)
    box.add_child(player_status_row)
    box.add_child(_divider())

    var type_caption := Label.new()
    type_caption.text = "当前牌型"
    type_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    type_caption.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(type_caption)
    hand_name_label = Label.new()
    hand_name_label.text = "等待选牌"
    hand_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hand_name_label.add_theme_font_size_override("font_size", 28)
    hand_name_label.add_theme_color_override("font_color", COLORS["cream"])
    box.add_child(hand_name_label)

    var equation := HBoxContainer.new()
    equation.alignment = BoxContainer.ALIGNMENT_CENTER
    equation.add_theme_constant_override("separation", 7)
    var base_tile := _number_tile("0", "基础值", COLORS["red"])
    base_value_label = base_tile["value"]
    equation.add_child(base_tile["root"])
    var times := Label.new()
    times.text = "×"
    times.add_theme_font_size_override("font_size", 28)
    times.add_theme_color_override("font_color", COLORS["muted"])
    equation.add_child(times)
    var multiplier_tile := _number_tile("1", "功法倍率", COLORS["blue"])
    multiplier_label = multiplier_tile["value"]
    equation.add_child(multiplier_tile["root"])
    box.add_child(equation)

    var power_panel := PanelContainer.new()
    power_panel.add_theme_stylebox_override("panel", _box(Color("3b3120"), 11, COLORS["gold"], 2, 5))
    var power_box := VBoxContainer.new()
    var power_caption := Label.new()
    power_caption.text = "功法值  P"
    power_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    power_caption.add_theme_color_override("font_color", Color("d8c79f"))
    power_box.add_child(power_caption)
    power_value_label = Label.new()
    power_value_label.text = "0"
    power_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    power_value_label.add_theme_font_size_override("font_size", 34)
    power_value_label.add_theme_color_override("font_color", Color("ffe08a"))
    power_box.add_child(power_value_label)
    baseline_label = Label.new()
    baseline_label.text = "牌型基准值 0 · 不自动伤害"
    baseline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    baseline_label.add_theme_font_size_override("font_size", 11)
    baseline_label.add_theme_color_override("font_color", Color("cbbd98"))
    power_box.add_child(baseline_label)
    power_panel.add_child(power_box)
    box.add_child(power_panel)

    left_technique_name = Label.new()
    left_technique_name.text = "当前功法：—"
    left_technique_name.add_theme_font_size_override("font_size", 16)
    left_technique_name.add_theme_color_override("font_color", COLORS["gold"])
    box.add_child(left_technique_name)
    left_technique_description = Label.new()
    left_technique_description.text = "选择真气后显示功法效果。"
    left_technique_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    left_technique_description.add_theme_font_size_override("font_size", 12)
    left_technique_description.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(left_technique_description)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(spacer)

    confirm_button = Button.new()
    confirm_button.text = "出  招"
    confirm_button.custom_minimum_size.y = 62
    confirm_button.add_theme_font_size_override("font_size", 24)
    confirm_button.add_theme_color_override("font_color", Color("fff4d2"))
    confirm_button.add_theme_stylebox_override("normal", _box(COLORS["orange"], 12, Color("5f2c18"), 3, 7))
    confirm_button.add_theme_stylebox_override("hover", _box(COLORS["orange"].lightened(0.12), 12, COLORS["gold"], 3, 10))
    confirm_button.add_theme_stylebox_override("pressed", _box(COLORS["orange"].darkened(0.12), 12, Color("ffe8a6"), 3, 3))
    confirm_button.pressed.connect(_confirm_play)
    box.add_child(confirm_button)

    var turn_buttons := HBoxContainer.new()
    turn_buttons.add_theme_constant_override("separation", 6)
    var start_turn := Button.new()
    start_turn.text = "补牌"
    start_turn.tooltip_text = "回合开始：补至当前手牌上限"
    start_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start_turn.pressed.connect(_start_turn)
    _style_small_button(start_turn)
    turn_buttons.add_child(start_turn)
    var end_turn := Button.new()
    end_turn.text = "结束回合"
    end_turn.tooltip_text = "结束玩家回合并推进延迟功法"
    end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    end_turn.pressed.connect(_end_turn)
    _style_small_button(end_turn)
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
    panel.add_theme_stylebox_override("panel", _box(Color(0.035, 0.19, 0.15, 0.58), 15, Color("2a6b58"), 2, 9))
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
    resolution_strip.add_theme_stylebox_override("normal", _box(Color(0.08, 0.12, 0.12, 0.74), 7, Color("3d5d57"), 1, 1))
    board.add_child(resolution_strip)
    board.add_child(_build_staging_zone())
    board.add_child(_build_hand_fan())
    panel.add_child(board)
    return panel

func _build_enemy_strip() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 92
    panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.12, 0.13, 0.88), 10, Color("25383d"), 1, 3))
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    var portrait := Label.new()
    portrait.text = "敌"
    portrait.custom_minimum_size = Vector2(34, 34)
    portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    portrait.add_theme_font_size_override("font_size", 15)
    portrait.add_theme_color_override("font_color", Color("ffe4d6"))
    portrait.add_theme_stylebox_override("normal", _box(Color("6b2f2d"), 17, Color("cf6259"), 2, 2))
    row.add_child(portrait)
    enemy_name_label = Label.new()
    enemy_name_label.text = "试炼对手"
    enemy_name_label.add_theme_font_size_override("font_size", 18)
    enemy_name_label.add_theme_color_override("font_color", COLORS["cream"])
    row.add_child(enemy_name_label)
    var meter := _make_life_meter(COLORS["red"], 310)
    enemy_hp_bar = meter["bar"]
    enemy_hp_text = meter["text"]
    row.add_child(meter["root"])
    enemy_defense_text = _shield_badge("0")
    row.add_child(enemy_defense_text)
    box.add_child(row)
    var status_row := HBoxContainer.new()
    status_row.alignment = BoxContainer.ALIGNMENT_CENTER
    status_row.add_theme_constant_override("separation", 6)
    var status_caption := Label.new()
    status_caption.text = "状态"
    status_caption.add_theme_font_size_override("font_size", 10)
    status_caption.add_theme_color_override("font_color", COLORS["muted"])
    status_row.add_child(status_caption)
    enemy_gu_text = _status_chip("蛊印 0", COLORS["purple"])
    status_row.add_child(enemy_gu_text)
    enemy_momentum_text = _status_chip("连势 0", COLORS["orange"])
    status_row.add_child(enemy_momentum_text)
    enemy_poison_text = _status_chip("烈毒 0", COLORS["red"])
    status_row.add_child(enemy_poison_text)
    box.add_child(status_row)
    var plan_row := HBoxContainer.new()
    plan_row.alignment = BoxContainer.ALIGNMENT_CENTER
    plan_row.add_theme_constant_override("separation", 6)
    var plan_caption := Label.new()
    plan_caption.text = "本击计划"
    plan_caption.add_theme_font_size_override("font_size", 11)
    plan_caption.add_theme_color_override("font_color", COLORS["gold"])
    plan_row.add_child(plan_caption)
    enemy_plan_damage_text = _status_chip("伤害 —", COLORS["red"])
    enemy_plan_damage_text.tooltip_text = "对手当前锁定行动预计造成的原始伤害；条件追击会在结算时动态变化"
    plan_row.add_child(enemy_plan_damage_text)
    enemy_plan_defense_text = _status_chip("防御 —", COLORS["blue"])
    enemy_plan_defense_text.tooltip_text = "对手当前锁定行动预计获得的防御"
    plan_row.add_child(enemy_plan_defense_text)
    enemy_plan_combo_text = _status_chip("连击 —", COLORS["orange"])
    enemy_plan_combo_text.tooltip_text = "本击是否已经满足自然连击或功法额外行动条件"
    plan_row.add_child(enemy_plan_combo_text)
    box.add_child(plan_row)
    panel.add_child(box)
    return panel

func _build_enemy_hand_strip() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 50
    panel.add_theme_stylebox_override("panel", _box(Color(0.045, 0.1, 0.1, 0.62), 9, Color("28443e"), 1, 2))
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
    enemy_hand_count_label = _status_chip("0 / 8", Color("485d69"))
    row.add_child(enemy_hand_count_label)
    panel.add_child(row)
    return panel

func _enemy_hand_back() -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(32, 42)
    card.rotation = deg_to_rad(-1.5)
    card.add_theme_stylebox_override("panel", _box(Color("4f356f"), 6, Color("9c78c5"), 2, 2))
    var mark := Label.new()
    mark.text = "◇"
    mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mark.add_theme_font_size_override("font_size", 13)
    mark.add_theme_color_override("font_color", Color("e8d9f0"))
    card.add_child(mark)
    return card

func _build_loadout_strip() -> Control:
    var row := HBoxContainer.new()
    row.custom_minimum_size.y = 90
    row.add_theme_constant_override("separation", 9)

    var inner_panel := PanelContainer.new()
    inner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inner_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.12, 0.13, 0.78), 10, Color("31434a"), 1, 3))
    var inner_box := VBoxContainer.new()
    inner_box.add_theme_constant_override("separation", 4)
    var inner_header := HBoxContainer.new()
    var inner_title := Label.new()
    inner_title.text = "内功"
    inner_title.add_theme_font_size_override("font_size", 14)
    inner_title.add_theme_color_override("font_color", COLORS["cream"])
    inner_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inner_header.add_child(inner_title)
    technique_slot_left_button = Button.new()
    technique_slot_left_button.text = "◀ 功法位"
    technique_slot_left_button.tooltip_text = "将动态功法结算位向左移动"
    technique_slot_left_button.pressed.connect(_move_technique_slot.bind(-1))
    _style_small_button(technique_slot_left_button)
    inner_header.add_child(technique_slot_left_button)
    technique_slot_right_button = Button.new()
    technique_slot_right_button.text = "功法位 ▶"
    technique_slot_right_button.tooltip_text = "将动态功法结算位向右移动"
    technique_slot_right_button.pressed.connect(_move_technique_slot.bind(1))
    _style_small_button(technique_slot_right_button)
    inner_header.add_child(technique_slot_right_button)
    inner_count_label = Label.new()
    inner_count_label.text = "0 / 6"
    inner_count_label.add_theme_color_override("font_color", COLORS["muted"])
    inner_header.add_child(inner_count_label)
    inner_box.add_child(inner_header)
    inner_slots_row = HBoxContainer.new()
    inner_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
    inner_slots_row.add_theme_constant_override("separation", 6)
    for index in range(6):
        inner_slots_row.add_child(_loadout_slot("内功", index + 1, Color("485461"), Vector2(84, 58)))
    inner_box.add_child(inner_slots_row)
    inner_panel.add_child(inner_box)
    row.add_child(inner_panel)

    var consumable_panel := PanelContainer.new()
    consumable_panel.custom_minimum_size.x = 296
    consumable_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.12, 0.13, 0.78), 10, Color("4b3e59"), 1, 3))
    var consumable_box := VBoxContainer.new()
    consumable_box.add_theme_constant_override("separation", 4)
    var consumable_header := HBoxContainer.new()
    var consumable_title := Label.new()
    consumable_title.text = "消耗品"
    consumable_title.add_theme_font_size_override("font_size", 14)
    consumable_title.add_theme_color_override("font_color", COLORS["cream"])
    consumable_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    consumable_header.add_child(consumable_title)
    consumable_count_label = Label.new()
    consumable_count_label.text = "0 / 3"
    consumable_count_label.add_theme_color_override("font_color", COLORS["muted"])
    consumable_header.add_child(consumable_count_label)
    consumable_box.add_child(consumable_header)
    consumable_slots_row = HBoxContainer.new()
    consumable_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
    consumable_slots_row.add_theme_constant_override("separation", 6)
    for index in range(3):
        consumable_slots_row.add_child(_loadout_slot("物", index + 1, COLORS["purple"], Vector2(58, 58)))
    use_consumable_button = Button.new()
    use_consumable_button.text = "使用"
    use_consumable_button.custom_minimum_size = Vector2(62, 58)
    use_consumable_button.tooltip_text = "使用当前选中的消耗品"
    use_consumable_button.pressed.connect(_use_active_consumable)
    _style_small_button(use_consumable_button)
    consumable_slots_row.add_child(use_consumable_button)
    consumable_box.add_child(consumable_slots_row)
    consumable_panel.add_child(consumable_box)
    row.add_child(consumable_panel)
    return row

func _loadout_slot(kind: String, number: int, color: Color, slot_size: Vector2) -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = slot_size
    panel.tooltip_text = "%s槽 %d：当前为空" % [kind, number]
    panel.add_theme_stylebox_override("panel", _box(Color("20262e"), 8, color.darkened(0.12), 2, 2))
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
    panel.add_theme_stylebox_override("panel", _box(Color("253b42"), 8, COLORS["blue"], 2, 3))
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    var slot_caption := Label.new()
    slot_caption.text = "槽 %d · 已装备" % number
    slot_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    slot_caption.add_theme_font_size_override("font_size", 9)
    slot_caption.add_theme_color_override("font_color", Color("8fb9ce"))
    box.add_child(slot_caption)
    var name := Label.new()
    name.text = definition.get("name", "内功")
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.add_theme_font_size_override("font_size", 12)
    name.add_theme_color_override("font_color", COLORS["cream"])
    box.add_child(name)
    panel.add_child(box)
    return panel

func _consumable_slot(definition: Dictionary, index: int) -> Button:
    var button := Button.new()
    var kind_name: String = {
        "insight": "心得",
        "pill": "丹药",
        "treasure": "天材",
    }.get(definition.get("kind", ""), "物品")
    button.text = "%s\n%s" % [kind_name, definition.get("name", "未命名")]
    button.custom_minimum_size = Vector2(66, 58)
    button.add_theme_font_size_override("font_size", 10)
    button.tooltip_text = "%s\n%s\n点击后选择使用目标；纵切调试入口" % [
        definition.get("name", "消耗品"), definition.get("description", "")]
    var active := index == active_consumable_slot
    var border := COLORS["gold"] if active else COLORS["purple"]
    var fill := Color("3b3120") if active else Color("29243a")
    button.add_theme_stylebox_override("normal", _box(fill, 8, border, 2 if not active else 3, 3))
    button.add_theme_stylebox_override("hover", _box(fill.lightened(0.1), 8, COLORS["gold"], 2, 5))
    button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.08), 8, Color("ffe3a0"), 2, 1))
    button.pressed.connect(_select_consumable_slot.bind(index))
    return button

func _build_technique_strip() -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.y = 36
    panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.12, 0.13, 0.7), 8, Color("314a45"), 1, 2))
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    var caption := Label.new()
    caption.text = "功法轮转"
    caption.add_theme_font_size_override("font_size", 11)
    caption.add_theme_color_override("font_color", COLORS["muted"])
    row.add_child(caption)
    current_technique_name = Label.new()
    current_technique_name.text = "等待选牌"
    current_technique_name.add_theme_font_size_override("font_size", 15)
    current_technique_name.add_theme_color_override("font_color", COLORS["gold"])
    row.add_child(current_technique_name)
    var arrow := Label.new()
    arrow.text = "➜"
    arrow.add_theme_font_size_override("font_size", 16)
    arrow.add_theme_color_override("font_color", COLORS["gold"])
    row.add_child(arrow)
    next_technique_name = Label.new()
    next_technique_name.text = "—"
    next_technique_name.add_theme_font_size_override("font_size", 13)
    next_technique_name.add_theme_color_override("font_color", COLORS["cream"])
    row.add_child(next_technique_name)
    sequence_pips = Label.new()
    sequence_pips.text = "● ○"
    sequence_pips.add_theme_font_size_override("font_size", 13)
    sequence_pips.add_theme_color_override("font_color", COLORS["muted"])
    row.add_child(sequence_pips)
    current_technique_description = Label.new()
    current_technique_description.text = ""
    current_technique_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    current_technique_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    current_technique_description.add_theme_font_size_override("font_size", 10)
    current_technique_description.add_theme_color_override("font_color", COLORS["muted"])
    row.add_child(current_technique_description)
    panel.add_child(row)
    return panel

func _technique_card(caption_text: String, highlighted: bool) -> Dictionary:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(260 if highlighted else 205, 92)
    var border := COLORS["gold"] if highlighted else Color("4a5862")
    var fill := Color("3a3020") if highlighted else COLORS["panel_2"]
    panel.add_theme_stylebox_override("panel", _box(fill, 11, border, 2, 6))
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 2)
    var caption := Label.new()
    caption.text = caption_text
    caption.add_theme_font_size_override("font_size", 11)
    caption.add_theme_color_override("font_color", COLORS["gold"] if highlighted else COLORS["muted"])
    box.add_child(caption)
    var name := Label.new()
    name.text = "等待选牌"
    name.add_theme_font_size_override("font_size", 18 if highlighted else 16)
    name.add_theme_color_override("font_color", COLORS["cream"])
    box.add_child(name)
    var description := Label.new()
    description.text = ""
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.max_lines_visible = 2
    description.add_theme_font_size_override("font_size", 11)
    description.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(description)
    panel.add_child(box)
    return {"root": panel, "name": name, "description": description}

func _build_staging_zone() -> Control:
    var panel := PanelContainer.new()
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size.y = 165
    panel.add_theme_stylebox_override("panel", _box(Color(0.03, 0.15, 0.12, 0.5), 14, Color(0.36, 0.76, 0.62, 0.18), 2, 3))
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
    var container := VBoxContainer.new()
    container.custom_minimum_size.y = 202
    var title := Label.new()
    title.text = "手  牌   ·   点击真气进行组合"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_color_override("font_color", Color(0.72, 0.86, 0.8, 0.76))
    container.add_child(title)
    hand_fan = Control.new()
    hand_fan.size_flags_vertical = Control.SIZE_EXPAND_FILL
    hand_fan.clip_contents = false
    hand_fan.resized.connect(_layout_hand_fan)
    var discard_pile := _pile_widget("弃", Color("59616a"))
    discard_pile_widget = discard_pile["root"]
    discard_count_label = discard_pile["count"]
    hand_fan.add_child(discard_pile_widget)
    var draw_pile := _pile_widget("真气", COLORS["purple"])
    draw_pile_widget = draw_pile["root"]
    draw_count_label = draw_pile["count"]
    hand_fan.add_child(draw_pile_widget)
    container.add_child(hand_fan)
    return container

func _pile_widget(title_text: String, color: Color) -> Dictionary:
    var root := Control.new()
    root.custom_minimum_size = Vector2(78, 126)
    root.size = root.custom_minimum_size
    for offset in [Vector2(7, 7), Vector2(4, 4), Vector2.ZERO]:
        var card_back := PanelContainer.new()
        card_back.position = Vector2(5, 4) + offset
        card_back.size = Vector2(65, 94)
        card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card_back.add_theme_stylebox_override("panel", _box(color.darkened(0.22), 8, color.lightened(0.08), 2, 3))
        if offset == Vector2.ZERO:
            var sigil := Label.new()
            sigil.text = "◇\n%s\n◇" % title_text
            sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            sigil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            sigil.add_theme_font_size_override("font_size", 13)
            sigil.add_theme_color_override("font_color", Color("eee5d5"))
            card_back.add_child(sigil)
        root.add_child(card_back)
    var count := Label.new()
    count.text = "0"
    count.position = Vector2(2, 104)
    count.size = Vector2(74, 20)
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count.add_theme_font_size_override("font_size", 12)
    count.add_theme_color_override("font_color", COLORS["cream"])
    root.add_child(count)
    return {"root": root, "count": count}

func _build_log_overlay() -> PanelContainer:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.offset_left = -382
    panel.offset_top = 72
    panel.offset_right = -18
    panel.offset_bottom = 700
    panel.z_index = 500
    panel.visible = false
    panel.add_theme_stylebox_override("panel", _box(COLORS["ink"], 13, Color("0b1216"), 3, 10))
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    var header := HBoxContainer.new()
    var title := Label.new()
    title.text = "触发历史"
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override("font_color", COLORS["cream"])
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    delayed_badge = _status_chip("延迟 0", COLORS["purple"])
    header.add_child(delayed_badge)
    log_channel_button = Button.new()
    log_channel_button.text = "系统日志"
    log_channel_button.tooltip_text = "切换战斗结算日志与系统诊断日志"
    log_channel_button.pressed.connect(_toggle_log_channel)
    _style_small_button(log_channel_button)
    header.add_child(log_channel_button)
    var close := Button.new()
    close.text = "×"
    close.tooltip_text = "关闭结算记录"
    close.pressed.connect(_toggle_log_overlay)
    _style_small_button(close)
    header.add_child(close)
    box.add_child(header)
    log_subtitle = Label.new()
    log_subtitle.text = "战斗日志 · 同一时点从左到右实时结算"
    log_subtitle.add_theme_font_size_override("font_size", 11)
    log_subtitle.add_theme_color_override("font_color", COLORS["muted"])
    box.add_child(log_subtitle)
    box.add_child(_divider())
    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.scroll_active = true
    log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_label.add_theme_font_size_override("normal_font_size", 13)
    log_label.add_theme_color_override("default_color", COLORS["cream"])
    box.add_child(log_label)
    var rule := Label.new()
    rule.text = "牌型基准值不会自动造成伤害\n弃牌堆不会自动洗回牌库"
    rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule.add_theme_font_size_override("font_size", 11)
    rule.add_theme_color_override("font_color", Color("768485"))
    box.add_child(rule)
    panel.add_child(box)
    return panel

func _toggle_log_overlay() -> void:
    log_overlay.visible = not log_overlay.visible

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
    var current = battle_session.snapshot()
    if current.value("battle_state", "") != "active":
        _refresh()
        return
    if int(current.value("actions_available", 0)) > 0 \
            or int(current.value("enemy_actions_available", 0)) > 0:
        board_message.text = "当前击仍有出牌机会；先出招或结束回合"
        return
    if not bool(current.value("round_ended", false)):
        battle_session.execute({"type": "end_turn"})
    battle_session.execute({"type": "start_turn"})
    _refresh()

func _end_turn() -> void:
    selected_ids.clear()
    battle_session.execute({"type": "end_turn"})
    _refresh()

func _confirm_play() -> void:
    var result: Dictionary = battle_session.execute({
        "type": "play_cards",
        "card_ids": selected_ids.duplicate(),
    })
    if not result.get("success", false):
        board_message.text = str(result.get("reason", "无法出招"))
    selected_ids.clear()
    _refresh()

func _select_consumable_slot(slot_index: int) -> void:
    var player_state: Dictionary = battle_session.snapshot().section("player")
    if slot_index < 0 or slot_index >= player_state.get("consumables", []).size():
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
    var result: Dictionary = battle_session.execute({
        "type": "use_consumable",
        "slot_index": active_consumable_slot,
        "card_ids": selected_ids.duplicate(),
    })
    if not result.get("success", false):
        board_message.text = str(result.get("reason", "无法使用消耗品"))
    else:
        var retained: Array[String] = []
        var player_state: Dictionary = battle_session.snapshot().section("player")
        var hand: Array = player_state.get("hand", [])
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
        var consumables: Array = battle_session.snapshot().section("player").get("consumables", [])
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
    if player_hp_bar == null:
        return
    var current = battle_session.snapshot()
    var player_state: Dictionary = current.section("player")
    var enemy_state: Dictionary = current.section("enemy")
    var player_stacks: Dictionary = player_state.get("stacks", {})
    var enemy_stacks: Dictionary = enemy_state.get("stacks", {})
    var enemy_plan: Dictionary = current.value("enemy_plan", {})
    player_hp_bar.max_value = int(player_state.get("max_life", 0))
    player_hp_bar.value = int(player_state.get("life", 0))
    player_hp_text.text = "♥  %d / %d" % [player_state.get("life", 0), player_state.get("max_life", 0)]
    player_defense_text.text = "盾 %d" % int(player_state.get("defense", 0))
    player_momentum_text.text = "连势 %d" % int(player_stacks.get("momentum", 0))
    enemy_hp_bar.max_value = int(enemy_state.get("max_life", 0))
    enemy_hp_bar.value = int(enemy_state.get("life", 0))
    enemy_hp_text.text = "♥  %d / %d" % [enemy_state.get("life", 0), enemy_state.get("max_life", 0)]
    enemy_name_label.text = str(enemy_state.get("name", "敌人"))
    enemy_defense_text.text = "盾 %d" % int(enemy_state.get("defense", 0))
    enemy_gu_text.text = "蛊印 %d" % int(enemy_stacks.get("gu_mark", 0))
    enemy_momentum_text.text = "连势 %d" % int(enemy_stacks.get("momentum", 0))
    enemy_poison_text.text = "烈毒 %d" % _count_card_anomaly(
        enemy_state.get("hand", []), "poison", "lethal_poison")
    var has_plan: bool = not enemy_plan.is_empty()
    enemy_plan_damage_text.text = "伤害 %s" % str(enemy_plan.get("damage", 0) if has_plan else "—")
    enemy_plan_defense_text.text = "防御 %s" % str(enemy_plan.get("defense", 0) if has_plan else "—")
    enemy_plan_combo_text.text = "连击 %s" % ("是" if enemy_plan.get("combo", false) else ("否" if has_plan else "—"))
    enemy_hand_count_label.text = "%d / %d%s" % [
        enemy_state.get("hand_count", 0),
        enemy_state.get("hand_limit", 0),
        " · 已计划" if int(current.value("locked_enemy_card_count", 0)) > 0 else "",
    ]
    round_badge.text = "第 %d 回合 · 我方 %d / 对手 %d 次" % [
        current.value("turn_number", 0),
        current.value("actions_available", 0),
        current.value("enemy_actions_available", 0)]
    if current.value("battle_state", "") != "active":
        round_badge.text = str(current.value("battle_state_detail", ""))
    zone_counts_label.text = "牌库 %d   手牌 %d/%d   弃牌 %d" % [
        player_state.get("draw_count", 0),
        player_state.get("hand_count", 0),
        player_state.get("hand_limit", 0),
        player_state.get("discard_count", 0),
    ]
    delayed_badge.text = "延迟 %d" % int(current.value("delayed_count", 0))
    draw_count_label.text = "%d / %d" % [
        int(player_state.get("draw_count", 0)),
        int(player_state.get("deck_count", 0)),
    ]
    discard_count_label.text = "%d" % int(player_state.get("discard_count", 0))
    _refresh_hand_fan(player_state)
    _refresh_enemy_hand(enemy_state)
    _refresh_inner_slots(player_state)
    _refresh_consumable_slots(player_state)
    _refresh_preview_and_staging(current, player_state)
    _refresh_log(current)
    confirm_button.disabled = (
        selected_ids.is_empty()
        or active_consumable_slot >= 0
        or int(current.value("actions_available", 0)) <= 0
        or current.value("battle_state", "") != "active")
    if current.value("battle_state", "") != "active" and not _battle_finish_emitted:
        _battle_finish_emitted = true
        run_progress = battle_session.player_progress_snapshot()
        battle_finished.emit.call_deferred(str(current.value("battle_state", "")))

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

func _refresh_consumable_slots(player_state: Dictionary) -> void:
    if consumable_slots_row == null:
        return
    var consumables: Array = player_state.get("consumables", [])
    var consumable_limit := int(player_state.get("consumable_limit", 0))
    if active_consumable_slot >= consumables.size():
        active_consumable_slot = -1
    for child in consumable_slots_row.get_children():
        child.queue_free()
    consumable_count_label.text = "%d / %d" % [
        consumables.size(), consumable_limit]
    for index in range(consumable_limit):
        if index < consumables.size():
            consumable_slots_row.add_child(_consumable_slot(consumables[index], index))
        else:
            consumable_slots_row.add_child(_loadout_slot("消耗品", index + 1, COLORS["purple"], Vector2(58, 58)))
    use_consumable_button = Button.new()
    use_consumable_button.text = "使用"
    use_consumable_button.custom_minimum_size = Vector2(62, 58)
    use_consumable_button.tooltip_text = "使用当前选中的消耗品"
    use_consumable_button.pressed.connect(_use_active_consumable)
    _style_small_button(use_consumable_button)
    use_consumable_button.disabled = not _active_consumable_targets_valid(player_state)
    consumable_slots_row.add_child(use_consumable_button)

func _active_consumable_targets_valid(player_state: Dictionary = {}) -> bool:
    if player_state.is_empty():
        player_state = battle_session.snapshot().section("player")
    var consumables: Array = player_state.get("consumables", [])
    if active_consumable_slot < 0 or active_consumable_slot >= consumables.size():
        return false
    return bool(battle_session.validate_consumable_targets(
        active_consumable_slot,
        selected_ids).get("ok", false))

func _refresh_enemy_hand(enemy_state: Dictionary) -> void:
    for child in enemy_hand_row.get_children():
        child.queue_free()
    var visible_cards := mini(int(enemy_state.get("hand_count", 0)), 10)
    for _index in range(visible_cards):
        enemy_hand_row.add_child(_enemy_hand_back())

func _refresh_inner_slots(player_state: Dictionary) -> void:
    if inner_slots_row == null:
        return
    for child in inner_slots_row.get_children():
        child.queue_free()
    var equipped: Array = player_state.get("equipped_inner_skills", [])
    inner_count_label.text = "%d / 6" % equipped.size()
    var technique_slot_index := int(player_state.get("technique_slot_index", 0))
    technique_slot_left_button.disabled = technique_slot_index <= 0
    technique_slot_right_button.disabled = technique_slot_index >= equipped.size()
    for index in range(6):
        if index < equipped.size():
            inner_slots_row.add_child(_equipped_inner_slot(equipped[index], index + 1))
        else:
            inner_slots_row.add_child(_loadout_slot("内功", index + 1, Color("485461"), Vector2(84, 58)))

func _move_technique_slot(direction: int) -> void:
    battle_session.execute({
        "type": "move_technique_slot",
        "direction": direction,
    })
    _refresh()

func _refresh_hand_fan(player_state: Dictionary) -> void:
    for child in hand_card_nodes:
        if is_instance_valid(child):
            child.queue_free()
    hand_card_nodes.clear()
    var sorted_hand: Array = player_state.get("hand", []).duplicate(true)
    sorted_hand.sort_custom(func(left, right):
        if int(left.get("rank_order", 0)) == int(right.get("rank_order", 0)):
            return str(left.get("attribute", "")) < str(right.get("attribute", ""))
        return int(left.get("rank_order", 0)) < int(right.get("rank_order", 0)))
    for card in sorted_hand:
        var view = QiCardViewScript.new()
        view.setup(card, selected_ids.has(card.get("id", "")), false, true)
        view.qi_card_pressed.connect(_on_card_pressed)
        var enhancement_text: String = {
            "bonus": "｜奖励牌：有效真气值 +2",
            "multiplier": "｜倍率牌：功法倍率 +2",
        }.get(card.get("reshapes", {}).get("enhancement", ""), "")
        var finish_text: String = {
            "foil": "｜箔面：自身贡献 +3",
            "holographic": "｜镭射：功法倍率 +1",
            "polychrome": "｜多彩：功法值增幅 +20%",
        }.get(card.get("reshapes", {}).get("finish", ""), "")
        view.tooltip_text = "%s｜牌阶 %s｜真气值 %d｜%s属性%s%s%s" % [
            card.get("id", ""), card.get("rank_name", ""), card.get("qi_value", 0), card.get("attribute_name", ""),
            enhancement_text, finish_text,
            "｜烈毒：打出时受到当前有效真气值伤害"
            if str(card.get("anomalies", {}).get("poison", "")) == "lethal_poison"
            else ""]
        hand_fan.add_child(view)
        hand_card_nodes.append(view)
    _layout_hand_fan.call_deferred()

func _layout_hand_fan() -> void:
    if hand_fan == null:
        return
    discard_pile_widget.position = Vector2(2, 35)
    discard_pile_widget.z_index = 120
    draw_pile_widget.position = Vector2(hand_fan.size.x - 80, 28)
    draw_pile_widget.z_index = 120
    if hand_card_nodes.is_empty():
        return
    var count := hand_card_nodes.size()
    var card_width := 116.0
    var reserved_left := 82.0
    var reserved_right := 92.0
    var available := maxf(100.0, hand_fan.size.x - reserved_left - reserved_right)
    var spacing := 0.0 if count <= 1 else minf(92.0, (available - card_width) / float(count - 1))
    spacing = maxf(38.0, spacing)
    var total_width := card_width + spacing * (count - 1)
    var start_x := reserved_left + (available - total_width) * 0.5
    var middle := (count - 1) * 0.5
    for index in range(count):
        var view = hand_card_nodes[index]
        var distance: float = absf(index - middle)
        var lift := 24.0 if selected_ids.has(view.card_id()) else 0.0
        view.position = Vector2(start_x + index * spacing, 8.0 + distance * 2.8 - lift)
        view.rotation = deg_to_rad((index - middle) * 1.15)
        view.z_index = 50 + index if selected_ids.has(view.card_id()) else index

func _refresh_preview_and_staging(current, player_state: Dictionary) -> void:
    for child in staging_row.get_children():
        child.queue_free()
    var consumables: Array = player_state.get("consumables", [])
    if active_consumable_slot >= 0 and active_consumable_slot < consumables.size():
        _refresh_consumable_targeting(player_state)
        return
    if selected_ids.is_empty():
        hand_name_label.text = "等待选牌"
        base_value_label.text = "0"
        multiplier_label.text = "1"
        power_value_label.text = "0"
        baseline_label.text = "牌型基准值 0 · 不自动伤害"
        left_technique_name.text = "当前功法：—"
        left_technique_description.text = "选择真气后显示功法效果。"
        current_technique_name.text = "等待选牌"
        current_technique_description.text = "结算顺序：%s" % " → ".join(battle_session.combat_order_labels())
        next_technique_name.text = "—"
        sequence_pips.text = "○ ○"
        var player_action_cards: Array = current.value("last_player_action_cards", [])
        var enemy_action_cards: Array = current.value("last_enemy_action_cards", [])
        if not player_action_cards.is_empty() or not enemy_action_cards.is_empty():
            staging_hint.visible = false
            _show_last_synchronized_reveal(current)
        else:
            staging_hint.visible = true
            board_message.text = (
                current.value("battle_state_detail", "")
                if current.value("battle_state", "") != "active"
                else "对手计划已公开 · 牌型与真气保持隐藏")
        return

    var preview: Dictionary = battle_session.preview(selected_ids)
    if not preview.get("valid", false):
        hand_name_label.text = "无效选择"
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
    hand_name_label.text = hand["name"]
    base_value_label.text = str(values["base_value"])
    multiplier_label.text = str(values["technique_multiplier"])
    power_value_label.text = str(values["technique_value"])
    baseline_label.text = "牌型基准值 %d · 不自动伤害" % values["baseline_value"]
    var technique_name: String = technique.get("name", "空序列")
    left_technique_name.text = "当前功法：%s" % technique_name
    left_technique_description.text = technique.get("description", "该精确牌型当前没有功法。")
    var inner_defense: int = int(preview.get("intent", {}).get("inner_skill_defense", 0))
    if inner_defense > 0:
        left_technique_description.text += "\n内功预计获得 %d 防御。" % inner_defense
    current_technique_name.text = technique_name
    var condition_text := "条件满足" if condition_ok else "条件失败：%s" % preview["condition"]["reason"]
    current_technique_description.text = "%s · 顺序：%s" % [
        condition_text, " → ".join(battle_session.combat_order_labels(technique_name))]
    var next_name: String = next_technique.get("name", "空序列")
    next_technique_name.text = next_name
    sequence_pips.text = "●  ○" if technique_name != next_name else "●"
    var contributing_count: int = hand.get("contributing_card_ids", []).size()
    board_message.text = "%s · %d 张参与数值计算 · P = %d · 内功防御 +%d · 对手计划已锁定" % [
        hand["name"], contributing_count, values["technique_value"], inner_defense]

func _refresh_consumable_targeting(player_state: Dictionary) -> void:
    var consumables: Array = player_state.get("consumables", [])
    var definition: Dictionary = consumables[active_consumable_slot]
    var limits: Dictionary = definition.get("targeting_limits", {})
    var hand: Array = player_state.get("hand", [])
    for card_id in selected_ids:
        var card := _find_card_snapshot(hand, card_id)
        if card.is_empty():
            continue
        var compact_view = QiCardViewScript.new()
        compact_view.setup(card, true, true, false)
        staging_row.add_child(compact_view)
    hand_name_label.text = "使用 · %s" % definition.get("name", "消耗品")
    base_value_label.text = "—"
    multiplier_label.text = "—"
    power_value_label.text = "—"
    baseline_label.text = "构筑改造 · 使用后立即刷新预览"
    left_technique_name.text = "%s · %s" % [
        {"insight": "心得", "pill": "丹药", "treasure": "天材地宝"}.get(definition.get("kind", ""), "消耗品"),
        definition.get("name", "")]
    left_technique_description.text = definition.get("description", "")
    current_technique_name.text = definition.get("name", "消耗品")
    current_technique_description.text = "纵切调试构筑入口"
    next_technique_name.text = "使用后释放槽位"
    sequence_pips.text = "◆"
    staging_hint.visible = selected_ids.is_empty() and limits["zone"] != "none"
    if limits["zone"] == "none":
        staging_hint.text = "无需选择真气，直接点击使用"
    else:
        staging_hint.text = "选择 %d～%d 张当前手牌" % [limits["minimum"], limits["maximum"]]
    board_message.text = "%s · 已选 %d / %d 张%s" % [
        definition.get("description", ""), selected_ids.size(), limits["maximum"],
        " · 可以使用" if _active_consumable_targets_valid(player_state) else ""]

func _show_last_synchronized_reveal(current) -> void:
    var player_action_cards: Array = current.value("last_player_action_cards", [])
    var enemy_action_cards: Array = current.value("last_enemy_action_cards", [])
    var player_preview: Dictionary = current.value("last_preview", {})
    var enemy_preview: Dictionary = current.value("last_enemy_preview", {})
    if not player_action_cards.is_empty():
        staging_row.add_child(_staging_caption("我方"))
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
        staging_row.add_child(_staging_caption("对手"))
        var enemy_contributing: Array = enemy_preview.get("hand", {}).get("contributing_card_ids", [])
        for card in enemy_action_cards:
            var enemy_view = QiCardViewScript.new()
            enemy_view.setup(card, enemy_contributing.has(card.get("id", "")), true, false)
            staging_row.add_child(enemy_view)
    var player_hand_name: String = player_preview.get("hand", {}).get("name", "未出牌")
    board_message.text = "同步结算 · 我方 %s / 对手已出招" % player_hand_name
    if current.value("battle_state", "") != "active":
        board_message.text += " · %s" % current.value("battle_state_detail", "")

func _staging_caption(text_value: String) -> Label:
    var label := Label.new()
    label.text = text_value
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", COLORS["muted"])
    return label

func _refresh_log(current) -> void:
    var lines: Array[String] = []
    var history: Array = current.value("%s_log" % active_log_channel, [])
    var battle_history: Array = current.value("battle_log", [])
    log_channel_button.text = "系统日志" if active_log_channel == "battle" else "战斗日志"
    log_subtitle.text = (
        "战斗日志 · 同一时点从左到右实时结算"
        if active_log_channel == "battle"
        else "系统日志 · 会话、命令与内容加载诊断")
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
    var start := maxi(0, history.size() - 13)
    for index in range(start, history.size()):
        var entry: Dictionary = history[index]
        var status := str(entry.get("context", {}).get("status", entry.get("severity", "info")))
        var success: bool = entry.get("severity", "info") not in ["warning", "error"]
        var color := "#efbd50" if success else "#df6a61"
        lines.append((
            "[color=#657478]%02d  %s[/color]\n"
            + "[color=%s]●[/color] [b]%s[/b]  [color=#a7b1b2]%s[/color]\n"
            + "[color=#849092]%s[/color]") % [
                int(entry.get("serial", index)) + 1,
                entry.get("category", ""),
                color,
                entry.get("message", ""),
                status,
                entry.get("detail", ""),
            ])
    log_label.text = "\n\n".join(lines) if not lines.is_empty() else "[color=#768485]当前通道暂无记录……[/color]"
    log_label.scroll_to_line(maxi(0, lines.size() * 3 - 1))

func _find_card_snapshot(cards: Array, card_id: String) -> Dictionary:
    for card_value in cards:
        var card: Dictionary = card_value
        if str(card.get("id", "")) == card_id:
            return card
    return {}

func _make_life_meter(color: Color, width: float = 220.0) -> Dictionary:
    var root := Control.new()
    root.custom_minimum_size = Vector2(width, 27)
    var bar := ProgressBar.new()
    bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bar.show_percentage = false
    bar.max_value = 100
    bar.value = 100
    bar.add_theme_stylebox_override("background", _box(Color("11161b"), 8, Color("080b0d"), 2, 0))
    bar.add_theme_stylebox_override("fill", _box(color, 7, color.lightened(0.16), 1, 0))
    root.add_child(bar)
    var text := Label.new()
    text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    text.text = "100 / 100"
    text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    text.add_theme_font_size_override("font_size", 12)
    text.add_theme_color_override("font_color", Color("fff4df"))
    text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(text)
    return {"root": root, "bar": bar, "text": text}

func _shield_badge(value_text: String) -> Label:
    var label := Label.new()
    label.text = "盾 %s" % value_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(62, 27)
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color("e7f5ff"))
    label.add_theme_stylebox_override("normal", _box(Color("1d4e72"), 8, COLORS["blue"], 2, 2))
    label.tooltip_text = "防御：受到普通伤害时先扣除，当前原型跨回合保留"
    return label

func _status_chip(text_value: String, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(68, 22)
    label.add_theme_font_size_override("font_size", 10)
    label.add_theme_color_override("font_color", Color("f1ebdf"))
    label.add_theme_stylebox_override("normal", _box(color.darkened(0.42), 7, color.darkened(0.06), 1, 1))
    return label

func _resource_pill(text_value: String, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(90, 28)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color("f9f1df"))
    label.add_theme_stylebox_override("normal", _box(color.darkened(0.25), 8, color, 2, 2))
    return label

func _number_tile(initial: String, caption_text: String, color: Color) -> Dictionary:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(83, 74)
    panel.add_theme_stylebox_override("panel", _box(color.darkened(0.1), 11, color.lightened(0.2), 2, 5))
    var box := VBoxContainer.new()
    var value := Label.new()
    value.text = initial
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value.add_theme_font_size_override("font_size", 29)
    value.add_theme_color_override("font_color", Color("fff4df"))
    box.add_child(value)
    var caption := Label.new()
    caption.text = caption_text
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 10)
    caption.add_theme_color_override("font_color", Color("f2d9c7"))
    box.add_child(caption)
    panel.add_child(box)
    return {"root": panel, "value": value}

func _divider() -> HSeparator:
    var separator := HSeparator.new()
    separator.add_theme_constant_override("separation", 2)
    return separator

func _style_small_button(button: Button) -> void:
    button.custom_minimum_size.y = 37
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", COLORS["cream"])
    button.add_theme_stylebox_override("normal", _box(COLORS["panel_2"], 8, Color("4b5862"), 1, 3))
    button.add_theme_stylebox_override("hover", _box(COLORS["panel_3"], 8, COLORS["gold"], 2, 5))
    button.add_theme_stylebox_override("pressed", _box(COLORS["panel_2"].darkened(0.12), 8, COLORS["gold"], 2, 1))

func _box(fill: Color, radius: int, border: Color, border_width: int, shadow_size: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.shadow_color = Color(0.01, 0.025, 0.02, 0.46)
    style.shadow_size = shadow_size
    style.shadow_offset = Vector2(3, 5) if shadow_size > 0 else Vector2.ZERO
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    style.anti_aliasing = true
    return style
