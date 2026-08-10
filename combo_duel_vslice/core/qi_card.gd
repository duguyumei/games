class_name QiCard
extends RefCounted

const CardReshapeRuleServiceScript = preload(
    "res://core/card_reshapes/card_reshape_rule_service.gd")

const ANOMALY_CATEGORIES := ["mark", "poison", "state", "other"]

var id: String
var definition_id: String
var rank_name: String
var rank_order: int
var qi_value: int
var attribute: String
var attribute_name: String

var reshape_enhancement: String = ""
var reshape_finish: String = ""
var reshape_imprint: String = ""
var reshape_others: Dictionary = {}

var anomaly_poison: String = ""
var anomaly_state: String = ""
var anomaly_marks: Dictionary = {}
var anomaly_others: Dictionary = {}

var suppressed_reshapes: Dictionary = {}
var original_owner_id: String = ""
var temporary_card: bool = false
var reshape_rule_service

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
    return "%s·%s" % [attribute_name, rank_name]

func is_attribute(attribute_id: String) -> bool:
    if attribute == attribute_id:
        return true
    var rules = _reshape_rules()
    if rules.matches_attribute(self, attribute_id):
        return true
    for payload_value in anomaly_marks.values():
        var payload: Dictionary = payload_value
        if payload.get("attribute_aliases", []).has(attribute_id):
            return true
    return false

func set_enhancement(enhancement_id: String) -> void:
    suppressed_reshapes.erase("enhancement")
    reshape_enhancement = enhancement_id
    _reshape_rules().apply_reshape(self, "enhancement", enhancement_id)

func set_finish(finish_id: String) -> void:
    suppressed_reshapes.erase("finish")
    reshape_finish = finish_id
    _reshape_rules().apply_reshape(self, "finish", finish_id)

func set_imprint(imprint_id: String) -> void:
    suppressed_reshapes.erase("imprint")
    reshape_imprint = imprint_id
    _reshape_rules().apply_reshape(self, "imprint", imprint_id)

func set_other_reshape(reshape_id: String, payload: Dictionary = {}) -> bool:
    if reshape_id == "":
        return false
    var suppressed_others: Dictionary = suppressed_reshapes.get("others", {})
    suppressed_others.erase(reshape_id)
    if suppressed_others.is_empty():
        suppressed_reshapes.erase("others")
    else:
        suppressed_reshapes["others"] = suppressed_others
    reshape_others[reshape_id] = payload.duplicate(true)
    var result: Dictionary = _reshape_rules().apply_reshape(self, "other", reshape_id, payload)
    if not bool(result.get("success", false)):
        reshape_others.erase(reshape_id)
        return false
    return true

func remove_other_reshape(reshape_id: String) -> Dictionary:
    var previous: Dictionary = reshape_others.get(reshape_id, {}).duplicate(true)
    reshape_others.erase(reshape_id)
    var suppressed_others: Dictionary = suppressed_reshapes.get("others", {})
    if previous.is_empty() and suppressed_others.has(reshape_id):
        previous = suppressed_others[reshape_id].duplicate(true)
    suppressed_others.erase(reshape_id)
    if suppressed_others.is_empty():
        suppressed_reshapes.erase("others")
    else:
        suppressed_reshapes["others"] = suppressed_others
    return previous

func set_anomaly(category: String, anomaly_id: String, payload: Dictionary = {}) -> bool:
    if not ANOMALY_CATEGORIES.has(category) or anomaly_id == "":
        return false
    var anomaly_check: Dictionary = _reshape_rules().can_apply_anomaly(self)
    if not bool(anomaly_check.get("allowed", true)):
        return false
    match category:
        "poison": anomaly_poison = anomaly_id
        "state": anomaly_state = anomaly_id
        "mark": anomaly_marks[anomaly_id] = payload.duplicate(true)
        "other": anomaly_others[anomaly_id] = payload.duplicate(true)
    return true

func configure_reshape_rule_service(service) -> void:
    reshape_rule_service = service

func effective_qi_value(include_contribution: bool = false) -> int:
    var value: int = int(_reshape_rules().effective_qi_value(self))
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
    return _reshape_rules().has_card_kind(self, kind)

func can_apply_anomaly() -> Dictionary:
    return _reshape_rules().can_apply_anomaly(self)

func _reshape_rules():
    if reshape_rule_service == null:
        reshape_rule_service = CardReshapeRuleServiceScript.fallback()
    return reshape_rule_service

func has_anomaly(category: String, anomaly_id: String = "") -> bool:
    match category:
        "poison": return anomaly_poison != "" and (anomaly_id == "" or anomaly_poison == anomaly_id)
        "state": return anomaly_state != "" and (anomaly_id == "" or anomaly_state == anomaly_id)
        "mark": return not anomaly_marks.is_empty() if anomaly_id == "" else anomaly_marks.has(anomaly_id)
        "other": return not anomaly_others.is_empty() if anomaly_id == "" else anomaly_others.has(anomaly_id)
    return false

