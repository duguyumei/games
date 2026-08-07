class_name BattleSessionFactory
extends RefCounted

## 按组合根依赖创建战斗会话。
##
## 工厂只保证日志、内容目录和运行模式被一致注入，不建立战斗场景，也不保存
## 会话生命周期状态。

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

func create() -> BattleSession:
    return BattleSessionScript.new(
        CombatEngineScript.new(game_log, content_catalog),
        runtime_profile)
