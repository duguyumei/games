class_name CardIdentityPolicy
extends RefCounted

const FactsScript = preload("res://core/passives/card_identity_facts.gd")
const ContextScript = preload("res://core/passives/passive_rule_context.gd")

const KNOWN_ATTRIBUTES := ["wind", "forest", "fire", "mountain"]

var _runtime_ref: WeakRef
var _providers: Array = []
var _serial: int = 0

func _init(passive_runtime = null) -> void:
    _runtime_ref = weakref(passive_runtime) if passive_runtime != null else null

func register_provider(provider, source_id: String = "", order: int = 0) -> String:
    var stable_id := source_id if source_id != "" else "provider:%06d" % _serial
    _providers.append({
        "provider": weakref(provider) if provider is Object and not provider is Callable else provider,
        "source_id": stable_id, "order": order, "serial": _serial,
    })
    _serial += 1
    _providers.sort_custom(func(left, right):
        if int(left["order"]) != int(right["order"]):
            return int(left["order"]) < int(right["order"])
        if str(left["source_id"]) != str(right["source_id"]):
            return str(left["source_id"]) < str(right["source_id"])
        return int(left["serial"]) < int(right["serial"]))
    return stable_id

func unregister_provider(source_id: String) -> bool:
    for index in range(_providers.size()):
        if str(_providers[index]["source_id"]) == source_id:
            _providers.remove_at(index)
            return true
    return false

func resolve(card, context: Dictionary = {}) -> Dictionary:
    if card == null:
        return _failure(null, "卡牌身份查询缺少卡牌", [])
    var facts = _base_facts(card)
    var owner = context.get("owner", context.get("actor"))
    var owner_before: Dictionary = owner.capture_passive_query_state() \
        if owner != null and owner.has_method("capture_passive_query_state") else {}
    var card_before := _card_state(card)
    var breakdown: Array = []
    var claimed_scalars: Dictionary = {}
    var runtime_entries := _runtime_entries(card, context)
    var purity_error := _restore_if_mutated(owner, owner_before, card, card_before)
    if purity_error != "":
        return _failure(facts, purity_error, breakdown)
    if not runtime_entries.get("success", false):
        return _failure(facts, str(runtime_entries.get("reason", "身份查询失败")), breakdown)
    var entries: Array = runtime_entries.get("entries", [])
    for provider in _providers:
        if bool(provider.get("suppressed", false)):
            continue
        var response := _call_provider(provider["provider"], card, context)
        purity_error = _restore_if_mutated(owner, owner_before, card, card_before)
        if purity_error != "":
            return _failure(facts, purity_error, breakdown)
        if not response.get("success", false):
            return _failure(facts, "%s：%s" % [provider["source_id"], response.get("reason", "查询失败")], breakdown)
        entries.append({"source_id": provider["source_id"], "value": response["value"]})
    for entry in entries:
        var merged := _merge(facts, entry["value"], claimed_scalars, str(entry["source_id"]))
        if not merged.get("success", false):
            return _failure(facts, str(merged.get("reason", "身份规则冲突")), breakdown)
        breakdown.append({"source_id": entry["source_id"], "facts": entry["value"].duplicate(true)})
    return {"success": true, "facts": facts, "source_breakdown": breakdown, "errors": []}

func facts_for(card, context: Dictionary = {}):
    var result := resolve(card, context)
    return result.get("facts")

func resolve_identity(card, context: Dictionary = {}) -> Dictionary:
    return resolve(card, context)

func _base_facts(card):
    var attribute := str(card.current_attribute()) \
        if card.has_method("current_attribute") else str(card.attribute)
    var attributes: Array[String] = []
    if attribute != "":
        attributes.append(attribute)
    if card.has_method("base_is_attribute"):
        for candidate in KNOWN_ATTRIBUTES:
            if card.base_is_attribute(candidate) and not attributes.has(candidate):
                attributes.append(candidate)
    elif card.has_method("is_attribute"):
        for candidate in KNOWN_ATTRIBUTES:
            if card.is_attribute(candidate) and not attributes.has(candidate):
                attributes.append(candidate)
    var rank_order := int(card.current_rank_order()) \
        if card.has_method("current_rank_order") else int(card.rank_order)
    var rank_name := str(card.current_rank_name()) \
        if card.has_method("current_rank_name") else str(card.rank_name)
    var native_true_qi := bool(card.is_true_qi)
    var kinds: Array[String] = ["normal"]
    if native_true_qi:
        kinds.append("true_qi")
    return FactsScript.new().configure({
        "is_true_qi": native_true_qi,
        "effective_attributes": attributes,
        "rank_tags": [rank_name, "rank_%d" % rank_order],
        "card_kinds": kinds,
        "rank_order": rank_order,
        "rank_name": rank_name,
        "definition_id": str(card.current_definition_id()) \
            if card.has_method("current_definition_id") else str(card.definition_id),
    })

