class_name TechniqueEffectContext
extends RefCounted

const SCRIPT_PATH := "res://core/effects/technique_effect_context.gd"

var actor = null
var target = null
var hand_result: Dictionary = {}
var played_cards: Array = []
var power: int = 0
var technique_id: String = ""
var technique_name: String = ""
var action_token: String = ""
var source_kind: String = ""
var captures: Dictionary = {}
var ports = null
var choice_responses: Dictionary = {}
var choice_candidates: Dictionary = {}
var sequence_book = null

func configure(values: Dictionary):
    actor = values.get("actor")
    target = values.get("target")
    hand_result = values.get("hand_result", {})
    played_cards = values.get("played_cards", [])
    power = int(values.get("power", 0))
    technique_id = str(values.get("technique_id", ""))
    technique_name = str(values.get("technique_name", ""))
    action_token = str(values.get("action_token", ""))
    source_kind = str(values.get("source_kind", ""))
    captures = values.get("captures", {})
    ports = values.get("ports")
    choice_responses = values.get("choice_responses", {})
    choice_candidates = values.get("choice_candidates", {})
    sequence_book = values.get("sequence_book")
    # 旧测试字典仍可传 engine，但上下文只保存它已经装配好的窄效果端口。
    if ports == null and values.get("engine") != null:
        ports = values["engine"].action_resolver.effect_ports
    return self

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
        "technique_id": technique_id,
        "technique_name": technique_name,
        "action_token": action_token,
        "source_kind": source_kind,
        "hand_id": str(hand_result.get("id", "")),
        "played_card_count": played_cards.size(),
        "capture_keys": captures.keys(),
        "has_ports": ports != null,
        "waiting_choice_count": choice_candidates.size(),
    }
