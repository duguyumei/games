class_name QiCard
extends RefCounted

const CardReshapeRuleServiceScript = preload(
    "res://core/card_reshapes/card_reshape_rule_service.gd")
const CardIdentityFactsScript = preload(
    "res://core/passives/card_identity_facts.gd")

const ANOMALY_CATEGORIES := ["buff", "debuff", "state", "mark"]
const TEMPORARY_RESHAPE_SUBSLOTS := ["enhancement", "attribute", "rank"]

var id: String
var definition_id: String
var rank_name: String
var rank_order: int
var qi_value: int
var attribute: String
var attribute_name: String
## 身份策略读取的本源真气标记；策略只覆盖查询结果，不写回此字段。
var is_true_qi: bool = true

var reshape_origin: Dictionary = {}
var reshape_enhancement: String = ""
var reshape_imprint: String = ""
var reshape_others: Dictionary = {}

var anomalies: Dictionary = {
    "buffs": {},
    "debuffs": {},
    "state": {},
    "marks": {},
}
var temporary_reshapes: Dictionary = {
    "enhancement": "",
    "attribute": "",
    "rank": {},
}
## 本源改造提交前的基础身份。只有存在本源时才非空；归元读取此快照，
## 不反向猜测已经物化到 definition_id/rank/attribute/qi_value 的旧身份。
var origin_base_identity: Dictionary = {}
var original_owner_id: String = ""
var temporary_card: bool = false
var reshape_rule_service
var identity_policy = null
var battle_permission_service = null

func _init(
        card_id: String = "",
        card_rank_name: String = "",
        card_rank_order: int = 0,
        card_qi_value: int = 0,
        card_attribute: String = "",
        card_attribute_name: String = "",
        card_definition_id: String = "") -> void:
    id = card_id
    definition_id = card_definition_id if card_definition_id != "" else card_id
    rank_name = card_rank_name
    rank_order = card_rank_order
    qi_value = card_qi_value
    attribute = card_attribute
    attribute_name = card_attribute_name

func display_name() -> String:
    return "%s·%s" % [current_attribute_name(), current_rank_name()]

func return_to_origin_active() -> bool:
    return has_anomaly("mark", "return_to_origin")

func current_definition_id() -> String:
    return str(_effective_identity().get("definition_id", definition_id))

func current_rank_name() -> String:
    return str(_effective_identity().get("rank_name", rank_name))

func current_rank_order() -> int:
    return int(_effective_identity().get("rank_order", rank_order))

func current_base_qi_value() -> int:
    return int(_effective_identity().get("qi_value", qi_value))

func current_attribute() -> String:
    return str(_effective_identity().get("attribute", attribute))

func current_attribute_name() -> String:
    return str(_effective_identity().get("attribute_name", attribute_name))

func _effective_identity() -> Dictionary:
    if return_to_origin_active() and not origin_base_identity.is_empty():
        return origin_base_identity
    if return_to_origin_active():
        return {}
    var temporary_rank = temporary_reshapes.get("rank", {})
    if temporary_rank is Dictionary and not temporary_rank.is_empty():
        return {
            "rank_name": str(temporary_rank.get("rank_name", rank_name)),
            "rank_order": int(temporary_rank.get("rank_order", rank_order)),
            "qi_value": int(temporary_rank.get("qi_value", qi_value)),
        }
    return {}

func is_attribute(attribute_id: String) -> bool:
    if identity_policy != null and identity_policy.has_method("resolve"):
        var resolved: Dictionary = identity_policy.resolve(self, {})
        if resolved.get("success", false):
            return bool(resolved["facts"].has_attribute(attribute_id))
    return base_is_attribute(attribute_id)

func base_is_attribute(attribute_id: String) -> bool:
    if current_attribute() == attribute_id:
        return true
    if not return_to_origin_active() \
            and str(temporary_reshapes.get("attribute", "")) == attribute_id:
        return true
    var rules = _reshape_rules()
    if rules.matches_attribute(self, attribute_id):
        return true
    return false

func set_enhancement(enhancement_id: String) -> void:
    reshape_enhancement = enhancement_id
    _reshape_rules().apply_reshape(self, "enhancement", enhancement_id)

func set_imprint(imprint_id: String) -> void:
    reshape_imprint = imprint_id
    _reshape_rules().apply_reshape(self, "imprint", imprint_id)

func origin_locked() -> bool:
    return not reshape_origin.is_empty()

func set_other_reshape(reshape_id: String, payload: Dictionary = {}) -> bool:
    if reshape_id == "":
        return false
    reshape_others[reshape_id] = payload.duplicate(true)
    var result: Dictionary = _reshape_rules().apply_reshape(self, "other", reshape_id, payload)
    if not bool(result.get("success", false)):
        reshape_others.erase(reshape_id)
        return false
    return true

func remove_other_reshape(reshape_id: String) -> Dictionary:
    var previous: Dictionary = reshape_others.get(reshape_id, {}).duplicate(true)
    reshape_others.erase(reshape_id)
    return previous

