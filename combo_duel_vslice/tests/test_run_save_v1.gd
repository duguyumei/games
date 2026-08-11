extends SceneTree

const RunSessionScript = preload("res://core/run_session.gd")
const RunSaveDataScript = preload("res://core/run_save_data.gd")
const SaveRepositoryScript = preload("res://core/save_repository.gd")
const MigrationRegistryScript = preload("res://core/run_save_migration_registry.gd")
const ApplicationServiceScript = preload("res://core/run_save_application_service.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")

const SAVE_PATH := "/tmp/taiwu-run-save-v1-test.json"

var failures: Array[String] = []
var assertions: int = 0

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
    _remove_test_files()
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
    _assert_equal(restored.growth.learned_technique_ids, [], "空功法池往返保持无已习得功法")
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
        "sequence": [],
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
