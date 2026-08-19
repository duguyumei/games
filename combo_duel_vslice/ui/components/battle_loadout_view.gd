class_name BattleLoadoutView
extends Control

signal detail_requested(section: String, payload: Dictionary)
signal tooltip_requested(detail: Dictionary, target_rect: Rect2)
signal tooltip_hidden

const UiDesignScript = preload("res://ui/ui_design.gd")

var _skills: Array = []
var _cards: Array[Button] = []
var _card_registry: Dictionary = {}
var _compact := false

func _ready() -> void:
    name = "BattleInnerSkillRow"
    custom_minimum_size = Vector2(380, 190)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clip_contents = false
    resized.connect(_layout_cards)

func present(data: Dictionary) -> void:
    _skills = data.get("inner_skills", []).duplicate(true)
    var visible_count := maxi(_skills.size(), mini(3, int(data.get("inner_skill_limit", 0))))
    var live_keys: Dictionary = {}
    var ordered: Array[Button] = []
    for index in range(visible_count):
        var definition: Dictionary = _skills[index] if index < _skills.size() else {}
        var key := _skill_key(definition, index)
        live_keys[key] = true
        var card: Button = _card_registry.get(key)
        if card == null or not is_instance_valid(card):
            card = _inner_skill_card(definition, index)
            add_child(card)
            _card_registry[key] = card
        _update_inner_skill_card(card, definition, index)
        ordered.append(card)
    for key in _card_registry.keys():
        if not live_keys.has(key):
            var stale = _card_registry[key]
            _card_registry.erase(key)
            if is_instance_valid(stale):
                stale.queue_free()
    _cards = ordered
    _layout_cards.call_deferred()

func card_node_for_key(key: String):
    return _card_registry.get(key)

func _skill_key(definition: Dictionary, index: int) -> String:
    var stable := str(definition.get("instance_id", definition.get("id", definition.get("definition_id", ""))))
    return "%d:%s" % [index, stable if stable != "" else "empty"]

func set_compact(value: bool) -> void:
    _compact = value
    custom_minimum_size = Vector2(260, 140) if _compact else Vector2(380, 190)
    _layout_cards()

func _inner_skill_card(definition: Dictionary, index: int) -> Button:
    var card := Button.new()
    card.name = "InnerSkillCard%d" % (index + 1)
    card.size = Vector2(132, 188)
    card.custom_minimum_size = card.size
    card.pressed.connect(func(): detail_requested.emit("inner_skills", card.get_meta("payload", {})))
    card.mouse_entered.connect(func(): tooltip_requested.emit(_tooltip_contract(card.get_meta("payload", {})), card.get_global_rect()))
    card.mouse_exited.connect(func(): tooltip_hidden.emit())
    return card

func _tooltip_contract(data: Dictionary) -> Dictionary:
    return {"kind": "inner_skill", "title": str(data.get("name", "内功空槽")),
        "subtitle": "内功", "description": str(data.get("description", "暂无说明")),
        "icon": str(data.get("icon", "")), "placeholder": "?", "values": [], "tags": data.get("tags", [])}

func _update_inner_skill_card(card: Button, definition: Dictionary, index: int) -> void:
    card.name = "InnerSkillCard%d" % (index + 1)
    card.size = Vector2(132, 188)
    card.custom_minimum_size = card.size
    var skill_name := str(definition.get("name", ""))
    var initial := skill_name.left(1) if skill_name != "" else "?"
    card.text = "内功\n\n%s\n%s" % [initial, skill_name if skill_name != "" else "空槽"]
    card.tooltip_text = (
        "%s\n%s" % [skill_name, definition.get("description", "")]
        if not definition.is_empty() else "内功空槽；缺少图标时使用明确问号占位")
    card.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
    card.add_theme_color_override("font_color", UiDesignScript.COLORS["cream"])
    var border := UiDesignScript.COLORS["copper"] if not definition.is_empty() else UiDesignScript.COLORS["line"]
    card.add_theme_stylebox_override("normal", UiDesignScript.box(
        UiDesignScript.COLORS["panel"], 10, border, 3, 7, Vector2(6, 6)))
    card.add_theme_stylebox_override("hover", UiDesignScript.box(
        UiDesignScript.COLORS["panel_2"], 10, UiDesignScript.COLORS["gold"], 3, 10, Vector2(6, 6)))
    card.disabled = definition.is_empty()
    card.set_meta("payload", definition.duplicate(true))

func _layout_cards() -> void:
    if _cards.is_empty():
        return
    var count := _cards.size()
    var card_size := Vector2(110, 156)
    var visual_scale := 0.72 if _compact else 1.0
    var available := maxf(card_size.x, size.x - card_size.x)
    var spacing := 0.0 if count <= 1 else minf(96.0, available / float(count - 1))
    var total_width := card_size.x + spacing * (count - 1)
    var start_x := maxf(0.0, (size.x - total_width) * 0.5)
    var rotations := [-5.0, 4.0, 2.0, -1.0, -3.0, -5.0]
    for index in range(count):
        var card := _cards[index]
        var distance := absf(index - (count - 1) * 0.5)
        card.position = Vector2(start_x + spacing * index, 8.0 + distance * 4.0)
        card.rotation = deg_to_rad(float(rotations[index % rotations.size()]))
        card.pivot_offset = card_size * 0.5
        card.scale = Vector2.ONE * visual_scale
        card.z_index = index
