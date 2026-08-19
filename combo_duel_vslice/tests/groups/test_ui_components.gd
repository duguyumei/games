extends SceneTree

const BattleHudScene = preload("res://ui/components/battle_hud.tscn")
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
    var hud = BattleHudScene.instantiate()
    viewport.add_child(hud)
    await process_frame
    await process_frame

    hud.configure_mode(false)
    _assert_true(hud.get_node_or_null("BattleDebugDrawer") == null,
        "production 不实例化 BattleDebugDrawer")
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
    var production_mapped: Dictionary = MapperScript.map(snapshot, {
        "selected_ids": [], "include_debug": false})
    _assert_true(not production_mapped.has("debug_info"),
        "production Mapper 不包含 raw_state/debug_info")
    mapped["player"]["items"] = [""]
    mapped["player"]["inner_skills"] = [{}]
    hud.present(mapped)
    await process_frame
    _assert_true(hud.is_inside_tree(), "缺少可选图标时使用问号占位且不崩溃")

    var hand_data: Dictionary = mapped["player"].duplicate(true)
    hand_data["hand"] = [{"id": "stable-card-1", "rank_name": "一", "attribute": "wind", "attribute_name": "风", "qi_value": 2}]
    hud.present(mapped.merged({"player": hand_data}, true))
    await process_frame
    var hand_view = hud.get_node("FormalBattleLayout/BottomPlayerRegion/PlayerHandZone")
    var first_card = hand_view.card_node_for_id("stable-card-1")
    hud.present(mapped.merged({"player": hand_data, "selection": {"ids": ["stable-card-1"]}}, true))
    await process_frame
    var second_card = hand_view.card_node_for_id("stable-card-1")
    _assert_true(first_card == second_card, "同一手牌连续刷新保持节点 identity")

    var presentation_probe := Label.new()
    presentation_probe.name = "PresentationProbe"
    hud.presentation_layers()["card_motion_layer"].add_child(presentation_probe)
    hud.present(mapped.merged({"player": hand_data}, true))
    await process_frame
    _assert_true(is_instance_valid(presentation_probe) and presentation_probe.is_inside_tree(),
        "普通刷新不清理正在执行的表现节点")

    var tooltip = hud.get_node("BattleTooltip")
    tooltip.show_contract({"title": "长名称详情", "description": "说明", "placeholder": "?"},
        Rect2(Vector2(1270, 710), Vector2(20, 20)), Vector2(1280, 720))
    await create_timer(0.2).timeout
    _assert_true(tooltip.visible, "Tooltip 延迟后显示")
    _assert_true(tooltip.get_global_rect().end.x <= 1280.5 and tooltip.get_global_rect().end.y <= 720.5,
        "Tooltip 自动限制在视口范围内")
    tooltip.hide_detail()
    _assert_true(not tooltip.visible, "Tooltip 移出后隐藏")

    hud.toggle_side_drawer()
    hud.toggle_side_drawer()
    hud.toggle_side_drawer()
    _assert_true(hud.side_drawer_is_open(), "快速重复切换抽屉以后一次操作为准")
    hud.toggle_side_drawer()

    for resolution in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]:
        viewport.size = resolution
        await process_frame
        await process_frame
        var action_rect: Rect2 = hud.main_action_rect()
        _assert_true(
            action_rect.position.x >= 0.0 and action_rect.position.y >= 0.0
            and action_rect.end.x <= resolution.x + 0.5
            and action_rect.end.y <= resolution.y + 0.5,
            "%s 主操作区完整处于可视范围：%s" % [str(resolution), str(action_rect)])
        var rects: Dictionary = hud.layout_rects()
        _assert_true(rects["top"].end.y <= rects["middle"].position.y + 0.5,
            "%s 顶部与中央区域不相交" % str(resolution))
        _assert_true(rects["middle"].end.y <= rects["bottom"].position.y + 0.5,
            "%s 中央与底部区域不相交" % str(resolution))
        _assert_true(not rects["hand"].intersects(rects["actions"]),
            "%s 手牌区域与操作区不相交" % str(resolution))
        for side_name in ["player_side", "enemy_side"]:
            var side_rect: Rect2 = rects[side_name]
            _assert_true(side_rect.position.x >= -0.5 and side_rect.end.x <= resolution.x + 0.5,
                "%s %s 处于视口内" % [str(resolution), side_name])

    var layers: Dictionary = hud.presentation_layers()
    for layer_name in ["card_motion_layer", "combat_vfx_layer", "floating_text_layer", "technique_banner_layer"]:
        _assert_equal(layers[layer_name].mouse_filter, Control.MOUSE_FILTER_IGNORE,
            "%s 允许鼠标穿透" % layer_name)
    _assert_equal(layers["modal_layer"].mouse_filter, Control.MOUSE_FILTER_STOP,
        "modal_layer 可以阻挡交互")

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
