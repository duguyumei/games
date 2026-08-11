class_name RunSaveData
extends RefCounted

const RunStateScript = preload("res://core/run_state.gd")
const RunSessionScript = preload("res://core/run_session.gd")
const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const RewardBundleScript = preload("res://core/reward_bundle.gd")
const NodeInteractionServiceScript = preload(
    "res://core/node_interactions/node_interaction_service.gd")

const SCHEMA_VERSION := 1
const CONTENT_VERSION := 1
const SAVE_FORMAT := "taiwu_run_save"
const ALLOWED_PHASES := [
    "awaiting_node",
    "node_in_progress",
    "awaiting_reward",
    "boss_chest",
    "run_complete",
]

var _data: Dictionary

func _init(values: Dictionary = {}) -> void:
    _data = values.duplicate(true)
    _normalize_v1_types()

func capture(run_session: RunSession, content_version_value: int = CONTENT_VERSION):
    var reward: Dictionary = run_session.snapshot().reward
    var pending_reward: Dictionary = (
        reward.get("bundle", {}).duplicate(true)
        if reward.get("available", false) else {})
    var phase := str(run_session.navigation.phase)
    var pending_interaction: Dictionary = (
        run_session._node_interaction_service.capture_pending()
        if run_session._node_interaction_service != null else {})
    _data = {
        "schema_version": SCHEMA_VERSION,
        "content_version": content_version_value,
        "run": {
            "seed": int(run_session.navigation.seed),
            "starter_build_id": str(run_session.selected_starter_build_id),
        },
        "map_state": {
            "act": int(run_session.navigation.act),
            "graph": run_session.navigation.graph.duplicate(true),
        },
        "node_state": {
            "phase": phase,
            "current_node_id": str(run_session.navigation.current_node_id),
            "completed_node_ids": run_session.navigation.completed_node_ids.keys(),
            "pending_reward": pending_reward,
            "pending_node_interaction": pending_interaction,
            "resume_policy": (
                "resume_interaction"
                if phase == "node_in_progress" and not pending_interaction.is_empty()
                else (
                    "restart_node_from_start"
                    if phase == "node_in_progress" else "resume_boundary")),
        },
        "growth": {
            "experience": int(run_session.growth.experience),
            "life": int(run_session.growth.life),
            "max_life": int(run_session.growth.max_life),
            "consumable_ids": run_session.growth.consumable_ids.duplicate(),
            "item_ids": run_session.growth.item_ids.duplicate(),
            "hand_technique_progression": run_session.growth.hand_technique_progression.duplicate(true),
            "practice_shop_state": run_session.growth.practice_shop_snapshot(),
            "learned_technique_ids": run_session.growth.learned_technique_ids.duplicate(),
            "learned_inner_skill_ids": run_session.growth.learned_inner_skill_ids.duplicate(),
            "equipped_inner_skill_ids": run_session.growth.equipped_inner_skill_ids.duplicate(),
            "technique_slot_index": int(run_session.growth.technique_slot_index),
            "forgotten_inner_skill_count": int(
                run_session.growth.forgotten_inner_skill_count),
            "practice_purchase_ids": run_session.growth.practice_purchases.keys(),
            "consumable_use_sequence": int(run_session.growth.consumable_use_sequence),
            "last_recallable_consumable_id": str(
                run_session.growth.last_recallable_consumable_id),
            "base_hand_limit_modifier": int(
                run_session.growth.base_hand_limit_modifier),
            "hand_technique_multiplier_modifiers": run_session.growth.hand_technique_multiplier_modifiers.duplicate(true),
            "used_unique_consumable_ids": run_session.growth.used_unique_consumable_ids.duplicate(),
            "run_deck": run_session.growth.run_deck.to_snapshot(),
        },
    }
    return self

func to_dict() -> Dictionary:
    return _data.duplicate(true)

func schema_version() -> int:
    return int(_data.get("schema_version", 0))

func content_version() -> int:
    return int(_data.get("content_version", 0))

