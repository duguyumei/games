class_name RunCardSelectionDialog
extends ColorRect

## 输入 query_consumable_use 返回值与当前 RunBuildDTO，仅渲染协议声明的选择。
## 输出 use_requested(slot_index, selected_instance_ids, choice_payload) 或 cancelled。
## 不按消耗品 ID 分支，不生成随机结果，也不对核心合法性作最终判断。

signal use_requested(
    slot_index: int,
    selected_instance_ids: Array,
    choice_payload: Dictionary)
signal cancelled

var _slot_index: int = -1
var _query: Dictionary = {}
var _build: RunBuildDTO
var _selected_targets: Array[String] = []
var _enum_value: String = ""
var _removals: Dictionary = {}
var _title: Label
var _message: Label
var _content: VBoxContainer
var _selection_count: Label
var _confirm_button: Button
var _built := false

func _ready() -> void:
    _ensure_built()

func present_query(
        slot_index: int,
        query: Dictionary,
        build: RunBuildDTO) -> void:
    _ensure_built()
    _slot_index = slot_index
    _query = query.duplicate(true)
    _build = build
    _selected_targets.clear()
    _enum_value = ""
    _removals.clear()
    _render()
    visible = true

func toggle_target(instance_id: String, selected: bool) -> bool:
    if str(_query.get("selection", "")) != "player_selected" \
            or not _eligible_target_ids().has(instance_id):
        return false
    if selected:
        if _selected_targets.has(instance_id):
            return true
        if _selected_targets.size() >= int(_query.get("maximum", 0)):
            return false
        _selected_targets.append(instance_id)
    else:
        _selected_targets.erase(instance_id)
    _update_confirmation()
    return true

func select_enum(value: String) -> bool:
    var schema: Dictionary = _query.get("choice_schema", {})
    if str(schema.get("type", "")) != "enum":
        return false
    var values: Array[String] = []
    for option in _query.get("choice_options", []):
        values.append(str(option.get("value", "")))
    if not values.has(value):
        return false
    _enum_value = value
    _update_confirmation()
    return true

func set_removal_selection(hand_id: String, technique_ids: Array) -> bool:
    var schema: Dictionary = _query.get("choice_schema", {})
    if str(schema.get("type", "")) != "technique_sequence_removals":
        return false
    var group := _removal_group(hand_id)
    if group.is_empty():
        return false
    var options: Array = group.get("options", [])
    var normalized: Array[String] = []
    for technique_id_value in technique_ids:
        var technique_id := str(technique_id_value)
        if technique_id == "" or normalized.has(technique_id) \
                or not options.has(technique_id):
            return false
        normalized.append(technique_id)
    if normalized.size() > int(group.get("required_count", 0)):
        return false
    _removals[hand_id] = normalized
    _update_confirmation()
    return true

func selected_instance_ids() -> Array:
    return _selected_targets.duplicate()

func choice_payload() -> Dictionary:
    var result: Dictionary = {}
    var schema: Dictionary = _query.get("choice_schema", {})
    match str(schema.get("type", "")):
        "enum":
            result[str(schema.get("field", "choice"))] = _enum_value
        "technique_sequence_removals":
            var values: Dictionary = {}
            for group_value in _removal_groups():
                var group: Dictionary = group_value
                var hand_id := str(group.get("hand_id", ""))
                values[hand_id] = _removals.get(hand_id, []).duplicate()
            result[str(schema.get(
                "field", "removed_technique_ids_by_hand"))] = values
    var token := str(_query.get("preparation_token", ""))
    if token != "":
        result["preparation_token"] = token
    return result

func can_confirm() -> bool:
    if not bool(_query.get("can_use", false)):
        return false
    if str(_query.get("selection", "")) == "player_selected":
        var count := _selected_targets.size()
        if count < int(_query.get("minimum", 0)) \
                or count > int(_query.get("maximum", 0)):
            return false
    var schema: Dictionary = _query.get("choice_schema", {})
    match str(schema.get("type", "")):
        "enum":
            if _enum_value == "":
                return false
        "technique_sequence_removals":
            for group_value in _removal_groups():
                var group: Dictionary = group_value
                if _removals.get(str(group.get("hand_id", "")), []).size() \
                        != int(group.get("required_count", 0)):
                    return false
    return true

func cancel() -> void:
    visible = false
    cancelled.emit()

func confirm() -> bool:
    if not can_confirm():
        return false
    use_requested.emit(
        _slot_index, selected_instance_ids(), choice_payload())
    return true

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    color = Color(0.01, 0.015, 0.02, 0.94)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visible = false
    z_index = 260
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(880, 660)
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    panel.add_child(box)
    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 24)
    box.add_child(_title)
    _message = Label.new()
    _message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_message)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 8)
    scroll.add_child(_content)
    box.add_child(scroll)
    _selection_count = Label.new()
    box.add_child(_selection_count)
    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    var cancel_button := Button.new()
    cancel_button.text = "取消"
    cancel_button.pressed.connect(cancel)
    actions.add_child(cancel_button)
    _confirm_button = Button.new()
    _confirm_button.text = "确认使用"
    _confirm_button.pressed.connect(confirm)
    actions.add_child(_confirm_button)
    box.add_child(actions)

