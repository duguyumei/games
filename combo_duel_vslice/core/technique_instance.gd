class_name TechniqueInstance
extends RefCounted

## 本局持有的功法实例。Definition 是只读内容，Instance 只保存稳定持有身份。
var definition: TechniqueDefinition
var owner_id: String = ""
var acquired_order: int = 0

func configure(source: TechniqueDefinition, holder_id: String = "", order: int = 0):
	definition = source
	owner_id = holder_id
	acquired_order = order
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
	}
