class_name TechniqueInstance
extends RefCounted

## 本局持有的功法实例。Definition 是只读内容，Instance 只保存运行时身份和状态。
var definition: TechniqueDefinition
var owner_id: String = ""
var acquired_order: int = 0
var battle_state: Dictionary = {}

func configure(source: TechniqueDefinition, holder_id: String = "", order: int = 0):
	definition = source
	owner_id = holder_id
	acquired_order = order
	battle_state.clear()
	return self

func id() -> String:
	return definition.id if definition != null else ""

func effects() -> Array:
	return definition.effects.duplicate(true) if definition != null else []

func snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"technique_id": id(),
		"owner_id": owner_id,
		"acquired_order": acquired_order,
		"battle_state": battle_state.duplicate(true),
	}
