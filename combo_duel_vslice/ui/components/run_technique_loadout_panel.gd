class_name RunTechniqueLoadoutPanel
extends VBoxContainer

const TechniqueLoadoutPolicyScript = preload(
    "res://core/technique_loadout_policy.gd")

## 输入 RunBuildDTO.hand_loadouts，为八种精确牌型维护彼此独立的本地草稿。
## 输出 save_requested(hand_id, complete_technique_ids)，始终提交完整序列。
## 不判断池归属、槽位合法性或阶段门禁，最终结果由核心命令复验。

signal save_requested(hand_id: String, technique_ids: Array)

var _build: RunBuildDTO
var _drafts: Dictionary = {}
var _dirty_hands: Dictionary = {}
var _hand_selector: OptionButton
var _summary: Label
var _sequence_list: ItemList
var _available_list: ItemList
var _add_button: Button
var _remove_button: Button
var _up_button: Button
var _down_button: Button
var _save_button: Button
var _empty_state: Label
var _built := false

func _ready() -> void:
    _ensure_built()

func present(build: RunBuildDTO, preserve_drafts: bool = false) -> void:
    _ensure_built()
    _build = build
    var previous_hand := selected_hand_id()
    if not preserve_drafts:
        _drafts.clear()
        _dirty_hands.clear()
    for loadout in build.hand_loadouts:
        if not preserve_drafts or not _drafts.has(loadout.hand_id):
            _drafts[loadout.hand_id] = _ids(loadout.sequence)
    _hand_selector.clear()
    for loadout in build.hand_loadouts:
        _hand_selector.add_item(loadout.hand_name)
        _hand_selector.set_item_metadata(
            _hand_selector.item_count - 1, loadout.hand_id)
    _select_hand(previous_hand)
    _render_selected()

func selected_hand_id() -> String:
    if _hand_selector == null or _hand_selector.item_count == 0:
        return ""
    return str(_hand_selector.get_item_metadata(_hand_selector.selected))

func draft_sequence(hand_id: String) -> Array:
    return _drafts.get(hand_id, []).duplicate()

func add_technique(hand_id: String, technique_id: String) -> bool:
    var loadout = _loadout(hand_id)
    if loadout == null or not loadout.editable:
        return false
    var draft: Array = _drafts.get(hand_id, []).duplicate()
    if not TechniqueLoadoutPolicyScript.has_sequence_capacity(
            draft.size(), loadout.slot_count):
        return false
    var allowed := _all_technique_ids(loadout)
    if not allowed.has(technique_id):
        return false
    var summary := _technique(loadout, technique_id)
    var current_count := draft.count(technique_id)
    var original_hand_count := _ids(loadout.sequence).count(technique_id)
    var total_without_original := int(summary.get(
        "equipped_total_count", 0)) - original_hand_count
    if total_without_original + current_count + 1 > int(summary.get(
            "effective_loadout_limit", 0)):
        return false
    draft.append(technique_id)
    _set_draft(hand_id, draft)
    return true

func remove_technique(hand_id: String, technique_id: String) -> bool:
    var draft: Array = _drafts.get(hand_id, [])
    return remove_technique_at(hand_id, draft.find(technique_id))

func remove_technique_at(hand_id: String, slot_index: int) -> bool:
    var loadout = _loadout(hand_id)
    if loadout == null or not loadout.editable:
        return false
    var draft: Array = _drafts.get(hand_id, []).duplicate()
    if slot_index < 0 or slot_index >= draft.size():
        return false
    if not TechniqueLoadoutPolicyScript.is_sequence_size_valid(
            draft.size() - 1, loadout.slot_count):
        return false
    draft.remove_at(slot_index)
    _set_draft(hand_id, draft)
    return true

func move_technique(hand_id: String, technique_id: String, offset: int) -> bool:
    var draft: Array = _drafts.get(hand_id, [])
    return move_technique_at(hand_id, draft.find(technique_id), offset)

func move_technique_at(hand_id: String, slot_index: int, offset: int) -> bool:
    var loadout = _loadout(hand_id)
    if loadout == null or not loadout.editable or not [-1, 1].has(offset):
        return false
    var draft: Array = _drafts.get(hand_id, []).duplicate()
    var target := slot_index + offset
    if slot_index < 0 or slot_index >= draft.size() \
            or target < 0 or target >= draft.size():
        return false
    var value = draft[slot_index]
    draft[slot_index] = draft[target]
    draft[target] = value
    _set_draft(hand_id, draft)
    return true

