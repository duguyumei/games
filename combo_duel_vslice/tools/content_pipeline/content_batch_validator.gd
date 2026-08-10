extends RefCounted

const ContentCatalogScript = preload("res://core/content_catalog.gd")
const ContentValidatorScript = preload("res://core/content_validator.gd")
const TechniqueDefinitionScript = preload("res://core/technique_definition.gd")
const EffectHandlerRegistryScript = preload("res://core/effects/effect_handler_registry.gd")
const EffectSpecValidatorScript = preload("res://core/effect_spec_validator.gd")
const ConsumableEffectHandlerRegistryScript = preload(
    "res://core/consumables/consumable_effect_handler_registry.gd")

const REPORT_SCHEMA_VERSION := 1
const TECHNIQUE_SCHEMA_VERSION := 1
const STABLE_ID_PATTERN := "^[a-z][a-z0-9_]*$"
const SIDE_IDS := ["actor", "target"]
const ZONE_IDS := ["hand", "draw_pile", "staging", "discard_pile"]
const DELAY_TIMINGS := ["turn_end", "after_normal_draw"]
const INNER_SKILL_TIMINGS := ["on_play_resolve"]
const AUTHORING_TYPES := ["technique", "inner_skill", "consumable", "enemy", "node"]

var _diagnostics: Array[Dictionary] = []
var _files: Array[String] = []
var _json_documents: Dictionary = {}
var _tres_resources: Dictionary = {}
var _anomaly_categories: Dictionary = {}
var _actor_status_ids: Dictionary = {}
var _id_regex := RegEx.new()
var _consumable_effect_ops: Array[String] = []

func _init() -> void:
    _id_regex.compile(STABLE_ID_PATTERN)
    _consumable_effect_ops = ConsumableEffectHandlerRegistryScript.new().operation_ids()

func validate_project(data_root: String = "res://data") -> Dictionary:
    _reset()
    _scan_directory(data_root)
    _validate_scanned_json()
    _validate_scanned_resources()

    var catalog = ContentCatalogScript.new()
    var catalog_valid: bool = catalog.load_all()
    for message in catalog.errors:
        _add_core_error(str(message))
    for message in catalog.warnings:
        _add("warning", "CORE_WARNING", "catalog", str(message))

    var definitions: Dictionary = {}
    for key in ContentCatalogScript.CONTENT_ORDER:
        var definition: Dictionary = catalog.definition(key)
        if not definition.is_empty():
            definitions[key] = definition
    if definitions.size() == ContentCatalogScript.CONTENT_ORDER.size():
        _audit_definitions(definitions)
        _validate_discovered_content_variants(definitions)
        _validate_authoring_fragments(definitions)
    elif catalog_valid:
        _add("error", "INCOMPLETE_CATALOG", "catalog", "内容目录未返回全部定义")

    _sort_results()
    return _report(data_root)

func validate_definitions(definitions: Dictionary, paths: Dictionary = {}) -> Dictionary:
    _reset()
    var validator = ContentValidatorScript.new()
    var result: Dictionary = validator.validate(definitions.duplicate(true), paths)
    for message in result.get("errors", []):
        _add_core_error(str(message))
    for message in result.get("warnings", []):
        _add("warning", "CORE_WARNING", "catalog", str(message))
    _audit_definitions(definitions)
    _sort_results()
    return _report("definitions")

func _reset() -> void:
    _diagnostics.clear()
    _files.clear()
    _json_documents.clear()
    _tres_resources.clear()
    _anomaly_categories.clear()
    _actor_status_ids.clear()

func _scan_directory(path: String) -> void:
    var directory := DirAccess.open(path)
    if directory == null:
        _add("error", "DATA_ROOT_MISSING", path, "内容目录不存在或不可读")
        return
    directory.list_dir_begin()
    var entry := directory.get_next()
    while entry != "":
        if entry != "." and entry != "..":
            var child := path.path_join(entry)
            if directory.current_is_dir():
                _scan_directory(child)
            elif entry.ends_with(".json"):
                _files.append(child)
                _parse_json_file(child)
            elif entry.ends_with(".tres"):
                _files.append(child)
                _load_tres_file(child)
        entry = directory.get_next()
    directory.list_dir_end()

