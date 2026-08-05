class_name AiBattleContext
extends RefCounted

const VERSION := 1

var battle_id: String = ""
var rules_version: String = ""
var player_build: Dictionary = {}
var enemy_build: Dictionary = {}
var visibility: Dictionary = {}
var protocol: Dictionary = {}

func configure(values: Dictionary):
    battle_id = str(values.get("battle_id", ""))
    rules_version = str(values.get("rules_version", ""))
    player_build = values.get("player_build", {}).duplicate(true)
    enemy_build = values.get("enemy_build", {}).duplicate(true)
    visibility = values.get("visibility", {}).duplicate(true)
    protocol = values.get("protocol", {}).duplicate(true)
    return self

func is_valid() -> bool:
    return battle_id != "" and rules_version != ""

func snapshot() -> Dictionary:
    return {
        "schema_version": VERSION,
        "battle_id": battle_id,
        "rules_version": rules_version,
        "player_build": player_build.duplicate(true),
        "enemy_build": enemy_build.duplicate(true),
        "visibility": visibility.duplicate(true),
        "protocol": protocol.duplicate(true),
    }