func set_anomaly(
        category: String,
        anomaly_id: String,
        payload: Dictionary = {},
        layers: int = 1) -> bool:
    if not ANOMALY_CATEGORIES.has(category) or anomaly_id == "":
        return false
    var anomaly_check: Dictionary = _reshape_rules().can_apply_anomaly(
        self, category, anomaly_id)
    if not bool(anomaly_check.get("allowed", true)):
        return false
    match category:
        "buff": anomalies["buffs"][anomaly_id] = maxi(1, layers)
        "debuff": anomalies["debuffs"][anomaly_id] = maxi(1, layers)
        "state": anomalies["state"] = {
            "id": anomaly_id,
            "layers": maxi(1, layers),
            "payload": payload.duplicate(true),
        }
        "mark": anomalies["marks"][anomaly_id] = payload.duplicate(true)
    return true

func add_anomaly_layers(category: String, anomaly_id: String, layers: int = 1) -> bool:
    if category not in ["buff", "debuff"] or anomaly_id == "" or layers <= 0:
        return false
    anomalies[_plural_category(category)][anomaly_id] = (
        anomaly_layers(category, anomaly_id) + layers)
    return true

func set_state_layers(layers: int) -> bool:
    if anomalies["state"].is_empty():
        return false
    if layers <= 0:
        anomalies["state"].clear()
    else:
        anomalies["state"]["layers"] = layers
    return true

func anomaly_layers(category: String, anomaly_id: String) -> int:
    match category:
        "buff", "debuff":
            return maxi(0, int(anomalies[_plural_category(category)].get(anomaly_id, 0)))
        "state":
            return int(anomalies["state"].get("layers", 0)) \
                if str(anomalies["state"].get("id", "")) == anomaly_id else 0
        "mark": return 1 if anomalies["marks"].has(anomaly_id) else 0
    return 0

func current_state() -> Dictionary:
    return anomalies["state"].duplicate(true)

func configure_reshape_rule_service(service) -> void:
    reshape_rule_service = service

func configure_identity_policy(policy) -> void:
    identity_policy = policy

func configure_battle_permission_service(service) -> void:
    battle_permission_service = service

func identity_facts(context: Dictionary = {}):
    if identity_policy != null and identity_policy.has_method("resolve"):
        var resolved: Dictionary = identity_policy.resolve(self, context)
        if resolved.get("success", false):
            return resolved["facts"]
    return CardIdentityFactsScript.new().configure({
        "is_true_qi": is_true_qi,
        "effective_attributes": [current_attribute()],
        "rank_tags": [current_rank_name(), "rank_%d" % current_rank_order()],
        "card_kinds": ["normal", "true_qi"] if is_true_qi else ["normal"],
        "rank_order": current_rank_order(),
        "rank_name": current_rank_name(),
        "definition_id": current_definition_id(),
    })

func effective_qi_value(
        include_contribution: bool = false,
        calculation_context: Dictionary = {}) -> int:
    var value: int = int(_reshape_rules().effective_qi_value(
        self, calculation_context))
    if include_contribution:
        value = _reshape_rules().card_contribution(self, value)
    return value

func reshape_card_contribution(base_value: int) -> int:
    return _reshape_rules().card_contribution(self, base_value)

func reshape_multiplier_bonus() -> int:
    return _reshape_rules().technique_multiplier_bonus(self)

func reshape_power_amp_percent() -> int:
    return _reshape_rules().power_amp_percent(self)

func is_card_kind(kind: String) -> bool:
    if identity_policy != null and identity_policy.has_method("resolve"):
        var resolved: Dictionary = identity_policy.resolve(self, {})
        if resolved.get("success", false):
            return bool(resolved["facts"].is_card_kind(kind))
    return base_is_card_kind(kind)

func base_is_card_kind(kind: String) -> bool:
    return _reshape_rules().has_card_kind(self, kind)

func can_apply_anomaly(category: String = "", anomaly_id: String = "") -> Dictionary:
    return _reshape_rules().can_apply_anomaly(self, category, anomaly_id)

func can_explicit_discard() -> Dictionary:
    if battle_permission_service != null:
        return battle_permission_service.can_explicit_discard(null, self)
    return _reshape_rules().can_explicit_discard(self)

func _reshape_rules():
    # Effective-value and identity reads are pure. Unbound fixture/legacy cards
    # may use the fallback rules, but a read must not silently bind a service
    # into the card's rollback state.
    return reshape_rule_service \
        if reshape_rule_service != null \
        else CardReshapeRuleServiceScript.fallback()

func has_anomaly(category: String, anomaly_id: String = "") -> bool:
    match category:
        "buff", "debuff":
            var entries: Dictionary = anomalies[_plural_category(category)]
            return not entries.is_empty() if anomaly_id == "" else int(entries.get(anomaly_id, 0)) > 0
        "state":
            var state_id := str(anomalies["state"].get("id", ""))
            return state_id != "" and (anomaly_id == "" or state_id == anomaly_id)
        "mark":
            return not anomalies["marks"].is_empty() \
                if anomaly_id == "" else anomalies["marks"].has(anomaly_id)
    return false

