class_name BattleHud
extends Control

signal card_pressed(card_id: String)
signal confirm_requested
signal end_turn_requested
signal start_turn_requested
signal consumable_selected(slot_index: int)
signal consumable_use_requested
signal reset_requested(seed: int)
signal debug_channel_toggle_requested

const UiDesignScript = preload("res://ui/ui_design.gd")
const ActorStatusScript = preload("res://ui/components/battle_actor_status.gd")
const HandZoneScript = preload("res://ui/components/battle_hand_zone.gd")
const LoadoutScript = preload("res://ui/components/battle_loadout_view.gd")
const ValuePanelScript = preload("res://ui/components/battle_value_panel.gd")
const IntentPanelScript = preload("res://ui/components/battle_intent_panel.gd")
const StageScript = preload("res://ui/components/battle_stage.gd")
const ActionBarScript = preload("res://ui/components/battle_action_bar.gd")
const TechniqueGridScript = preload("res://ui/components/battle_technique_grid.gd")
const SideDrawerScript = preload("res://ui/components/battle_side_drawer.gd")
const DebugDrawerScript = preload("res://ui/components/battle_debug_drawer.gd")
const TooltipScript = preload("res://ui/components/battle_tooltip.gd")
const NotificationScript = preload("res://ui/components/battle_notification_layer.gd")

var _debug_enabled := false
var _round_label: Label
var _action_label: Label
var _player_inner: BattleLoadoutView
var _enemy_inner: BattleLoadoutView
var _player_actor: BattleActorStatus
var _enemy_actor: BattleActorStatus
var _enemy_hand: Label
var _player_grid
var _enemy_grid
var _player_values: BattleValuePanel
var _enemy_values: BattleValuePanel
var _intent_panel
var _stage
var _hand: BattleHandZone
var _action_bar
var _side_drawer
var _debug_drawer
var _tooltip
var _notifications
var _drawer_button: Button
var _debug_button: Button
var _last_notification := ""
var _top_region: Control
var _bottom_region: Control

func _ready() -> void:
    name = "BattleHud"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    theme = UiDesignScript.create_theme()
    _build_background()
    _build_layout()
    _build_overlays()
    resized.connect(_apply_responsive_layout)
    _apply_responsive_layout.call_deferred()

func configure_mode(debug_enabled: bool) -> void:
    _debug_enabled = debug_enabled
    if _debug_button != null:
        _debug_button.visible = _debug_enabled
    if _debug_drawer != null:
        _debug_drawer.configure_mode(_debug_enabled)

func present(snapshot: Dictionary) -> void:
    var player: Dictionary = snapshot.get("player", {})
    var enemy: Dictionary = snapshot.get("enemy", {})
    var phase: Dictionary = snapshot.get("battle_phase", {})
    _round_label.text = (
        "第 %02d 回合" % int(phase.get("turn", 0))
        if str(phase.get("state", "active")) == "active"
        else str(phase.get("detail", "战斗结束")))
    _action_label.text = "第 %02d 次行动" % int(phase.get("action_index", 0))
    _player_inner.present(player)
    _enemy_inner.present(enemy)
    _player_actor.present(player.merged({"items": player.get("items", [])}, true))
    _enemy_actor.present(enemy)
    _enemy_hand.text = "敌方牌区\n手牌 %d / %d    经脉 %d    牌库 %d" % [
        int(enemy.get("hand_count", 0)), int(enemy.get("hand_limit", 0)),
        int(enemy.get("occupied_meridian_count", 0)),
        int(enemy.get("zones", {}).get("draw_count", 0))]
    _player_grid.present(snapshot.get("technique_sequences", {}).get("player", []), "我方功法槽")
    _enemy_grid.present(snapshot.get("technique_sequences", {}).get("enemy", []), "敌方功法槽")
    _player_values.present(snapshot.get("action_preview", {}))
    _enemy_values.present({}, true)
    _intent_panel.present(snapshot.get("enemy_intents", []))
    _stage.present(snapshot.get("action_preview", {}), snapshot.get("last_resolution", {}))
    _hand.present(player, snapshot.get("selection", {}).get("ids", []))
    _action_bar.present(
        player.get("consumables", []),
        int(snapshot.get("selection", {}).get("active_consumable_slot", -1)),
        snapshot.get("available_commands", {}))
    _side_drawer.present(snapshot)
    _debug_drawer.present(snapshot.get("debug_info", {}))
    var notification := str(snapshot.get("notification", ""))
    if notification != "" and notification != _last_notification:
        _notifications.notify(notification, true)
    _last_notification = notification

func toggle_side_drawer() -> void:
    _side_drawer.toggle()

func toggle_debug_drawer() -> void:
    if _debug_enabled:
        _debug_drawer.toggle()

func side_drawer_is_open() -> bool:
    return _side_drawer.is_open()

func debug_drawer_is_open() -> bool:
    return _debug_drawer.is_open()

