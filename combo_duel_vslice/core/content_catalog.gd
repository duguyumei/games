class_name ContentCatalog
extends RefCounted

const ContentValidatorScript = preload("res://core/content_validator.gd")
const TechniqueDefinitionScript = preload("res://core/technique_definition.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")

const CONTENT_ORDER := [
    "base_deck",
    "starter_builds",
    "battle_statuses",
    "card_states",
    "techniques",
    "inner_skills",
    "consumables",
    "node_rewards",
    "map_rules",
    "node_content",
    "scripted_battle",
    "sequences",
]
const DEFAULT_PATHS := {
    "base_deck": "res://data/base_deck.json",
    "starter_builds": "res://data/starter_builds.json",
    "battle_statuses": "res://data/battle_statuses.json",
    "card_states": "res://data/card_states.json",
    "techniques": "res://data/techniques.json",
    "inner_skills": "res://data/inner_skills.json",
    "consumables": "res://data/consumables.json",
    "node_rewards": "res://data/node_rewards.json",
    "map_rules": "res://data/map_rules.json",
    "node_content": "res://data/node_content.json",
    "scripted_battle": "res://data/scripted_battle.json",
    "sequences": "res://data/vertical_slice_sequences.json",
}

var errors: Array[String] = []
var warnings: Array[String] = []
var loaded: bool = false
var paths: Dictionary = {}
var _definitions: Dictionary = {}
var _indexes: Dictionary = {}
var runtime_profile
var effect_registry

func _init(runtime_profile_override = null, effect_registry_override = null) -> void:
    runtime_profile = (
        runtime_profile_override
        if runtime_profile_override != null
        else RuntimeProfileScript.current())
    effect_registry = effect_registry_override

func load_all(path_overrides: Dictionary = {}) -> bool:
    errors.clear()
    warnings.clear()
    loaded = false
    paths = DEFAULT_PATHS.duplicate(true)
    paths.merge(runtime_profile.content_path_overrides(), true)
    for key in path_overrides:
        if not CONTENT_ORDER.has(str(key)):
            errors.append("catalog: 未知内容路径键 %s" % str(key))
            continue
        paths[str(key)] = str(path_overrides[key])
    errors.append_array(runtime_profile.validate_content_paths(paths))
    if not errors.is_empty():
        _definitions.clear()
        _indexes.clear()
        return false
    var values: Dictionary = {}
    for key in CONTENT_ORDER:
        var path := str(paths[key])
        if not FileAccess.file_exists(path):
            errors.append("%s: 内容文件不存在：%s" % [key, path])
            continue
        var parser := JSON.new()
        var parse_error := parser.parse(FileAccess.get_file_as_string(path))
        if parse_error != OK:
            errors.append("%s: JSON 解析失败（第 %d 行）：%s" % [
                key, parser.get_error_line(), parser.get_error_message()])
            continue
        if not parser.data is Dictionary:
            errors.append("%s: 顶层 JSON 必须是对象" % key)
            continue
        values[key] = parser.data.duplicate(true)
    if not errors.is_empty():
        _definitions.clear()
        _indexes.clear()
        return false
    return load_from_definitions(values, paths)

func load_from_definitions(values: Dictionary, source_paths: Dictionary = {}) -> bool:
    errors.clear()
    warnings.clear()
    loaded = false
    paths = DEFAULT_PATHS.duplicate(true)
    paths.merge(runtime_profile.content_path_overrides(), true)
    for key in source_paths:
        paths[str(key)] = str(source_paths[key])
    errors.append_array(runtime_profile.validate_content_paths(paths))
    if not errors.is_empty():
        _definitions.clear()
        _indexes.clear()
        return false
    _definitions = values.duplicate(true)
    _expand_technique_resources()
    if not errors.is_empty():
        _indexes.clear()
        return false
    var validator = ContentValidatorScript.new(effect_registry)
    var validation: Dictionary = validator.validate(_definitions, paths)
    errors.assign(validation.get("errors", []))
    warnings.assign(validation.get("warnings", []))
    if not errors.is_empty():
        _indexes.clear()
        return false
    _build_indexes()
    loaded = true
    return true

func definition(content_key: String) -> Dictionary:
    return _definitions.get(content_key, {}).duplicate(true)

func path_for(content_key: String) -> String:
    return str(paths.get(content_key, ""))

func get_by_id(content_type: String, content_id: String) -> Dictionary:
    return _indexes.get(content_type, {}).get(content_id, {}).duplicate(true)

func has_id(content_type: String, content_id: String) -> bool:
    return _indexes.get(content_type, {}).has(content_id)

func all_of(content_type: String) -> Array:
    var result: Array = []
    for value in _indexes.get(content_type, {}).values():
        result.append(value.duplicate(true))
    return result

func _build_indexes() -> void:
    _indexes = {
        "card": {},
        "starter_build": {},
        "actor_status": {},
        "enhancement": {},
        "finish": {},
        "imprint": {},
        "other_reshape": {},
        "anomaly": {},
        "technique": {},
        "inner_skill": {},
        "consumable": {},
        "node_type": {},
        "scenario": {},
    }
    var base_deck: Dictionary = _definitions["base_deck"]
    _index_array("starter_build", _definitions["starter_builds"]["starter_builds"])
    for attribute_value in base_deck["attributes"]:
        var attribute: Dictionary = attribute_value
        for rank_value in base_deck["ranks"]:
            var rank: Dictionary = rank_value
            var card_id := "%s_%s" % [attribute["id"], rank["id"]]
            _indexes["card"][card_id] = {
                "id": card_id,
                "rank": str(rank["id"]),
                "order": int(rank["order"]),
                "qi": int(rank["qi"]),
                "attribute": str(attribute["id"]),
                "attribute_name": str(attribute["name"]),
            }
    var card_states: Dictionary = _definitions["card_states"]
    _index_array("actor_status", _definitions["battle_statuses"]["actor_statuses"])
    _index_array("enhancement", card_states["enhancements"])
    _index_array("finish", card_states["finishes"])
    _index_array("imprint", card_states["imprints"])
    _index_array("other_reshape", card_states["other_reshapes"])
    _index_array("anomaly", card_states["anomalies"])
    _index_array("technique", _definitions["techniques"]["techniques"])
    _index_array("inner_skill", _definitions["inner_skills"]["inner_skills"])
    _index_array("consumable", _definitions["consumables"]["consumables"])
    for node_type in _definitions["node_content"]["node_types"]:
        var value: Dictionary = _definitions["node_content"]["node_types"][node_type].duplicate(true)
        value["id"] = str(node_type)
        _indexes["node_type"][str(node_type)] = value
    var scenario: Dictionary = _definitions["scripted_battle"]
    _indexes["scenario"][str(scenario["id"])] = scenario.duplicate(true)

func _index_array(content_type: String, values: Array) -> void:
    for value in values:
        _indexes[content_type][str(value["id"])] = value.duplicate(true)

func _expand_technique_resources() -> void:
    var technique_content: Dictionary = _definitions.get("techniques", {})
    if technique_content.has("techniques"):
        return
    var definitions: Array = []
    for path_value in technique_content.get("resource_paths", []):
        var path := str(path_value)
        var resource = load(path)
        if not resource is TechniqueDefinition:
            errors.append("techniques: 功法资源无法加载：%s" % path)
            continue
        definitions.append(resource.to_definition())
    technique_content["techniques"] = definitions
    _definitions["techniques"] = technique_content
