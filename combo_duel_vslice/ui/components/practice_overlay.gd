class_name PracticeOverlay
extends ColorRect

signal close_requested
signal purchase_requested(consumable_id: String)

const UiDesignScript = preload("res://ui/ui_design.gd")
const OfferCardScene = preload("res://ui/components/practice_offer_card.tscn")

var _experience: Label
var _offers: HBoxContainer
var _inventory: Label
var _built := false

func _ready() -> void:
    _ensure_built()

func present(data: Dictionary) -> void:
    _ensure_built()
    _experience.text = "历练 %d" % int(data.get("experience", 0))
    var growth: Dictionary = data.get("growth", {})
    var consumables: Array = growth.get("consumables", [])
    _inventory.text = "共享消耗品栏  %d / 3  ·  %s" % [
        consumables.size(),
        "、".join(_consumable_names(consumables)) if not consumables.is_empty() else "当前为空"]
    for child in _offers.get_children():
        child.queue_free()
    var practice: Dictionary = data.get("practice", {})
    for offer_value in practice.get("offers", []):
        var offer = OfferCardScene.instantiate()
        offer.purchase_requested.connect(func(consumable_id: String):
            purchase_requested.emit(consumable_id))
        _offers.add_child(offer)
        offer.present(offer_value)

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    color = Color(0.015, 0.02, 0.025, 0.9)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visible = false
    z_index = 200
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(1040, 590)
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color("211d27"), 18, Color("7a5b91"), 3, 14))
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    panel.add_child(box)
    var header := HBoxContainer.new()
    box.add_child(header)
    var title := Label.new()
    title.text = "修 习"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 32)
    header.add_child(title)
    _experience = UiDesignScript.chip("历练 0", UiDesignScript.COLORS["gold"], 112)
    _experience.custom_minimum_size.y = 34
    header.add_child(_experience)
    var close := Button.new()
    close.text = "返回地图"
    close.pressed.connect(func(): close_requested.emit())
    UiDesignScript.style_button(close)
    header.add_child(close)
    var subtitle := Label.new()
    subtitle.text = "地图待选节点期间可随时打开 · 当前纵切使用固定代表选项"
    subtitle.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    box.add_child(subtitle)
    box.add_child(UiDesignScript.divider())
    _offers = HBoxContainer.new()
    _offers.alignment = BoxContainer.ALIGNMENT_CENTER
    _offers.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _offers.add_theme_constant_override("separation", 16)
    box.add_child(_offers)
    _inventory = Label.new()
    _inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _inventory.add_theme_font_size_override("font_size", 14)
    _inventory.add_theme_color_override("font_color", Color("d8c9e1"))
    box.add_child(_inventory)
    var note := Label.new()
    note.text = "冥想费用、商品数量与购买后补货规则尚未确认，本纵切不补设计。"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_color_override("font_color", Color("877f8b"))
    box.add_child(note)

func _consumable_names(consumables: Array) -> Array[String]:
    var names: Array[String] = []
    for value in consumables:
        var definition: Dictionary = value
        names.append(str(definition.get("name", definition.get("id", "未命名"))))
    return names