func debug_drawer_enabled() -> bool:
    return _debug_drawer.is_debug_enabled()

func intent_panel():
    return _intent_panel

func presentation_layers() -> Dictionary:
    return _stage.presentation_layers()

func main_action_rect() -> Rect2:
    return _action_bar.primary_actions_rect()

func _build_background() -> void:
    var background := ColorRect.new()
    background.name = "BattlefieldBackground"
    background.color = UiDesignScript.COLORS["background"]
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var bottom := ColorRect.new()
    bottom.name = "BottomZoneBackground"
    bottom.color = Color(UiDesignScript.COLORS["ink"], 0.42)
    bottom.anchor_top = 1.0
    bottom.anchor_right = 1.0
    bottom.anchor_bottom = 1.0
    bottom.offset_top = -UiDesignScript.BOTTOM_ZONE_HEIGHT
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.add_child(bottom)

func _build_layout() -> void:
    var page := VBoxContainer.new()
    page.name = "FormalBattleLayout"
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.add_theme_constant_override("separation", UiDesignScript.SPACE_SM)
    add_child(page)
    _top_region = _build_top_region()
    page.add_child(_top_region)
    var middle := _build_middle_region()
    middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page.add_child(middle)
    _bottom_region = _build_bottom_region()
    page.add_child(_bottom_region)

func _build_top_region() -> Control:
    var top := HBoxContainer.new()
    top.name = "TopInnerSkillLayer"
    top.custom_minimum_size.y = 190
    top.add_theme_constant_override("separation", UiDesignScript.SPACE_MD)
    _player_inner = LoadoutScript.new()
    _player_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _player_inner.detail_requested.connect(_show_detail)
    top.add_child(_player_inner)
    var counter := VBoxContainer.new()
    counter.name = "RoundAndActionCounter"
    counter.custom_minimum_size.x = 190
    counter.alignment = BoxContainer.ALIGNMENT_CENTER
    top.add_child(counter)
    _round_label = Label.new()
    _round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _round_label.add_theme_font_size_override("font_size", 19)
    _round_label.add_theme_color_override("font_color", UiDesignScript.COLORS["cream"])
    counter.add_child(_round_label)
    _action_label = Label.new()
    _action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _action_label.add_theme_font_size_override("font_size", 12)
    _action_label.add_theme_color_override("font_color", UiDesignScript.COLORS["green"])
    counter.add_child(_action_label)
    counter.add_child(_resolution_timeline())
    _enemy_inner = LoadoutScript.new()
    _enemy_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _enemy_inner.detail_requested.connect(_show_detail)
    top.add_child(_enemy_inner)
    return top

func _resolution_timeline() -> Control:
    var row := HBoxContainer.new()
    row.name = "ResolutionTimeline"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", UiDesignScript.SPACE_SM)
    for index in range(3):
        var label := Label.new()
        label.text = ["运转", "真气", "功法"][index]
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 10)
        label.add_theme_color_override("font_color",
            UiDesignScript.COLORS["gold"] if index == 0 else UiDesignScript.COLORS["line"])
        row.add_child(label)
        if index < 2:
            var line := HSeparator.new()
            line.custom_minimum_size.x = 20
            row.add_child(line)
    return row

func _build_middle_region() -> Control:
    var middle := HBoxContainer.new()
    middle.name = "Battlefield"
    middle.add_theme_constant_override("separation", UiDesignScript.SPACE_MD)
    var player_side := VBoxContainer.new()
    player_side.name = "PlayerSideColumn"
    player_side.custom_minimum_size.x = UiDesignScript.SIDE_COLUMN_WIDTH
    middle.add_child(player_side)
    _player_actor = ActorStatusScript.new()
    _player_actor.configure({"meter_width": 140.0, "show_items": true, "minimum_height": 190.0})
    player_side.add_child(_player_actor)
    _player_grid = TechniqueGridScript.new()
    _player_grid.details_requested.connect(_show_detail)
    player_side.add_child(_player_grid)
    var center := VBoxContainer.new()
    center.name = "CentralBattleStage"
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    middle.add_child(center)
    var readouts := HBoxContainer.new()
    readouts.name = "CombatReadouts"
    readouts.add_theme_constant_override("separation", UiDesignScript.SPACE_MD)
    center.add_child(readouts)
    _player_values = ValuePanelScript.new()
    _player_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    readouts.add_child(_player_values)
    _intent_panel = IntentPanelScript.new()
    readouts.add_child(_intent_panel)
    _enemy_values = ValuePanelScript.new()
    _enemy_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    readouts.add_child(_enemy_values)
    _stage = StageScript.new()
    center.add_child(_stage)
    var enemy_side := VBoxContainer.new()
    enemy_side.name = "EnemySideColumn"
    enemy_side.custom_minimum_size.x = UiDesignScript.SIDE_COLUMN_WIDTH
    middle.add_child(enemy_side)
    _enemy_actor = ActorStatusScript.new()
    _enemy_actor.configure({"meter_width": 140.0, "minimum_height": 112.0})
    enemy_side.add_child(_enemy_actor)
    _enemy_hand = Label.new()
    _enemy_hand.name = "EnemyHandSummary"
    _enemy_hand.custom_minimum_size.y = 68
    _enemy_hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _enemy_hand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _enemy_hand.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
    _enemy_hand.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    _enemy_hand.add_theme_stylebox_override("normal", UiDesignScript.box(
        UiDesignScript.COLORS["panel"], UiDesignScript.RADIUS_MD,
        UiDesignScript.COLORS["copper_dark"], UiDesignScript.BORDER_THIN, 3))
    enemy_side.add_child(_enemy_hand)
    _enemy_grid = TechniqueGridScript.new()
    _enemy_grid.details_requested.connect(_show_detail)
    enemy_side.add_child(_enemy_grid)
    return middle

