class_name TechniqueRepository
extends RefCounted

const DATA_PATH := "res://data/techniques.json"
const DefinitionScript = preload("res://core/technique_definition.gd")
const InstanceScript = preload("res://core/technique_instance.gd")
const RESOURCE_DIR := "res://data/techniques"

var techniques: Dictionary = {}
var pool_membership: Dictionary = {}
var definitions: Dictionary = {}

func load_from_file(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("功法数据无法解析：%s" % path)
        return false
    return configure(parsed, true)

func configure(value: Dictionary, load_resource_entities: bool = false) -> bool:
    techniques.clear()
    pool_membership.clear()
    definitions.clear()
    var parsed := value.duplicate(true)
    pool_membership = parsed.get("pool_membership", {}).duplicate(true)
    for definition in parsed.get("techniques", []):
        var entity = DefinitionScript.new().configure_from_dictionary(definition)
        definitions[entity.id] = entity
        techniques[entity.id] = entity.to_definition()
    if load_resource_entities:
        _load_resource_entities()
    return not techniques.is_empty()

func get_definition(technique_id: String):
    var dictionary: Dictionary = techniques.get(technique_id, {})
    if dictionary.is_empty():
        return null
    var entity: TechniqueDefinition = definitions.get(technique_id)
    # 旧测试和调试工具仍可能直接替换公开字典；在兼容边界同步成临时实体。
    if entity == null or entity.to_definition() != _normalized_definition(dictionary):
        entity = DefinitionScript.new().configure_from_dictionary(dictionary)
        definitions[technique_id] = entity
    return entity

func get_instance(technique_id: String, owner_id: String = "", acquired_order: int = 0):
    var definition = get_definition(technique_id)
    if definition == null:
        return null
    return InstanceScript.new().configure(definition, owner_id, acquired_order)

func get_technique(technique_id: String) -> Dictionary:
    return techniques.get(technique_id, {}).duplicate(true)

func _load_resource_entities() -> void:
    var directory := DirAccess.open(RESOURCE_DIR)
    if directory == null:
        return
    for file_name in directory.get_files():
        if not file_name.ends_with(".tres"):
            continue
        var resource = load("%s/%s" % [RESOURCE_DIR, file_name])
        if not resource is TechniqueDefinition or resource.id == "":
            continue
        var entity: TechniqueDefinition = resource
        var previous: TechniqueDefinition = definitions.get(entity.id)
        # 迁移期间 effects 仍从旧夹具补齐；实体身份和元数据以独立资源为准。
        if entity.effects.is_empty() and previous != null:
            entity.effects = previous.effects.duplicate(true)
        definitions[entity.id] = entity
        techniques[entity.id] = entity.to_definition()

func is_allowed_for_hand(technique, hand_id: String) -> bool:
    var eligible_pools: Array = pool_membership.get(hand_id, [])
    return eligible_pools.has(_definition_value(technique, "pool", ""))

func conditions_met(technique, hand_result: Dictionary) -> Dictionary:
    if technique == null or (technique is Dictionary and technique.is_empty()):
        return {"ok": false, "reason": "功法不存在"}
    var hand_id: String = hand_result.get("id", "")
    if not is_allowed_for_hand(technique, hand_id):
        return {"ok": false, "reason": "功法不属于该精确牌型的合格共用池"}
    var condition: Dictionary = _definition_value(technique, "condition", {})
    if condition.is_empty():
        return {"ok": true, "reason": "条件满足"}
    if condition.has("attribute"):
        var wanted: String = condition["attribute"]
        var count := 0
        for card in hand_result.get("contributing", []):
            if card.is_attribute(wanted):
                count += 1
        if count < int(condition.get("minimum", 1)):
            return {"ok": false, "reason": "参与最高牌型的%s属性真气不足" % wanted}
    if condition.has("pure_attribute") and not is_pure_attribute(hand_result, condition["pure_attribute"]):
        return {"ok": false, "reason": "参与最高牌型的真气不是纯属性"}
    return {"ok": true, "reason": "条件满足"}

func _definition_value(technique, key: String, fallback):
    if technique is TechniqueDefinition:
        return technique.get(key) if key != "name" else technique.display_name
    return technique.get(key, fallback)

func _normalized_definition(value: Dictionary) -> Dictionary:
    return DefinitionScript.new().configure_from_dictionary(value).to_definition()

static func is_pure_attribute(hand_result: Dictionary, attribute: String) -> bool:
    var contributing: Array = hand_result.get("contributing", [])
    if contributing.is_empty():
        return false
    for card in contributing:
        if not card.is_attribute(attribute):
            return false
    return true