func validate(content_catalog = null) -> Array[String]:
    var errors: Array[String] = []
    if schema_version() != SCHEMA_VERSION:
        errors.append("本局存档 schema_version 不受支持：%s" % str(_data.get("schema_version", "")))
    if content_version() != CONTENT_VERSION:
        errors.append("本局存档 content_version 不受支持：%s" % str(_data.get("content_version", "")))
    for section in ["run", "map_state", "node_state", "growth"]:
        if not _data.get(section) is Dictionary:
            errors.append("本局存档缺少对象 %s" % section)
    if not errors.is_empty():
        return errors
    var run: Dictionary = _data["run"]
    var map_state: Dictionary = _data["map_state"]
    var node_state: Dictionary = _data["node_state"]
    var growth: Dictionary = _data["growth"]
    var graph = map_state.get("graph", {})
    if not graph is Dictionary or not graph.get("nodes", []) is Array \
            or not graph.get("edges", []) is Array:
        errors.append("地图状态 graph 结构无效")
        return errors
    var node_ids: Dictionary = {}
    for node in graph.get("nodes", []):
        if not node is Dictionary or str(node.get("id", "")) == "":
            errors.append("地图包含缺少稳定 ID 的节点")
            continue
        node_ids[str(node["id"])] = true
    var phase := str(node_state.get("phase", ""))
    var current_node_id := str(node_state.get("current_node_id", ""))
    if not ALLOWED_PHASES.has(phase):
        errors.append("本局阶段不是合法节点边界：%s" % phase)
    if current_node_id != "" and not node_ids.has(current_node_id):
        errors.append("当前节点 ID 不在已保存地图中：%s" % current_node_id)
    if phase in ["node_in_progress", "awaiting_reward"] and current_node_id == "":
        errors.append("阶段 %s 缺少 current_node_id" % phase)
    var pending_interaction = node_state.get("pending_node_interaction", {})
    if not pending_interaction is Dictionary:
        errors.append("pending_node_interaction 必须是对象")
        pending_interaction = {}
    if phase == "node_in_progress":
        var expected_policy := (
            "resume_interaction"
            if not pending_interaction.is_empty()
            else "restart_node_from_start")
        if str(node_state.get("resume_policy", "")) != expected_policy:
            errors.append("进行中节点 resume_policy 必须为 %s" % expected_policy)
    elif not pending_interaction.is_empty():
        errors.append("只有 node_in_progress 可以保存 pending_node_interaction")
    for completed_id in node_state.get("completed_node_ids", []):
        if not node_ids.has(str(completed_id)):
            errors.append("已完成节点 ID 不在已保存地图中：%s" % str(completed_id))
    var pending_reward = node_state.get("pending_reward", {})
    if phase == "awaiting_reward" and (not pending_reward is Dictionary or pending_reward.is_empty()):
        errors.append("待领取奖励阶段缺少 pending_reward")
    if phase != "awaiting_reward" and pending_reward is Dictionary and not pending_reward.is_empty():
        errors.append("非奖励边界不能保存 pending_reward")
    if int(growth.get("experience", -1)) < 0:
        errors.append("历练不能为负数")
    if growth.get("consumable_ids", []) is Array \
            and growth.get("consumable_ids", []).size() \
            > GrowthInventoryScript.CONSUMABLE_LIMIT:
        errors.append("共享消耗品栏不能超过 %d 格" % GrowthInventoryScript.CONSUMABLE_LIMIT)
    if not growth.get("item_ids", []) is Array:
        errors.append("物品 ID 列表必须是数组")
    if growth.has("consumable_use_sequence") \
            and (not growth["consumable_use_sequence"] is int \
            or int(growth["consumable_use_sequence"]) < 0):
        errors.append("consumable_use_sequence 必须是非负整数")
    if growth.has("forgotten_inner_skill_count") \
            and (not growth["forgotten_inner_skill_count"] is int \
            or int(growth["forgotten_inner_skill_count"]) < 0):
        errors.append("forgotten_inner_skill_count 必须是非负整数")
    if growth.has("last_recallable_consumable_id") \
            and not growth["last_recallable_consumable_id"] is String:
        errors.append("last_recallable_consumable_id 必须是字符串")
    if growth.has("base_hand_limit_modifier") \
            and not growth["base_hand_limit_modifier"] is int:
        errors.append("base_hand_limit_modifier 必须是整数")
    if growth.has("hand_technique_multiplier_modifiers") \
            and not growth["hand_technique_multiplier_modifiers"] is Dictionary:
        errors.append("hand_technique_multiplier_modifiers 必须是对象")
    elif growth.has("hand_technique_multiplier_modifiers"):
        for hand_id in growth["hand_technique_multiplier_modifiers"]:
            if str(hand_id) not in GrowthInventoryScript.HAND_IDS:
                errors.append("hand_technique_multiplier_modifiers 包含未知牌型：%s" % str(hand_id))
            elif not growth["hand_technique_multiplier_modifiers"][hand_id] is int:
                errors.append("hand_technique_multiplier_modifiers.%s 必须是整数" % str(hand_id))
    _validate_life_fields(growth, errors)
    if not growth.get("run_deck", {}) is Dictionary:
        errors.append("成长状态缺少完整 RunDeck")
        return errors
    var catalog = content_catalog
    if catalog == null:
        catalog = ContentCatalogScript.new()
        if not catalog.load_all():
            errors.append("无法载入内容目录以校验存档")
            return errors
    _validate_pending_interaction(
        pending_interaction, phase, current_node_id, graph, catalog, errors)
    if growth.has("used_unique_consumable_ids"):
        _validate_id_array(
            growth["used_unique_consumable_ids"], "consumable", catalog, errors)
        for consumable_id in growth["used_unique_consumable_ids"]:
            var unique_definition: Dictionary = catalog.get_by_id(
                "consumable", str(consumable_id))
            if not bool(unique_definition.get("unique", false)):
                errors.append("已用唯一消耗品记录引用非唯一内容：%s" % str(consumable_id))
    _validate_hand_progression(growth.get("hand_technique_progression", {}), catalog, errors)
    if not growth.has("life") and not growth.has("max_life") \
            and _player_max_life_for_act(catalog, int(map_state.get("act", 0))) <= 0:
        errors.append(
            "旧版存档 map_state.act 无对应玩家生命上限：%s" %
            str(map_state.get("act", "")))
    _validate_content_ids(run, growth, catalog, errors)
    var deck = GrowthInventoryScript.new(catalog, false).run_deck
    errors.append_array(deck.restore_snapshot(growth["run_deck"]))
    for card in growth["run_deck"].get("cards", []):
        if not card is Dictionary:
            continue
        if card.has("anomalies") or card.has("temporary_reshapes") \
                or card.has("suppressed_reshapes"):
            errors.append("本局 RunDeck 不能包含战斗异状、临时重塑或旧压制状态")
        if bool(card.get("temporary_card", false)) or str(card.get("original_owner_id", "")) != "":
            errors.append("本局 RunDeck 不能包含临时或夺取真气")
    return errors