func request_save(hand_id: String) -> bool:
    var loadout = _loadout(hand_id)
    if loadout == null or not loadout.editable \
            or not _dirty_hands.has(hand_id) \
            or not TechniqueLoadoutPolicyScript.is_sequence_size_valid(
                draft_sequence(hand_id).size(), loadout.slot_count):
        return false
    save_requested.emit(hand_id, draft_sequence(hand_id))
    return true

func has_unsaved_changes() -> bool:
    return not _dirty_hands.is_empty()

func mark_saved(hand_id: String) -> void:
    _dirty_hands.erase(hand_id)
    _render_selected()

func discard_drafts() -> void:
    if _build != null:
        present(_build, false)

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    add_theme_constant_override("separation", 8)
    var header := HBoxContainer.new()
    var label := Label.new()
    label.text = "精确牌型"
    header.add_child(label)
    _hand_selector = OptionButton.new()
    _hand_selector.custom_minimum_size.x = 190
    _hand_selector.item_selected.connect(func(_index: int): _render_selected())
    header.add_child(_hand_selector)
    _summary = Label.new()
    _summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(_summary)
    add_child(header)
    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var current_box := VBoxContainer.new()
    current_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    current_box.add_child(_title("当前循环序列"))
    _sequence_list = ItemList.new()
    _sequence_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _sequence_list.custom_minimum_size.y = 320
    current_box.add_child(_sequence_list)
    columns.add_child(current_box)
    var controls := VBoxContainer.new()
    controls.custom_minimum_size.x = 120
    _add_button = _action_button("← 加入", _on_add)
    _remove_button = _action_button("移出 →", _on_remove)
    _up_button = _action_button("上移", _on_move_up)
    _down_button = _action_button("下移", _on_move_down)
    controls.add_child(_add_button)
    controls.add_child(_remove_button)
    controls.add_child(_up_button)
    controls.add_child(_down_button)
    columns.add_child(controls)
    var available_box := VBoxContainer.new()
    available_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    available_box.add_child(_title("可加入的已获正式功法"))
    _available_list = ItemList.new()
    _available_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _available_list.custom_minimum_size.y = 320
    available_box.add_child(_available_list)
    columns.add_child(available_box)
    add_child(columns)
    _empty_state = Label.new()
    _empty_state.text = "当前没有可配置的正式功法"
    add_child(_empty_state)
    _save_button = _action_button("保存当前牌型完整序列", _on_save)
    add_child(_save_button)

func _render_selected() -> void:
    if _build == null:
        return
    var hand_id := selected_hand_id()
    var loadout = _loadout(hand_id)
    if loadout == null:
        return
    var draft: Array = _drafts.get(hand_id, [])
    _sequence_list.clear()
    for technique_id_value in draft:
        var technique_id := str(technique_id_value)
        _sequence_list.add_item(_technique_name(loadout, technique_id))
        _sequence_list.set_item_metadata(
            _sequence_list.item_count - 1, technique_id)
    _available_list.clear()
    for technique in _all_techniques(loadout):
        var technique_id := str(technique.get("id", ""))
        if technique_id == "":
            continue
        var current_count := draft.count(technique_id)
        var original_hand_count := _ids(loadout.sequence).count(technique_id)
        var displayed_total := int(technique.get(
            "equipped_total_count", 0)) - original_hand_count + current_count
        var effective_limit := int(technique.get(
            "effective_loadout_limit", 0))
        var label := str(technique.get("name", technique_id))
        label += " · 已装配 %d/%d" % [
            displayed_total, effective_limit]
        _available_list.add_item(label)
        _available_list.set_item_metadata(
            _available_list.item_count - 1, technique_id)
        _available_list.set_item_disabled(
            _available_list.item_count - 1,
            not bool(technique.get("eligible", false)) \
                or displayed_total >= effective_limit \
                or (str(technique.get("disabled_reason", "")) != "" \
                    and not str(technique.get("disabled_reason", "")).begins_with(
                        "已装配 ")))
    var is_editable := bool(loadout.editable)
    _summary.text = "%d / %d 槽%s" % [
        draft.size(), loadout.slot_count,
        " · 未保存" if _dirty_hands.has(hand_id) else ""]
    if not is_editable:
        _summary.text += " · 只读：%s" % loadout.blocked_reason
    elif draft.size() < loadout.slot_count:
        _summary.text += " · 空余 %d 个槽位" % (loadout.slot_count - draft.size())
    _empty_state.visible = (
        _all_techniques(loadout).is_empty()
        and loadout.sequence.is_empty())
    _add_button.disabled = not is_editable \
        or not TechniqueLoadoutPolicyScript.has_sequence_capacity(
            draft.size(), loadout.slot_count)
    _remove_button.disabled = not is_editable \
        or not TechniqueLoadoutPolicyScript.is_sequence_size_valid(
            draft.size() - 1, loadout.slot_count)
    _up_button.disabled = not is_editable
    _down_button.disabled = not is_editable
    _save_button.disabled = not is_editable \
        or not _dirty_hands.has(hand_id) \
        or not TechniqueLoadoutPolicyScript.is_sequence_size_valid(
            draft.size(), loadout.slot_count)

