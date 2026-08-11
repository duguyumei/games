class_name RunInnerSkillLoadoutPanel
extends VBoxContainer

## 输入 RunBuildDTO.inner_skill_loadout，维护内功多副本、顺序与功法位置草稿。
## 输出完整配装保存请求，以及单份普通遗忘请求。
## 不计算副本合法性或遗忘所得，也不直接修改已获/已装备数组与历练。

signal save_requested(equipped_inner_skill_ids: Array, technique_slot_index: int)
signal forget_requested(inner_skill_id: String)

var _build: RunBuildDTO
var _draft_equipped: Array = []
var _draft_technique_slot_index: int = 0
var _dirty := false
var _learned_selector: OptionButton
var _equipped_list: ItemList
var _position_spin: SpinBox
var _summary: Label
var _add_button: Button
var _remove_button: Button
var _up_button: Button
var _down_button: Button
var _save_button: Button
var _forget_button: Button
var _forget_confirmation: ConfirmationDialog
var _empty_state: Label
var _built := false

func _ready() -> void:
    _ensure_built()

func present(build: RunBuildDTO, preserve_draft: bool = false) -> void:
    _ensure_built()
    _build = build
    var dto = build.inner_skill_loadout
    if not preserve_draft:
        _draft_equipped = dto.equipped_inner_skill_ids.duplicate()
        _draft_technique_slot_index = dto.technique_slot_index
        _dirty = false
    _learned_selector.clear()
    for learned_value in dto.learned:
        var learned: Dictionary = learned_value
        var inner_skill_id := str(learned.get("id", ""))
        _learned_selector.add_item("%s ×%d（已装备 %d）" % [
            learned.get("name", inner_skill_id),
            int(learned.get("total_count", 0)),
            int(learned.get("equipped_count", 0))])
        _learned_selector.set_item_metadata(
            _learned_selector.item_count - 1, inner_skill_id)
    _position_spin.max_value = _draft_equipped.size()
    _position_spin.set_value_no_signal(_draft_technique_slot_index)
    _render()

func draft_equipped_ids() -> Array:
    return _draft_equipped.duplicate()

func draft_technique_slot_index() -> int:
    return _draft_technique_slot_index

func add_copy(inner_skill_id: String) -> bool:
    var dto = _dto()
    if dto == null or not dto.editable \
            or _draft_equipped.size() >= dto.inner_skill_limit:
        return false
    var learned := _learned(inner_skill_id)
    if learned.is_empty() or _count(_draft_equipped, inner_skill_id) \
            >= int(learned.get("total_count", 0)):
        return false
    _draft_equipped.append(inner_skill_id)
    _draft_technique_slot_index = mini(
        _draft_technique_slot_index, _draft_equipped.size())
    _mark_dirty()
    return true

func remove_copy(slot_index: int) -> bool:
    var dto = _dto()
    if dto == null or not dto.editable \
            or slot_index < 0 or slot_index >= _draft_equipped.size():
        return false
    _draft_equipped.remove_at(slot_index)
    _draft_technique_slot_index = mini(
        _draft_technique_slot_index, _draft_equipped.size())
    _mark_dirty()
    return true

func move_copy(slot_index: int, offset: int) -> bool:
    var dto = _dto()
    var target := slot_index + offset
    if dto == null or not dto.editable or not [-1, 1].has(offset) \
            or slot_index < 0 or target < 0 \
            or target >= _draft_equipped.size():
        return false
    var value = _draft_equipped[slot_index]
    _draft_equipped[slot_index] = _draft_equipped[target]
    _draft_equipped[target] = value
    _mark_dirty()
    return true

func set_technique_position(position: int) -> bool:
    var dto = _dto()
    if dto == null or not dto.editable \
            or position < 0 or position > _draft_equipped.size():
        return false
    _draft_technique_slot_index = position
    _mark_dirty()
    return true

func request_save() -> bool:
    var dto = _dto()
    if dto == null or not dto.editable or not _dirty:
        return false
    save_requested.emit(
        _draft_equipped.duplicate(), _draft_technique_slot_index)
    return true

func request_forget(inner_skill_id: String) -> bool:
    var dto = _dto()
    var learned := _learned(inner_skill_id)
    if dto == null or not dto.editable \
            or not bool(learned.get("can_forget", false)) \
            or learned.get("forget_value") == null:
        return false
    _forget_confirmation.dialog_text = (
        "遗忘一份未装备副本，获得 %d 点历练。\n确认遗忘「%s」？" % [
            int(learned.get("forget_value", 0)),
            learned.get("name", inner_skill_id)])
    _forget_confirmation.set_meta("inner_skill_id", inner_skill_id)
    if _forget_confirmation.is_inside_tree():
        _forget_confirmation.popup_centered()
    return true

func has_unsaved_changes() -> bool:
    return _dirty

func mark_saved() -> void:
    _dirty = false
    _render()