func _render() -> void:
    for child in _content.get_children():
        child.queue_free()
    _title.text = "使用 %s" % str(_query.get("name", "消耗品"))
    _message.text = "%s%s" % [
        str(_query.get("description", "")),
        "\n不可使用：%s" % str(_query.get("reason", ""))
        if not bool(_query.get("can_use", false)) else ""]
    if str(_query.get("selection", "")) == "player_selected":
        _render_targets()
    var schema: Dictionary = _query.get("choice_schema", {})
    match str(schema.get("type", "")):
        "enum":
            _render_enum()
        "technique_sequence_removals":
            _render_removals()
    var preview: Dictionary = _query.get("prepared_preview", {})
    if not preview.is_empty():
        _render_preview(preview)
    _update_confirmation()

func _render_targets() -> void:
    var title := Label.new()
    title.text = "选择真气（%d～%d 张）" % [
        int(_query.get("minimum", 0)), int(_query.get("maximum", 0))]
    _content.add_child(title)
    for target_value in _query.get("eligible_targets", []):
        var target: Dictionary = target_value
        var check := CheckBox.new()
        var instance_id := str(target.get("instance_id", ""))
        check.text = "%s · %s" % [
            target.get("display_name", instance_id), _short_id(instance_id)]
        check.toggled.connect(func(selected: bool):
            if not toggle_target(instance_id, selected):
                check.set_pressed_no_signal(false))
        _content.add_child(check)

func _render_enum() -> void:
    var schema: Dictionary = _query.get("choice_schema", {})
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "请选择%s" % str(schema.get("field", "选项"))
    row.add_child(label)
    var options := OptionButton.new()
    for option_value in _query.get("choice_options", []):
        var option: Dictionary = option_value
        options.add_item(str(option.get("label", option.get("value", ""))))
        options.set_item_metadata(
            options.item_count - 1, str(option.get("value", "")))
    if options.item_count > 0:
        _enum_value = str(options.get_item_metadata(0))
    options.item_selected.connect(func(index: int):
        select_enum(str(options.get_item_metadata(index))))
    row.add_child(options)
    _content.add_child(row)

func _render_removals() -> void:
    for group_value in _removal_groups():
        var group: Dictionary = group_value
        var hand_id := str(group.get("hand_id", ""))
        var required := int(group.get("required_count", 0))
        _removals[hand_id] = []
        var label := Label.new()
        label.text = "%s：%s" % [
            _hand_name(hand_id),
            "无需移出" if required == 0 else "必须移出 %d 门" % required]
        _content.add_child(label)
        if required == 0:
            continue
        var list := ItemList.new()
        list.select_mode = ItemList.SELECT_MULTI
        list.custom_minimum_size.y = 90
        for technique_id_value in group.get("options", []):
            var technique_id := str(technique_id_value)
            list.add_item(_technique_name(technique_id))
            list.set_item_metadata(list.item_count - 1, technique_id)
        list.multi_selected.connect(func(_index: int, _selected: bool):
            var values: Array = []
            for selected_index in list.get_selected_items():
                values.append(str(list.get_item_metadata(selected_index)))
            if not set_removal_selection(hand_id, values):
                list.deselect_all())
        _content.add_child(list)

func _render_preview(preview: Dictionary) -> void:
    var title := Label.new()
    title.text = "冻结预览"
    _content.add_child(title)
    var target_names: Array[String] = []
    for instance_id_value in preview.get("targets", []):
        var instance_id := str(instance_id_value)
        target_names.append(_target_name(instance_id))
    var text := Label.new()
    text.text = "目标：%s\n变化：%s" % [
        "、".join(target_names) if not target_names.is_empty() else "无目标",
        JSON.stringify(preview.get("effects", []))]
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _content.add_child(text)

func _update_confirmation() -> void:
    if _selection_count == null:
        return
    _selection_count.text = "已选择 %d 张真气" % _selected_targets.size()
    _confirm_button.disabled = not can_confirm()

func _eligible_target_ids() -> Array[String]:
    var result: Array[String] = []
    for value in _query.get("eligible_targets", []):
        result.append(str(value.get("instance_id", "")))
    return result

func _removal_groups() -> Array:
    var schema: Dictionary = _query.get("choice_schema", {})
    return schema.get("groups", _query.get("choice_options", []))

func _removal_group(hand_id: String) -> Dictionary:
    for value in _removal_groups():
        if str(value.get("hand_id", "")) == hand_id:
            return value
    return {}

func _hand_name(hand_id: String) -> String:
    if _build == null:
        return hand_id
    var loadout = _build.hand_loadout(hand_id)
    return loadout.hand_name if loadout != null else hand_id

func _technique_name(technique_id: String) -> String:
    if _build == null:
        return technique_id
    for loadout in _build.hand_loadouts:
        for source in [loadout.sequence, loadout.available_techniques]:
            for technique in source:
                if str(technique.get("id", "")) == technique_id:
                    return str(technique.get("name", technique_id))
    return technique_id

func _target_name(instance_id: String) -> String:
    for value in _query.get("eligible_targets", []):
        if str(value.get("instance_id", "")) == instance_id:
            return str(value.get("display_name", instance_id))
    if _build != null:
        for card in _build.cards:
            if str(card.get("instance_id", "")) == instance_id:
                return str(card.get("display_name", instance_id))
    return instance_id

func _short_id(instance_id: String) -> String:
    return instance_id if instance_id.length() <= 12 else "…%s" % instance_id.right(10)

