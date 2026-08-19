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
const DebugDrawerScene = preload("res://ui/components/battle_debug_drawer.tscn")

@onready var _layout: VBoxContainer = $FormalBattleLayout
@onready var _top_region: Control = $FormalBattleLayout/TopInnerSkillLayer
@onready var _player_inner = $FormalBattleLayout/TopInnerSkillLayer/BattleInnerSkillRow
@onready var _enemy_inner = $FormalBattleLayout/TopInnerSkillLayer/BattleInnerSkillRow2
@onready var _round_label: Label = $FormalBattleLayout/TopInnerSkillLayer/RoundAndActionCounter/RoundLabel
@onready var _action_label: Label = $FormalBattleLayout/TopInnerSkillLayer/RoundAndActionCounter/ActionLabel
@onready var _middle_region: Control = $FormalBattleLayout/Battlefield
@onready var _player_side: Control = $FormalBattleLayout/Battlefield/PlayerSideColumn
@onready var _player_actor = $FormalBattleLayout/Battlefield/PlayerSideColumn/BattleActorPanel
@onready var _player_grid = $FormalBattleLayout/Battlefield/PlayerSideColumn/BattleTechniqueGrid
@onready var _player_values = $FormalBattleLayout/Battlefield/CentralBattleStage/CombatReadouts/BattleCombatReadout
@onready var _intent_panel = $FormalBattleLayout/Battlefield/CentralBattleStage/CombatReadouts/BattleIntentPanel
@onready var _enemy_values = $FormalBattleLayout/Battlefield/CentralBattleStage/CombatReadouts/BattleCombatReadout2
@onready var _stage = $FormalBattleLayout/Battlefield/CentralBattleStage/BattleStage
@onready var _enemy_side: Control = $FormalBattleLayout/Battlefield/EnemySideColumn
@onready var _enemy_actor = $FormalBattleLayout/Battlefield/EnemySideColumn/BattleActorPanel
@onready var _enemy_hand: Label = $FormalBattleLayout/Battlefield/EnemySideColumn/EnemyHandSummary
@onready var _enemy_grid = $FormalBattleLayout/Battlefield/EnemySideColumn/BattleTechniqueGrid
@onready var _bottom_region: Control = $FormalBattleLayout/BottomPlayerRegion
@onready var _hand = $FormalBattleLayout/BottomPlayerRegion/PlayerHandZone
@onready var _action_bar = $FormalBattleLayout/BottomPlayerRegion/BattleActionBar
@onready var _side_drawer = $BattleSideDrawer
@onready var _tooltip = $BattleTooltip
@onready var _notifications = $BattleNotificationLayer
@onready var _drawer_button: Button = $BuildDetailsToggle
@onready var _debug_button: Button = $DebugDrawerToggle

var _debug_enabled := false
var _debug_drawer
var _last_notification := ""
var _presentation_busy := false

func _ready() -> void:
    theme = UiDesignScript.create_theme()
    _player_actor.configure({"meter_width": 140.0, "show_items": true, "minimum_height": 190.0})
    _enemy_actor.configure({"meter_width": 140.0, "minimum_height": 112.0})
    _connect_components()
    resized.connect(_apply_responsive_layout)
    _apply_responsive_layout.call_deferred()

func _connect_components() -> void:
    _player_inner.detail_requested.connect(_show_detail)
    _enemy_inner.detail_requested.connect(_show_detail)
    _connect_tooltip_source(_player_inner)
    _connect_tooltip_source(_enemy_inner)
    _player_grid.details_requested.connect(_show_detail)
    _enemy_grid.details_requested.connect(_show_detail)
    _connect_tooltip_source(_player_grid)
    _connect_tooltip_source(_enemy_grid)
    _connect_tooltip_source(_player_actor)
    _connect_tooltip_source(_enemy_actor)
    _connect_tooltip_source(_intent_panel)
    _player_actor.detail_requested.connect(_show_detail)
    _enemy_actor.detail_requested.connect(_show_detail)
    _intent_panel.detail_requested.connect(_show_detail)
    _hand.card_pressed.connect(func(card_id: String): card_pressed.emit(card_id))
    _hand.zone_details_requested.connect(func(zones: Dictionary): _show_detail("zones", zones))
    _hand.card_detail_requested.connect(func(card: Dictionary): _show_detail("cards", card))
    _hand.tooltip_requested.connect(_show_tooltip)
    _hand.tooltip_hidden.connect(_hide_tooltip)
    _action_bar.confirm_requested.connect(func(): confirm_requested.emit())
    _action_bar.end_turn_requested.connect(func(): end_turn_requested.emit())
    _action_bar.start_turn_requested.connect(func(): start_turn_requested.emit())
    _action_bar.consumable_selected.connect(func(index: int): consumable_selected.emit(index))
    _action_bar.consumable_use_requested.connect(func(): consumable_use_requested.emit())
    _connect_tooltip_source(_action_bar)
    _action_bar.detail_requested.connect(_show_detail)
    _drawer_button.pressed.connect(toggle_side_drawer)
    _debug_button.pressed.connect(toggle_debug_drawer)

func _connect_tooltip_source(source: Object) -> void:
    source.tooltip_requested.connect(_show_tooltip)
    source.tooltip_hidden.connect(_hide_tooltip)

