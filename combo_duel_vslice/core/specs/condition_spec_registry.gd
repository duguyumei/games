class_name ConditionSpecRegistry
extends RefCounted

const CONDITION_FIELDS := [
    "all", "any", "not", "pure_attribute", "capture_nonempty",
    "capture_empty", "hand_id", "exact_hand_id", "capture_count_equals",
    "capture_count_at_least", "capture_all_attribute", "capture_any_anomaly",
    "same_qi", "action_same_qi_attribute", "action_is_extra",
    "action_from_same_qi", "group_snapshot_flag", "group_played_count",
    "group_has_common_attribute", "contributing_has_common_attribute",
    "contributing_has_no_common_attribute", "base_attribute_count_at_least",
    "capture_result_life_lost", "capture_card_effective_above_base",
    "capture_card_in_zone", "initial_power_greater_than_group_base_qi",
    "actor_defense_equals", "actor_hand_less_than_target", "actor_alive",
    "value_at_least", "value_at_most", "value_greater_than",
    "action_has_cooperation", "group_all_active_any_reshape",
    "hand_differs_from_previous_success", "hand_stronger_than_opposing",
    "opposing_has_normal_attack",
]

const EVENT_FIELDS := [
    "event_actor_is_owner", "event_actor_is_opponent",
    "event_target_is_owner", "source_kind", "source_kind_in",
    "draw_reason", "damage_type", "hand_id", "technique_power",
    "requested_amount", "final_amount", "effective_amount",
    "defense_lost", "life_lost", "actual_life_loss", "frozen_amount",
    "defense_before", "defense_after", "reason", "from_zone", "to_zone",
    "explicit_discard", "normal_play", "technique_triggered",
    "action_succeeded", "holder_is_actor", "attacker_is_actor",
    "attacker_is_target", "defender_is_actor", "defense_lost_positive",
    "actual_life_loss_positive", "life_lost_equals", "defense_after_equals",
    "same_qi_gain_at_least", "is_extra_action", "became_burned_out",
    "had_burned_out", "action_token_is_record", "owner", "holder",
    "max_triggers", "card_instance_ids", "source_card_instance_ids",
    "source_tokens", "next_round", "source_category",
    "conversion_count_at_least", "from_same_qi", "challenge_met",
    "challenge_difference_at_least", "same_action_window", "had_poison",
    "block_damage_at_most_defense", "block_defender_hand_more_than_attacker",
    "card_instance_ids_from_capture", "source_card_instance_ids_from_capture",
    "source_tokens_from_capture",
]

func condition_fields() -> Array[String]:
    return CONDITION_FIELDS.duplicate()

func event_fields() -> Array[String]:
    return EVENT_FIELDS.duplicate()

func validate_condition(condition: Dictionary, report_error: Callable, scope: String) -> bool:
    return _validate_keys(condition, CONDITION_FIELDS, report_error, scope, true)

func validate_event_filters(filters: Dictionary, report_error: Callable, scope: String) -> bool:
    return _validate_keys(filters, EVENT_FIELDS, report_error, scope, false)

func evaluate(condition: Dictionary, context, evaluator: Callable) -> bool:
    if not _keys_known(condition, CONDITION_FIELDS, true):
        return false
    return bool(evaluator.call(condition, context))

func event_matches(filters: Dictionary, values: Dictionary, owner, opponent = null,
        record: Dictionary = {}) -> bool:
    if not _keys_known(filters, EVENT_FIELDS, false):
        return false
    var actor = values.get("actor")
    var target = values.get("target")
    var metadata: Dictionary = values.get("metadata", {})
    for field_value in filters:
        var field := str(field_value)
        var expected = filters[field]
        var actual = _event_value(field, values, metadata, owner, opponent, record)
        if field in ["max_triggers"]:
            continue
        if field == "source_kind_in":
            if not expected is Array or not expected.has(str(actual)):
                return false
        elif field in ["same_qi_gain_at_least", "conversion_count_at_least",
                "challenge_difference_at_least"]:
            if int(actual) < int(expected):
                return false
        elif field in ["card_instance_ids", "source_card_instance_ids",
                "source_tokens"]:
            if not expected is Array or not expected.has(str(actual)):
                return false
        elif field == "owner":
            if str(expected) == "actor" and values.get("actor") != record.get("actor", owner):
                return false
        elif field == "holder":
            if str(expected) == "target" and values.get("holder") != record.get("target", opponent):
                return false
        elif expected is Array:
            if not expected.has(actual):
                return false
        elif actual != expected:
            return false
    return true

