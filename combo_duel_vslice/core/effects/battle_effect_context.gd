class_name BattleEffectContext
extends RefCounted

const SCRIPT_PATH := "res://core/effects/battle_effect_context.gd"
const EffectSourceProtocolScript = preload(
    "res://core/effects/effect_source_protocol.gd")

## 来源中立的战斗效果运行上下文。
##
## 功法专属数值继续作为可选字段存在，但所有效果来源只读取统一 source_* 协议。

var actor = null
var target = null
var owner = null
var opponent = null
var hand_result: Dictionary = {}
var played_cards: Array = []
var power: int = 0
var initial_power: int = 0
var direct_power_fixed: int = 0
var direct_power_percent: int = 0
var pre_momentum_power: int = 0
var momentum_used: int = 0
## 仅供旧功法调用方兼容；新代码不得用它判断来源。
var technique_id: String = ""
var technique_name: String = ""
var actual_hand_id: String = ""
var branch_hand_id: String = ""
var technique_pool: String = ""
var action_token: String = ""
var event_token: String = ""
var root_action_token: String = ""
var invocation_token: String = ""
var caller_technique_id: String = ""
var slot_instance_id: String = ""
var trigger_mode: String = "manual"
var source_kind: String = ""
var source_id: String = ""
var source_name: String = ""
var source_instance_key: String = ""
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
var consumed_marker_value: int = 0
## 仅被动标准效果设置；0 表示不限制普通功法链。
var effect_command_limit: int = 0
var effect_chain_state: Dictionary = {}

func configure(values: Dictionary):
    actor = values.get("actor", values.get("owner"))
    target = values.get("target")
    owner = values.get("owner", actor)
    opponent = values.get("opponent")
    if opponent == null and owner != null:
        if target != null and target != owner:
            opponent = target
        elif actor != null and actor != owner:
            opponent = actor
    hand_result = values.get("hand_result", {})
    played_cards = values.get("played_cards", [])
    var power_values: Dictionary = values.get("values", {})
    power = int(values.get("power", power_values.get("technique_value", 0)))
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
    event_token = str(values.get("event_token", ""))
    root_action_token = str(values.get("root_action_token", action_token))
    invocation_token = str(values.get("invocation_token", ""))
    caller_technique_id = str(values.get("caller_technique_id", ""))
    slot_instance_id = str(values.get("slot_instance_id", ""))
    var source: Dictionary = EffectSourceProtocolScript.from_values(values)
    trigger_mode = str(source["trigger_mode"])
    source_kind = str(source["source_kind"])
    source_id = str(source["source_id"])
    source_name = str(source["source_name"])
    source_instance_key = str(source["source_instance_key"])
    if source_kind == "technique":
        if technique_id == "":
            technique_id = source_id
        if technique_name == "":
            technique_name = source_name
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
    consumed_marker_value = int(values.get("consumed_marker_value", 0))
    effect_command_limit = int(values.get("effect_command_limit", 0))
    effect_chain_state = values.get("effect_chain_state", {})
    # 旧测试字典仍可传 engine，但上下文只保存它已经装配好的窄效果端口。
    if ports == null and values.get("engine") != null:
        ports = values["engine"].action_resolver.effect_ports
    return self

func resolve_side(scope: String):
    match scope:
        "actor": return actor
        "target": return target
        "owner": return owner
        "opponent": return opponent
    return null

static func _default_branch_hand_id(actual_hand: String, pool_id: String) -> String:
    if actual_hand != "full_house":
        return actual_hand
    match pool_id:
        "pair": return "pair"
        "three": return "three_kind"
    return actual_hand

func choice_request_id(choice_id: String) -> String:
    var prefix := action_token
    if prefix == "":
        prefix = source_id if source_id != "" else "effect"
    return "%s:%s" % [prefix, choice_id]

static func coerce(value):
    if value is BattleEffectContext:
        return value
    var script = load(SCRIPT_PATH)
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
        "event_token": event_token,
        "root_action_token": root_action_token,
        "invocation_token": invocation_token,
        "caller_technique_id": caller_technique_id,
        "slot_instance_id": slot_instance_id,
        "trigger_mode": trigger_mode,
        "source_kind": source_kind,
        "source_id": source_id,
        "source_name": source_name,
        "source_instance_key": source_instance_key,
        "source_card_instance_id": source_card_instance_id,
        "source_trigger": source_trigger,
        "replay_depth": replay_depth,
        "hand_id": str(hand_result.get("id", "")),
        "played_card_count": played_cards.size(),
        "capture_keys": captures.keys(),
        "has_ports": ports != null,
        "waiting_choice_count": choice_candidates.size(),
    }

func source_metadata() -> Dictionary:
    return {
        "source_kind": source_kind,
        "source_id": source_id,
        "source_name": source_name,
        "source_instance_key": source_instance_key,
        "trigger_mode": trigger_mode,
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