func _runtime_entries(card, context: Dictionary) -> Dictionary:
    var runtime = _runtime_ref.get_ref() if _runtime_ref != null else null
    if runtime == null:
        return {"success": true, "entries": []}
    var owner = context.get("owner", context.get("actor"))
    var rule_context = ContextScript.new().configure({
        "owner": owner,
        "actor": context.get("actor", owner),
        "target": context.get("target"),
        "round_number": int(context.get("round_number", 0)),
        "payload": context.merged({"card": card}, true),
    })
    var plan = runtime.build_execution_plan("card_identity_query", rule_context)
    if not plan.is_valid():
        return {"success": false, "reason": "；".join(plan.errors)}
    var entries: Array = []
    for invocation in plan.invocations:
        var executed: Dictionary = runtime.execute_invocation(invocation, null, "read")
        if not executed.get("success", false):
            return {"success": false, "reason": executed.get("reason", "身份查询失败")}
        var value = executed["result"].get("facts", executed["result"])
        if not value is Dictionary:
            return {"success": false, "reason": "身份 Handler 必须返回 facts 对象"}
        entries.append({"source_id": invocation.source.source_instance_key, "value": value})
    return {"success": true, "entries": entries}

func _call_provider(provider, card, context: Dictionary) -> Dictionary:
    if provider is WeakRef:
        provider = provider.get_ref()
        if provider == null:
            return {"success": false, "reason": "Provider 已释放"}
    var value = null
    if provider is Callable:
        value = provider.call(card, context)
    elif provider != null and provider.has_method("resolve_identity"):
        value = provider.resolve_identity(card, context)
    elif provider != null and provider.has_method("query"):
        value = provider.query("card_identity_query", card, context)
    if not value is Dictionary:
        return {"success": false, "reason": "Provider 必须返回对象"}
    if value.has("success") and not bool(value["success"]):
        return {"success": false, "reason": value.get("reason", "查询失败")}
    var facts = value.get("facts", value)
    if not facts is Dictionary:
        return {"success": false, "reason": "Provider 的 facts 必须是对象"}
    return {"success": true, "value": facts}

func _merge(facts, values: Dictionary, claimed: Dictionary, source_id: String) -> Dictionary:
    for field in ["is_true_qi", "rank_order", "rank_name", "definition_id"]:
        if not values.has(field):
            continue
        if claimed.has(field) and claimed[field]["value"] != values[field]:
            return {"success": false, "reason": "身份字段 %s 冲突：%s 与 %s" % [field, claimed[field]["source"], source_id]}
        claimed[field] = {"value": values[field], "source": source_id}
        facts.set(field, values[field])
    for field in ["effective_attributes", "rank_tags", "card_kinds"]:
        if not values.has(field) or not values[field] is Array:
            continue
        var target: Array = facts.get(field)
        for value in values[field]:
            var text := str(value)
            if text != "" and not target.has(text):
                target.append(text)
    if values.has("additional_effective_attributes") and values["additional_effective_attributes"] is Array:
        for value in values["additional_effective_attributes"]:
            var text := str(value)
            if text != "" and not facts.effective_attributes.has(text):
                facts.effective_attributes.append(text)
    return {"success": true}

func _failure(facts, reason: String, breakdown: Array) -> Dictionary:
    return {"success": false, "facts": facts, "source_breakdown": breakdown, "errors": [reason], "reason": reason}

func _card_state(card) -> Dictionary:
    return {
        "definition_id": str(card.definition_id),
        "rank_name": str(card.rank_name), "rank_order": int(card.rank_order),
        "qi_value": int(card.qi_value), "attribute": str(card.attribute),
        "attribute_name": str(card.attribute_name),
        "is_true_qi": bool(card.is_true_qi),
        "reshape_origin": card.reshape_origin.duplicate(true),
        "reshape_enhancement": str(card.reshape_enhancement),
        "reshape_imprint": str(card.reshape_imprint),
        "reshape_others": card.reshape_others.duplicate(true),
        "anomalies": card.anomalies.duplicate(true),
        "temporary_reshapes": card.temporary_reshapes.duplicate(true),
        "origin_base_identity": card.origin_base_identity.duplicate(true),
    }

func _restore_if_mutated(owner, owner_before: Dictionary, card, card_before: Dictionary) -> String:
    var mutated := _card_state(card) != card_before
    if owner != null and not owner_before.is_empty() \
            and owner.has_method("capture_passive_query_state") \
            and owner.capture_passive_query_state() != owner_before:
        mutated = true
        owner.replace_passive_query_state(owner_before)
    if not mutated:
        return ""
    card.definition_id = card_before["definition_id"]
    card.rank_name = card_before["rank_name"]
    card.rank_order = card_before["rank_order"]
    card.qi_value = card_before["qi_value"]
    card.attribute = card_before["attribute"]
    card.attribute_name = card_before["attribute_name"]
    card.is_true_qi = card_before["is_true_qi"]
    card.reshape_origin = card_before["reshape_origin"].duplicate(true)
    card.reshape_enhancement = card_before["reshape_enhancement"]
    card.reshape_imprint = card_before["reshape_imprint"]
    card.reshape_others = card_before["reshape_others"].duplicate(true)
    card.anomalies = card_before["anomalies"].duplicate(true)
    card.temporary_reshapes = card_before["temporary_reshapes"].duplicate(true)
    card.origin_base_identity = card_before["origin_base_identity"].duplicate(true)
    return "纯查询 Handler 不得修改卡牌或战斗状态"
