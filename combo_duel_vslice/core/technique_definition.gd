class_name TechniqueDefinition
extends Resource

## 所有功法都使用这一种内容实体。每门功法由独立 .tres 文件声明。
## effects 只引用通用操作码，不在 CombatEngine 中按名称分支。
@export var id: String = ""
@export var display_name: String = ""
@export var pool: String = ""
@export var special: bool = false
@export_multiline var description: String = ""
@export var condition: Dictionary = {}
@export var cooperation: Dictionary = {}
@export var effects: Array = []

func configure_from_dictionary(value: Dictionary):
	id = str(value.get("id", ""))
	display_name = str(value.get("name", value.get("display_name", id)))
	pool = str(value.get("pool", ""))
	special = bool(value.get("special", false))
	description = str(value.get("description", ""))
	condition = value.get("condition", {}).duplicate(true)
	cooperation = value.get("cooperation", {}).duplicate(true)
	effects = value.get("effects", []).duplicate(true)
	return self

func to_definition() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"pool": pool,
		"special": special,
		"description": description,
		"condition": condition.duplicate(true),
		"cooperation": cooperation.duplicate(true),
		"effects": effects.duplicate(true),
	}

func snapshot() -> Dictionary:
	var value := to_definition()
	value["schema_version"] = 1
	return value