func _parse_json_file(path: String) -> void:
    var parser := JSON.new()
    var parse_error := parser.parse(FileAccess.get_file_as_string(path))
    if parse_error != OK:
        _add("error", "JSON_PARSE_ERROR", path, "第 %d 行：%s" % [
            parser.get_error_line(), parser.get_error_message()])
        return
    if not parser.data is Dictionary:
        _add("error", "JSON_ROOT_TYPE", path, "顶层 JSON 必须是对象")
        return
    _json_documents[path] = parser.data

func _load_tres_file(path: String) -> void:
    var resource = load(path)
    if resource == null:
        _add("error", "RESOURCE_LOAD_FAILED", path, "TRES 资源无法加载")
        return
    _tres_resources[path] = resource

func _validate_scanned_json() -> void:
    for path_value in _json_documents:
        var path := str(path_value)
        var definition: Dictionary = _json_documents[path]
        if definition.has("content_type") and definition.has("content"):
            _validate_authoring_envelope(path, definition)
            continue
        if definition.has("version"):
            if not _is_positive_integer(definition["version"]):
                _add("error", "INVALID_VERSION", path + ".version", "version 必须是大于等于 1 的整数")
        elif definition.has("schema_version"):
            if not _is_positive_integer(definition["schema_version"]):
                _add("error", "INVALID_VERSION", path + ".schema_version", "schema_version 必须是大于等于 1 的整数")
        else:
            _add("error", "MISSING_VERSION", path, "缺少 version 或 schema_version")
        _audit_resource_paths(definition, path)

func _validate_authoring_envelope(path: String, envelope: Dictionary) -> void:
    if int(envelope.get("schema_version", 0)) != REPORT_SCHEMA_VERSION:
        _add("error", "INVALID_AUTHORING_VERSION", path, "schema_version 必须为 %d" % REPORT_SCHEMA_VERSION)
    var content_type := str(envelope.get("content_type", ""))
    if content_type not in AUTHORING_TYPES:
        _add("error", "UNKNOWN_AUTHORING_TYPE", path, "未知内容骨架类型 %s" % content_type)
    if not envelope.get("content") is Dictionary:
        _add("error", "INVALID_AUTHORING_CONTENT", path, "content 必须是对象")

func _validate_scanned_resources() -> void:
    var technique_manifest: Dictionary = _json_documents.get("res://data/techniques.json", {})
    var registered_paths: Dictionary = {}
    var resource_paths = technique_manifest.get("resource_paths", [])
    if not resource_paths is Array:
        _add("error", "RESOURCE_PATHS_TYPE", "res://data/techniques.json.resource_paths", "必须是数组")
        resource_paths = []
    for index in range(resource_paths.size()):
        var path := str(resource_paths[index])
        var scope := "res://data/techniques.json.resource_paths[%d]" % index
        if registered_paths.has(path):
            _add("error", "DUPLICATE_RESOURCE_PATH", scope, "资源路径重复：%s" % path)
        registered_paths[path] = true
        if not path.begins_with("res://data/techniques/") or not path.ends_with(".tres"):
            _add("error", "INVALID_RESOURCE_PATH", scope, "功法资源必须位于 res://data/techniques 并使用 .tres")
        if not FileAccess.file_exists(path):
            _add("error", "MISSING_RESOURCE", scope, "资源不存在：%s" % path)

    for path_value in _tres_resources:
        var path := str(path_value)
        var resource = _tres_resources[path]
        if not resource is TechniqueDefinitionScript:
            _add("error", "UNSUPPORTED_TRES_TYPE", path, "data 下的 TRES 必须使用 TechniqueDefinition 契约")
            continue
        if not registered_paths.has(path):
            _add("error", "UNREGISTERED_RESOURCE", path, "功法资源未登记到 techniques.json")
        var snapshot: Dictionary = resource.snapshot()
        if int(snapshot.get("schema_version", 0)) != TECHNIQUE_SCHEMA_VERSION:
            _add("error", "INVALID_RESOURCE_VERSION", path, "功法资源 schema_version 必须为 %d" % TECHNIQUE_SCHEMA_VERSION)
        var content_id := str(snapshot.get("id", ""))
        _validate_stable_id(content_id, path + ".id")
        if path.get_file().get_basename() != content_id:
            _add("error", "RESOURCE_ID_FILENAME_MISMATCH", path, "文件名必须与功法 ID 一致：%s" % content_id)