func _set_draft(hand_id: String, draft: Array) -> void:
    _drafts[hand_id] = draft.duplicate()
    var loadout = _loadout(hand_id)
    if loadout != null and draft == _ids(loadout.sequence):
        _dirty_hands.erase(hand_id)
    else:
        _dirty_hands[hand_id] = true
    _render_selected()

func _loadout(hand_id: String):
    return _build.hand_loadout(hand_id) if _build != null else null

func _all_techniques(loadout) -> Array:
    var result: Array = []
    var emitted: Dictionary = {}
    for source in [loadout.sequence, loadout.available_techniques]:
        for value in source:
            var technique: Dictionary = value
            var technique_id := str(technique.get("id", ""))
            if technique_id == "" or emitted.has(technique_id):
                continue
            emitted[technique_id] = true
            result.append(technique.duplicate(true))
    return result

func _all_technique_ids(loadout) -> Array[String]:
    var result: Array[String] = []
    for technique in _all_techniques(loadout):
        result.append(str(technique.get("id", "")))
    return result

func _technique_name(loadout, technique_id: String) -> String:
    for technique in _all_techniques(loadout):
        if str(technique.get("id", "")) == technique_id:
            return _technique_label(technique, technique_id)
    return technique_id

func _technique_label(technique: Dictionary, fallback: String) -> String:
    var label := str(technique.get("name", fallback))
    var markers: Array = technique.get("run_markers", [])
    if not markers.is_empty():
        label += " · " + " / ".join(markers.map(func(marker):
            return "%s %d" % [
                str(marker.get("display_name", marker.get("marker_id", ""))),
                int(marker.get("value", 0)),
            ]))
    return label

func _technique(loadout, technique_id: String) -> Dictionary:
    for technique in _all_techniques(loadout):
        if str(technique.get("id", "")) == technique_id:
            return technique
    return {}

func _ids(techniques: Array) -> Array:
    var result: Array = []
    for technique in techniques:
        if technique is Dictionary:
            result.append(str(technique.get("id", "")))
        else:
            result.append(str(technique))
    return result

func _select_hand(hand_id: String) -> void:
    for index in range(_hand_selector.item_count):
        if str(_hand_selector.get_item_metadata(index)) == hand_id:
            _hand_selector.select(index)
            return
    if _hand_selector.item_count > 0:
        _hand_selector.select(0)

func _selected_metadata(list: ItemList) -> String:
    var selected := list.get_selected_items()
    return "" if selected.is_empty() else str(
        list.get_item_metadata(int(selected[0])))

func _on_add() -> void:
    add_technique(selected_hand_id(), _selected_metadata(_available_list))

func _on_remove() -> void:
    var selected := _sequence_list.get_selected_items()
    remove_technique_at(
        selected_hand_id(), -1 if selected.is_empty() else int(selected[0]))

func _on_move_up() -> void:
    var selected := _sequence_list.get_selected_items()
    move_technique_at(
        selected_hand_id(), -1 if selected.is_empty() else int(selected[0]), -1)

func _on_move_down() -> void:
    var selected := _sequence_list.get_selected_items()
    move_technique_at(
        selected_hand_id(), -1 if selected.is_empty() else int(selected[0]), 1)

func _on_save() -> void:
    request_save(selected_hand_id())

func _action_button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.pressed.connect(callback)
    return button

func _title(text_value: String) -> Label:
    var label := Label.new()
    label.text = text_value
    return label