func restore_session(content_catalog = null) -> Dictionary:
    var catalog = content_catalog
    if catalog == null:
        catalog = ContentCatalogScript.new()
        if not catalog.load_all():
            return {"success": false, "reason": "统一内容目录无效"}
    var errors := validate(catalog)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors), "errors": errors}
    var run: Dictionary = _data["run"]
    var map_state: Dictionary = _data["map_state"]
    var node_state: Dictionary = _data["node_state"]
    var growth_state: Dictionary = _data["growth"]
    var navigation = MapNavigationServiceScript.new()
    navigation.seed = int(run["seed"])
    navigation.act = int(map_state["act"])
    navigation.graph = map_state["graph"].duplicate(true)
    navigation.phase = str(node_state["phase"])
    navigation.current_node_id = str(node_state["current_node_id"])
    navigation.completed_node_ids.clear()
    for node_id in node_state["completed_node_ids"]:
        navigation.completed_node_ids[str(node_id)] = true
    var growth = GrowthInventoryScript.new(catalog, false)
    growth.experience = int(growth_state["experience"])
    var restored_life := _life_values_for_restore(
        growth_state, int(map_state["act"]), catalog)
    var progress_values := {
        "consumable_ids": growth_state["consumable_ids"],
        "item_ids": growth_state.get("item_ids", []),
        "learned_technique_ids": growth_state["learned_technique_ids"],
        "learned_inner_skill_ids": growth_state["learned_inner_skill_ids"],
        "equipped_inner_skill_ids": growth_state["equipped_inner_skill_ids"],
        "technique_slot_index": growth_state["technique_slot_index"],
        "forgotten_inner_skill_count": growth_state.get(
            "forgotten_inner_skill_count", 0),
        "run_deck": growth_state["run_deck"],
        "life": restored_life["life"],
        "max_life": restored_life["max_life"],
    }
    if growth_state.has("hand_technique_progression"):
        progress_values["hand_technique_progression"] = growth_state["hand_technique_progression"]
    if growth_state.has("practice_shop_state"):
        progress_values["practice_shop_state"] = growth_state["practice_shop_state"]
    if growth_state.has("consumable_use_sequence"):
        progress_values["consumable_use_sequence"] = growth_state["consumable_use_sequence"]
    if growth_state.has("last_recallable_consumable_id"):
        progress_values["last_recallable_consumable_id"] = (
            growth_state["last_recallable_consumable_id"])
    if growth_state.has("base_hand_limit_modifier"):
        progress_values["base_hand_limit_modifier"] = (
            growth_state["base_hand_limit_modifier"])
    if growth_state.has("hand_technique_multiplier_modifiers"):
        progress_values["hand_technique_multiplier_modifiers"] = (
            growth_state["hand_technique_multiplier_modifiers"])
    if growth_state.has("used_unique_consumable_ids"):
        progress_values["used_unique_consumable_ids"] = (
            growth_state["used_unique_consumable_ids"])
    growth.apply_progress_snapshot(RunProgressSnapshotScript.from_dict(progress_values))
    growth.practice_purchases.clear()
    for content_id in growth_state["practice_purchase_ids"]:
        growth.practice_purchases[str(content_id)] = true
    var state = RunStateScript.new(navigation, growth)
    var session = RunSessionScript.new(state, null, null, null, catalog)
    session.selected_starter_build_id = str(run["starter_build_id"])
    if navigation.phase == "awaiting_reward":
        session._pending_reward = RewardBundleScript.new(node_state["pending_reward"])
    var pending_interaction: Dictionary = node_state.get(
        "pending_node_interaction", {})
    if not pending_interaction.is_empty():
        var pending_restore: Dictionary = session._node_interaction_service.restore_pending(
            pending_interaction)
        if not pending_restore.get("success", false):
            return pending_restore
    return {
        "success": true,
        "run_session": session,
        "resume_policy": str(node_state["resume_policy"]),
    }

