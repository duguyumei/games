## 战斗内一条有容量限制的功法循环队列；不参与本局存档。
extends RefCounted
class_name GongfaQueueState

## 队列对应的精确牌型 ID。
var hand_type_id: String = ""

## 当前战斗内队列容量。
var capacity: int = 1

## 队列中按触发顺序排列的战斗功法实例字典。
var _entries: Array[Dictionary] = []

## 生成稳定且只在本场战斗有效的实例序号。
var _next_serial: int = 0

## 敌我和不同战斗对象之间用于隔离槽实例 ID 的稳定前缀。
var _slot_instance_prefix: String = "side"

## 从本局永久功法 UID 序列创建战斗队列。
func initialize(
		_hand_type_id: String,
		_capacity: int,
		permanent_gongfa_uids: Array,
		instance_prefix: String = "player") -> void:
	hand_type_id = _hand_type_id
	capacity = max(_capacity, 1)
	_slot_instance_prefix = instance_prefix if instance_prefix != "" else "player"
	_entries.clear()
	_next_serial = 0
	for gongfa_uid_value: Variant in permanent_gongfa_uids:
		if not gongfa_uid_value is String or str(gongfa_uid_value) == "":
			continue
		if _entries.size() >= capacity:
			break
		_entries.append(_create_entry(str(gongfa_uid_value), false, "", ""))

## 从敌方固定功法定义 ID创建只属于本场战斗的循环队列。
func initialize_from_definition_ids(
		_hand_type_id: String,
		_capacity: int,
		gongfa_definition_ids: Array,
		instance_prefix: String) -> bool:
	hand_type_id = _hand_type_id
	capacity = max(_capacity, 1)
	_slot_instance_prefix = instance_prefix if instance_prefix != "" else "enemy"
	_entries.clear()
	_next_serial = 0
	for gongfa_definition_value: Variant in gongfa_definition_ids:
		if not gongfa_definition_value is String:
			return false
		var gongfa_definition_id: String = str(gongfa_definition_value)
		if gongfa_definition_id == "" or _entries.size() >= capacity:
			if gongfa_definition_id == "":
				return false
			break
		var battle_instance_uid: String = "%s-gongfa-%s-%d" % [
			instance_prefix, hand_type_id, _entries.size()]
		_entries.append(_create_entry(
			battle_instance_uid, false, "", gongfa_definition_id))
	return true

## 返回队列当前内容的深复制，调用方不能直接修改队列。
func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		result.append(entry.duplicate(true))
	return result

## 返回队列第一项的独立副本；队列为空时返回空字典。
func peek_front() -> Dictionary:
	if _entries.is_empty():
		return {}
	return _entries[0].duplicate(true)

## 返回当前队列长度。
func size() -> int:
	return _entries.size()

## 返回是否还能生成新的临时功法。
func can_copy_front() -> bool:
	return not _entries.is_empty() and _entries.size() < capacity

## 触发第一项并旋转队列；复制数量按触发前的空槽数量限制。
func trigger_front(requested_copy_count: int = 0) -> Dictionary:
	if _entries.is_empty():
		return {}
	var original: Dictionary = _entries[0].duplicate(true)
	var available_slots: int = max(capacity - _entries.size(), 0)
	var copy_count: int = clamp(requested_copy_count, 0, available_slots)
	var copies: Array[Dictionary] = []
	for copy_index: int in copy_count:
		copies.append(_create_entry(
			str(original.get("gongfa_instance_uid", "")),
			true,
			str(original.get("slot_instance_id", "")),
			str(original.get("gongfa_definition_id", ""))))
	_entries.remove_at(0)
	var rotated_entries: Array[Dictionary] = []
	rotated_entries.append_array(copies)
	rotated_entries.append_array(_entries)
	rotated_entries.append(original)
	_entries = rotated_entries
	return {
		"original": original,
		"copies": copies,
		"copy_count": copy_count,
		"copy_rejected_count": max(requested_copy_count - copy_count, 0),
	}

## 清空战斗队列；战斗结束时调用。
func clear() -> void:
	_entries.clear()

## 创建一个永久或临时的战斗功法实例记录。
func _create_entry(
		gongfa_instance_uid: String,
		temporary: bool,
		origin_slot_instance_id: String,
		gongfa_definition_id: String) -> Dictionary:
	_next_serial += 1
	var definition_id: String = gongfa_definition_id
	if definition_id == "" and gongfa_instance_uid.begins_with("enemy-"):
		definition_id = ""
	elif definition_id == "" and Global.player_data != null:
		var gongfa_data: GongfaData = Global.player_data.get_owned_gongfa(gongfa_instance_uid)
		if gongfa_data != null:
			definition_id = gongfa_data.object_id
	return {
		"slot_instance_id": "battle-gongfa-%s-%s-%d" % [
			_slot_instance_prefix, hand_type_id, _next_serial],
		"gongfa_instance_uid": gongfa_instance_uid,
		"gongfa_definition_id": definition_id,
		"hand_type_id": hand_type_id,
		"temporary": temporary,
		"origin_slot_instance_id": origin_slot_instance_id,
		"origin_gongfa_instance_uid": gongfa_instance_uid,
		"insertion_serial": _next_serial,
	}