func remove_anomaly(category: String, anomaly_id: String = ""):
    match category:
        "poison":
            var previous_poison := anomaly_poison
            if anomaly_id == "" or anomaly_poison == anomaly_id:
                anomaly_poison = ""
            return previous_poison
        "state":
            var previous_state := anomaly_state
            if anomaly_id == "" or anomaly_state == anomaly_id:
                anomaly_state = ""
            return previous_state
        "mark":
            if anomaly_id == "":
                var previous_marks := anomaly_marks.duplicate(true)
                anomaly_marks.clear()
                return previous_marks
            var previous_mark: Dictionary = anomaly_marks.get(anomaly_id, {}).duplicate(true)
            anomaly_marks.erase(anomaly_id)
            return previous_mark
        "other":
            if anomaly_id == "":
                var previous_others := anomaly_others.duplicate(true)
                anomaly_others.clear()
                return previous_others
            var previous_other: Dictionary = anomaly_others.get(anomaly_id, {}).duplicate(true)
            anomaly_others.erase(anomaly_id)
            return previous_other
    return null

func anomaly_snapshot() -> Dictionary:
    return {
        "poison": anomaly_poison,
        "state": anomaly_state,
        "marks": anomaly_marks.duplicate(true),
        "others": anomaly_others.duplicate(true),
    }

func clear_anomalies() -> Dictionary:
    var removed := anomaly_snapshot()
    anomaly_poison = ""
    anomaly_state = ""
    anomaly_marks.clear()
    anomaly_others.clear()
    return removed

func clear_combat_state() -> void:
    restore_suppressed_reshapes()
    clear_anomalies()

func suppress_existing_reshapes_and_clear_anomalies() -> Dictionary:
    if not suppressed_reshapes.is_empty():
        return {"reshapes": {}, "anomalies": {}}
    var removed_reshapes := active_reshape_state()
    suppressed_reshapes = {}
    if reshape_enhancement != "":
        suppressed_reshapes["enhancement"] = reshape_enhancement
    if reshape_finish != "":
        suppressed_reshapes["finish"] = reshape_finish
    if reshape_imprint != "":
        suppressed_reshapes["imprint"] = reshape_imprint
    if not reshape_others.is_empty():
        suppressed_reshapes["others"] = reshape_others.duplicate(true)
    reshape_enhancement = ""
    reshape_finish = ""
    reshape_imprint = ""
    reshape_others.clear()
    return {"reshapes": removed_reshapes, "anomalies": clear_anomalies()}

func restore_suppressed_reshapes() -> Dictionary:
    var restored := {"enhancement": "", "finish": "", "imprint": "", "others": {}}
    if reshape_enhancement == "" and suppressed_reshapes.has("enhancement"):
        reshape_enhancement = str(suppressed_reshapes["enhancement"])
        restored["enhancement"] = reshape_enhancement
    if reshape_finish == "" and suppressed_reshapes.has("finish"):
        reshape_finish = str(suppressed_reshapes["finish"])
        restored["finish"] = reshape_finish
    if reshape_imprint == "" and suppressed_reshapes.has("imprint"):
        reshape_imprint = str(suppressed_reshapes["imprint"])
        restored["imprint"] = reshape_imprint
    var suppressed_others: Dictionary = suppressed_reshapes.get("others", {})
    for reshape_id in suppressed_others:
        if not reshape_others.has(reshape_id):
            reshape_others[reshape_id] = suppressed_others[reshape_id].duplicate(true)
            restored["others"][reshape_id] = suppressed_others[reshape_id].duplicate(true)
    suppressed_reshapes.clear()
    return restored

func active_reshape_state() -> Dictionary:
    return {
        "enhancement": reshape_enhancement,
        "finish": reshape_finish,
        "imprint": reshape_imprint,
        "others": reshape_others.duplicate(true),
    }

func persistent_reshape_state() -> Dictionary:
    var values := {
        "enhancement": str(suppressed_reshapes.get("enhancement", "")),
        "finish": str(suppressed_reshapes.get("finish", "")),
        "imprint": str(suppressed_reshapes.get("imprint", "")),
        "others": suppressed_reshapes.get("others", {}).duplicate(true),
    }
    if reshape_enhancement != "":
        values["enhancement"] = reshape_enhancement
    if reshape_finish != "":
        values["finish"] = reshape_finish
    if reshape_imprint != "":
        values["imprint"] = reshape_imprint
    for reshape_id in reshape_others:
        values["others"][reshape_id] = reshape_others[reshape_id].duplicate(true)
    return values

func to_dict() -> Dictionary:
    return {
        "id": id,
        "instance_id": id,
        "definition_id": definition_id,
        "rank_name": rank_name,
        "rank_order": rank_order,
        "qi_value": qi_value,
        "attribute": attribute,
        "attribute_name": attribute_name,
        "reshapes": active_reshape_state(),
        "anomalies": anomaly_snapshot(),
        "suppressed_reshapes": suppressed_reshapes.duplicate(true),
        "original_owner_id": original_owner_id,
        "temporary_card": temporary_card,
    }