func _validate_pending_interaction(
        pending: Dictionary,
        phase: String,
        current_node_id: String,
        graph: Dictionary,
        catalog,
        errors: Array[String]) -> void:
    if pending.is_empty():
        return
    if phase != "node_in_progress":
        return
    if int(pending.get("schema_version", 0)) \
            != NodeInteractionServiceScript.SCHEMA_VERSION:
        errors.append("pending_node_interaction schema_version 不受支持")
    if str(pending.get("node_id", "")) != current_node_id:
        errors.append("pending_node_interaction.node_id 与当前节点不一致")
    if str(pending.get("source_kind", "")) not in ["map_node", "boss_chest"]:
        errors.append("pending_node_interaction.source_kind 无效")
    if str(pending.get("source_id", "")) == "":
        errors.append("pending_node_interaction.source_id 不能为空")
    elif str(pending.get("source_kind", "")) == "map_node" \
            and str(pending.get("source_id", "")) != current_node_id:
        errors.append("map_node pending interaction 的 source_id 必须是当前节点")
    if not pending.get("configuration") is Dictionary:
        errors.append("pending_node_interaction.configuration 必须是对象")
    var dto = pending.get("interaction")
    if not dto is Dictionary:
        errors.append("pending_node_interaction 缺少冻结 interaction DTO")
    else:
        var dto_error := NodeInteractionServiceScript.validate_frozen_dto(dto)
        if dto_error != "":
            errors.append(dto_error)
        if str(dto.get("node_id", "")) != current_node_id:
            errors.append("冻结 interaction DTO 与当前节点不一致")
        if str(dto.get("interaction_token", "")) != str(pending.get("token", "")):
            errors.append("pending_node_interaction token 与 DTO 不一致")
        for field in [
                "source_kind", "source_id", "node_type", "content_id",
                "interaction_kind", "act", "content_seed"]:
            if dto.get(field) != pending.get(field):
                errors.append("pending_node_interaction.%s 与 DTO 不一致" % field)
    var current_node: Dictionary = {}
    for node_value in graph.get("nodes", []):
        if node_value is Dictionary \
                and str(node_value.get("id", "")) == current_node_id:
            current_node = node_value
            break
    var node_type := str(current_node.get("type", ""))
    if str(pending.get("node_type", "")) != node_type:
        errors.append("pending_node_interaction.node_type 与当前节点不一致")
    var content: Dictionary = catalog.get_by_id("node_type", node_type)
    if str(content.get("route", "")) != "interaction":
        errors.append("pending_node_interaction 当前节点不是 interaction 路由")
        return
    if str(pending.get("content_id", "")) != str(content.get("content_id", "")):
        errors.append("pending_node_interaction.content_id 与当前内容配置不一致")
    var interaction: Dictionary = content.get("interaction", {})
    if str(interaction.get("kind", "")) != str(pending.get("interaction_kind", "")):
        errors.append("pending_node_interaction kind 与当前内容配置不一致")
    if not catalog.node_interaction_registry.has_handler(
            str(pending.get("interaction_kind", ""))):
        errors.append("pending_node_interaction kind 未注册")

