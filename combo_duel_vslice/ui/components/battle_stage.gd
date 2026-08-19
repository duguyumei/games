class_name BattleStage
extends Control

const UiDesignScript = preload("res://ui/ui_design.gd")
const QiCardViewScript = preload("res://ui/qi_card_view.gd")

var _player_anchor: HBoxContainer
var _enemy_anchor: HBoxContainer
var _empty_hint: Label
var card_motion_layer: Control
var combat_vfx_layer: Control
var floating_text_layer: Control
var technique_banner_layer: Control
var modal_layer: Control

func _ready() -> void:
    name = "BattleStage"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var content := VBoxContainer.new()
    content.name = "ResolutionStage"
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(content)
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(spacer)
    var anchors := HBoxContainer.new()
    anchors.custom_minimum_size.y = 220
    anchors.add_theme_constant_override("separation", UiDesignScript.SPACE_XL)
    anchors.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(anchors)
    _player_anchor = _anchor("player_card_resolution_anchor")
    anchors.add_child(_player_anchor)
    _empty_hint = Label.new()
    _empty_hint.text = "选择手牌后，双方打出的真气将在此同步结算"
    _empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _empty_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _empty_hint.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
    _empty_hint.add_theme_color_override("font_color", Color(UiDesignScript.COLORS["muted"], 0.55))
    anchors.add_child(_empty_hint)
    _enemy_anchor = _anchor("enemy_card_resolution_anchor")
    anchors.add_child(_enemy_anchor)
    _build_presentation_layers()

func present(action_preview: Dictionary, last_resolution: Dictionary) -> void:
    var preview_cards: Array = action_preview.get("cards", [])
    var player_cards: Array = preview_cards
    var enemy_cards: Array = []
    if preview_cards.is_empty():
        player_cards = last_resolution.get("player_cards", [])
        enemy_cards = last_resolution.get("enemy_cards", [])
    _populate(_player_anchor, player_cards,
        action_preview.get("contributing_card_ids", []))
    _populate(_enemy_anchor, enemy_cards,
        last_resolution.get("enemy_preview", {}).get("hand", {}).get(
            "contributing_card_ids", []))
    _empty_hint.visible = player_cards.is_empty() and enemy_cards.is_empty()

func presentation_layers() -> Dictionary:
    return {
        "card_motion_layer": card_motion_layer,
        "combat_vfx_layer": combat_vfx_layer,
        "floating_text_layer": floating_text_layer,
        "technique_banner_layer": technique_banner_layer,
        "modal_layer": modal_layer,
    }

func _anchor(node_name: String) -> HBoxContainer:
    var result := HBoxContainer.new()
    result.name = node_name
    result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    result.alignment = BoxContainer.ALIGNMENT_CENTER
    result.add_theme_constant_override("separation", -32)
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return result

func _populate(container: HBoxContainer, cards: Array, contributing_ids: Array) -> void:
    for child in container.get_children():
        child.queue_free()
    for card_value in cards.slice(0, 5):
        var card: Dictionary = card_value
        var view = QiCardViewScript.new()
        view.setup(card, contributing_ids.has(str(card.get("id", ""))), true, false)
        view.mouse_filter = Control.MOUSE_FILTER_IGNORE
        container.add_child(view)

func _build_presentation_layers() -> void:
    card_motion_layer = _presentation_layer("card_motion_layer", true)
    combat_vfx_layer = _presentation_layer("combat_vfx_layer", true)
    floating_text_layer = _presentation_layer("floating_text_layer", true)
    technique_banner_layer = _presentation_layer("technique_banner_layer", true)
    modal_layer = _presentation_layer("modal_layer", false)
    modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    modal_layer.visible = false

func _presentation_layer(layer_name: String, pass_mouse: bool) -> Control:
    var layer := Control.new()
    layer.name = layer_name
    layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE if pass_mouse else Control.MOUSE_FILTER_STOP
    layer.z_index = 300 + get_child_count()
    add_child(layer)
    return layer
