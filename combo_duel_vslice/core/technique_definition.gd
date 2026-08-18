class_name TechniqueDefinition
extends Resource

## 所有功法都使用这一种内容实体。每门功法由独立 .tres 文件声明。
## effects 只引用通用操作码，不在 CombatEngine 中按名称分支。
@export var id: String = ""
@export var display_name: String = ""
@export var pool: String = ""
@export var special: bool = false
@export_enum("normal", "advance_only") var manual_effect_mode: String = "normal"
@export var automatic_triggers: Array = []
@export var marker_definitions: Array = []
## 空字典表示没有主要蓄力值；倒计时和完成条件不属于此声明。
@export var charging: Dictionary = {}
@export var built_in: bool = false
@export var base_loadout_limit: int = 1
@export var eligible_hand_ids: Array[String] = []
@export var built_in_fallback_order: int = 0
@export_multiline var description: String = ""
@export var condition: Dictionary = {}
@export var cooperation: Dictionary = {}
@export var effects: Array = []
@export var power_formation: Dictionary = {}
@export var semantic_tags: Array[String] = []
@export var public_behavior_summary: Array[String] = []
@export var implementation_category: String = ""

func configure_from_dictionary(value: Dictionary):
	id = str(value.get("id", ""))
	display_name = str(value.get("name", value.get("display_name", id)))
	pool = str(value.get("pool", ""))
	special = bool(value.get("special", false))
	manual_effect_mode = str(value.get("manual_effect_mode", "normal"))
	automatic_triggers = value.get("automatic_triggers", []).duplicate(true)
	marker_definitions = value.get("marker_definitions", []).duplicate(true)
	charging = value.get("charging", {}).duplicate(true)
	built_in = bool(value.get("built_in", false))
	base_loadout_limit = int(value.get("base_loadout_limit", 1))
	eligible_hand_ids.assign(value.get("eligible_hand_ids", []))
	built_in_fallback_order = int(value.get("built_in_fallback_order", 0))
	description = str(value.get("description", ""))
	condition = value.get("condition", {}).duplicate(true)
	cooperation = value.get("cooperation", {}).duplicate(true)
	effects = value.get("effects", []).duplicate(true)
	power_formation = value.get("power_formation", {}).duplicate(true)
	semantic_tags.assign(value.get("semantic_tags", []))
	public_behavior_summary.assign(value.get("public_behavior_summary", []))
	implementation_category = str(value.get("implementation_category", ""))
	return self

func to_definition() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"pool": pool,
		"special": special,
		"manual_effect_mode": manual_effect_mode,
		"automatic_triggers": automatic_triggers.duplicate(true),
		"marker_definitions": marker_definitions.duplicate(true),
		"charging": charging.duplicate(true),
		"built_in": built_in,
		"base_loadout_limit": base_loadout_limit,
		"eligible_hand_ids": eligible_hand_ids.duplicate(),
		"built_in_fallback_order": built_in_fallback_order,
		"description": description,
		"condition": condition.duplicate(true),
		"cooperation": cooperation.duplicate(true),
		"effects": effects.duplicate(true),
		"power_formation": power_formation.duplicate(true),
		"semantic_tags": semantic_tags.duplicate(),
		"public_behavior_summary": public_behavior_summary.duplicate(),
		"implementation_category": implementation_category,
	}

func snapshot() -> Dictionary:
	var value := to_definition()
	value["schema_version"] = 1
	return value