func _validate_content_ids(
        run: Dictionary,
        growth: Dictionary,
        catalog,
        errors: Array[String]) -> void:
    var starter_build_id := str(run.get("starter_build_id", ""))
    if starter_build_id != "" and not catalog.has_id("starter_build", starter_build_id):
        errors.append("存档引用未知初始构筑 ID：%s" % starter_build_id)
    _validate_id_array(growth.get("consumable_ids", []), "consumable", catalog, errors, true)
    _validate_id_array(growth.get("item_ids", []), "item", catalog, errors)
    _validate_practice_purchase_ids(
        growth.get("practice_purchase_ids", []), catalog, errors)
    _validate_id_array(growth.get("learned_technique_ids", []), "technique", catalog, errors)
    _validate_id_array(growth.get("learned_inner_skill_ids", []), "inner_skill", catalog, errors, true)
    _validate_id_array(growth.get("equipped_inner_skill_ids", []), "inner_skill", catalog, errors, true)
    var last_recallable := str(growth.get("last_recallable_consumable_id", ""))
    if last_recallable != "":
        var recall_definition: Dictionary = catalog.get_by_id(
            "consumable", last_recallable)
        if recall_definition.is_empty():
            errors.append("存档引用未知最近使用消耗品 ID：%s" % last_recallable)
        elif str(recall_definition.get("kind", "")) not in ["pill", "insight"] \
                or not bool(recall_definition.get("record_last_used", true)):
            errors.append("最近使用记录不是可溯忆的丹药或心得：%s" % last_recallable)
    var learned_counts := _counts(growth.get("learned_inner_skill_ids", []))
    var equipped_counts := _counts(growth.get("equipped_inner_skill_ids", []))
    for inner_skill_id in equipped_counts:
        if int(equipped_counts[inner_skill_id]) > int(learned_counts.get(inner_skill_id, 0)):
            errors.append("已装备内功数量超过已习得内功：%s" % str(inner_skill_id))
    var equipped_count: int = growth.get("equipped_inner_skill_ids", []).size()
    if equipped_count > 6:
        errors.append("已装备内功不能超过 6 门")
    var slot := int(growth.get("technique_slot_index", -1))
    if slot < 0 or slot > equipped_count:
        errors.append("功法结算槽位超出已装备内功范围")

func _validate_id_array(
        values,
        content_type: String,
        catalog,
        errors: Array[String],
        allow_duplicates: bool = false) -> void:
    if not values is Array:
        errors.append("%s ID 列表必须是数组" % content_type)
        return
    var seen: Dictionary = {}
    for value in values:
        var content_id := str(value)
        if content_id == "" or not catalog.has_id(content_type, content_id):
            errors.append("存档引用未知 %s ID：%s" % [content_type, content_id])
        elif seen.has(content_id) and not allow_duplicates:
            errors.append("存档包含重复 %s ID：%s" % [content_type, content_id])
        seen[content_id] = true