func remove_anomaly(category: String, anomaly_id: String = ""):
    match category:
        "buff", "debuff":
            var entries: Dictionary = anomalies[_plural_category(category)]
            if anomaly_id == "":
                var previous_entries := entries.duplicate(true)
                entries.clear()
                return previous_entries
            var previous_layers := int(entries.get(anomaly_id, 0))
            entries.erase(anomaly_id)
            return previous_layers
        "state":
            var previous_state: Dictionary = anomalies["state"].duplicate(true)
            if anomaly_id == "" or str(anomalies["state"].get("id", "")) == anomaly_id:
                anomalies["state"].clear()
            return previous_state
        "mark":
            if anomaly_id == "":
                var previous_marks: Dictionary = anomalies["marks"].duplicate(true)
                anomalies["marks"].clear()
                return previous_marks
            var previous_mark: Dictionary = anomalies["marks"].get(anomaly_id, {}).duplicate(true)
            anomalies["marks"].erase(anomaly_id)
            return previous_mark
    return null

func anomaly_snapshot() -> Dictionary:
    return anomalies.duplicate(true)

func restore_anomaly_snapshot(values: Dictionary) -> bool:
    if values.has("poison") or values.has("others") \
            or not values.has_all(["buffs", "debuffs", "state", "marks"]):
        return false
    anomalies = {
        "buffs": values.get("buffs", {}).duplicate(true),
        "debuffs": values.get("debuffs", {}).duplicate(true),
        "state": values.get("state", {}).duplicate(true),
        "marks": values.get("marks", {}).duplicate(true),
    }
    return true

func clear_anomalies() -> Dictionary:
    var removed := anomaly_snapshot()
    anomalies["buffs"].clear()
    anomalies["debuffs"].clear()
    anomalies["state"].clear()
    anomalies["marks"].clear()
    return removed

func clear_combat_state() -> void:
    clear_anomalies()
    clear_all_temporary_reshapes()

func set_temporary_enhancement(enhancement_id: String) -> bool:
    if enhancement_id == "":
        return false
    temporary_reshapes["enhancement"] = enhancement_id
    return true

func set_temporary_attribute(attribute_id: String) -> bool:
    if attribute_id not in ["wind", "forest", "fire", "mountain"]:
        return false
    temporary_reshapes["attribute"] = attribute_id
    return true

func set_temporary_rank(rank_id: String, order: int, base_qi: int) -> bool:
    if rank_id == "" or order < 2 or order > 14 or base_qi < 0:
        return false
    temporary_reshapes["rank"] = {
        "rank_name": rank_id,
        "rank_order": order,
        "qi_value": base_qi,
    }
    return true

func clear_temporary_reshape(subslot: String):
    if subslot not in TEMPORARY_RESHAPE_SUBSLOTS:
        return ""
    var previous = temporary_reshapes.get(subslot, {}).duplicate(true) \
        if subslot == "rank" else str(temporary_reshapes.get(subslot, ""))
    temporary_reshapes[subslot] = {} if subslot == "rank" else ""
    return previous

func clear_all_temporary_reshapes() -> Dictionary:
    var previous := temporary_reshapes.duplicate(true)
    temporary_reshapes = {"enhancement": "", "attribute": "", "rank": {}}
    return previous

func active_reshape_state() -> Dictionary:
    return {
        "origin": reshape_origin.duplicate(true),
        "enhancement": reshape_enhancement,
        "imprint": reshape_imprint,
        "others": reshape_others.duplicate(true),
    }

func persistent_reshape_state() -> Dictionary:
    return active_reshape_state()

func has_any_reshape_storage() -> bool:
    return not reshape_origin.is_empty() \
        or reshape_enhancement != "" \
        or reshape_imprint != "" \
        or not reshape_others.is_empty() \
        or str(temporary_reshapes.get("enhancement", "")) != "" \
        or str(temporary_reshapes.get("attribute", "")) != "" \
        or not temporary_reshapes.get("rank", {}).is_empty()

func _plural_category(category: String) -> String:
    return "buffs" if category == "buff" else "debuffs"

func to_dict() -> Dictionary:
    return {
        "id": id,
        "instance_id": id,
        "definition_id": current_definition_id(),
        "rank_name": current_rank_name(),
        "rank_order": current_rank_order(),
        "qi_value": current_base_qi_value(),
        "attribute": attribute,
        "attribute_name": attribute_name,
        "permanent_definition_id": definition_id,
        "permanent_rank_name": rank_name,
        "permanent_rank_order": rank_order,
        "permanent_qi_value": qi_value,
        "origin_base_identity": origin_base_identity.duplicate(true),
        "reshapes": active_reshape_state(),
        "anomalies": anomaly_snapshot(),
        "temporary_reshapes": temporary_reshapes.duplicate(true),
        "original_owner_id": original_owner_id,
        "temporary_card": temporary_card,
    }
