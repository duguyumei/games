extends SceneTree

const BattleHudScript = preload("res://ui/components/battle_hud.gd")
const MapperScript = preload("res://ui/battle_ui_mapper.gd")
const SnapshotScript = preload("res://core/battle_snapshot.gd")
const SideSnapshotScript = preload("res://core/battle_side_snapshot.gd")

var _failures: Array[String] = []
var _assertions := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1280, 720)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var hud = BattleHudScript.new()
    viewport.add_child(hud)
    await process_frame
    await process_frame

    hud.configure_mode(false)
    _assert_true(not hud.debug_drawer_enabled(), "production 模式不装配可见调试抽屉")
    hud.toggle_debug_drawer()
    _assert_true(not hud.debug_drawer_is_open(), "production 模式不能打开调试抽屉")
    hud.configure_mode(true)
    hud.toggle_debug_drawer()
    _assert_true(hud.debug_drawer_is_open(), "test/debug 模式可以打开调试抽屉")
    hud.toggle_debug_drawer()

    for count in range(1, 6):
        var intents: Array = []
        for index in range(count):
            intents.append({
                "display_name": "意图 %d" % index,
                "direction": "assault",
                "damage": index,
                "defense": 0,
                "same_qi_gain": 0,
                "played_count": index + 1,
            })
        hud.intent_panel().present(intents)
        _assert_equal(hud.intent_panel().candidate_count(), count,
            "敌方 %d 个意图均进入候选布局" % count)

    _assert_true(not hud.side_drawer_is_open(), "构筑侧栏默认收起")
    hud.toggle_side_drawer()
    _assert_true(hud.side_drawer_is_open(), "构筑侧栏可以展开")
    hud.toggle_side_drawer()
    _assert_true(not hud.side_drawer_is_open(), "构筑侧栏可以恢复收起")

    var snapshot = _snapshot_fixture()
    var before := JSON.stringify(snapshot.to_dict())
    var mapped: Dictionary = MapperScript.map(snapshot, {"selected_ids": []})
    var after := JSON.stringify(snapshot.to_dict())
    _assert_equal(after, before, "UI mapper 刷新不改变战斗快照")
    _assert_true(mapped.has("debug_info") and mapped.has("available_commands"),
        "UI 展示模型包含调试信息和公开命令能力")
    mapped["player"]["items"] = [""]
    mapped["player"]["inner_skills"] = [{}]
    hud.present(mapped)
    await process_frame
    _assert_true(hud.is_inside_tree(), "缺少可选图标时使用问号占位且不崩溃")

    var action_rect := hud.main_action_rect()
    _assert_true(action_rect.position.x >= 0.0 and action_rect.position.y >= 0.0,
        "1280×720 主操作区起点在可视范围")
    _assert_true(action_rect.end.x <= 1280.5 and action_rect.end.y <= 720.5,
        "1280×720 主操作区完整处于可视范围：%s" % str(action_rect))

    viewport.queue_free()
    if _failures.is_empty():
        print("UI COMPONENTS PASS: %d assertions" % _assertions)
        quit(0)
        return
    for failure in _failures:
        push_error("UI COMPONENTS FAIL: %s" % failure)
    quit(1)

func _snapshot_fixture():
    var player = SideSnapshotScript.new()
    player.name = "太吾"
    player.life = 82
    player.max_life = 100
    player.defense = 18
    player.hand_limit = 8
    player.inner_skill_limit = 6
    player.consumable_limit = 3
    player.technique_sequences = {}
    player.technique_slot_usage = {}
    var enemy = SideSnapshotScript.new()
    enemy.name = "太吾宿敌"
    enemy.life = 68
    enemy.max_life = 100
    enemy.defense = 12
    enemy.hand_limit = 8
    enemy.inner_skill_limit = 6
    enemy.technique_sequences = {}
    enemy.technique_slot_usage = {}
    var snapshot = SnapshotScript.new()
    snapshot.battle_state = "active"
    snapshot.battle_state_detail = "战斗中"
    snapshot.turn_number = 6
    snapshot.actions_available = 2
    snapshot.enemy_actions_available = 2
    snapshot.player = player
    snapshot.enemy = enemy
    snapshot.possible_enemy_intents = [{
        "display_name": "试探", "direction": "prepare",
        "damage": 0, "defense": 4, "same_qi_gain": 1, "played_count": 1,
    }]
    return snapshot

func _assert_true(value: bool, message: String) -> void:
    _assertions += 1
    if not value:
        _failures.append(message)

func _assert_equal(actual, expected, message: String) -> void:
    _assertions += 1
    if actual != expected:
        _failures.append("%s（实际 %s，期望 %s）" % [message, str(actual), str(expected)])
