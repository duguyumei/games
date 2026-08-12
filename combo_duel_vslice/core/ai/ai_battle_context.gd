class_name AiBattleContext
extends RefCounted

const VERSION := 3

var battle_id: String = ""
var rules_version: String = ""
var content_version: int = 0
var content_fingerprint: String = ""
var ai_protocol_version: int = 0
var prompt_version: int = 0
var player_build: Dictionary = {}
var enemy_build: Dictionary = {}
var content_semantics: Dictionary = {}
var visibility: Dictionary = {}
var protocol: Dictionary = {}

func configure(values: Dictionary):
    battle_id = str(values.get("battle_id", ""))
    rules_version = str(values.get("rules_version", ""))
    content_version = int(values.get("content_version", 0))
    content_fingerprint = str(values.get("content_fingerprint", ""))
    ai_protocol_version = int(values.get("ai_protocol_version", 0))
    prompt_version = int(values.get("prompt_version", 0))
    player_build = values.get("player_build", {}).duplicate(true)
    enemy_build = values.get("enemy_build", {}).duplicate(true)
    content_semantics = values.get("content_semantics", {}).duplicate(true)
    visibility = values.get("visibility", {}).duplicate(true)
    protocol = values.get("protocol", {}).duplicate(true)
    return self

func is_valid() -> bool:
    return battle_id != "" and rules_version != "" \
        and content_version > 0 and content_fingerprint != "" \
        and ai_protocol_version == 3 and prompt_version == 3

func snapshot() -> Dictionary:
    return {
        "schema_version": VERSION,
        "battle_id": battle_id,
        "rules_version": rules_version,
        "content_version": content_version,
        "content_fingerprint": content_fingerprint,
        "ai_protocol_version": ai_protocol_version,
        "prompt_version": prompt_version,
        "player_build": player_build.duplicate(true),
        "enemy_build": enemy_build.duplicate(true),
        "content_semantics": content_semantics.duplicate(true),
        "visibility": visibility.duplicate(true),
        "protocol": protocol.duplicate(true),
    }