func _build_bottom_region() -> Control:
    var bottom := HBoxContainer.new()
    bottom.name = "BottomPlayerRegion"
    bottom.custom_minimum_size.y = UiDesignScript.BOTTOM_ZONE_HEIGHT
    bottom.add_theme_constant_override("separation", UiDesignScript.SPACE_MD)
    _hand = HandZoneScript.new()
    _hand.card_pressed.connect(func(card_id: String): card_pressed.emit(card_id))
    _hand.zone_details_requested.connect(func(zones: Dictionary): _show_detail("zones", zones))
    _hand.card_detail_requested.connect(func(card: Dictionary): _show_detail("cards", card))
    bottom.add_child(_hand)
    _action_bar = ActionBarScript.new()
    _action_bar.confirm_requested.connect(func(): confirm_requested.emit())
    _action_bar.end_turn_requested.connect(func(): end_turn_requested.emit())
    _action_bar.start_turn_requested.connect(func(): start_turn_requested.emit())
    _action_bar.consumable_selected.connect(func(index: int): consumable_selected.emit(index))
    _action_bar.consumable_use_requested.connect(func(): consumable_use_requested.emit())
    bottom.add_child(_action_bar)
    return bottom

func _build_overlays() -> void:
    _drawer_button = Button.new()
    _drawer_button.name = "BuildDetailsToggle"
    _drawer_button.text = "构筑详情"
    _drawer_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _drawer_button.position = Vector2(-116, 8)
    _drawer_button.size = Vector2(108, 36)
    _drawer_button.pressed.connect(toggle_side_drawer)
    UiDesignScript.style_button(_drawer_button)
    add_child(_drawer_button)
    _debug_button = Button.new()
    _debug_button.name = "DebugDrawerToggle"
    _debug_button.text = "调试"
    _debug_button.position = Vector2(8, 8)
    _debug_button.size = Vector2(72, 36)
    _debug_button.pressed.connect(toggle_debug_drawer)
    UiDesignScript.style_button(_debug_button)
    _debug_button.visible = _debug_enabled
    add_child(_debug_button)
    _side_drawer = SideDrawerScript.new()
    add_child(_side_drawer)
    _debug_drawer = DebugDrawerScript.new()
    _debug_drawer.reset_requested.connect(func(seed: int): reset_requested.emit(seed))
    _debug_drawer.channel_toggle_requested.connect(func(): debug_channel_toggle_requested.emit())
    add_child(_debug_drawer)
    _debug_drawer.configure_mode(_debug_enabled)
    _tooltip = TooltipScript.new()
    add_child(_tooltip)
    _notifications = NotificationScript.new()
    add_child(_notifications)

func _show_detail(section: String, payload: Dictionary) -> void:
    _side_drawer.show_detail(section, payload)

func _apply_responsive_layout() -> void:
    if _player_actor == null:
        return
    var compact := size.x < 1500.0 or size.y < 850.0
    var side_width := 220.0 if compact else float(UiDesignScript.SIDE_COLUMN_WIDTH)
    _top_region.custom_minimum_size.y = 140.0 if compact else 190.0
    _bottom_region.custom_minimum_size.y = float(UiDesignScript.BOTTOM_ZONE_HEIGHT)
    _player_inner.set_compact(compact)
    _enemy_inner.set_compact(compact)
    _player_actor.get_parent().custom_minimum_size.x = side_width
    _enemy_actor.get_parent().custom_minimum_size.x = side_width
    _player_actor.custom_minimum_size.y = 105.0 if compact else 190.0
    _enemy_actor.custom_minimum_size.y = 80.0 if compact else 112.0
    _player_grid.set_compact(compact)
    _enemy_grid.set_compact(compact)
    _player_values.custom_minimum_size.x = 230.0 if compact else 330.0
    _enemy_values.custom_minimum_size.x = 230.0 if compact else 330.0
    _intent_panel.custom_minimum_size.x = 140.0 if compact else 190.0
