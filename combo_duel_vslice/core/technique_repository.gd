class_name TechniqueRepository
extends RefCounted

const DATA_PATH := "res://data/techniques.json"
const DefinitionScript = preload("res://core/technique_definition.gd")
const InstanceScript = preload("res://core/technique_instance.gd")
var techniques: Dictionary = {}
var pool_membership: Dictionary = {}
var definitions: Dictionary = {}
var integration_statuses: Dictionary = {}
var resource_paths: Array = []
var loaded_successfully: bool = false
var last_error: String = ""

func load_from_file(path: String = DATA_PATH) -> bool:
    loaded_successfully = false
    last_error = ""
    if not FileAccess.file_exists(path):
        last_error = "功法数据文件不存在：%s" % path
        push_error(last_error)
        return false
    var parser := JSON.new()
    var parse_error := parser.parse(FileAccess.get_file_as_string(path))
    if parse_error != OK or not parser.data is Dictionary:
        last_error = "功法数据无法解析：%s" % path
        push_error(last_error)
        return false
    var parsed: Dictionary = parser.data
    return configure(parsed, true)

func configure(value: Dictionary, load_resource_entities: bool = false) -> bool:
    techniques.clear()
    pool_membership.clear()
    definitions.clear()
    integration_statuses.clear()
    resource_paths.clear()
    loaded_successfully = false
    last_error = ""
    var parsed := value.duplicate(true)
    if not parsed.get("pool_membership", {}) is Dictionary \
            or not parsed.get("integration_statuses", {}) is Dictionary \
            or not parsed.get("resource_paths", []) is Array \
            or (parsed.has("techniques") and not parsed["techniques"] is Array):
        last_error = "功法仓库结构非法"
        push_error(last_error)
        return false
    pool_membership = parsed.get("pool_membership", {}).duplicate(true)
    integration_statuses = parsed.get("integration_statuses", {}).duplicate(true)
    resource_paths = parsed.get("resource_paths", []).duplicate()
    for definition in parsed.get("techniques", []):
        if not definition is Dictionary:
            last_error = "功法定义必须是对象"
            push_error(last_error)
            return false
        var entity = DefinitionScript.new().configure_from_dictionary(definition)
        if entity.id == "":
            last_error = "功法定义缺少 ID"
            push_error(last_error)
            return false
        definitions[entity.id] = entity
        techniques[entity.id] = entity.to_definition()
    if load_resource_entities and not _load_resource_entities():
        return false
    loaded_successfully = true
    return true

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

func integration_status(technique_id: String) -> String:
    return str(integration_statuses.get(technique_id, "missing"))

func is_formally_complete(technique_id: String) -> bool:
    return integration_status(technique_id) == "formal_complete"

func formal_technique_ids() -> Array[String]:
    var result: Array[String] = []
    for technique_id_value in integration_statuses:
        var technique_id := str(technique_id_value)
        var definition = get_definition(technique_id)
        if is_formally_complete(technique_id) \
                and definition != null and not definition.built_in:
            result.append(technique_id)
    result.sort()
    return result

func formal_technique_ids_for_hand(hand_id: String, excluded_ids: Array = []) -> Array[String]:
    var result: Array[String] = []
    for technique_id in formal_technique_ids():
        if excluded_ids.has(technique_id):
            continue
        var definition = get_definition(technique_id)
        if definition != null and is_allowed_for_hand(definition, hand_id):
            result.append(technique_id)
    return result

func _load_resource_entities() -> bool:
    for path_value in resource_paths:
        var path := str(path_value)
        if not ResourceLoader.exists(path):
            last_error = "功法资源不存在：%s" % path
            push_error(last_error)
            return false
        var resource = load(path)
        if not resource is TechniqueDefinition or resource.id == "":
            last_error = "功法资源非法：%s" % path
            push_error(last_error)
            return false
        var entity: TechniqueDefinition = resource
        var previous: TechniqueDefinition = definitions.get(entity.id)
        # 迁移期间 effects 仍从旧夹具补齐；实体身份和元数据以独立资源为准。
        if entity.effects.is_empty() and previous != null:
            entity.effects = previous.effects.duplicate(true)
        definitions[entity.id] = entity
        techniques[entity.id] = entity.to_definition()
    return true

func is_allowed_for_hand(technique, hand_id: String) -> bool:
    var eligible_hand_ids: Array = _definition_value(
        technique, "eligible_hand_ids", [])
    if not eligible_hand_ids.is_empty():
        return eligible_hand_ids.has(hand_id)
    var eligible_pools: Array = pool_membership.get(hand_id, [])
    return eligible_pools.has(_definition_value(technique, "pool", ""))

func conditions_met(technique, hand_result: Dictionary, identity_policy = null,
        host_sequence_qualified: bool = false) -> Dictionary:
    if technique == null or (technique is Dictionary and technique.is_empty()):
        return {"ok": false, "reason": "功法不存在"}
    var hand_id: String = hand_result.get("id", "")
    if not host_sequence_qualified and not is_allowed_for_hand(technique, hand_id):
        return {"ok": false, "reason": "功法不属于该精确牌型的合格共用池"}
    var condition: Dictionary = _definition_value(technique, "condition", {})
    if condition.is_empty():
        return {"ok": true, "reason": "条件满足"}
    if condition.has("attribute"):
        var wanted: String = condition["attribute"]
        var count := 0
        for card in hand_result.get("contributing", []):
            if _card_has_attribute(card, wanted, identity_policy):
                count += 1
        if count < int(condition.get("minimum", 1)):
            return {"ok": false, "reason": "参与最高牌型的%s属性真气不足" % wanted}
    if condition.has("pure_attribute") and not is_pure_attribute(hand_result, condition["pure_attribute"], identity_policy):
        return {"ok": false, "reason": "参与最高牌型的真气不是纯属性"}
    return {"ok": true, "reason": "条件满足"}

func _definition_value(technique, key: String, fallback):
    if technique is TechniqueDefinition:
        return technique.get(key) if key != "name" else technique.display_name
    return technique.get(key, fallback)

func _normalized_definition(value: Dictionary) -> Dictionary:
    return DefinitionScript.new().configure_from_dictionary(value).to_definition()

static func is_pure_attribute(hand_result: Dictionary, attribute: String, identity_policy = null) -> bool:
    var contributing: Array = hand_result.get("contributing", [])
    if contributing.is_empty():
        return false
    for card in contributing:
        if not _card_has_attribute(card, attribute, identity_policy):
            return false
    return true

static func _card_has_attribute(card, attribute: String, identity_policy = null) -> bool:
    if identity_policy != null and identity_policy.has_method("resolve"):
        var result: Dictionary = identity_policy.resolve(card, {})
        if result.get("success", false):
            return bool(result["facts"].has_attribute(attribute))
    return card.is_attribute(attribute)
