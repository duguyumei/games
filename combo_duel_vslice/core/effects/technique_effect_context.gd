class_name TechniqueEffectContext
extends RefCounted

const SCRIPT_PATH := "res://core/effects/technique_effect_context.gd"

var actor = null
var target = null
var hand_result: Dictionary = {}
var played_cards: Array = []
var power: int = 0
var initial_power: int = 0
var direct_power_fixed: int = 0
var direct_power_percent: int = 0
var pre_momentum_power: int = 0
var momentum_used: int = 0
var technique_id: String = ""
var technique_name: String = ""
var actual_hand_id: String = ""
var branch_hand_id: String = ""
var technique_pool: String = ""
var action_token: String = ""
var source_kind: String = ""
var captures: Dictionary = {}
var ports = null
var choice_responses: Dictionary = {}
var choice_candidates: Dictionary = {}
var sequence_book = null
var source_card = null
var source_card_instance_id: String = ""
var source_trigger: String = ""
var replay_depth: int = 0
var card_identity_policy = null
var group_snapshot: Dictionary = {}

func configure(values: Dictionary):
    actor = values.get("actor")
    target = values.get("target")
    hand_result = values.get("hand_result", {})
    played_cards = values.get("played_cards", [])
    var power_values: Dictionary = values.get("values", {})
    power = int(values.get(
        "power", power_values.get("technique_value", 0)))
    initial_power = int(values.get(
        "initial_power", power_values.get("initial_power", power)))
    direct_power_fixed = int(values.get(
        "direct_power_fixed", power_values.get("direct_power_fixed", 0)))
    direct_power_percent = int(values.get(
        "direct_power_percent", power_values.get("direct_power_percent", 0)))
    pre_momentum_power = int(values.get(
        "pre_momentum_power", power_values.get("pre_momentum_power", power)))
    momentum_used = int(values.get(
        "momentum_used", power_values.get("momentum_used", 0)))
    technique_id = str(values.get("technique_id", ""))
    technique_name = str(values.get("technique_name", ""))
    actual_hand_id = str(values.get(
        "actual_hand_id", hand_result.get("id", "")))
    if actual_hand_id == "":
        actual_hand_id = str(hand_result.get("id", ""))
    technique_pool = str(values.get("technique_pool", ""))
    branch_hand_id = str(values.get("branch_hand_id", ""))
    if branch_hand_id == "":
        branch_hand_id = _default_branch_hand_id(actual_hand_id, technique_pool)
    action_token = str(values.get("action_token", ""))
    source_kind = str(values.get("source_kind", ""))
    captures = values.get("captures", {})
    ports = values.get("ports")
    choice_responses = values.get("choice_responses", {})
    choice_candidates = values.get("choice_candidates", {})
    sequence_book = values.get("sequence_book")
    source_card = values.get("source_card")
    source_card_instance_id = str(values.get("source_card_instance_id", ""))
    source_trigger = str(values.get("source_trigger", ""))
    replay_depth = int(values.get("replay_depth", 0))
    card_identity_policy = values.get("card_identity_policy")
    group_snapshot = values.get("group_snapshot", {})
    # 旧测试字典仍可传 engine，但上下文只保存它已经装配好的窄效果端口。
    if ports == null and values.get("engine") != null:
        ports = values["engine"].action_resolver.effect_ports
    return self

static func _default_branch_hand_id(actual_hand: String, pool_id: String) -> String:
    if actual_hand != "full_house":
        return actual_hand
    match pool_id:
        "pair":
            return "pair"
        "three":
            return "three_kind"
    return actual_hand

func choice_request_id(choice_id: String) -> String:
    var prefix := action_token
    if prefix == "":
        prefix = technique_id if technique_id != "" else "effect"
    return "%s:%s" % [prefix, choice_id]

static func coerce(value):
    var script = load(SCRIPT_PATH)
    if value is Object and value.get_script() == script:
        return value
    if value is Dictionary:
        return script.new().configure(value)
    return script.new()

func public_metadata() -> Dictionary:
    return {
        "power": power,
        "initial_power": initial_power,
        "direct_power_fixed": direct_power_fixed,
        "direct_power_percent": direct_power_percent,
        "pre_momentum_power": pre_momentum_power,
        "momentum_used": momentum_used,
        "technique_id": technique_id,
        "technique_name": technique_name,
        "actual_hand_id": actual_hand_id,
        "branch_hand_id": branch_hand_id,
        "technique_pool": technique_pool,
        "action_token": action_token,
        "source_kind": source_kind,
        "source_card_instance_id": source_card_instance_id,
        "source_trigger": source_trigger,
        "replay_depth": replay_depth,
        "hand_id": str(hand_result.get("id", "")),
        "played_card_count": played_cards.size(),
        "capture_keys": captures.keys(),
        "has_ports": ports != null,
        "waiting_choice_count": choice_candidates.size(),
    }

func power_snapshot() -> Dictionary:
    return {
        "initial_power": initial_power,
        "direct_power_fixed": direct_power_fixed,
        "direct_power_percent": direct_power_percent,
        "pre_momentum_power": pre_momentum_power,
        "momentum_used": momentum_used,
        "group_snapshot": group_snapshot,
        "technique_value": power,
    }