func _validate_practice_purchase_ids(
        values,
        catalog,
        errors: Array[String]) -> void:
    if not values is Array:
        errors.append("修习购买 ID 列表必须是数组")
        return
    var seen: Dictionary = {}
    for value in values:
        var content_id := str(value)
        if content_id == "" or seen.has(content_id):
            errors.append("修习购买记录包含空值或重复 ID：%s" % content_id)
        elif not catalog.has_id("technique", content_id) \
                and not catalog.has_id("inner_skill", content_id) \
                and not catalog.has_id("consumable", content_id) \
                and not catalog.has_id("item", content_id):
            errors.append("修习购买记录引用未知内容 ID：%s" % content_id)
        seen[content_id] = true

func _counts(values) -> Dictionary:
    var result: Dictionary = {}
    if not values is Array:
        return result
    for value in values:
        var content_id := str(value)
        result[content_id] = int(result.get(content_id, 0)) + 1
    return result

func _validate_life_fields(growth: Dictionary, errors: Array[String]) -> void:
    var has_life := growth.has("life")
    var has_max_life := growth.has("max_life")
    if has_life != has_max_life:
        errors.append("growth.life 与 growth.max_life 必须同时存在或同时缺省")
        return
    if not has_life:
        return
    var life_value = growth["life"]
    var max_life_value = growth["max_life"]
    var life_valid := life_value is int and int(life_value) > 0
    var max_life_valid := max_life_value is int and int(max_life_value) > 0
    if not life_valid:
        errors.append("growth.life 必须是正整数")
    if not max_life_valid:
        errors.append("growth.max_life 必须是正整数")
    if life_valid and max_life_valid and int(life_value) > int(max_life_value):
        errors.append("growth.life 不能大于 growth.max_life")

func _validate_hand_progression(values, catalog, errors: Array[String]) -> void:
    if values.is_empty():
        return
    if not values is Dictionary:
        errors.append("growth.hand_technique_progression 必须是对象")
        return
    for hand_id in GrowthInventoryScript.HAND_IDS:
        if not values.has(hand_id):
            errors.append("growth.hand_technique_progression 缺少牌型：%s" % hand_id)
            continue
        var progression = values[hand_id]
        if not progression is Dictionary:
            errors.append("growth.hand_technique_progression.%s 必须是对象" % hand_id)
            continue
        var slot_count = progression.get("slot_count", 0)
        var sequence = progression.get("sequence", [])
        if not slot_count is int or int(slot_count) < 0:
            errors.append("growth.hand_technique_progression.%s.slot_count 必须是非负整数" % hand_id)
        if not sequence is Array or sequence.size() > int(slot_count):
            errors.append("growth.hand_technique_progression.%s.sequence 超出槽位" % hand_id)
            continue
        var seen: Dictionary = {}
        for technique_id_value in sequence:
            var technique_id := str(technique_id_value)
            if seen.has(technique_id):
                errors.append("growth.hand_technique_progression.%s.sequence 重复功法 %s" % [hand_id, technique_id])
            seen[technique_id] = true
            if not catalog.has_id("technique", technique_id):
                errors.append("growth.hand_technique_progression 引用未知功法：%s" % technique_id)

func _life_values_for_restore(
        growth: Dictionary,
        act: int,
        catalog) -> Dictionary:
    if growth.has("life") and growth.has("max_life"):
        return {
            "life": int(growth["life"]),
            "max_life": int(growth["max_life"]),
        }
    var authoritative_max_life := _player_max_life_for_act(catalog, act)
    return {
        "life": authoritative_max_life,
        "max_life": authoritative_max_life,
    }

func _player_max_life_for_act(catalog, act: int) -> int:
    for entry in catalog.definition("act_progression").get("acts", []):
        if int(entry.get("act", 0)) == act:
            return int(entry.get("player", {}).get("max_life", 0))
    return 0

