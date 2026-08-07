class_name BattleSessionFactory
extends RefCounted

const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")

var game_log
var content_catalog
var runtime_profile

func _init(
        game_log_override = null,
        content_catalog_override = null,
        runtime_profile_override = null) -> void:
    game_log = game_log_override
    content_catalog = content_catalog_override
    runtime_profile = (
        runtime_profile_override
        if runtime_profile_override != null
        else RuntimeProfileScript.current())

func create():
    return BattleSessionScript.new(
        CombatEngineScript.new(game_log, content_catalog),
        runtime_profile)