func _audit_resource_paths(value, scope: String) -> void:
    if value is Dictionary:
        for key_value in value:
            var key := str(key_value)
            var child_scope := scope + "." + key
            if (key.ends_with("_path") or key == "path") and value[key_value] is String:
                var resource_path := str(value[key_value])
                if not resource_path.begins_with("res://"):
                    _add("error", "INVALID_RESOURCE_PATH", child_scope, "资源路径必须使用 res://")
                elif not FileAccess.file_exists(resource_path):
                    _add("error", "MISSING_RESOURCE", child_scope, "资源不存在：%s" % resource_path)
            else:
                _audit_resource_paths(value[key_value], child_scope)
    elif value is Array:
        for index in range(value.size()):
            _audit_resource_paths(value[index], "%s[%d]" % [scope, index])

func _audit_definitions(definitions: Dictionary) -> void:
    _anomaly_categories.clear()
    for value in definitions.get("card_states", {}).get("anomalies", []):
        if value is Dictionary:
            _anomaly_categories[str(value.get("id", ""))] = str(value.get("category", ""))
    _actor_status_ids.clear()
    for value in definitions.get("battle_statuses", {}).get("actor_statuses", []):
        if value is Dictionary:
            _actor_status_ids[str(value.get("id", ""))] = true
    _audit_runtime_operation_registry()
    _audit_ids(definitions)
    var techniques: Array = definitions.get("techniques", {}).get("techniques", [])
    for index in range(techniques.size()):
        if techniques[index] is Dictionary:
            _audit_effects(techniques[index].get("effects", []), _battle_effect_ops(),
                "techniques.techniques[%d].effects" % index)
    var inner_skills: Array = definitions.get("inner_skills", {}).get("inner_skills", [])
    for index in range(inner_skills.size()):
        var value = inner_skills[index]
        if not value is Dictionary:
            continue
        var scope := "inner_skills.inner_skills[%d]" % index
        if str(value.get("timing", "")) not in INNER_SKILL_TIMINGS:
            _add("error", "UNKNOWN_EVENT_TIMING", scope + ".timing", "未知内功事件时点 %s" % str(value.get("timing", "")))
        _audit_effects(value.get("effects", []), _battle_effect_ops(), scope + ".effects")
    var consumables: Array = definitions.get("consumables", {}).get("consumables", [])
    for index in range(consumables.size()):
        if consumables[index] is Dictionary:
            _audit_effects(consumables[index].get("effects", []), _consumable_effect_ops,
                "consumables.consumables[%d].effects" % index)

func _audit_runtime_operation_registry() -> void:
    var registry = EffectHandlerRegistryScript.new(RandomNumberGenerator.new())
    if registry.operation_ids().is_empty():
        _add("error", "OP_NOT_REGISTERED", "runtime.operations", "运行时没有注册任何战斗效果")

func _audit_ids(definitions: Dictionary) -> void:
    var arrays := [
        ["starter_builds", "starter_builds"],
        ["battle_statuses", "actor_statuses"],
        ["card_states", "enhancements"],
        ["card_states", "finishes"],
        ["card_states", "imprints"],
        ["card_states", "other_reshapes"],
        ["card_states", "anomalies"],
        ["techniques", "techniques"],
        ["inner_skills", "inner_skills"],
        ["consumables", "consumables"],
    ]
    for spec in arrays:
        var values = definitions.get(spec[0], {}).get(spec[1], [])
        if not values is Array:
            continue
        for index in range(values.size()):
            if values[index] is Dictionary:
                _validate_stable_id(str(values[index].get("id", "")), "%s.%s[%d].id" % [spec[0], spec[1], index])
    var scenario: Dictionary = definitions.get("scripted_battle", {})
    _validate_stable_id(str(scenario.get("id", "")), "scripted_battle.id")
    var node_types: Dictionary = definitions.get("node_content", {}).get("node_types", {})
    for node_type_value in node_types:
        var node_type := str(node_type_value)
        _validate_stable_id(node_type, "node_content.node_types.%s" % node_type)
        if node_types[node_type_value] is Dictionary:
            _validate_stable_id(str(node_types[node_type_value].get("content_id", "")),
                "node_content.node_types.%s.content_id" % node_type)

