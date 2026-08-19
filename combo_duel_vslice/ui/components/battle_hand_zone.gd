class_name BattleHandZone
extends Control

signal card_pressed(card_id: String)
signal zone_details_requested(zones: Dictionary)
signal card_detail_requested(card: Dictionary)
signal tooltip_requested(detail: Dictionary, target_rect: Rect2)
signal tooltip_hidden

const QiCardViewScript = preload("res://ui/qi_card_view.gd")
const UiDesignScript = preload("res://ui/ui_design.gd")

var _fan: Control
var _deck_button: Button
var _hand_capacity: Label
var _card_nodes: Array = []
var _card_registry: Dictionary = {}
var _selected_ids: Array[String] = []
var _zones: Dictionary = {}

func _ready() -> void:
    name = "PlayerHandZone"
    custom_minimum_size.y = UiDesignScript.BOTTOM_ZONE_HEIGHT
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clip_contents = false
    _fan = Control.new()
    _fan.name = "HandFan"
    _fan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _fan.clip_contents = false
    _fan.resized.connect(_layout_cards)
    add_child(_fan)
    _deck_button = Button.new()
    _deck_button.name = "DeckStack"
    _deck_button.tooltip_text = "点击查看牌库、弃牌和消耗区的完整内容"
    _deck_button.pressed.connect(func(): zone_details_requested.emit(_zones.duplicate(true)))
    _deck_button.add_theme_font_size_override("font_size", UiDesignScript.FONT_SUBTITLE)
    _deck_button.add_theme_stylebox_override("normal", UiDesignScript.box(
        UiDesignScript.COLORS["panel"], 12, UiDesignScript.COLORS["copper"], 3, 8))
    _fan.add_child(_deck_button)
    _hand_capacity = Label.new()
    _hand_capacity.name = "HandCapacity"
    _hand_capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hand_capacity.add_theme_font_size_override("font_size", UiDesignScript.FONT_BODY)
    _hand_capacity.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    _fan.add_child(_hand_capacity)

func present(data: Dictionary, selected_ids: Array) -> void:
    _selected_ids.clear()
    for card_id in selected_ids:
        _selected_ids.append(str(card_id))
    _zones = data.get("zones", {}).duplicate(true)
    _deck_button.text = "太吾\n\n%d" % int(_zones.get("draw_count", 0))
    _hand_capacity.text = "%d / %d" % [
        int(data.get("hand_count", 0)), int(data.get("hand_limit", 0))]
    var hand: Array = data.get("hand", []).duplicate(true)
    hand.sort_custom(func(left, right):
        if int(left.get("rank_order", 0)) == int(right.get("rank_order", 0)):
            return str(left.get("attribute", "")) < str(right.get("attribute", ""))
        return int(left.get("rank_order", 0)) < int(right.get("rank_order", 0)))
    var live_ids: Dictionary = {}
    var ordered_nodes: Array = []
    for card_value in hand:
        var card: Dictionary = card_value
        var card_id := str(card.get("id", ""))
        if card_id == "":
            card_id = "anonymous:%d" % ordered_nodes.size()
        live_ids[card_id] = true
        var view = _card_registry.get(card_id)
        if view == null or not is_instance_valid(view):
            view = QiCardViewScript.new()
            view.name = "QiCard_%s" % card_id.validate_node_name()
            view.qi_card_pressed.connect(func(pressed_id: String): card_pressed.emit(pressed_id))
            view.gui_input.connect(func(event: InputEvent):
                if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
                    card_detail_requested.emit(view.card_data.duplicate(true)))
            view.mouse_entered.connect(func():
                tooltip_requested.emit(_card_detail(view.card_data), view.get_global_rect()))
            view.mouse_exited.connect(func(): tooltip_hidden.emit())
            _fan.add_child(view)
            _card_registry[card_id] = view
        view.update_card(card, _selected_ids.has(str(card.get("id", ""))), false, true)
        ordered_nodes.append(view)
    for existing_id in _card_registry.keys():
        if not live_ids.has(existing_id):
            var stale = _card_registry[existing_id]
            _card_registry.erase(existing_id)
            if is_instance_valid(stale):
                stale.queue_free()
    _card_nodes = ordered_nodes
    _layout_cards.call_deferred()

func card_node_for_id(card_id: String):
    return _card_registry.get(card_id)

func hand_cards_rect() -> Rect2:
    var result := Rect2()
    var initialized := false
    for card in _card_nodes:
        if not is_instance_valid(card):
            continue
        result = card.get_global_rect() if not initialized else result.merge(card.get_global_rect())
        initialized = true
    return result

func main_actions_visible(viewport_size: Vector2) -> bool:
    return viewport_size.x >= 1280.0 and viewport_size.y >= 720.0

func _layout_cards() -> void:
    if _fan == null:
        return
    var deck_size := Vector2(132, 188)
    _deck_button.position = Vector2(maxf(16.0, _fan.size.x * 0.02), 54)
    _deck_button.size = deck_size
    _hand_capacity.position = Vector2(_fan.size.x * 0.5 - 80, _fan.size.y - 26)
    _hand_capacity.size = Vector2(160, 22)
    if _card_nodes.is_empty():
        return
    var count := _card_nodes.size()
    var card_width := 116.0
    var reserved_left := minf(180.0, _fan.size.x * 0.17)
    var reserved_right := 12.0
    var available := maxf(220.0, _fan.size.x - reserved_left - reserved_right)
    var spacing := 0.0 if count <= 1 else minf(112.0, (available - card_width) / float(count - 1))
    spacing = maxf(38.0, spacing)
    var total_width := card_width + spacing * (count - 1)
    var start_x := reserved_left + maxf(0.0, (available - total_width) * 0.5)
    var middle := (count - 1) * 0.5
    for index in range(count):
        var view = _card_nodes[index]
        var distance: float = absf(index - middle)
        var lift := 30.0 if _selected_ids.has(view.card_id()) else 0.0
        view.position = Vector2(start_x + index * spacing, 42.0 + distance * 5.0 - lift)
        view.rotation = deg_to_rad((index - middle) * 2.2)
        view.z_index = 100 + index if _selected_ids.has(view.card_id()) else index

func _card_detail(card: Dictionary) -> Dictionary:
    return {
        "kind": "qi_card",
        "title": str(card.get("name", card.get("id", "未知卡牌"))),
        "subtitle": "牌阶 %s · %s" % [card.get("rank_name", "?"), card.get("attribute_name", "未知属性")],
        "description": str(card.get("description", "右键打开完整详情")),
        "values": [{"label": "真气", "value": int(card.get("qi_value", 0))}],
        "tags": card.get("tags", []),
        "icon": str(card.get("icon", "")),
        "placeholder": "?",
    }
