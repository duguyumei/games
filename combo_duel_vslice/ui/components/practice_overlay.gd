class_name PracticeOverlay
extends ColorRect

signal close_requested
signal purchase_requested(consumable_id: String)
signal purchase_offer_requested(group: String, slot_index: int)
signal pack_selection_requested(
    group: String,
    slot_index: int,
    selected_ids: Array,
    preparation_token: String)
signal meditate_requested

const UiDesignScript = preload("res://ui/ui_design.gd")
const OfferCardScene = preload("res://ui/components/practice_offer_card.tscn")

var _experience: Label
var _offers: HBoxContainer
var _packs: HBoxContainer
var _items: HBoxContainer
var _inventory: Label
var _meditate_button: Button
var _built := false

func _ready() -> void:
    _ensure_built()

func present(data: Dictionary) -> void:
    _ensure_built()
    _experience.text = "历练 %d" % int(data.get("experience", 0))
    var growth: Dictionary = data.get("growth", {})
    var consumables: Array = growth.get("consumables", [])
    var items: Array = growth.get("items", [])
    _inventory.text = "共享消耗品栏  %d / 3  ·  %s　｜　物品  %s" % [
        consumables.size(),
        "、".join(_content_names(consumables)) if not consumables.is_empty() else "当前为空",
        "、".join(_content_names(items)) if not items.is_empty() else "当前为空"]
    var practice: Dictionary = data.get("practice", {})
    _present_group(_offers, practice.get("normal", []), "normal")
    _present_group(_packs, practice.get("packs", []), "packs")
    _present_group(_items, practice.get("items", []), "items")
    _meditate_button.text = "冥想刷新（%d 历练）" % int(
        practice.get(
            "effective_meditation_cost",
            practice.get("next_meditation_cost", 5)))

func present_pack_choices(
        group: String,
        slot_index: int,
        offered: Array,
        minimum_choose_count: int,
        max_choose_count: int,
        preparation_token: String) -> void:
    var window := Window.new()
    window.title = "选择补充包内容"
    window.size = Vector2i(420, 360)
    window.transient = true
    window.exclusive = true
    var box := VBoxContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    box.add_theme_constant_override("separation", 10)
    window.add_child(box)
    var hint := Label.new()
    hint.text = (
        "当前没有空余消耗品栏位"
        if max_choose_count <= 0
        else "请选择 %d～%d 项" % [minimum_choose_count, max_choose_count])
    box.add_child(hint)
    var list := ItemList.new()
    list.select_mode = ItemList.SELECT_MULTI
    list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    for value in offered:
        list.add_item(str(value))
    box.add_child(list)
    var confirm := Button.new()
    confirm.text = "确认选择"
    confirm.disabled = max_choose_count <= 0
    list.multi_selected.connect(func(index: int, selected: bool):
        if selected and list.get_selected_items().size() > max_choose_count:
            list.deselect(index)
            hint.text = "最多选择 %d 项" % max_choose_count)
    confirm.pressed.connect(func():
        var selected: Array = []
        for index in list.get_selected_items():
            selected.append(str(offered[index]))
        if selected.size() < minimum_choose_count \
                or selected.size() > max_choose_count:
            hint.text = "请选择 %d～%d 项" % [
                minimum_choose_count, max_choose_count]
            return
        pack_selection_requested.emit(
            group, slot_index, selected, preparation_token)
        window.queue_free())
    box.add_child(confirm)
    window.close_requested.connect(func(): window.queue_free())
    add_child(window)
    window.popup_centered()

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
    subtitle.text = "地图待选节点期间可随时打开 · 普通商品、补充包和物品分别占用独立槽位"
    subtitle.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    box.add_child(subtitle)
    box.add_child(UiDesignScript.divider())
    var offers_scroll := ScrollContainer.new()
    offers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    offers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    offers_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    offers_scroll.custom_minimum_size.y = 340
    box.add_child(offers_scroll)
    _offers = HBoxContainer.new()
    _offers.alignment = BoxContainer.ALIGNMENT_CENTER
    _offers.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _offers.add_theme_constant_override("separation", 16)
    offers_scroll.add_child(_offers)
    var packs_title := Label.new()
    packs_title.text = "补充包"
    box.add_child(packs_title)
    _packs = HBoxContainer.new()
    _packs.add_theme_constant_override("separation", 16)
    box.add_child(_packs)
    var items_title := Label.new()
    items_title.text = "物品"
    box.add_child(items_title)
    _items = HBoxContainer.new()
    _items.add_theme_constant_override("separation", 16)
    box.add_child(_items)
    _meditate_button = Button.new()
    _meditate_button.text = "冥想刷新（5 历练）"
    _meditate_button.pressed.connect(func(): meditate_requested.emit())
    UiDesignScript.style_button(_meditate_button)
    box.add_child(_meditate_button)
    _inventory = Label.new()
    _inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _inventory.add_theme_font_size_override("font_size", 14)
    _inventory.add_theme_color_override("font_color", Color("d8c9e1"))
    box.add_child(_inventory)
    var note := Label.new()
    note.text = "购买后保留空槽；关闭页面不会刷新。四条与五条共用功法池，但序列独立。"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_color_override("font_color", Color("877f8b"))
    box.add_child(note)

func _content_names(values: Array) -> Array[String]:
    var names: Array[String] = []
    for value in values:
        var definition: Dictionary = value
        names.append(str(definition.get("name", definition.get("id", "未命名"))))
    return names

func _present_group(container: HBoxContainer, values: Array, group: String) -> void:
    if container == null:
        return
    for child in container.get_children():
        child.queue_free()
    for index in range(values.size()):
        var definition: Dictionary = values[index].duplicate(true)
        if not definition.is_empty():
            definition["_group"] = group
            definition["_slot_index"] = index
        var offer = OfferCardScene.instantiate()
        offer.purchase_requested.connect(func(consumable_id: String):
            purchase_requested.emit(consumable_id))
        offer.purchase_offer_requested.connect(func(group_id: String, slot_id: int):
            purchase_offer_requested.emit(group_id, slot_id))
        container.add_child(offer)
        offer.present(definition)