func _normalize_v1_types() -> void:
    if int(_data.get("schema_version", 0)) != SCHEMA_VERSION:
        return
    _data["schema_version"] = int(_data.get("schema_version", 0))
    _data["content_version"] = int(_data.get("content_version", 0))
    var run = _data.get("run", {})
    if run is Dictionary:
        run["seed"] = int(run.get("seed", 0))
    var map_state = _data.get("map_state", {})
    if map_state is Dictionary:
        map_state["act"] = int(map_state.get("act", 1))
        _normalize_graph(map_state.get("graph", {}))
    var node_state = _data.get("node_state", {})
    if node_state is Dictionary:
        _normalize_reward(node_state.get("pending_reward", {}))
    var growth = _data.get("growth", {})
    if not growth is Dictionary:
        return
    growth["experience"] = int(growth.get("experience", 0))
    _normalize_optional_integer(growth, "life")
    _normalize_optional_integer(growth, "max_life")
    _normalize_optional_integer(growth, "consumable_use_sequence")
    _normalize_optional_integer(growth, "forgotten_inner_skill_count")
    _normalize_optional_integer(growth, "base_hand_limit_modifier")
    growth["technique_slot_index"] = int(growth.get("technique_slot_index", 0))
    var progression = growth.get("hand_technique_progression", {})
    if progression is Dictionary:
        for hand_id in progression:
            if progression[hand_id] is Dictionary:
                progression[hand_id]["slot_count"] = int(progression[hand_id].get("slot_count", 1))
    var shop = growth.get("practice_shop_state", {})
    if shop is Dictionary:
        if not shop.has("items") and shop.has("coupons"):
            shop["items"] = shop["coupons"]
        if not shop.has("item_candidates") and shop.has("coupon_candidates"):
            shop["item_candidates"] = shop["coupon_candidates"]
        if not shop.has("item_slots") and shop.has("coupon_slots"):
            shop["item_slots"] = shop["coupon_slots"]
        shop.erase("coupons")
        shop.erase("coupon_candidates")
        shop.erase("coupon_slots")
        for field in [
                "shop_index", "act", "meditation_count",
                "next_meditation_cost", "pack_open_sequence"]:
            if shop.has(field):
                shop[field] = int(shop[field])
        for group in ["normal", "packs", "items"]:
            for slot in shop.get(group, []):
                if not slot is Dictionary or slot.is_empty():
                    continue
                if slot.has("price"):
                    slot["price"] = int(slot["price"])
                if group == "packs":
                    for field in ["offer_count", "choose_count"]:
                        if slot.has(field):
                            slot[field] = int(slot[field])
    var run_deck = growth.get("run_deck", {})
    if not run_deck is Dictionary:
        return
    run_deck["version"] = int(run_deck.get("version", 0))
    run_deck["next_serial"] = int(run_deck.get("next_serial", 1))
    for card in run_deck.get("cards", []):
        if not card is Dictionary:
            continue
        card["version"] = int(card.get("version", 0))
        card["rank_order"] = int(card.get("rank_order", 0))
        card["qi_value"] = int(card.get("qi_value", 0))

func _normalize_optional_integer(values: Dictionary, field: String) -> void:
    if not values.has(field):
        return
    var value = values[field]
    if value is float and value == floor(value):
        values[field] = int(value)

func _normalize_graph(graph) -> void:
    if not graph is Dictionary:
        return
    for field in ["seed", "act", "width", "route_rows", "boss_variant"]:
        graph[field] = int(graph.get(field, 0))
    for node in graph.get("nodes", []):
        if not node is Dictionary:
            continue
        node["row"] = int(node.get("row", 0))
        node["column"] = int(node.get("column", 0))
    for edge in graph.get("edges", []):
        if not edge is Dictionary:
            continue
        for field in ["from_row", "from_column", "to_row", "to_column"]:
            edge[field] = int(edge.get(field, 0))

func _normalize_reward(reward) -> void:
    if not reward is Dictionary or reward.is_empty():
        return
    reward["version"] = int(reward.get("version", 0))
    reward["seed"] = int(reward.get("seed", 0))
    reward["act"] = int(reward.get("act", 1))
    for entry in reward.get("entries", []):
        if entry is Dictionary and entry.has("amount"):
            entry["amount"] = int(entry["amount"])
