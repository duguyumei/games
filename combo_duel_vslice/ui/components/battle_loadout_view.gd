class_name BattleLoadoutView
extends Control

signal detail_requested(section: String, payload: Dictionary)

const UiDesignScript = preload("res://ui/ui_design.gd")

var _skills: Array = []
var _cards: Array[Button] = []
var _compact := false

func _ready() -> void:
    name = "BattleInnerSkillRow"
    custom_minimum_size = Vector2(380, 190)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clip_contents = false
    resized.connect(_layout_cards)

func present(data: Dictionary) -> void:
    _skills = data.get("inner_skills", []).duplicate(true)
    for card in _cards:
        if is_instance_valid(card):
            card.queue_free()
    _cards.clear()
    var visible_count := maxi(_skills.size(), mini(3, int(data.get("inner_skill_limit", 0))))
    for index in range(visible_count):
        var definition: Dictionary = _skills[index] if index < _skills.size() else {}
        var card := _inner_skill_card(definition, index)
        add_child(card)
        _cards.append(card)
    _layout_cards.call_deferred()

func set_compact(value: bool) -> void:
    _compact = value
    custom_minimum_size.y = 140 if _compact else 190
    _layout_cards()

func _inner_skill_card(definition: Dictionary, index: int) -> Button:
    var card := Button.new()
    card.name = "InnerSkillCard%d" % (index + 1)
    card.size = Vector2(110, 156)
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
    card.pressed.connect(func(): detail_requested.emit("inner_skills", definition))
    return card

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