func _event_value(field: String, values: Dictionary, metadata: Dictionary,
        owner, opponent, record: Dictionary):
    match field:
        "event_actor_is_owner": return values.get("actor") == owner
        "event_actor_is_opponent": return values.get("actor") == opponent
        "event_target_is_owner": return values.get("target") == owner
        "holder_is_actor": return values.get("holder") == record.get("actor", owner)
        "attacker_is_actor": return values.get("attacker") == record.get("actor", owner)
        "attacker_is_target": return values.get("attacker") == record.get("target", opponent)
        "defender_is_actor": return values.get("defender") == record.get("actor", owner)
        "defense_lost_positive": return int(values.get("defense_lost", 0)) > 0
        "actual_life_loss_positive": return int(values.get("actual_life_loss", values.get("life_lost", 0))) > 0
        "life_lost_equals": return int(values.get("life_lost", 0))
        "defense_after_equals": return int(values.get("defense_after", 0))
        "same_qi_gain_at_least": return int(values.get(
            "same_qi_gain", values.get("gained", values.get(
                "actual_gain", values.get("effective_amount", 0)))))
        "conversion_count_at_least": return int(values.get(
            "conversion_count", values.get("same_qi_trigger_count", 0)))
        "challenge_difference_at_least": return int(values.get(
            "difference", values.get("payload", {}).get("difference", 0)))
        "action_token_is_record": return str(values.get("action_token", "")) == str(record.get("action_token", ""))
        "owner":
            if str(record.get("owner", "")) == "actor":
                return values.get("actor") == record.get("actor")
            return values.get("owner")
        "holder":
            if str(record.get("holder", "")) == "target":
                return values.get("holder") == record.get("target")
            return values.get("holder")
        "source_kind_in": return str(values.get("source_kind", metadata.get("source_kind", "")))
        "is_extra_action": return bool(values.get("is_extra_action", metadata.get("is_extra_action", false)))
        "from_same_qi": return bool(values.get("from_same_qi", false))
        "became_burned_out": return bool(values.get("became_burned_out", false))
        "had_burned_out": return bool(values.get(
            "had_burned_out", values.get(
                "pre_move_snapshot", {}).get("had_burned_out", false)))
        "had_poison": return bool(values.get(
            "pre_move_snapshot", {}).get("had_poison", false))
        "challenge_met": return bool(values.get(
            "challenge_met", values.get("payload", {}).get("met", false)))
        "same_action_window": return values.get("action_tokens", []).has(
            str(record.get("action_token", "")))
        "block_damage_at_most_defense": return int(values.get("amount", 0)) \
            <= int(values.get("defense", 0))
        "block_defender_hand_more_than_attacker": return int(
            values.get("defender_hand_count", -1)) > int(
                values.get("attacker_hand_count", -1))
        "next_round": return int(values.get("round_number", -1)) == int(record.get("source_round", -2)) + 1
        "card_instance_ids", "source_card_instance_ids":
            return str(values.get("source_card_instance_id", values.get("card_instance_id", "")))
        "source_tokens": return str(values.get("source_token", ""))
    return values.get(field, metadata.get(field))

func _validate_keys(value: Dictionary, allowed: Array, report_error: Callable,
        scope: String, recurse: bool) -> bool:
    var valid := true
    for field_value in value:
        var field := str(field_value)
        if field not in allowed:
            report_error.call(scope + "." + field, "未知条件字段")
            valid = false
    if recurse:
        for list_field in ["all", "any"]:
            if value.get(list_field) is Array:
                for index in range(value[list_field].size()):
                    if value[list_field][index] is Dictionary:
                        valid = _validate_keys(value[list_field][index], allowed,
                            report_error, "%s.%s[%d]" % [scope, list_field, index], true) and valid
        if value.get("not") is Dictionary:
            valid = _validate_keys(value["not"], allowed, report_error,
                scope + ".not", true) and valid
    return valid

func _keys_known(value: Dictionary, allowed: Array, recurse: bool) -> bool:
    for field in value:
        if str(field) not in allowed:
            return false
    if recurse:
        for list_field in ["all", "any"]:
            for child in value.get(list_field, []):
                if child is Dictionary and not _keys_known(child, allowed, true):
                    return false
        if value.get("not") is Dictionary and not _keys_known(value["not"], allowed, true):
            return false
    return true