func configure_mode(debug_enabled: bool) -> void:
    _debug_enabled = debug_enabled
    if _debug_enabled and _debug_drawer == null and is_inside_tree():
        _debug_drawer = DebugDrawerScene.instantiate()
        _debug_drawer.reset_requested.connect(func(seed: int): reset_requested.emit(seed))
        _debug_drawer.channel_toggle_requested.connect(func(): debug_channel_toggle_requested.emit())
        add_child(_debug_drawer)
        _debug_drawer.configure_mode(true)
    if _debug_button != null:
        _debug_button.visible = _debug_enabled
    if _debug_drawer != null:
        _debug_drawer.configure_mode(_debug_enabled)

func present(snapshot: Dictionary) -> void:
    var player: Dictionary = snapshot.get("player", {})
    var enemy: Dictionary = snapshot.get("enemy", {})
    var phase: Dictionary = snapshot.get("battle_phase", {})
    _round_label.text = ("第 %02d 回合" % int(phase.get("turn", 0))
        if str(phase.get("state", "active")) == "active"
        else str(phase.get("detail", "战斗结束")))
    _action_label.text = "第 %02d 次行动" % int(phase.get("action_index", 0))
    _player_inner.present(player)
    _enemy_inner.present(enemy)
    _player_actor.present(player.merged({"items": player.get("items", [])}, true))
    _enemy_actor.present(enemy)
    _enemy_hand.text = "敌方牌区\n手牌 %d / %d    经脉 %d    牌库 %d" % [
        int(enemy.get("hand_count", 0)), int(enemy.get("hand_limit", 0)),
        int(enemy.get("occupied_meridian_count", 0)), int(enemy.get("zones", {}).get("draw_count", 0))]
    _player_grid.present(snapshot.get("technique_sequences", {}).get("player", []), "我方功法槽")
    _enemy_grid.present(snapshot.get("technique_sequences", {}).get("enemy", []), "敌方功法槽")
    _player_values.present(snapshot.get("action_preview", {}))
    _enemy_values.present({}, true)
    _intent_panel.present(snapshot.get("enemy_intents", []))
    _stage.present(snapshot.get("action_preview", {}), snapshot.get("last_resolution", {}))
    _hand.present(player, snapshot.get("selection", {}).get("ids", []))
    _action_bar.present(player.get("consumables", []), int(snapshot.get("selection", {}).get("active_consumable_slot", -1)), snapshot.get("available_commands", {}))
    _side_drawer.present(snapshot)
    if _debug_drawer != null and _debug_enabled:
        _debug_drawer.present(snapshot.get("debug_info", {}))
    var notification := str(snapshot.get("notification", ""))
    if notification != "" and notification != _last_notification:
        _notifications.notify(notification, true)
    _last_notification = notification

func toggle_side_drawer() -> void:
    _side_drawer.toggle()

func toggle_debug_drawer() -> void:
    if _debug_enabled and _debug_drawer != null:
        _debug_drawer.toggle()

func side_drawer_is_open() -> bool:
    return _side_drawer.is_open()

func debug_drawer_is_open() -> bool:
    return _debug_drawer != null and _debug_drawer.is_open()

func debug_drawer_enabled() -> bool:
    return _debug_drawer != null and _debug_drawer.is_debug_enabled()

func intent_panel():
    return _intent_panel

func presentation_layers() -> Dictionary:
    return _stage.presentation_layers()

func main_action_rect() -> Rect2:
    return _action_bar.primary_actions_rect()

func layout_rects() -> Dictionary:
    return {"top": _top_region.get_global_rect(), "middle": _middle_region.get_global_rect(),
        "bottom": _bottom_region.get_global_rect(), "player_side": _player_side.get_global_rect(),
        "enemy_side": _enemy_side.get_global_rect(), "hand": _hand.hand_cards_rect(),
        "actions": main_action_rect()}

func set_input_locked(value: bool) -> void:
    _presentation_busy = value
    _hand.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_PASS
    _action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_PASS

func presentation_busy() -> bool:
    return _presentation_busy

func clear_presentation() -> void:
    for layer_name in ["card_motion_layer", "combat_vfx_layer", "floating_text_layer", "technique_banner_layer"]:
        for child in presentation_layers()[layer_name].get_children():
            child.queue_free()
    set_input_locked(false)

func _show_detail(section: String, payload: Dictionary) -> void:
    _side_drawer.show_detail(section, payload)

func _show_tooltip(detail: Dictionary, target_rect: Rect2) -> void:
    _tooltip.show_contract(detail, target_rect, get_viewport_rect().size)

func _hide_tooltip() -> void:
    _tooltip.hide_detail()

func _apply_responsive_layout() -> void:
    if not is_node_ready():
        return
    var small := size.x < 1400.0 or size.y < 800.0
    var medium := not small and (size.x < 1800.0 or size.y < 1000.0)
    var compact := small or medium
    var side_width := 180.0 if small else (240.0 if medium else 300.0)
    _top_region.custom_minimum_size.y = 140.0 if small else (165.0 if medium else 190.0)
    _bottom_region.custom_minimum_size.y = 260.0 if small else 300.0
    _player_inner.set_compact(compact)
    _enemy_inner.set_compact(compact)
    _player_side.custom_minimum_size.x = side_width
    _enemy_side.custom_minimum_size.x = side_width
    _player_actor.custom_minimum_size.y = 105.0 if compact else 190.0
    _enemy_actor.custom_minimum_size.y = 80.0 if compact else 112.0
    _player_grid.set_compact(compact)
    _enemy_grid.set_compact(compact)
    _player_values.custom_minimum_size.x = 150.0 if small else (240.0 if medium else 330.0)
    _enemy_values.custom_minimum_size.x = 150.0 if small else (240.0 if medium else 330.0)
    _intent_panel.custom_minimum_size.x = 100.0 if small else (150.0 if medium else 190.0)
