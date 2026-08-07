class_name BattleHandZone
extends VBoxContainer

signal card_pressed(card_id: String)

const QiCardViewScript = preload("res://ui/qi_card_view.gd")
const UiDesignScript = preload("res://ui/ui_design.gd")

var _fan: Control
var _draw_pile: Control
var _discard_pile: Control
var _draw_count: Label
var _discard_count: Label
var _card_nodes: Array = []
var _selected_ids: Array[String] = []
var _built := false

func _ready() -> void:
    _ensure_built()

func present(data: Dictionary, selected_ids: Array) -> void:
    _ensure_built()
    _selected_ids.clear()
    for card_id in selected_ids:
        _selected_ids.append(str(card_id))
    _draw_count.text = "%d / %d" % [
        int(data.get("draw_count", 0)), int(data.get("deck_count", 0))]
    _discard_count.text = str(int(data.get("discard_count", 0)))
    for child in _card_nodes:
        if is_instance_valid(child):
            child.queue_free()
    _card_nodes.clear()
    var sorted_hand: Array = data.get("hand", []).duplicate(true)
    sorted_hand.sort_custom(func(left, right):
        if int(left.get("rank_order", 0)) == int(right.get("rank_order", 0)):
            return str(left.get("attribute", "")) < str(right.get("attribute", ""))
        return int(left.get("rank_order", 0)) < int(right.get("rank_order", 0)))
    for card_value in sorted_hand:
        var card: Dictionary = card_value
        var view = QiCardViewScript.new()
        view.setup(card, _selected_ids.has(str(card.get("id", ""))), false, true)
        view.qi_card_pressed.connect(func(card_id: String): card_pressed.emit(card_id))
        view.tooltip_text = _card_tooltip(card)
        _fan.add_child(view)
        _card_nodes.append(view)
    _layout_cards.call_deferred()

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    custom_minimum_size.y = 202
    var title := Label.new()
    title.text = "手  牌   ·   点击真气进行组合"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_color_override("font_color", Color(0.72, 0.86, 0.8, 0.76))
    add_child(title)
    _fan = Control.new()
    _fan.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _fan.clip_contents = false
    _fan.resized.connect(_layout_cards)
    var discard := _pile_widget("弃", Color("59616a"))
    _discard_pile = discard["root"]
    _discard_count = discard["count"]
    _fan.add_child(_discard_pile)
    var draw := _pile_widget("真气", UiDesignScript.COLORS["purple"])
    _draw_pile = draw["root"]
    _draw_count = draw["count"]
    _fan.add_child(_draw_pile)
    add_child(_fan)

func _layout_cards() -> void:
    if _fan == null or _draw_pile == null:
        return
    _discard_pile.position = Vector2(2, 35)
    _discard_pile.z_index = 120
    _draw_pile.position = Vector2(_fan.size.x - 80, 28)
    _draw_pile.z_index = 120
    if _card_nodes.is_empty():
        return
    var count := _card_nodes.size()
    var card_width := 116.0
    var reserved_left := 82.0
    var reserved_right := 92.0
    var available := maxf(100.0, _fan.size.x - reserved_left - reserved_right)
    var spacing := 0.0 if count <= 1 else minf(92.0, (available - card_width) / float(count - 1))
    spacing = maxf(38.0, spacing)
    var total_width := card_width + spacing * (count - 1)
    var start_x := reserved_left + (available - total_width) * 0.5
    var middle := (count - 1) * 0.5
    for index in range(count):
        var view = _card_nodes[index]
        var distance: float = absf(index - middle)
        var lift := 24.0 if _selected_ids.has(view.card_id()) else 0.0
        view.position = Vector2(start_x + index * spacing, 8.0 + distance * 2.8 - lift)
        view.rotation = deg_to_rad((index - middle) * 1.15)
        view.z_index = 50 + index if _selected_ids.has(view.card_id()) else index

func _pile_widget(title_text: String, color: Color) -> Dictionary:
    var root := Control.new()
    root.custom_minimum_size = Vector2(78, 126)
    root.size = root.custom_minimum_size
    for offset in [Vector2(7, 7), Vector2(4, 4), Vector2.ZERO]:
        var card_back := PanelContainer.new()
        card_back.position = Vector2(5, 4) + offset
        card_back.size = Vector2(65, 94)
        card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card_back.add_theme_stylebox_override(
            "panel", UiDesignScript.box(color.darkened(0.22), 8, color.lightened(0.08), 2, 3))
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
    count.position = Vector2(2, 104)
    count.size = Vector2(74, 20)
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count.add_theme_font_size_override("font_size", 12)
    root.add_child(count)
    return {"root": root, "count": count}

func _card_tooltip(card: Dictionary) -> String:
    var enhancement_text: String = {
        "bonus": "｜奖励牌：有效真气值 +2",
        "multiplier": "｜倍率牌：功法倍率 +2",
    }.get(card.get("reshapes", {}).get("enhancement", ""), "")
    var finish_text: String = {
        "foil": "｜箔面：自身贡献 +3",
        "holographic": "｜镭射：功法倍率 +1",
        "polychrome": "｜多彩：功法值增幅 +20%",
    }.get(card.get("reshapes", {}).get("finish", ""), "")
    return "%s｜牌阶 %s｜真气值 %d｜%s属性%s%s%s" % [
        card.get("id", ""), card.get("rank_name", ""), card.get("qi_value", 0),
        card.get("attribute_name", ""), enhancement_text, finish_text,
        "｜烈毒：打出时受到当前有效真气值伤害"
        if str(card.get("anomalies", {}).get("poison", "")) == "lethal_poison" else ""]