func _audit_effects(values, allowed_ops: Array, scope: String) -> void:
    if not values is Array:
        return
    for index in range(values.size()):
        var effect = values[index]
        var effect_scope := "%s[%d]" % [scope, index]
        if not effect is Dictionary:
            continue
        var op := str(effect.get("op", ""))
        if op not in allowed_ops:
            _add("error", "UNKNOWN_OPERATION", effect_scope + ".op", "未知效果操作码 %s" % op)
        for field in ["side", "from_side", "to_side", "chooser"]:
            if effect.has(field) and str(effect[field]) not in SIDE_IDS:
                _add("error", "INVALID_TARGET_SIDE", effect_scope + "." + field, "目标策略必须为 actor 或 target")
        for field in ["zone", "from_zone", "to_zone"]:
            if effect.has(field) and str(effect[field]) not in ZONE_IDS:
                _add("error", "INVALID_TARGET_ZONE", effect_scope + "." + field, "引用未知牌区 %s" % str(effect[field]))
        for field in ["amount", "count", "damage", "minimum", "maximum", "limit"]:
            if effect.get(field) is Dictionary:
                _audit_amount_spec(effect[field], effect_scope + "." + field)
        if op == "select_cards":
            if str(effect.get("insufficient_policy", "")) not in ["use_available", "skip", "fail"]:
                _add("error", "INVALID_TARGET_POLICY", effect_scope + ".insufficient_policy",
                    "目标不足策略必须为 use_available、skip 或 fail")
            _audit_query(effect.get("query"), effect_scope + ".query")
        if op in ["move_query", "draw_filtered", "capture_query"]:
            _audit_query(effect.get("query"), effect_scope + ".query")
        if op == "register_delayed_effects":
            if str(effect.get("timing", "")) not in DELAY_TIMINGS:
                _add("error", "UNKNOWN_EVENT_TIMING", effect_scope + ".timing", "未知延迟事件时点 %s" % str(effect.get("timing", "")))
            if not _is_positive_integer(effect.get("occurrences")):
                _add("error", "INVALID_OCCURRENCES", effect_scope + ".occurrences", "occurrences 必须是正整数")
            _audit_effects(effect.get("effects", []), _battle_effect_ops(), effect_scope + ".effects")
        if op in ["add_stack", "add_target_stack", "add_stack_per_captured_card", "register_turn_end_stack"]:
            var stack_id := str(effect.get("stack", ""))
            if not _actor_status_ids.has(stack_id):
                _add("error", "UNKNOWN_REFERENCE", effect_scope + ".stack", "引用未知角色状态 %s" % stack_id)
        if op in ["apply_random_card_anomaly", "apply_card_anomaly_to_captured"]:
            _audit_anomaly_options(effect, effect_scope)

func _audit_query(value, scope: String) -> void:
    if not value is Dictionary:
        return
    if str(value.get("side", "actor")) not in SIDE_IDS:
        _add("error", "INVALID_TARGET_SIDE", scope + ".side", "目标策略必须为 actor 或 target")
    if str(value.get("zone", "hand")) not in ZONE_IDS:
        _add("error", "INVALID_TARGET_ZONE", scope + ".zone", "引用未知牌区 %s" % str(value.get("zone", "")))
    if str(value.get("order", "zone")) not in ["zone", "top", "bottom", "random"]:
        _add("error", "INVALID_TARGET_ORDER", scope + ".order", "目标顺序必须为 zone、top、bottom 或 random")
    if value.get("limit") is Dictionary:
        _audit_amount_spec(value["limit"], scope + ".limit")

func _audit_anomaly_options(effect: Dictionary, scope: String) -> void:
    if not effect.has("random_options"):
        var anomaly_id := str(effect.get("anomaly", ""))
        var category := str(effect.get("category", ""))
        if not _anomaly_categories.has(anomaly_id):
            _add("error", "UNKNOWN_REFERENCE", scope + ".anomaly", "引用未知真气异状 %s" % anomaly_id)
        elif str(_anomaly_categories[anomaly_id]) != category:
            _add("error", "INVALID_ANOMALY_CATEGORY", scope + ".category",
                "异状 %s 不属于类别 %s" % [anomaly_id, category])
        return
    var options = effect["random_options"]
    if not options is Array or options.is_empty():
        _add("error", "INVALID_RANDOM_OPTIONS", scope + ".random_options", "random_options 必须是非空数组")
        return
    for index in range(options.size()):
        if not options[index] is Dictionary:
            _add("error", "INVALID_RANDOM_OPTION", "%s.random_options[%d]" % [scope, index], "必须是对象")
            continue
        var anomaly_id := str(options[index].get("anomaly", ""))
        var category := str(options[index].get("category", ""))
        var option_scope := "%s.random_options[%d]" % [scope, index]
        if not _anomaly_categories.has(anomaly_id):
            _add("error", "UNKNOWN_REFERENCE", option_scope + ".anomaly", "引用未知真气异状 %s" % anomaly_id)
        elif str(_anomaly_categories[anomaly_id]) != category:
            _add("error", "INVALID_ANOMALY_CATEGORY", option_scope + ".category",
                "异状 %s 不属于类别 %s" % [anomaly_id, category])

