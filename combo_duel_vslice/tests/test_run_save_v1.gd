extends SceneTree

const RunSessionScript = preload("res://core/run_session.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunSaveDataScript = preload("res://core/run_save_data.gd")
const SaveRepositoryScript = preload("res://core/save_repository.gd")
const MigrationRegistryScript = preload("res://core/run_save_migration_registry.gd")
const ApplicationServiceScript = preload("res://core/run_save_application_service.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const RunAutosaveCoordinatorScript = preload(
    "res://core/run_autosave_coordinator.gd")
const BattleFinalResultDTOScript = preload(
    "res://core/battle_final_result_dto.gd")
const RunProgressSnapshotScript = preload(
    "res://core/run_progress_snapshot.gd")
const RunScene = preload("res://ui/run_main.tscn")
const FrontScene = preload("res://ui/front_main.tscn")
const AutosaveStatusScript = preload(
    "res://ui/components/autosave_status.gd")

const SAVE_PATH := "/tmp/taiwu-run-save-v1-test.json"

var failures: Array[String] = []
var assertions: int = 0

class CountingSaveApplication:
    extends RefCounted

    var save_count: int = 0

    func execute(command: Dictionary) -> Dictionary:
        if str(command.get("type", "")) != "save_run":
            return {"success": false, "reason": "测试服务只接受 save_run"}
        save_count += 1
        return {"success": true, "save_count": save_count}

func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _remove_test_files()
    _test_round_trip_and_complete_run_deck()
    _remove_test_files()
    _test_life_round_trip_and_legacy_defaults()
    _remove_test_files()
    _test_corruption_backup_recovery_and_unknown_version_rejection()
    _remove_test_files()
    _test_reward_boundary_and_v1_to_v2_migration()
    _test_s2f6a_content_version_and_complete_loadout_round_trip()
    _remove_test_files()
    _test_autosave_stable_boundaries_and_battle_exclusion()
    _test_composition_root_restore_factory_and_first_save()
    _test_autosave_failure_preserves_previous_and_retry()
    _test_front_continue_backup_and_resume_routes()
    _test_resume_policy_ui_routes_and_restart_identity()
    if failures.is_empty():
        print("RUN SAVE V1 TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("RUN SAVE V1 TEST FAIL: %s" % failure)
    print("RUN SAVE V1 TEST FAILURES: %d / %d assertions" % [failures.size(), assertions])
    quit(1)

func _test_round_trip_and_complete_run_deck() -> void:
    var repository = SaveRepositoryScript.new(SAVE_PATH)
    var service = ApplicationServiceScript.new(repository)
    var session = _configured_session(2308, 12)
    var available: Array = session.snapshot().available_node_ids
    _assert_true(not available.is_empty(), "建局后存在可进入节点")
    _assert_true(
        session.execute({"type": "begin_node", "node_id": str(available[0])}).success,
        "在节点入口合法边界保存")
    var expected = RunSaveDataScript.new().capture(session)
    _assert_equal(expected.validate(service.content_catalog), [], "完整本局数据通过稳定内容 ID 校验")
    _assert_equal(
        expected.to_dict()["node_state"]["resume_policy"],
        "restart_node_from_start",
        "进行中节点明确从节点开头恢复")
    var illegal_boundary: Dictionary = expected.to_dict()
    illegal_boundary["node_state"]["phase"] = "battle_mid_round"
    _assert_true(
        not RunSaveDataScript.new(illegal_boundary).validate(service.content_catalog).is_empty(),
        "战斗中间阶段不能写入本局存档")
    _assert_true(service.execute({"type": "save_run", "run_session": session})["success"], "应用命令写入本局存档")
    var loaded: Dictionary = service.execute({"type": "load_run"})
    _assert_true(loaded.get("success", false), "应用命令读取本局存档")
    _assert_equal(loaded.get("source"), "primary", "有效主存档优先读取")
    _assert_equal(loaded.get("resume_policy"), "restart_node_from_start", "载入结果向 UI 公开重开节点策略")
    var restored = loaded["run_session"]
    _assert_equal(
        RunSaveDataScript.new().capture(restored).to_dict(),
        expected.to_dict(),
        "本局存档往返保持全部状态一致")
    _assert_equal(restored.growth.experience, 12, "往返保留历练")
    _assert_equal(restored.growth.consumable_ids, ["zengyuan_pill"], "往返保留消耗品稳定 ID")
    _assert_equal(
        restored.growth.hand_progression("high_card")["slot_count"],
        2,
        "往返保留高牌功法槽位")
    _assert_equal(restored.growth.learned_technique_ids, [], "基础功法往返仍不计入已习得功法")
    _assert_equal(restored.growth.learned_inner_skill_ids, ["extra_qi_to_defense"], "往返保留已习得内功 ID")
    _assert_equal(restored.growth.equipped_inner_skill_ids, ["extra_qi_to_defense"], "往返保留已装备内功 ID")
    _assert_equal(restored.growth.technique_slot_index, 1, "往返保留功法与内功结算槽位")
    var deck_snapshot: Dictionary = restored.growth.run_deck.to_snapshot()
    _assert_equal(deck_snapshot["cards"].size(), 53, "完整 RunDeck 保留永久复制后的牌数")
    _assert_equal(deck_snapshot["next_serial"], 2, "完整 RunDeck 保留实例 ID 序列")
    var wind_seven: Dictionary = restored.growth.run_deck.card_data("wind_7")
    _assert_equal(wind_seven["definition_id"], "mountain_7", "QiCardInstanceData 保留本源后的定义 ID")
    _assert_equal(wind_seven["rank_name"], "7", "QiCardInstanceData 保留点数")
    _assert_equal(wind_seven["attribute"], "mountain", "QiCardInstanceData 保留转属后的属性 ID")
    _assert_equal(wind_seven["reshapes"]["origin"]["id"], "attribute_change", "QiCardInstanceData 保留本源锁")
    _assert_equal(wind_seven["reshapes"]["enhancement"], "qi_boost", "QiCardInstanceData 保留强化")
    _assert_equal(wind_seven["reshapes"]["imprint"], "", "QiCardInstanceData 保留空印记槽")
    _assert_true(not wind_seven.has("anomalies"), "本局存档不保存战斗异状")
    _assert_true(not repository.encode(expected.to_dict()).contains("battle_state"), "磁盘 payload 不包含战斗中间状态")

func _test_corruption_backup_recovery_and_unknown_version_rejection() -> void:
    var repository = SaveRepositoryScript.new(SAVE_PATH)
    var service = ApplicationServiceScript.new(repository)
    var previous = _configured_session(815, 7)
    _assert_true(service.save_run(previous)["success"], "首次有效存档写入成功")
    var preserved_primary := FileAccess.get_file_as_string(repository.save_path)
    _assert_true(not repository.save({}).get("success", false), "空数据写入在替换前失败")
    _assert_equal(
        FileAccess.get_file_as_string(repository.save_path),
        preserved_primary,
        "失败写入不改变上一份有效主存档")
    previous.growth.experience = 19
    _assert_true(service.save_run(previous)["success"], "第二次写入前建立上一版备份")
    _assert_true(FileAccess.file_exists(repository.backup_path), "上一份有效存档存在于备份路径")
    var tampered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(repository.save_path))
    tampered["payload_sha256"] = "tampered"
    _write_raw(repository.save_path, JSON.stringify(tampered))
    var recovered: Dictionary = repository.load()
    _assert_true(recovered.get("success", false), "主存档校验和损坏后从备份恢复")
    _assert_equal(recovered.get("source"), "backup", "恢复结果标记备份来源")
    _assert_true(recovered.get("recovery_restored_primary", false), "有效备份恢复回主存档路径")
    var restored: Dictionary = recovered["data"].restore_session()
    _assert_true(restored.get("success", false), "恢复出的备份仍通过完整领域校验")
    _assert_equal(restored["run_session"].growth.experience, 7, "损坏恢复使用上一份有效存档")
    _assert_true(repository.load().get("source") == "primary", "恢复后主存档可再次正常读取")

    var unknown: Dictionary = recovered["data"].to_dict()
    unknown["schema_version"] = 99
    _write_raw(repository.save_path, repository.encode(unknown))
    var rejected: Dictionary = repository.load()
    _assert_true(not rejected.get("success", false), "未知未来 schema_version 被拒绝")
    _assert_equal(rejected.get("kind"), "incompatible", "未知版本与损坏明确区分")
    _assert_true(str(rejected.get("reason", "")).contains("未知 schema_version 99"), "未知版本错误包含实际版本")
    _assert_true(FileAccess.file_exists(repository.backup_path), "未知版本拒绝不会覆盖或删除备份")

    unknown["schema_version"] = 1
    unknown["content_version"] = 99
    _assert_true(
        not RunSaveDataScript.new(unknown).validate(service.content_catalog).is_empty(),
        "未知 content_version 在领域读取边界被拒绝")

func _test_life_round_trip_and_legacy_defaults() -> void:
    var session = _configured_session(5205, 9)
    session.navigation.act = 2
    session.navigation.graph = session.navigation.map_generator.generate(
        session.navigation.seed, 2)
    session.growth.life = 90
    session.growth.max_life = 150
    var data = RunSaveDataScript.new().capture(session)
    var restored: Dictionary = data.restore_session()
    _assert_true(restored.get("success", false), "含生命字段的v1存档可以恢复")
    _assert_equal(restored["run_session"].growth.life, 90, "v1往返保留第二层90点当前生命")
    _assert_equal(restored["run_session"].growth.max_life, 150, "v1往返保留第二层150点生命上限")
    _assert_true(restored["run_session"].progress_snapshot().has_life, "生命往返快照has_life标志保持")
    _assert_true(restored["run_session"].progress_snapshot().has_max_life, "生命往返快照has_max_life标志保持")

    var legacy: Dictionary = data.to_dict()
    legacy["growth"].erase("life")
    legacy["growth"].erase("max_life")
    var legacy_restored: Dictionary = RunSaveDataScript.new(legacy).restore_session()
    _assert_true(legacy_restored.get("success", false), "缺少生命字段的旧v1存档可以恢复")
    _assert_equal(legacy_restored["run_session"].growth.life, 150, "旧v1第2层补齐为150点满生命")
    _assert_equal(legacy_restored["run_session"].growth.max_life, 150, "旧v1第2层按权威表补齐150点上限")
    _assert_true(legacy_restored["run_session"].progress_snapshot().has_life, "旧v1补齐后快照has_life标志为真")
    _assert_true(legacy_restored["run_session"].progress_snapshot().has_max_life, "旧v1补齐后快照has_max_life标志为真")

func _test_reward_boundary_and_v1_to_v2_migration() -> void:
    var session = _configured_session(420, 3)
    var node_id := str(session.snapshot().available_node_ids[0])
    _assert_true(session.execute({"type": "begin_node", "node_id": node_id}).success, "奖励边界测试进入节点")
    _assert_true(session.execute({"type": "complete_node"}).success, "奖励边界测试完成节点")
    var data = RunSaveDataScript.new().capture(session)
    _assert_equal(data.to_dict()["node_state"]["phase"], "awaiting_reward", "v1 保存待领奖励阶段")
    _assert_true(not data.to_dict()["node_state"]["pending_reward"].is_empty(), "v1 保存确定性待领奖励包")
    var restored: Dictionary = data.restore_session()
    _assert_true(restored.get("success", false), "待领奖励边界可恢复")
    var reward_session = restored["run_session"]
    var bundle_id := str(reward_session.snapshot().reward["bundle"]["id"])
    _assert_true(
        reward_session.execute({"type": "claim_reward", "bundle_id": bundle_id}).success,
        "恢复后不会丢失待领奖励命令状态")

    var registry = MigrationRegistryScript.new(2)
    var registration := registry.register_migration(1, 2, func(values: Dictionary) -> Dictionary:
        values["v2_migration_marker"] = "simulated"
        return values)
    _assert_true(registration["success"], "注册逐版本 v1 到 v2 迁移")
    var migrated: Dictionary = registry.migrate(data.to_dict())
    _assert_true(migrated.get("success", false), "模拟 v1 存档迁移到 v2")
    _assert_equal(migrated["data"]["schema_version"], 2, "迁移后 schema_version 为 v2")
    _assert_equal(migrated["data"]["v2_migration_marker"], "simulated", "v1 到 v2 转换逻辑实际执行")
    _assert_equal(migrated["migrations"], ["v1->v2"], "迁移结果记录完整迁移链")

func _test_autosave_stable_boundaries_and_battle_exclusion() -> void:
    var save_application := CountingSaveApplication.new()
    var coordinator = RunAutosaveCoordinatorScript.new(save_application)
    var session: RunSession = RunSessionScript.new()
    _assert_true(coordinator.bind_session(session).get("success", false), "自动存档协调器绑定 RunSession")
    _assert_true(session.execute({
        "type": "setup_run",
        "seed": 71001,
        "starter_build_id": "standard_52",
    }).success, "自动存档边界测试建立本局")
    _assert_equal(save_application.save_count, 1, "setup_run 成功后只自动保存一次")
    _assert_true(session.execute({"type": "get_run_build"}).success, "查询命令成功")
    _assert_equal(save_application.save_count, 1, "查询命令不触发自动存档")
    _assert_true(session.execute({
        "type": "set_inner_skill_loadout",
        "equipped_inner_skill_ids": [],
        "technique_slot_index": 0,
    }).success, "无变化的成功配装命令可完成")
    _assert_equal(save_application.save_count, 1, "成功但未产生持久变化的命令不自动保存")
    _assert_true(not session.execute({
        "type": "begin_node", "node_id": "missing-node",
    }).success, "失败命令被拒绝")
    _assert_equal(save_application.save_count, 1, "失败命令不触发自动存档")

    var node_id := str(session.snapshot().available_node_ids[0])
    var begin := session.execute({"type": "begin_node", "node_id": node_id})
    _assert_true(begin.success, "自动存档测试进入战斗节点")
    _assert_equal(save_application.save_count, 2, "begin_node 稳定边界保存一次")
    var battle = session.create_battle_session()
    _assert_true(battle.setup_battle(
        begin.payload_value("dispatch", {}), session.progress_snapshot()),
        "战斗中间状态测试建立 BattleSession")
    battle.execute({"type": "start_turn"})
    battle.snapshot()
    _assert_equal(save_application.save_count, 2, "战斗抽牌、预览与 AI 状态不写本局存档")

    var dispatch: Dictionary = begin.payload_value("dispatch", {})
    var progress_values := session.progress_snapshot().to_dict()
    progress_values["experience"] = session.growth.experience + 4
    var battle_result = BattleFinalResultDTOScript.from_dict({
        "battle_state": "player_victory",
        "detail": "自动存档多变化测试胜利",
        "node_id": node_id,
        "act": session.navigation.act,
        "node_type": dispatch.get("node_type", ""),
        "content_id": dispatch.get("content_id", ""),
        "content_seed": dispatch.get("content_seed", 0),
        "turn_number": 1,
    })
    var resolved := session.execute({
        "type": "resolve_battle_result",
        "battle_result": battle_result,
        "progress_snapshot": RunProgressSnapshotScript.from_dict(progress_values),
    })
    _assert_true(resolved.success, "战斗胜利完整进入 awaiting_reward")
    _assert_equal(session.snapshot().phase, "awaiting_reward", "保存发生在完整奖励边界")
    _assert_equal(
        save_application.save_count,
        3,
        "resolve_battle_result 内成长同步与奖励建立多次变化仍只保存一次")
    coordinator.unbind_session()
    _assert_true(coordinator.bound_session == null, "自动存档协调器可解绑旧会话")

func _test_composition_root_restore_factory_and_first_save() -> void:
    var save_path := "/tmp/taiwu-s2-f4c-factory.json"
    _remove_paths(save_path)
    var composition = _composition_with_save(save_path)
    var service = composition.run_save_application_service
    var coordinator = RunAutosaveCoordinatorScript.new(service)
    var session = composition.create_run_session()
    coordinator.bind_session(session)
    _assert_true(session.execute({
        "type": "setup_run",
        "seed": 71002,
        "starter_build_id": "standard_52",
    }).success, "组合根新本局建立成功")
    _assert_true(FileAccess.file_exists(save_path), "新本局首次稳定边界产生有效自动存档")
    var expected: Dictionary = RunSaveDataScript.new().capture(session).to_dict()
    var encoded_before := FileAccess.get_file_as_string(save_path)
    var loaded: Dictionary = service.execute({"type": "load_run"})
    _assert_true(loaded.get("success", false), "组合根存档服务恢复本局")
    _assert_equal(FileAccess.get_file_as_string(save_path), encoded_before, "无新变化的恢复不会立即重写存档")
    var restored = loaded["run_session"]
    _assert_equal(RunSaveDataScript.new().capture(restored).to_dict(), expected, "恢复路径不调用 setup_run 或重建地图")
    _assert_true(restored._content_catalog == composition.content_catalog, "恢复会话复用组合根 ContentCatalog")
    _assert_true(restored.runtime_profile == composition.runtime_profile, "恢复会话复用组合根 RuntimeProfile")
    _assert_true(restored._battle_session_factory.content_catalog == composition.content_catalog, "恢复会话复用组合根 BattleSessionFactory 内容依赖")
    _assert_true(restored._node_reward_service.mutation_service == composition.run_mutation_service, "恢复会话复用共享 RunMutationService")
    _assert_true(restored._node_reward_service.mutation_service.handler_registry == composition.run_effect_registry, "恢复会话复用共享 Handler Registry")
    _assert_true(restored._node_interaction_service == composition.node_interaction_service, "恢复会话复用共享 NodeInteractionService")
    _assert_true(restored._ai_settings_service == composition.ai_settings_service, "恢复会话复用共享 AISettingsService")
    var run_logs: Array = restored.game_log.entries("run")
    _assert_equal(run_logs.size(), 1, "载入时只建立一条新的本局日志")
    _assert_equal(run_logs[0].get("category"), "run_restored", "载入记录结构化 run_restored 日志")
    coordinator.unbind_session()
    _remove_paths(save_path)

func _test_autosave_failure_preserves_previous_and_retry() -> void:
    var save_path := "/tmp/taiwu-s2-f4c-autosave-failure.json"
    _remove_paths(save_path)
    var composition = _composition_with_save(save_path)
    var coordinator = RunAutosaveCoordinatorScript.new(
        composition.run_save_application_service)
    var session = composition.create_run_session()
    coordinator.bind_session(session)
    session.execute({
        "type": "setup_run",
        "seed": 71003,
        "starter_build_id": "standard_52",
    })
    var previous_encoded := FileAccess.get_file_as_string(save_path)
    var status = AutosaveStatusScript.new()
    root.add_child(status)
    coordinator.save_succeeded.connect(status.present_success)
    coordinator.save_failed.connect(status.present_failure)
    status.retry_requested.connect(func(): coordinator.retry_last_save())
    session.growth.life = -1
    var failed := coordinator.save_now("forced_validation_failure")
    _assert_true(not failed.get("success", false), "非法稳定状态自动存档明确失败")
    _assert_true(status.status_label.text.contains("自动存档失败"), "自动存档失败 UI 持久显示具体原因")
    _assert_true(status.retry_button.visible, "自动存档失败 UI 提供手动重试")
    _assert_equal(FileAccess.get_file_as_string(save_path), previous_encoded, "失败写入不改变上一份有效存档")
    var previous: Dictionary = composition.run_save_application_service.execute({"type": "load_run"})
    _assert_true(previous.get("success", false), "自动存档失败后上一份有效存档仍可读取")
    _assert_equal(previous["run_session"].growth.life, 100, "失败写入没有污染上一份生命状态")
    var failure_logs: Array = session.game_log.entries("system").filter(
        func(entry): return str(entry.get("category", "")) == "autosave_failed")
    _assert_equal(failure_logs.size(), 1, "一次自动存档失败记录一条 autosave_failed 日志")
    session.growth.life = 100
    status.retry_button.pressed.emit()
    _assert_equal(status.status_label.text, "已自动保存", "手动重试成功后更新保存状态")
    _assert_true(not status.retry_button.visible, "手动重试成功后隐藏重试入口")
    status.queue_free()
    coordinator.unbind_session()
    _remove_paths(save_path)

func _test_front_continue_backup_and_resume_routes() -> void:
    var save_path := "/tmp/taiwu-s2-f4c-front-continue.json"
    _remove_paths(save_path)
    var composition = _composition_with_save(save_path)
    var service = composition.run_save_application_service
    var source = composition.create_run_session()
    source.execute({
        "type": "setup_run",
        "seed": 71004,
        "starter_build_id": "standard_52",
    })
    _assert_true(service.save_run(source).get("success", false), "首页继续游戏测试写入主存档")
    var expected_graph: Dictionary = source.snapshot().graph.duplicate(true)
    var front = FrontScene.instantiate()
    front.composition_root = composition
    root.add_child(front)
    front.initialize_interface()
    _assert_true(not front.continue_button.disabled, "主存档存在时首页启用继续游戏")
    DirAccess.copy_absolute(save_path, save_path + ".bak")
    DirAccess.remove_absolute(save_path)
    front._refresh_continue_availability()
    _assert_true(not front.continue_button.disabled, "仅备份存在时首页仍启用继续游戏")
    DirAccess.copy_absolute(save_path + ".bak", save_path)
    var encoded_before := FileAccess.get_file_as_string(save_path)
    front._on_continue_game()
    _assert_true(front.active_run != null, "继续游戏成功进入 RunMain")
    _assert_equal(front.active_run._startup_mode, "restored", "继续游戏使用明确恢复启动模式")
    _assert_equal(front.active_run.run_session.snapshot().phase, "awaiting_node", "resume_boundary 恢复到地图待选页面")
    _assert_equal(front.active_run.run_session.snapshot().graph, expected_graph, "恢复路径不重新生成地图")
    _assert_equal(FileAccess.get_file_as_string(save_path), encoded_before, "继续游戏载入本身不触发自动保存")
    var old_coordinator = front.active_run.autosave_coordinator
    front.active_run._request_return_to_menu()
    _assert_true(front.active_run == null, "返回主菜单释放当前 RunMain")
    _assert_true(old_coordinator.bound_session == null, "返回主菜单解绑旧 autosave coordinator")
    _assert_true(not front.continue_button.disabled, "返回主菜单后继续游戏仍可用")

    var before_confirmation := FileAccess.get_file_as_string(save_path)
    front._on_new_game()
    _assert_equal(
        front.new_game_confirmation.dialog_text,
        "开始新行旅会覆盖当前本局记录，是否继续？",
        "已有存档时新游戏显示明确覆盖确认")
    _assert_true(not front.build_page.visible, "确认前不进入新本局构筑流程")
    _assert_equal(FileAccess.get_file_as_string(save_path), before_confirmation, "新游戏确认前不写入或删除旧存档")
    front.new_game_confirmation.hide()

    source.growth.experience = 9
    _assert_true(service.save_run(source).get("success", false), "建立可恢复的上一份有效备份")
    var repository = service.repository
    _write_raw(repository.save_path, "{broken-primary")
    _assert_true(FileAccess.file_exists(repository.backup_path), "主存档损坏前备份存在")
    front._on_continue_game()
    _assert_true(front.active_run != null, "主存档损坏时从备份进入游戏")
    _assert_true(front.active_run.toast_label.text.contains(
        "主存档损坏，已从上一份有效备份恢复"), "备份恢复显示非阻断提示")
    _assert_equal(front.active_run.run_session.growth.experience, 0, "备份恢复使用上一份冻结状态")
    front.active_run._request_return_to_menu()

    var unknown_content: Dictionary = RunSaveDataScript.new().capture(source).to_dict()
    unknown_content["content_version"] = 99
    _write_raw(repository.save_path, repository.encode(unknown_content))
    var unknown_content_before := FileAccess.get_file_as_string(repository.save_path)
    front._on_continue_game()
    _assert_true(front.active_run == null, "未知 content 版本不会进入本局")
    _assert_equal(front.info_page._title.text, "存档内容校验失败", "未知 content 版本进入领域校验错误页")
    _assert_true(front.info_page._body.text.contains("content_version 不受支持：99"), "content 版本错误显示具体版本")
    _assert_equal(FileAccess.get_file_as_string(repository.save_path), unknown_content_before, "未知 content 版本保留原文件")

    var unknown: Dictionary = RunSaveDataScript.new().capture(source).to_dict()
    unknown["schema_version"] = 99
    _write_raw(repository.save_path, repository.encode(unknown))
    var incompatible_before := FileAccess.get_file_as_string(repository.save_path)
    front._on_continue_game()
    _assert_true(front.active_run == null, "未知 schema 版本不会进入本局")
    _assert_true(front.info_page.visible, "版本不兼容显示正式错误页面")
    _assert_equal(front.info_page._title.text, "存档版本不兼容", "版本不兼容与损坏明确区分")
    _assert_true(front.info_page._body.text.contains("未知 schema_version 99"), "版本错误显示具体未知版本")
    _assert_equal(FileAccess.get_file_as_string(repository.save_path), incompatible_before, "版本不兼容时原文件保持不变")
    front.queue_free()
    _remove_paths(save_path)

func _test_resume_policy_ui_routes_and_restart_identity() -> void:
    var save_path := "/tmp/taiwu-s2-f4c-resume-ui.json"
    _remove_paths(save_path)
    var composition = _composition_with_save(save_path)
    var service = composition.run_save_application_service

    var reward_source = composition.create_run_session()
    reward_source.execute({
        "type": "setup_run", "seed": 71005,
        "starter_build_id": "standard_52",
    })
    var reward_node := str(reward_source.snapshot().available_node_ids[0])
    reward_source.execute({"type": "begin_node", "node_id": reward_node})
    reward_source.execute({"type": "complete_node"})
    var frozen_reward: Dictionary = reward_source.snapshot().reward.get(
        "bundle", {}).duplicate(true)
    for entry in frozen_reward.get("entries", []):
        if entry is Dictionary and entry.has("amount"):
            entry["amount"] = int(entry["amount"])
    service.save_run(reward_source)
    var reward_loaded: Dictionary = service.load_run()
    var reward_ui = RunScene.instantiate()
    reward_ui.configure_composition_root(composition)
    reward_ui.configure_restored_run(
        reward_loaded["run_session"],
        reward_loaded["resume_policy"],
        {"source": reward_loaded.get("source", "primary")})
    reward_ui.initialize_interface()
    root.add_child(reward_ui)
    _assert_true(reward_ui.reward_overlay.visible, "awaiting_reward 恢复后打开奖励领取页面")
    _assert_equal(
        reward_ui.run_session.snapshot().reward.get("bundle", {}),
        frozen_reward,
        "awaiting_reward 恢复使用同一个冻结奖励包")
    reward_ui.queue_free()

    var chest_source = composition.create_run_session()
    chest_source.execute({
        "type": "setup_run", "seed": 71006,
        "starter_build_id": "standard_52",
    })
    chest_source.navigation.phase = "boss_chest"
    service.save_run(chest_source)
    var chest_loaded: Dictionary = service.load_run()
    var chest_ui = RunScene.instantiate()
    chest_ui.configure_composition_root(composition)
    chest_ui.configure_restored_run(
        chest_loaded["run_session"],
        chest_loaded["resume_policy"], {})
    chest_ui.initialize_interface()
    root.add_child(chest_ui)
    _assert_true(chest_ui.boss_chest_overlay.visible, "boss_chest 恢复后打开 Boss 宝箱页面")
    chest_ui.queue_free()

    var terminal_source = composition.create_run_session()
    terminal_source.execute({
        "type": "setup_run", "seed": 71007,
        "starter_build_id": "standard_52",
    })
    terminal_source.execute({"type": "abandon_run"})
    var expected_terminal: Dictionary = terminal_source.snapshot().terminal_result.duplicate(true)
    service.save_run(terminal_source)
    var terminal_loaded: Dictionary = service.load_run()
    var terminal_ui = RunScene.instantiate()
    terminal_ui.configure_composition_root(composition)
    terminal_ui.configure_restored_run(
        terminal_loaded["run_session"],
        terminal_loaded["resume_policy"], {})
    terminal_ui.initialize_interface()
    root.add_child(terminal_ui)
    _assert_true(terminal_ui.terminal_overlay.visible, "show_terminal 恢复后直接显示终局页面")
    _assert_equal(terminal_ui.run_session.snapshot().terminal_result, expected_terminal, "show_terminal 保留原终局结果")
    var terminal_logs: Array = terminal_ui.run_session.game_log.entries("run")
    _assert_equal(terminal_logs.size(), 1, "show_terminal 不重复写终局日志")
    _assert_equal(terminal_logs[0].get("category"), "run_restored", "终局恢复只记录 run_restored")
    terminal_ui.queue_free()

    var battle_source = composition.create_run_session()
    battle_source.execute({
        "type": "setup_run", "seed": 71008,
        "starter_build_id": "standard_52",
    })
    var battle_node := str(battle_source.snapshot().available_node_ids[0])
    var battle_begin = battle_source.execute({
        "type": "begin_node", "node_id": battle_node,
    })
    var original_dispatch: Dictionary = battle_begin.payload_value("dispatch", {})
    var original_battle = battle_source.create_battle_session()
    original_battle.setup_battle(original_dispatch, battle_source.progress_snapshot())
    var original_enemy: Dictionary = _enemy_signature(original_battle)
    battle_source.close_active_battle()
    service.save_run(battle_source)
    var battle_loaded: Dictionary = service.load_run()
    var battle_ui = RunScene.instantiate()
    battle_ui.configure_composition_root(composition)
    battle_ui.configure_restored_run(
        battle_loaded["run_session"],
        battle_loaded["resume_policy"], {})
    battle_ui.initialize_interface()
    root.add_child(battle_ui)
    _assert_true(battle_ui.current_battle != null, "restart_node_from_start 重新建立战斗场景")
    if not battle_ui.current_battle.is_node_ready():
        battle_ui.current_battle.battle_session.setup_battle(
            battle_ui.current_battle.battle_configuration,
            battle_ui.run_session.progress_snapshot())
    var resumed_configuration: Dictionary = battle_ui.current_battle.battle_configuration
    _assert_equal(resumed_configuration.get("node_id"), original_dispatch.get("node_id"), "重启战斗保持同一 node ID")
    _assert_equal(resumed_configuration.get("content_seed"), original_dispatch.get("content_seed"), "重启战斗保持同一 content seed")
    _assert_equal(resumed_configuration.get("content_id"), original_dispatch.get("content_id"), "重启战斗保持同一敌人内容候选")
    _assert_equal(_enemy_signature(battle_ui.current_battle.battle_session), original_enemy, "重启战斗保持同一敌人装配与牌组")
    _assert_true(battle_ui.toast_label.text.contains("战斗从节点开头重新开始"), "节点重启显示明确恢复提示")
    battle_ui.queue_free()
    _remove_paths(save_path)

func _composition_with_save(save_path: String):
    var composition = GameCompositionRootScript.new(RuntimeProfileScript.test())
    _assert_true(composition.initialize(), "测试组合根内容加载成功")
    composition.run_save_application_service = ApplicationServiceScript.new(
        SaveRepositoryScript.new(save_path),
        composition.content_catalog,
        Callable(composition, "create_run_session"))
    return composition

func _enemy_signature(battle_session) -> Dictionary:
    var enemy = battle_session.engine.enemy
    var card_ids: Array[String] = []
    for zone in [enemy.draw_pile, enemy.hand, enemy.discard_pile]:
        for card in zone:
            card_ids.append(str(card.id))
    card_ids.sort()
    return {"name": enemy.name, "card_ids": card_ids}

func _remove_paths(save_path: String) -> void:
    for path in [save_path, save_path + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func _test_s2f6a_content_version_and_complete_loadout_round_trip() -> void:
    var session = _configured_session(6206, 6)
    var current = RunSaveDataScript.new().capture(session)
    _assert_equal(current.to_dict().get("content_version"), 2,
        "F6A 新存档写入 content_version=2")
    var old_values: Dictionary = current.to_dict()
    old_values["content_version"] = 1
    _assert_true(not RunSaveDataScript.new(old_values).validate().is_empty(),
        "content_version=1 旧存档明确拒绝")
    var restored: Dictionary = current.restore_session()
    _assert_true(restored.get("success", false), "content_version=2 新存档可以恢复")
    for hand_id in GrowthInventoryScript.HAND_IDS:
        var progression: Dictionary = restored["run_session"].growth.hand_progression(hand_id)
        _assert_true(int(progression["slot_count"]) >= 1,
            "%s 往返后槽位至少为 1" % hand_id)
        _assert_equal(progression["sequence"].size(), progression["slot_count"],
            "%s 往返后序列仍完整填满" % hand_id)

func _configured_session(seed_value: int, experience: int):
    var session: RunSession = RunSessionScript.new()
    var setup := session.execute({
        "type": "setup_run",
        "seed": seed_value,
        "starter_build_id": "standard_52",
    })
    _assert_true(setup.success, "测试本局建立成功")
    session.growth.experience = experience
    session.growth.consumable_ids.clear()
    session.growth.consumable_ids.append("zengyuan_pill")
    session.growth.hand_technique_progression["high_card"] = {
        "slot_count": 2,
        "sequence": ["basic_scatter", "basic_scatter"],
    }
    session.growth.learned_technique_ids.clear()
    session.growth.learned_inner_skill_ids.clear()
    session.growth.learned_inner_skill_ids.append("extra_qi_to_defense")
    session.growth.equipped_inner_skill_ids.clear()
    session.growth.equipped_inner_skill_ids.append("extra_qi_to_defense")
    session.growth.technique_slot_index = 1
    session.growth.practice_purchases = {"zengyuan_pill": true}
    var cards: Array = session.growth.run_deck.create_battle_cards()
    for card in cards:
        if card.id != "wind_7":
            continue
        card.set_enhancement("qi_boost")
        card.set_anomaly("state", "poison")
    session.growth.run_deck.sync_from_battle_cards(cards)
    _assert_true(session.growth.run_deck.apply_card_origin(
        ["wind_7"], "attribute_change", {"attribute": "mountain"}
    ).get("success", false), "测试本局为真气施加转属本源")
    var copied: Dictionary = session.growth.run_deck.copy_card("wind_7")
    _assert_true(copied.get("success", false), "测试本局永久复制真气")
    return session

func _write_raw(path: String, value: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        failures.append("测试无法写入 %s" % path)
        return
    file.store_string(value)
    file.flush()

func _remove_test_files() -> void:
    for path in [SAVE_PATH, SAVE_PATH + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)