func discard_draft() -> void:
    if _build != null:
        present(_build, false)

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    add_theme_constant_override("separation", 8)
    _summary = Label.new()
    add_child(_summary)
    _empty_state = Label.new()
    _empty_state.text = "当前没有可配置的正式内功"
    add_child(_empty_state)
    var learned_row := HBoxContainer.new()
    _learned_selector = OptionButton.new()
    _learned_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _learned_selector.item_selected.connect(func(_index: int): _render())
    learned_row.add_child(_learned_selector)
    _add_button = _button("装备一份", _on_add)
    learned_row.add_child(_add_button)
    _forget_button = _button("普通遗忘", _on_forget)
    learned_row.add_child(_forget_button)
    add_child(learned_row)
    _equipped_list = ItemList.new()
    _equipped_list.custom_minimum_size.y = 310
    _equipped_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(_equipped_list)
    var actions := HBoxContainer.new()
    _up_button = _button("上移", _on_move_up)
    _down_button = _button("下移", _on_move_down)
    _remove_button = _button("卸下一份", _on_remove)
    actions.add_child(_up_button)
    actions.add_child(_down_button)
    actions.add_child(_remove_button)
    var position_label := Label.new()
    position_label.text = "功法结算位置"
    actions.add_child(position_label)
    _position_spin = SpinBox.new()
    _position_spin.min_value = 0
    _position_spin.step = 1
    _position_spin.value_changed.connect(
        func(value: float): set_technique_position(int(value)))
    actions.add_child(_position_spin)
    add_child(actions)
    _save_button = _button("保存完整内功配装", request_save)
    add_child(_save_button)
    _forget_confirmation = ConfirmationDialog.new()
    _forget_confirmation.title = "确认普通遗忘"
    _forget_confirmation.confirmed.connect(func():
        forget_requested.emit(str(
            _forget_confirmation.get_meta("inner_skill_id", ""))))
    add_child(_forget_confirmation)

func _render() -> void:
    if _build == null:
        return
    var dto = _dto()
    _equipped_list.clear()
    var occurrences: Dictionary = {}
    for queue_index in range(_draft_equipped.size() + 1):
        if queue_index == _draft_technique_slot_index:
            _equipped_list.add_item("[功法]")
            _equipped_list.set_item_metadata(
                _equipped_list.item_count - 1, {"technique": true})
        if queue_index >= _draft_equipped.size():
            continue
        var inner_skill_id := str(_draft_equipped[queue_index])
        occurrences[inner_skill_id] = int(
            occurrences.get(inner_skill_id, 0)) + 1
        _equipped_list.add_item("%d. %s（第 %d 份）" % [
            queue_index + 1,
            _learned(inner_skill_id).get("name", inner_skill_id),
            int(occurrences[inner_skill_id])])
        _equipped_list.set_item_metadata(
            _equipped_list.item_count - 1,
            {"slot_index": queue_index, "inner_skill_id": inner_skill_id})
    _position_spin.max_value = _draft_equipped.size()
    _position_spin.set_value_no_signal(_draft_technique_slot_index)
    var editable := bool(dto.editable)
    _empty_state.visible = dto.learned.is_empty()
    _summary.text = "已装备 %d / %d%s" % [
        _draft_equipped.size(), dto.inner_skill_limit,
        " · 未保存" if _dirty else ""]
    if not editable:
        _summary.text += " · 只读：%s" % dto.blocked_reason
    var selected_id := _selected_learned_id()
    var learned := _learned(selected_id)
    _add_button.disabled = (
        not editable or learned.is_empty()
        or _draft_equipped.size() >= dto.inner_skill_limit
        or _count(_draft_equipped, selected_id) \
            >= int(learned.get("total_count", 0)))
    _remove_button.disabled = not editable
    _up_button.disabled = not editable
    _down_button.disabled = not editable
    _position_spin.editable = editable
    _save_button.disabled = not editable or not _dirty
    var forget_value = learned.get("forget_value")
    _forget_button.text = (
        "普通遗忘（+%d 历练）" % int(forget_value)
        if forget_value != null
        else "尚未配置普通遗忘所得")
    _forget_button.disabled = (
        not editable or not bool(learned.get("can_forget", false))
        or forget_value == null)

func _mark_dirty() -> void:
    var dto = _dto()
    _dirty = (
        dto != null
        and (_draft_equipped != dto.equipped_inner_skill_ids
            or _draft_technique_slot_index != dto.technique_slot_index))
    _render()

func _dto():
    return _build.inner_skill_loadout if _build != null else null

func _learned(inner_skill_id: String) -> Dictionary:
    var dto = _dto()
    if dto == null:
        return {}
    for value in dto.learned:
        if str(value.get("id", "")) == inner_skill_id:
            return value
    return {}

func _selected_learned_id() -> String:
    if _learned_selector.item_count == 0:
        return ""
    return str(_learned_selector.get_item_metadata(
        _learned_selector.selected))

func _selected_equipped_index() -> int:
    var selected := _equipped_list.get_selected_items()
    if selected.is_empty():
        return -1
    var metadata = _equipped_list.get_item_metadata(int(selected[0]))
    if not metadata is Dictionary or metadata.has("technique"):
        return -1
    return int(metadata.get("slot_index", -1))

func _on_add() -> void:
    add_copy(_selected_learned_id())

func _on_remove() -> void:
    remove_copy(_selected_equipped_index())

func _on_move_up() -> void:
    move_copy(_selected_equipped_index(), -1)

func _on_move_down() -> void:
    move_copy(_selected_equipped_index(), 1)

func _on_forget() -> void:
    request_forget(_selected_learned_id())

func _count(values: Array, inner_skill_id: String) -> int:
    var result := 0
    for value in values:
        if str(value) == inner_skill_id:
            result += 1
    return result

func _button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.pressed.connect(callback)
    return button