func _audit_amount_spec(spec: Dictionary, scope: String) -> void:
    ## 此前这里 new 一个临时 ContentValidator 只为调用其私有 _validate_amount_spec
    ## 再从 errors 数组捞结果。数值规格校验现在是 EffectSpecValidator 的公开接口，
    ## 直接构造并接管错误汇总。
    var validator = EffectSpecValidatorScript.new(
        func(error_scope: String, message: String) -> void:
            _add_core_error("%s: %s" % [error_scope, message]),
        {
            "attribute_ids": ContentValidatorScript.ATTRIBUTE_IDS,
            "anomaly_category_ids": ContentValidatorScript.ANOMALY_CATEGORY_IDS,
            "reshape_category_ids": ContentValidatorScript.RESHAPE_CATEGORY_IDS,
            "hand_ids": ContentValidatorScript.TECHNIQUE_BRANCH_HAND_IDS,
        },
        EffectHandlerRegistryScript.new(RandomNumberGenerator.new()))
    validator.validate_amount_spec(spec, scope)

func _battle_effect_ops() -> Array[String]:
    return EffectHandlerRegistryScript.new(RandomNumberGenerator.new()).operation_ids()

func _validate_authoring_fragments(baseline: Dictionary) -> void:
    var fragments: Array[Dictionary] = []
    for path_value in _json_documents:
        var document = _json_documents[path_value]
        if document is Dictionary and document.has("content_type") and document.get("content") is Dictionary:
            fragments.append({"path": str(path_value), "type": str(document.get("content_type", "")), "content": document["content"]})
    if fragments.is_empty():
        return
    var merged: Dictionary = baseline.duplicate(true)
    var enemy_ids: Dictionary = {}
    for fragment in fragments:
        var content_type := str(fragment["type"])
        var content: Dictionary = fragment["content"]
        var path := str(fragment["path"])
        if content_type == "technique":
            merged["techniques"]["techniques"].append(content.duplicate(true))
        elif content_type == "inner_skill":
            merged["inner_skills"]["inner_skills"].append(content.duplicate(true))
        elif content_type == "consumable":
            merged["consumables"]["consumables"].append(content.duplicate(true))
        elif content_type == "node":
            var node_id := str(content.get("node_type", content.get("content_id", "")))
            var node_entry: Dictionary = content.duplicate(true)
            node_entry.erase("node_type")
            merged["node_content"]["node_types"][node_id] = node_entry
        elif content_type == "enemy":
            var enemy_id := str(content.get("id", ""))
            if enemy_ids.has(enemy_id):
                _add("error", "DUPLICATE_ID", path + ".content.id", "敌人 ID 重复：%s" % enemy_id)
            enemy_ids[enemy_id] = true
            var enemy_definitions: Dictionary = merged.duplicate(true)
            enemy_definitions["scripted_battle"] = content.duplicate(true)
            _merge_validation_result(ContentValidatorScript.new().validate(enemy_definitions), path)
    var without_enemy: Dictionary = merged.duplicate(true)
    _merge_validation_result(ContentValidatorScript.new().validate(without_enemy), "authoring")
    _audit_definitions(without_enemy)

func _validate_discovered_content_variants(baseline: Dictionary) -> void:
    for path_value in _json_documents:
        var path := str(path_value)
        if path in ContentCatalogScript.DEFAULT_PATHS.values():
            continue
        var document = _json_documents[path]
        if not document is Dictionary or document.has("content_type"):
            continue
        var candidate_definitions: Dictionary = baseline.duplicate(true)
        if document.has("player") and document.has("enemy") and document.has("rounds"):
            candidate_definitions["scripted_battle"] = document.duplicate(true)
            _merge_validation_result(ContentValidatorScript.new().validate(candidate_definitions), path)
            _validate_stable_id(str(document.get("id", "")), path + ".id")
        elif document.has("node_types"):
            candidate_definitions["node_content"] = document.duplicate(true)
            var scenario_paths: Dictionary = {}
            for node_value in document.get("node_types", {}).values():
                if node_value is Dictionary and node_value.get("battle") is Dictionary:
                    var scenario_path := str(node_value["battle"].get("scenario_path", ""))
                    if scenario_path != "":
                        scenario_paths[scenario_path] = true
            if scenario_paths.size() == 1:
                var scenario_path := str(scenario_paths.keys()[0])
                if _json_documents.get(scenario_path) is Dictionary:
                    candidate_definitions["scripted_battle"] = _json_documents[scenario_path].duplicate(true)
                _merge_validation_result(
                    ContentValidatorScript.new().validate(candidate_definitions, {"scripted_battle": scenario_path}), path)
            else:
                _merge_validation_result(ContentValidatorScript.new().validate(candidate_definitions), path)
        elif _looks_like_sequence_book(document):
            candidate_definitions["sequences"] = document.duplicate(true)
            _merge_validation_result(ContentValidatorScript.new().validate(candidate_definitions), path)
        else:
            var content_key := _content_key_for_document(document)
            if content_key != "":
                candidate_definitions[content_key] = document.duplicate(true)
                _merge_validation_result(ContentValidatorScript.new().validate(candidate_definitions), path)

