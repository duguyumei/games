class_name QiCardView
extends Button

signal qi_card_pressed(card_id: String)

const ATTR_COLORS := {
    "wind": Color("317fb7"),
    "forest": Color("3f965c"),
    "fire": Color("c94d3f"),
    "mountain": Color("c18a31"),
}

const ATTR_SYMBOLS := {
    "wind": "≋",
    "forest": "♣",
    "fire": "◆",
    "mountain": "▲",
}

var card_data
var selected: bool = false
var compact: bool = false
var interactive: bool = true
var _accent := Color.WHITE

func setup(card, is_selected: bool = false, is_compact: bool = false, is_interactive: bool = true) -> void:
    card_data = card
    selected = is_selected
    compact = is_compact
    interactive = is_interactive
    _accent = ATTR_COLORS.get(card.attribute, Color("666666"))
    custom_minimum_size = Vector2(80, 114) if compact else Vector2(116, 168)
    size = custom_minimum_size
    pivot_offset = size * 0.5
    focus_mode = Control.FOCUS_NONE
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
    disabled = not interactive
    flat = false
    clip_contents = false
    _rebuild_visuals()
    if interactive:
        mouse_entered.connect(_on_mouse_entered)
        mouse_exited.connect(_on_mouse_exited)
        pressed.connect(func(): qi_card_pressed.emit(card_data.id))

func _rebuild_visuals() -> void:
    for child in get_children():
        child.queue_free()
    _apply_styles()
    var width := custom_minimum_size.x
    var height := custom_minimum_size.y
    var rank_size := 21 if compact else 29
    var small_size := 11 if compact else 13

    var art_path := _find_card_art()
    if art_path != "":
        var artwork := TextureRect.new()
        artwork.position = Vector2(4, 4)
        artwork.size = Vector2(width - 8, height - 8)
        artwork.texture = load(art_path)
        artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(artwork)
        _add_selected_badge(width)
        return

    var rank := Label.new()
    rank.text = card_data.rank_name
    rank.position = Vector2(9, 5)
    rank.size = Vector2(48, 36)
    rank.add_theme_font_size_override("font_size", rank_size)
    rank.add_theme_color_override("font_color", Color("182026"))
    rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(rank)

    var symbol := Label.new()
    symbol.text = ATTR_SYMBOLS.get(card_data.attribute, "●")
    symbol.position = Vector2(10, 34 if not compact else 27)
    symbol.size = Vector2(34, 28)
    symbol.add_theme_font_size_override("font_size", 17 if compact else 23)
    symbol.add_theme_color_override("font_color", _accent)
    symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(symbol)

    var emblem := PanelContainer.new()
    var emblem_width := 54.0 if compact else 76.0
    var emblem_height := 48.0 if compact else 68.0
    emblem.position = Vector2((width - emblem_width) * 0.5, 39 if compact else 48)
    emblem.size = Vector2(emblem_width, emblem_height)
    emblem.add_theme_stylebox_override("panel", _emblem_style())
    emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var emblem_label := Label.new()
    emblem_label.text = card_data.attribute_name
    emblem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    emblem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    emblem_label.add_theme_font_size_override("font_size", 23 if compact else 34)
    emblem_label.add_theme_color_override("font_color", Color("f8edcf"))
    emblem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    emblem.add_child(emblem_label)
    add_child(emblem)

    var qi_pill := PanelContainer.new()
    qi_pill.position = Vector2(8, height - (26 if compact else 34))
    qi_pill.size = Vector2(50 if compact else 68, 20 if compact else 25)
    qi_pill.add_theme_stylebox_override("panel", _pill_style())
    qi_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var qi_label := Label.new()
    qi_label.text = "气 %d" % card_data.qi_value
    qi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    qi_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    qi_label.add_theme_font_size_override("font_size", small_size)
    qi_label.add_theme_color_override("font_color", Color("f9f0da"))
    qi_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    qi_pill.add_child(qi_label)
    add_child(qi_pill)

    var corner_rank := Label.new()
    corner_rank.text = card_data.rank_name
    corner_rank.position = Vector2(width - (29 if compact else 40), height - (31 if compact else 43))
    corner_rank.size = Vector2(25, 29)
    corner_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    corner_rank.add_theme_font_size_override("font_size", 17 if compact else 22)
    corner_rank.add_theme_color_override("font_color", _accent.darkened(0.2))
    corner_rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(corner_rank)

    _add_selected_badge(width)

func _add_selected_badge(width: float) -> void:
    var selected_badge := Label.new()
    selected_badge.text = "✓" if selected else ""
    selected_badge.position = Vector2(width - 33, 6)
    selected_badge.size = Vector2(25, 25)
    selected_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selected_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    selected_badge.add_theme_font_size_override("font_size", 18)
    selected_badge.add_theme_color_override("font_color", Color("ffd86a"))
    selected_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(selected_badge)

func _find_card_art() -> String:
    for extension in ["png", "webp", "jpg"]:
        var candidate := "res://assets/cards/%s.%s" % [card_data.id, extension]
        if ResourceLoader.exists(candidate):
            return candidate
    return ""

func _apply_styles() -> void:
    var border := Color("ffd760") if selected else Color("25252a")
    var border_width := 5 if selected else 3
    add_theme_stylebox_override("normal", _card_style(Color("f4e8c8"), border, border_width, 7 if selected else 5, Vector2(5, 8)))
    add_theme_stylebox_override("hover", _card_style(Color("fff2cf"), Color("ffd760"), 4, 10, Vector2(6, 10)))
    add_theme_stylebox_override("pressed", _card_style(Color("ead9b4"), Color("fff0a2"), 5, 4, Vector2(3, 5)))
    add_theme_stylebox_override("disabled", _card_style(Color("f4e8c8"), border, border_width, 5, Vector2(4, 7)))

func _card_style(fill: Color, border: Color, border_width: int, shadow_size: int, shadow_offset: Vector2) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(11 if compact else 14)
    style.shadow_color = Color(0.01, 0.03, 0.025, 0.62)
    style.shadow_size = shadow_size
    style.shadow_offset = shadow_offset
    style.anti_aliasing = true
    return style

func _emblem_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = _accent
    style.border_color = _accent.lightened(0.28)
    style.set_border_width_all(2)
    style.set_corner_radius_all(14 if compact else 20)
    style.shadow_color = Color(0.02, 0.04, 0.03, 0.28)
    style.shadow_size = 4
    style.shadow_offset = Vector2(2, 3)
    return style

func _pill_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = _accent.darkened(0.22)
    style.set_corner_radius_all(8)
    return style

func _on_mouse_entered() -> void:
    z_index = 100
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2(1.075, 1.075), 0.12)

func _on_mouse_exited() -> void:
    z_index = 50 if selected else 0
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, 0.1)