func _looks_like_sequence_book(document: Dictionary) -> bool:
    for hand_id in ContentValidatorScript.HAND_IDS:
        if not document.has(hand_id):
            return false
    return true

func _content_key_for_document(document: Dictionary) -> String:
    if document.has("attributes") and document.has("ranks"):
        return "base_deck"
    if document.has("starter_builds"):
        return "starter_builds"
    if document.has("actor_statuses"):
        return "battle_statuses"
    if document.has("categories") and document.has("anomalies"):
        return "card_states"
    if document.has("pool_membership") and document.has("techniques"):
        return "techniques"
    if document.has("inner_skills"):
        return "inner_skills"
    if document.has("consumables"):
        return "consumables"
    if document.has("reward_kinds") and document.has("node_rewards"):
        return "node_rewards"
    if document.has("acts") and document.has("node_weights"):
        return "map_rules"
    return ""

func _merge_validation_result(result: Dictionary, prefix: String) -> void:
    for message in result.get("errors", []):
        _add_core_error(prefix + ": " + str(message))

func _validate_stable_id(content_id: String, scope: String) -> void:
    if content_id == "" or _id_regex.search(content_id) == null:
        _add("error", "UNSTABLE_ID", scope, "ID 必须匹配 %s，且发布后不得复用" % STABLE_ID_PATTERN)

func _add_core_error(message: String) -> void:
    var code := "CORE_CONTRACT"
    if message.contains("ID 重复") or message.contains("content_id 重复"):
        code = "DUPLICATE_ID"
    elif message.contains("缺少版本"):
        code = "MISSING_VERSION"
    elif message.contains("未知效果操作码"):
        code = "UNKNOWN_OPERATION"
    elif message.contains("未知数值规格"):
        code = "INVALID_VALUE_SPEC"
    elif message.contains("引用未知"):
        code = "UNKNOWN_REFERENCE"
    elif message.contains("功法池") or message.contains("合格共用池"):
        code = "INVALID_TECHNIQUE_POOL"
    elif message.contains("目标") or message.contains("牌区") or message.contains("chooser"):
        code = "INVALID_TARGET_POLICY"
    _add("error", code, _scope_from_message(message), message)

func _scope_from_message(message: String) -> String:
    var separator := message.find(": ")
    return message.substr(0, separator) if separator >= 0 else "catalog"

func _add(severity: String, code: String, path: String, message: String) -> void:
    var diagnostic := {"severity": severity, "code": code, "path": path, "message": message}
    if not _diagnostics.has(diagnostic):
        _diagnostics.append(diagnostic)

func _sort_results() -> void:
    _files.sort()
    _diagnostics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return "%s|%s|%s" % [a["path"], a["code"], a["message"]] < "%s|%s|%s" % [b["path"], b["code"], b["message"]])

func _report(source: String) -> Dictionary:
    var error_count := 0
    var warning_count := 0
    for diagnostic in _diagnostics:
        if diagnostic["severity"] == "error":
            error_count += 1
        else:
            warning_count += 1
    return {
        "schema_version": REPORT_SCHEMA_VERSION,
        "valid": error_count == 0,
        "source": source,
        "summary": {
            "errors": error_count,
            "warnings": warning_count,
            "json_files": _json_documents.size(),
            "tres_files": _tres_resources.size(),
            "files_scanned": _files.size(),
        },
        "files": _files.duplicate(),
        "diagnostics": _diagnostics.duplicate(true),
    }

func _is_positive_integer(value) -> bool:
    return (value is int or value is float) and float(value) == floor(float(value)) and int(value) >= 1
