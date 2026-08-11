class_name RunSession
extends RefCounted

## 单局地图、成长、奖励与战斗入口的应用层门面。
##
## 会话统一接受命令并发布快照和事件；故意不执行战斗规则、不解析内容文件，
## 也不把地图、奖励或成长服务的规则复制到门面中。

signal state_changed
signal persistence_boundary_reached(command_type: String)

const RunStateScript = preload("res://core/run_state.gd")
const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunSnapshotScript = preload("res://core/run_snapshot.gd")
const RunEventScript = preload("res://core/run_event.gd")
const CommandResultScript = preload("res://core/command_result.gd")
const NodeDispatcherScript = preload("res://core/node_dispatcher.gd")
const ConsumableRepositoryScript = preload("res://core/consumable_repository.gd")
const GameLogScript = preload("res://core/game_log.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const MapGeneratorScript = preload("res://core/map_generator.gd")
const StarterBuildRepositoryScript = preload("res://core/starter_build_repository.gd")
const StarterBuildAssemblerScript = preload("res://core/starter_build_assembler.gd")
const BattleSessionFactoryScript = preload("res://core/battle_session_factory.gd")
const NodeRewardServiceScript = preload("res://core/node_reward_service.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const ConsumableUseServiceScript = preload(
    "res://core/consumables/consumable_use_service.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const PracticeServiceScript = preload("res://core/practice_service.gd")
const InnerSkillRepositoryScript = preload(
    "res://core/inner_skill_repository.gd")
const InnerSkillLoadoutServiceScript = preload(
    "res://core/inner_skill_loadout_service.gd")
const RunBuildQueryServiceScript = preload(
    "res://core/run_build_query_service.gd")
const NodeInteractionServiceScript = preload(
    "res://core/node_interactions/node_interaction_service.gd")
const BattleFinalResultDTOScript = preload(
    "res://core/battle_final_result_dto.gd")
const RunTerminalResultDTOScript = preload(
    "res://core/run_terminal_result_dto.gd")

var game_log
var _run_state
var navigation
var growth
var _node_dispatcher
var _consumable_repository
var _content_catalog
var _event_queue: Array = []
var _event_serial: int = 0
var _ai_settings_service = null
var _starter_build_repository := StarterBuildRepositoryScript.new()
var _starter_build_assembler
var _battle_session_factory
var _node_reward_service
var _practice_service
var _consumable_use_service
var _inner_skill_repository
var _inner_skill_loadout_service
var _run_build_query_service
var _node_interaction_service
var _pending_reward = null
var _active_battle_session = null
var _pending_victory_battle_result: Dictionary = {}
var selected_starter_build_id: String = ""
var runtime_profile
var _persistent_change_serial: int = 0

func _init(
        run_state_override = null,
        node_dispatcher_override = null,
        game_log_override = null,
        consumable_repository_override = null,
        content_catalog_override = null,
        starter_build_repository_override = null,
        starter_build_assembler_override = null,
        battle_session_factory_override = null,
        node_reward_service_override = null,
        runtime_profile_override = null,
        consumable_use_service_override = null,
        node_interaction_service_override = null) -> void:
    runtime_profile = (
        runtime_profile_override
        if runtime_profile_override != null
        else RuntimeProfileScript.current())
    game_log = game_log_override if game_log_override != null else GameLogScript.new()
    _content_catalog = (
        content_catalog_override
        if content_catalog_override != null
        else ContentCatalogScript.new(runtime_profile))
    if content_catalog_override == null:
        _content_catalog.load_all()
    if run_state_override != null:
        _run_state = run_state_override
        navigation = _run_state.navigation
        growth = _run_state.growth
        if _content_catalog.loaded:
            navigation.map_generator.configure(_content_catalog.definition("map_rules"))
    else:
        var map_generator = MapGeneratorScript.new(
            _content_catalog.definition("map_rules") if _content_catalog.loaded else {})
        navigation = MapNavigationServiceScript.new(map_generator)
        growth = GrowthInventoryScript.new(_content_catalog)
        _run_state = RunStateScript.new(navigation, growth)
    _node_dispatcher = (
        node_dispatcher_override
        if node_dispatcher_override != null
        else NodeDispatcherScript.new(
            _content_catalog.definition("node_content") if _content_catalog.loaded else {}))
    _consumable_repository = (
        consumable_repository_override
        if consumable_repository_override != null
        else ConsumableRepositoryScript.new())
    if consumable_repository_override == null and _content_catalog.loaded:
        _consumable_repository.configure(_content_catalog.definition("consumables"))
    elif consumable_repository_override == null:
        _consumable_repository.consumables.clear()
    _starter_build_repository = (
        starter_build_repository_override
        if starter_build_repository_override != null
        else StarterBuildRepositoryScript.new())
    _starter_build_assembler = (
        starter_build_assembler_override
        if starter_build_assembler_override != null
        else StarterBuildAssemblerScript.new(_content_catalog))
    _battle_session_factory = (
        battle_session_factory_override
        if battle_session_factory_override != null
        else BattleSessionFactoryScript.new(
            game_log, _content_catalog, runtime_profile))
    _node_reward_service = (
        node_reward_service_override
        if node_reward_service_override != null
        else NodeRewardServiceScript.new(
            _content_catalog.definition("node_rewards")
            if _content_catalog.loaded else {},
            RunMutationServiceScript.new(
                _content_catalog.run_effect_registry, _content_catalog)))
    _practice_service = PracticeServiceScript.new(_content_catalog)
    _inner_skill_repository = InnerSkillRepositoryScript.new()
    if _content_catalog.loaded:
        _inner_skill_repository.configure(
            _content_catalog.definition("inner_skills"))
    _inner_skill_loadout_service = InnerSkillLoadoutServiceScript.new(
        growth, _inner_skill_repository)
    _run_build_query_service = RunBuildQueryServiceScript.new(
        growth, _content_catalog, _inner_skill_loadout_service)
    _consumable_use_service = (
        consumable_use_service_override
        if consumable_use_service_override != null
        else ConsumableUseServiceScript.new(
            _content_catalog.consumable_effect_registry,
            _content_catalog,
            ContentValidator.HAND_IDS,
            ContentValidator.POOL_IDS))
    _node_interaction_service = (
        node_interaction_service_override
        if node_interaction_service_override != null
        else NodeInteractionServiceScript.new(
            _content_catalog.node_interaction_registry,
            _node_reward_service.mutation_service,
            _content_catalog))
    if not _content_catalog.loaded:
        game_log.record_system(
            "error",
            "content_catalog",
            "本局内容目录校验失败",
            "\n".join(_content_catalog.errors))
    else:
        _starter_build_repository.configure(
            _content_catalog.definition("starter_builds"))
    _run_state.changed.connect(_on_run_state_changed)

func create_battle_session() -> BattleSession:
    var session = _battle_session_factory.create()
    if _ai_settings_service != null \
            and _ai_settings_service.has_method("runtime_profile"):
        session.configure_ai_runtime(
            _ai_settings_service.runtime_profile(true))
    _active_battle_session = session
    return session

func configure_ai_settings_service(service) -> void:
    _ai_settings_service = service

func ai_settings_snapshot() -> Dictionary:
    if _ai_settings_service == null \
            or not _ai_settings_service.has_method("public_snapshot"):
        return {}
    return _ai_settings_service.public_snapshot()

func execute(command: Dictionary) -> CommandResult:
    var command_type := str(command.get("type", ""))
    var change_serial_before := _persistent_change_serial
    var persistence_state_before := _capture_persistence_state()
    var result: Dictionary
    match command_type:
        "setup_run":
            result = _setup_run(
                (
                    int(command["seed"])
                    if command.has("seed")
                    else runtime_profile.default_seed()),
                str(command.get(
                    "starter_build_id",
                    StarterBuildRepositoryScript.DEFAULT_BUILD_ID)))
        "begin_node":
            result = _begin_node(str(command.get("node_id", "")))
        "complete_node":
            result = _complete_node()
        "resolve_battle_result":
            result = _resolve_battle_result(
                command.get("battle_result"),
                command.get("progress_snapshot"))
        "abandon_run":
            result = _abandon_run()
        "resume_current_node":
            result = _resume_current_node()
        "query_node_interaction":
            result = _query_node_interaction()
        "commit_node_interaction":
            result = _commit_node_interaction(
                str(command.get("interaction_token", command.get("token", ""))),
                str(command.get("choice_id", "")),
                command.get("choice_payload", {}))
        "cancel_node_interaction":
            result = _cancel_node_interaction(
                str(command.get("interaction_token", command.get("token", ""))))
        "claim_reward":
            result = _claim_reward(str(command.get("bundle_id", "")))
        "complete_boss_chest":
            result = _complete_boss_chest()
        "open_practice":
            result = _open_practice()
        "close_practice":
            result = _close_practice()
        "purchase_practice_offer":
            result = _purchase_practice_offer(
                str(command.get("group", "normal")),
                int(command.get("slot_index", -1)))
        "open_practice_pack":
            result = _open_practice_pack(
                str(command.get("group", "packs")),
                int(command.get("slot_index", -1)),
                command.get("selected_ids", []),
                str(command.get("preparation_token", "")))
        "meditate":
            result = _meditate()
        "get_hand_technique_loadout":
            result = {"success": true, "loadout": growth.get_hand_technique_loadout(
                str(command.get("hand_id", "")))}
        "get_run_build":
            result = _get_run_build()
        "set_hand_technique_loadout":
            result = _set_hand_technique_loadout(
                str(command.get("hand_id", "")), command.get("technique_ids", []))
        "get_inner_skill_loadout":
            result = _get_inner_skill_loadout()
        "set_inner_skill_loadout":
            result = _set_inner_skill_loadout(
                command.get("equipped_inner_skill_ids", []),
                command.get("technique_slot_index", -1))
        "forget_inner_skill":
            result = _forget_inner_skill(
                str(command.get("inner_skill_id", "")))
        "purchase_consumable":
            result = _purchase_consumable(str(command.get("consumable_id", "")))
        "query_consumable_use":
            result = _query_consumable_use(
                int(command.get("slot_index", -1)), int(command.get("run_seed", navigation.seed)))
        "use_consumable":
            result = _use_consumable(
                int(command.get("slot_index", -1)),
                command.get("selected_instance_ids", []),
                command.get("choice_payload", {}))
        _:
            result = {"success": false, "reason": "未知本局命令：%s" % command_type}
    if not result.get("success", false) \
            and not bool(result.get("suppress_rejection_log", false)):
        _record_command_rejected(command_type, str(result.get("reason", "命令执行失败")))
    result.erase("suppress_rejection_log")
    var command_result = CommandResultScript.from_dict(command_type, result)
    if command_result.success \
            and _persistent_change_serial != change_serial_before \
            and _capture_persistence_state() != persistence_state_before:
        persistence_boundary_reached.emit(command_type)
    return command_result

func snapshot() -> RunSnapshot:
    var graph: Dictionary = navigation.graph.duplicate(true)
    var completed: Dictionary = navigation.completed_node_ids.duplicate(true)
    var available: Array[String] = navigation.available_node_ids()
    return RunSnapshotScript.from_dict({
        "seed": navigation.seed,
        "starter_build_id": selected_starter_build_id,
        "act": navigation.act,
        "act_count": int(navigation.map_generator.rules.get("acts", 3)),
        "phase": navigation.phase,
        "experience": growth.experience,
        "current_node_id": navigation.current_node_id,
        "completed_node_ids": completed,
        "completed_node_count": completed.size(),
        "available_node_ids": available,
        "available_node_count": available.size(),
        "can_open_practice": navigation.can_open_practice(),
        "reward": _reward_snapshot(),
        "graph": graph,
        "practice": _practice_snapshot(),
        "growth": _growth_snapshot(),
        "run_log": game_log.entries("run", 200),
        "battle_log": game_log.entries("battle", 200),
        "system_log": game_log.entries("system", 200),
        "runtime_mode": runtime_profile.mode_name(),
        "debug_menu_enabled": runtime_profile.allows_debug_menu(),
        "terminal_result": (
            _run_state.terminal_result.to_dict()
            if _run_state.terminal_result != null else {}),
    })

func drain_events() -> Array:
    var drained := _event_queue.duplicate()
    _event_queue.clear()
    return drained

func progress_snapshot() -> RunProgressSnapshot:
    return growth.to_progress_snapshot()

func available_starter_builds() -> Array:
    return _starter_build_repository.available_builds()

func sync_progress_snapshot(progress_snapshot: RunProgressSnapshot) -> void:
    if progress_snapshot == null:
        return
    var before: Dictionary = growth.to_progress_snapshot().to_dict()
    growth.apply_progress_snapshot(progress_snapshot)
    var after: Dictionary = growth.to_progress_snapshot().to_dict()
    if before == after:
        return
    var entry: Dictionary = game_log.record_run(
        "growth_sync",
        "战斗成长同步到本局",
        "牌组 %d 张，消耗品 %d/3，已获功法 %d 门" % [
            growth.run_deck.card_count(),
            growth.consumable_ids.size(),
            growth.learned_technique_ids.size()],
        {"act": navigation.act, "phase": navigation.phase})
    _queue_event("growth_synced", entry, {
        "run_deck_count": growth.run_deck.card_count(),
        "consumable_count": growth.consumable_ids.size(),
        "learned_technique_count": growth.learned_technique_ids.size(),
    })
    _run_state.changed.emit()

func _setup_run(seed_value: int, starter_build_id: String) -> Dictionary:
    if not _content_catalog.loaded:
        return {"success": false, "reason": "统一内容目录无效"}
    var build_check: Dictionary = _starter_build_repository.validate_selection(
        starter_build_id)
    if not build_check.get("success", false):
        return build_check
    var assembled: Dictionary = _starter_build_assembler.assemble_into_run_deck(
        build_check["definition"], "run-%d" % seed_value)
    if not assembled.get("success", false):
        return assembled
    _close_active_battle_session()
    game_log.clear("run")
    game_log.clear("battle")
    _event_queue.clear()
    _event_serial = 0
    _pending_reward = null
    _pending_victory_battle_result.clear()
    _node_interaction_service.clear()
    _run_state.terminal_result = null
    growth.reset(
        "run-%d" % seed_value,
        assembled["run_deck"],
        _player_max_life_for_act(1))
    selected_starter_build_id = starter_build_id
    navigation.setup(seed_value)
    _practice_service.start_new_shop(growth, seed_value, 1, 1)
    _run_state.changed.emit()
    var entry: Dictionary = game_log.record_run(
        "run_lifecycle",
        "建立新本局",
        "%s · 第 1 层路线已生成" % build_check["definition"].get(
            "name", starter_build_id),
        {
            "seed": seed_value,
            "act": 1,
            "phase": navigation.phase,
            "starter_build_id": starter_build_id,
        })
    _queue_event("run_setup", entry, {
        "seed": seed_value,
        "act": 1,
        "starter_build_id": starter_build_id,
    })
    return {
        "success": true,
        "seed": seed_value,
        "act": 1,
        "starter_build_id": starter_build_id,
    }

func _begin_node(node_id: String) -> Dictionary:
    var node: Dictionary = navigation.node_definition(node_id)
    var dispatch: Dictionary = _node_dispatcher.dispatch(
        node,
        navigation.node_dispatch_context())
    if not dispatch.get("success", false):
        return dispatch
    var interaction_result: Dictionary = {}
    if str(dispatch.get("route", "")) == "interaction":
        interaction_result = _node_interaction_service.prepare(
            dispatch, growth, {
                "source_kind": "map_node",
                "source_id": node_id,
                "run_seed": navigation.seed,
            })
        if not interaction_result.get("success", false):
            return interaction_result
    var result: Dictionary = navigation.begin_node(node_id)
    if not result.get("success", false):
        if not interaction_result.is_empty() \
                and not interaction_result.get("reused", false):
            _node_interaction_service.clear()
        return result
    _run_state.changed.emit()
    result["dispatch"] = dispatch.duplicate(true)
    if not interaction_result.is_empty():
        result["interaction"] = interaction_result.get(
            "interaction", {}).duplicate(true)
    var entry: Dictionary = game_log.record_run(
        "node_lifecycle",
        "进入节点",
        "%s · %s" % [dispatch.get("title", node_id), dispatch.get("route", "")],
        {
            "seed": navigation.seed,
            "act": navigation.act,
            "node_id": node_id,
            "node_type": dispatch.get("node_type", ""),
            "content_id": dispatch.get("content_id", ""),
            "content_seed": dispatch.get("content_seed", 0),
        })
    _queue_event("node_started", entry, {
        "node_id": node_id,
        "node_type": dispatch.get("node_type", ""),
        "route": dispatch.get("route", ""),
    })
    return result

func _resolve_battle_result(
        battle_result,
        progress_snapshot) -> Dictionary:
    if navigation.phase != "node_in_progress":
        return {
            "success": false,
            "reason": "当前没有可结算的进行中战斗",
            "suppress_rejection_log": navigation.is_terminal(),
        }
    var gate := _validate_battle_final_result(battle_result)
    if not gate.get("success", false):
        return gate
    var state := str(battle_result.battle_state)
    if state in ["player_victory", "player_defeat"] \
            and not progress_snapshot is RunProgressSnapshot:
        return {"success": false, "reason": "战斗结果缺少绝对 progress_snapshot"}
    _close_active_battle_session()
    match state:
        "player_victory":
            sync_progress_snapshot(progress_snapshot)
            _pending_victory_battle_result = battle_result.to_dict()
            var completion := _complete_node_to_reward()
            if not completion.get("success", false):
                _pending_victory_battle_result.clear()
                return completion
            return completion
        "player_defeat":
            sync_progress_snapshot(progress_snapshot)
            return _terminate_from_battle_result(
                battle_result, "defeat", "玩家在战斗中失败")
        "unresolved_draw":
            return _terminate_from_battle_result(
                battle_result,
                "unresolved_rule",
                "双方同时倒下\n当前胜负规则尚未确认，本局无法继续结算。")
        "scenario_error":
            return _terminate_from_battle_result(
                battle_result, "scenario_error", str(battle_result.detail))
    return {"success": false, "reason": "未知战斗终止状态"}

func _validate_battle_final_result(battle_result) -> Dictionary:
    if battle_result == null \
            or battle_result.get_script() != BattleFinalResultDTOScript \
            or not battle_result.is_terminal():
        return {"success": false, "reason": "battle_result 必须是已终止战斗的正式 DTO"}
    var dispatch := _current_node_dispatch()
    if not dispatch.get("success", false):
        return dispatch
    if str(dispatch.get("route", "")) != "battle":
        return {"success": false, "reason": "当前节点不是战斗路由"}
    if str(battle_result.node_id) != navigation.current_node_id:
        return {"success": false, "reason": "战斗结果 node_id 已过期或不匹配"}
    if int(battle_result.act) != navigation.act:
        return {"success": false, "reason": "战斗结果 act 已过期或不匹配"}
    if int(battle_result.content_seed) != int(dispatch.get("content_seed", 0)):
        return {"success": false, "reason": "战斗结果 content_seed 已过期或不匹配"}
    if str(battle_result.content_id) != str(dispatch.get("content_id", "")):
        return {"success": false, "reason": "战斗结果 content_id 已过期或不匹配"}
    if str(battle_result.node_type) != str(dispatch.get("node_type", "")):
        return {"success": false, "reason": "战斗结果 node_type 不匹配"}
    return {"success": true, "dispatch": dispatch}

func _terminate_from_battle_result(
        battle_result,
        kind: String,
        default_detail: String) -> Dictionary:
    var detail := str(battle_result.detail)
    if kind == "unresolved_rule":
        detail = default_detail
    elif detail == "":
        detail = default_detail
    var terminal = RunTerminalResultDTOScript.from_dict({
        "schema_version": RunTerminalResultDTOScript.SCHEMA_VERSION,
        "kind": kind,
        "source": "battle",
        "detail": detail,
        "battle_state": str(battle_result.battle_state),
        "act": int(battle_result.act),
        "node_id": str(battle_result.node_id),
        "node_type": str(battle_result.node_type),
        "turn_number": int(battle_result.turn_number),
    })
    if terminal == null:
        return {"success": false, "reason": "无法建立本局终局结果"}
    return _enter_terminal(terminal, false)

func _abandon_run() -> Dictionary:
    if navigation.is_terminal() or _run_state.terminal_result != null:
        return {
            "success": false,
            "reason": "本局已经结束，不能重复放弃",
            "suppress_rejection_log": true,
        }
    if navigation.phase not in [
            "awaiting_node", "node_in_progress", "awaiting_reward", "boss_chest"]:
        return {"success": false, "reason": "当前阶段不能放弃本局"}
    var node: Dictionary = navigation.node_definition(navigation.current_node_id)
    var terminal = RunTerminalResultDTOScript.from_dict({
        "schema_version": RunTerminalResultDTOScript.SCHEMA_VERSION,
        "kind": "abandoned",
        "source": "player_command",
        "detail": "玩家主动放弃本局",
        "battle_state": "",
        "act": navigation.act,
        "node_id": navigation.current_node_id,
        "node_type": str(node.get("type", "")),
        "turn_number": 0,
    })
    return _enter_terminal(terminal, false)

func _enter_terminal(terminal_result, already_complete: bool) -> Dictionary:
    if terminal_result == null or not terminal_result.is_valid():
        return {"success": false, "reason": "终局结果无效"}
    if _run_state.terminal_result != null:
        return {
            "success": false,
            "reason": "本局终局已经记录",
            "suppress_rejection_log": true,
        }
    _close_active_battle_session()
    if already_complete:
        if navigation.phase != "run_complete" or not terminal_result.is_victory():
            return {"success": false, "reason": "通关终局与本局阶段不一致"}
    else:
        var transition: Dictionary = navigation.terminate_run()
        if not transition.get("success", false):
            return transition
    _pending_reward = null
    _pending_victory_battle_result.clear()
    _node_interaction_service.clear()
    _run_state.terminal_result = terminal_result
    _run_state.changed.emit()
    var event_type := _terminal_event_type(terminal_result.kind)
    var metadata := {
        "kind": terminal_result.kind,
        "act": terminal_result.act,
        "node_id": terminal_result.node_id,
        "node_type": terminal_result.node_type,
        "battle_state": terminal_result.battle_state,
        "turn_number": terminal_result.turn_number,
    }
    var entry: Dictionary = game_log.record_run(
        event_type,
        _terminal_title(terminal_result.kind),
        terminal_result.detail,
        metadata)
    _queue_event(event_type, entry, metadata)
    return {
        "success": true,
        "phase": navigation.phase,
        "terminal_result": terminal_result.to_dict(),
    }

func _complete_victory_terminal() -> Dictionary:
    var node: Dictionary = navigation.node_definition(navigation.current_node_id)
    var battle_values := _pending_victory_battle_result
    var terminal = RunTerminalResultDTOScript.from_dict({
        "schema_version": RunTerminalResultDTOScript.SCHEMA_VERSION,
        "kind": "victory",
        "source": "battle_reward",
        "detail": "第三层 Boss 的完整奖励与功行已经结算，本局通关。",
        "battle_state": str(battle_values.get("battle_state", "player_victory")),
        "act": navigation.act,
        "node_id": navigation.current_node_id,
        "node_type": str(node.get("type", battle_values.get("node_type", "boss"))),
        "turn_number": int(battle_values.get("turn_number", 0)),
    })
    return _enter_terminal(terminal, true)

func _terminal_event_type(kind: String) -> String:
    return {
        "victory": "run_completed",
        "defeat": "run_defeated",
        "abandoned": "run_abandoned",
        "unresolved_rule": "run_rule_unresolved",
        "scenario_error": "run_scenario_error",
    }.get(kind, "run_terminated")

func _terminal_title(kind: String) -> String:
    return {
        "victory": "本局通关",
        "defeat": "本局战败",
        "abandoned": "本局已放弃",
        "unresolved_rule": "本局因规则未确认而终止",
        "scenario_error": "本局因场景错误而终止",
    }.get(kind, "本局结束")

func _close_active_battle_session() -> bool:
    if _active_battle_session == null:
        return false
    var cancelled := bool(_active_battle_session.close_battle())
    _active_battle_session = null
    return cancelled

func _complete_node() -> Dictionary:
    var dispatch := _current_node_dispatch()
    if not dispatch.get("success", false):
        return dispatch
    if str(dispatch.get("route", "")) == "interaction":
        return {"success": false, "reason": "节点交互尚未成功提交"}
    return _complete_node_to_reward()

func _complete_node_to_reward() -> Dictionary:
    var act_before: int = navigation.act
    var result: Dictionary = navigation.complete_current_node_to_reward()
    if not result.get("success", false):
        return result
    var node: Dictionary = result.get("node", {})
    _pending_reward = _node_reward_service.create_bundle(node, {
        "seed": navigation.seed,
        "act": act_before,
    })
    _run_state.changed.emit()
    var entry: Dictionary = game_log.record_run(
        "reward_lifecycle",
        "建立节点奖励",
        "%s · 待领取历练 %d" % [
            node.get("type", ""), _pending_reward.total("experience")],
        {
            "act": act_before,
            "node_id": node.get("id", ""),
            "node_type": node.get("type", ""),
            "bundle_id": _pending_reward.bundle_id(),
            "experience_reward": _pending_reward.total("experience"),
        })
    _queue_event("reward_created", entry, {
        "act": act_before,
        "node_id": node.get("id", ""),
        "bundle_id": _pending_reward.bundle_id(),
        "experience_reward": _pending_reward.total("experience"),
    })
    result["reward"] = _pending_reward.to_dict()
    return result

func _query_node_interaction() -> Dictionary:
    var gate := _node_interaction_gate()
    if not gate.get("success", false):
        return gate
    var interaction: Dictionary = _node_interaction_service.query_active()
    if interaction.is_empty():
        return {"success": false, "reason": "当前没有待选择的节点交互"}
    return {"success": true, "interaction": interaction}

func _commit_node_interaction(
        token: String,
        choice_id: String,
        choice_payload) -> Dictionary:
    var gate := _node_interaction_gate()
    if not gate.get("success", false):
        return gate
    var pending: Dictionary = _node_interaction_service.capture_pending()
    if str(pending.get("node_id", "")) != navigation.current_node_id:
        return {"success": false, "reason": "待提交交互与当前节点不一致"}
    if token != str(pending.get("token", "")):
        return {"success": false, "reason": "interaction_token 不匹配"}
    var interaction_result: Dictionary = _node_interaction_service.commit(
        token, choice_id, choice_payload, growth)
    if not interaction_result.get("success", false):
        return interaction_result
    var completion: Dictionary = _complete_node_to_reward()
    if not completion.get("success", false):
        return completion
    _node_interaction_service.clear()
    completion["interaction_result"] = interaction_result.get(
        "interaction_result", {}).duplicate(true)
    completion["applied"] = interaction_result.get("applied", []).duplicate(true)
    completion["changed"] = bool(interaction_result.get("changed", false))
    completion["interaction_token"] = token
    return completion

func _cancel_node_interaction(token: String) -> Dictionary:
    var gate := _node_interaction_gate()
    if not gate.get("success", false):
        return gate
    var pending: Dictionary = _node_interaction_service.capture_pending()
    if str(pending.get("node_id", "")) != navigation.current_node_id:
        return {"success": false, "reason": "待取消交互与当前节点不一致"}
    return _node_interaction_service.cancel(token)

func _node_interaction_gate() -> Dictionary:
    if navigation.phase != "node_in_progress":
        return {"success": false, "reason": "当前阶段没有进行中的节点交互"}
    var dispatch := _current_node_dispatch()
    if not dispatch.get("success", false):
        return dispatch
    if str(dispatch.get("route", "")) != "interaction":
        return {"success": false, "reason": "当前节点不是 interaction 路由"}
    return {"success": true, "dispatch": dispatch}

func _current_node_dispatch() -> Dictionary:
    if navigation.current_node_id == "":
        return {"success": false, "reason": "当前没有节点"}
    return _node_dispatcher.dispatch(
        navigation.node_definition(navigation.current_node_id),
        navigation.node_dispatch_context())

func _resume_current_node() -> Dictionary:
    if navigation.phase != "node_in_progress":
        return {"success": false, "reason": "当前没有可从开头恢复的进行中节点"}
    var dispatch := _current_node_dispatch()
    if not dispatch.get("success", false):
        return dispatch
    return {
        "success": true,
        "phase": navigation.phase,
        "dispatch": dispatch.duplicate(true),
    }

func close_active_battle() -> bool:
    return _close_active_battle_session()

func _claim_reward(bundle_id: String) -> Dictionary:
    if navigation.phase != "awaiting_reward" or _pending_reward == null:
        return {"success": false, "reason": "当前没有待领取的节点奖励"}
    if bundle_id != "" and bundle_id != _pending_reward.bundle_id():
        return {"success": false, "reason": "奖励包已过期或不匹配"}
    var bundle_snapshot: Dictionary = _pending_reward.to_dict()
    var apply_result: Dictionary = _node_reward_service.apply_bundle(
        _pending_reward, growth)
    if not apply_result.get("success", false):
        return apply_result
    var interest: Dictionary = _settle_node_experience_interest()
    var navigation_result: Dictionary = navigation.claim_current_node_reward()
    if not navigation_result.get("success", false):
        return navigation_result
    growth.clear_practice_purchases()
    _pending_reward = null
    _run_state.changed.emit()
    var entry: Dictionary = game_log.record_run(
        "reward_lifecycle",
        "领取节点奖励",
        "历练 +%d · 功行生息 +%d · 下一阶段 %s" % [
            int(apply_result.get("applied", []).reduce(
                func(total, value): return total + (
                    int(value.get("amount", 0))
                    if str(value.get("kind", "")) == "experience" else 0), 0)),
            int(interest.get("amount", 0)),
            navigation_result.get("phase", "")],
        {
            "act": int(bundle_snapshot.get("act", navigation.act)),
            "node_id": bundle_snapshot.get("node_id", ""),
            "node_type": bundle_snapshot.get("node_type", ""),
            "bundle_id": bundle_snapshot.get("id", ""),
            "applied": apply_result.get("applied", []).duplicate(true),
            "experience_interest": interest.duplicate(true),
            "experience": growth.experience,
            "next_phase": navigation_result.get("phase", ""),
        })
    _queue_event("reward_claimed", entry, {
        "bundle_id": bundle_snapshot.get("id", ""),
        "experience_interest": interest.duplicate(true),
        "experience": growth.experience,
        "next_phase": navigation_result.get("phase", ""),
    })
    navigation_result["bundle"] = bundle_snapshot
    navigation_result["applied"] = apply_result.get("applied", []).duplicate(true)
    navigation_result["experience_interest"] = interest.duplicate(true)
    navigation_result["experience"] = growth.experience
    if navigation_result.get("phase", "") == "awaiting_node":
        _practice_service.start_new_shop(
            growth, navigation.seed, navigation.act,
            int(growth.practice_shop_state.get("shop_index", 0)) + 1)
    elif navigation_result.get("phase", "") == "run_complete":
        var terminal_result := _complete_victory_terminal()
        if not terminal_result.get("success", false):
            return terminal_result
        navigation_result["terminal_result"] = terminal_result.get(
            "terminal_result", {}).duplicate(true)
    return navigation_result

func _reward_snapshot() -> Dictionary:
    if _pending_reward == null:
        return {
            "available": false,
            "bundle": {},
            "experience_total": 0,
        }
    return {
        "available": true,
        "bundle": _pending_reward.to_dict(),
        "experience_total": _pending_reward.total("experience"),
    }

func _complete_boss_chest() -> Dictionary:
    if navigation.phase != "boss_chest":
        return {"success": false, "reason": "当前没有待完成的 Boss 宝箱"}
    var act_before: int = navigation.act
    var interest: Dictionary = _settle_node_experience_interest()
    var result: Dictionary = navigation.complete_boss_chest()
    if not result.get("success", false):
        return result
    result["experience_interest"] = interest.duplicate(true)
    result["experience"] = growth.experience
    growth.grow_life_to(_player_max_life_for_act(navigation.act))
    _practice_service.start_new_shop(
        growth, navigation.seed, navigation.act,
        int(growth.practice_shop_state.get("shop_index", 0)) + 1)
    result["life"] = growth.life
    result["max_life"] = growth.max_life
    _run_state.changed.emit()
    var entry: Dictionary = game_log.record_run(
        "run_lifecycle",
        "完成 Boss 宝箱流程",
        "第 %d 层进入第 %d 层" % [act_before, result.get("act", act_before)],
        {
            "act": act_before,
            "next_act": result.get("act", act_before),
            "next_phase": result.get("phase", ""),
            "experience_interest": interest.duplicate(true),
            "experience": growth.experience,
            "life": growth.life,
            "max_life": growth.max_life,
        })
    _queue_event("boss_chest_completed", entry, {
        "act": act_before,
        "next_act": result.get("act", act_before),
        "experience_interest": interest.duplicate(true),
        "experience": growth.experience,
        "life": growth.life,
        "max_life": growth.max_life,
    })
    return result

func _open_practice() -> Dictionary:
    if not navigation.can_open_practice():
        return {"success": false, "reason": "当前节点尚未完成，不能修习"}
    var entry: Dictionary = game_log.record_run(
        "practice_lifecycle",
        "打开修习",
        "当前历练 %d" % growth.experience,
        {"act": navigation.act, "experience": growth.experience})
    _queue_event("practice_opened", entry, {"act": navigation.act})
    return {"success": true}

func _close_practice() -> Dictionary:
    var entry: Dictionary = game_log.record_run(
        "practice_lifecycle",
        "关闭修习",
        "返回地图待选状态",
        {"act": navigation.act, "phase": navigation.phase})
    _queue_event("practice_closed", entry, {"act": navigation.act})
    return {"success": true}

func _purchase_consumable(consumable_id: String) -> Dictionary:
    var definition: Dictionary = _consumable_repository.get_consumable(consumable_id)
    if definition.is_empty() or not _consumable_repository.practice_offers().has(consumable_id):
        return {"success": false, "reason": "当前修习没有该选项"}
    var price := int(definition.get("price", 0))
    var result: Dictionary = growth.purchase_consumable(
        consumable_id,
        price,
        navigation.can_open_practice())
    if not result.get("success", false):
        return result
    _run_state.changed.emit()
    result["price"] = price
    result["definition"] = definition.duplicate(true)
    var entry: Dictionary = game_log.record_run(
        "practice_purchase",
        "修习购入",
        "%s · 历练 -%d" % [definition.get("name", consumable_id), price],
        {
            "act": navigation.act,
            "consumable_id": consumable_id,
            "kind": definition.get("kind", ""),
            "price": price,
            "remaining_experience": growth.experience,
        })
    _queue_event("practice_purchased", entry, {
        "consumable_id": consumable_id,
        "price": price,
        "remaining_experience": growth.experience,
    })
    return result

func _query_consumable_use(slot_index: int, run_seed: int = 0) -> Dictionary:
    if slot_index < 0 or slot_index >= growth.consumable_ids.size():
        return {
            "success": true,
            "consumable_id": "",
            "name": "",
            "description": "",
            "targeting": {"zone": "none", "selection": "deterministic_random"},
            "zone": "none",
            "selection": "deterministic_random",
            "minimum": 0,
            "maximum": 0,
            "eligible_targets": [],
            "can_use": false,
            "reason": "消耗品槽位无效",
        }
    var consumable_id := str(growth.consumable_ids[slot_index])
    var definition: Dictionary = _consumable_repository.get_consumable(consumable_id)
    var result: Dictionary = _consumable_use_service.query_use(
        growth, slot_index, definition, run_seed)
    if not result.get("success", false):
        return {
            "success": true,
            "consumable_id": consumable_id,
            "name": str(definition.get("name", "")),
            "description": str(definition.get("description", "")),
            "targeting": {
                "zone": str(definition.get("targeting", {}).get("zone", "none")),
                "selection": str(definition.get("targeting", {}).get("selection", "")),
            },
            "zone": str(definition.get("targeting", {}).get("zone", "none")),
            "selection": str(definition.get("targeting", {}).get("selection", "")),
            "minimum": int(definition.get("targeting", {}).get("minimum", 0)),
            "maximum": int(definition.get("targeting", {}).get("maximum", 0)),
            "eligible_targets": [],
            "can_use": false,
            "reason": str(result.get("reason", "消耗品不可用")),
        }
    if not navigation.can_open_practice():
        result["can_use"] = false
        result["reason"] = "节点执行中、战斗中或奖励流程未完成，不能使用消耗品"
    result["phase"] = navigation.phase
    return result

func _use_consumable(
        slot_index: int,
        selected_instance_ids: Array,
        choice_payload = {}) -> Dictionary:
    if not choice_payload is Dictionary:
        return {"success": false, "reason": "choice_payload 必须是对象"}
    var gate := _consumable_use_gate()
    if not gate.get("allowed", false):
        return {"success": false, "reason": str(gate.get("reason", "当前阶段不能使用消耗品"))}
    if slot_index < 0 or slot_index >= growth.consumable_ids.size():
        return {"success": false, "reason": "消耗品槽位无效"}
    var consumable_id := str(growth.consumable_ids[slot_index])
    var definition: Dictionary = _consumable_repository.get_consumable(consumable_id)
    var result: Dictionary = _consumable_use_service.use(
        growth, slot_index, selected_instance_ids, navigation.seed, definition,
        choice_payload)
    if not result.get("success", false):
        return result
    _run_state.changed.emit()
    var details: Array[String] = []
    for applied in result.get("applied", []):
        if applied is Dictionary:
            details.append_array(applied.get("details", []))
    result["definition"] = definition.duplicate(true)
    result["detail"] = "；".join(details)
    var entry: Dictionary = game_log.record_run(
        "consumable_use",
        "使用消耗品",
        "%s · %s" % [definition.get("name", consumable_id), "；".join(details)],
        {
            "act": navigation.act,
            "consumable_id": consumable_id,
            "slot_index": slot_index,
            "consumable_use_sequence": growth.consumable_use_sequence,
        })
    _queue_event("consumable_used", entry, {
        "consumable_id": consumable_id,
        "slot_index": slot_index,
        "consumable_use_sequence": growth.consumable_use_sequence,
        "detail": "；".join(details),
    })
    return result

func _consumable_use_gate() -> Dictionary:
    if not navigation.can_open_practice():
        return {"allowed": false, "reason": "节点执行中、战斗中或奖励流程未完成，不能使用消耗品"}
    if _pending_reward != null:
        return {"allowed": false, "reason": "奖励尚未领取完成，不能使用消耗品"}
    return {"allowed": true, "reason": ""}

func _run_build_edit_gate() -> Dictionary:
    if _pending_reward != null or navigation.phase == "awaiting_reward":
        return {
            "allowed": false,
            "reason": "奖励尚未领取完成，不能修改本局构筑",
        }
    if navigation.phase == "boss_chest":
        return {
            "allowed": false,
            "reason": "Boss 宝箱流程中不能修改本局构筑",
        }
    if not navigation.can_open_practice():
        return {
            "allowed": false,
            "reason": "节点执行中或战斗中不能修改本局构筑",
        }
    return {"allowed": true, "reason": ""}

func _get_inner_skill_loadout() -> Dictionary:
    var gate := _run_build_edit_gate()
    var loadout = _inner_skill_loadout_service.get_loadout(
        bool(gate.get("allowed", false)), str(gate.get("reason", "")))
    return {"success": true, "loadout": loadout.to_dict()}

func _get_run_build() -> Dictionary:
    var gate := _run_build_edit_gate()
    var build = _run_build_query_service.query(
        bool(gate.get("allowed", false)), str(gate.get("reason", "")))
    return {"success": true, "build": build.to_dict()}

func _set_inner_skill_loadout(
        equipped_inner_skill_ids,
        technique_slot_index) -> Dictionary:
    var gate := _run_build_edit_gate()
    if not gate.get("allowed", false):
        return {"success": false, "reason": str(gate.get("reason", ""))}
    var result: Dictionary = _inner_skill_loadout_service.set_loadout(
        equipped_inner_skill_ids, technique_slot_index)
    if result.get("success", false):
        _run_state.changed.emit()
    return result

func _forget_inner_skill(inner_skill_id: String) -> Dictionary:
    var gate := _run_build_edit_gate()
    if not gate.get("allowed", false):
        return {"success": false, "reason": str(gate.get("reason", ""))}
    var result: Dictionary = _inner_skill_loadout_service.forget_inner_skill(
        inner_skill_id)
    if result.get("success", false):
        _run_state.changed.emit()
    return result

func _set_hand_technique_loadout(
        hand_id: String,
        technique_ids) -> Dictionary:
    var gate := _run_build_edit_gate()
    if not gate.get("allowed", false):
        return {"success": false, "reason": str(gate.get("reason", ""))}
    if not technique_ids is Array:
        return {"success": false, "reason": "technique_ids 必须是数组"}
    var result: Dictionary = growth.set_hand_technique_loadout(
        hand_id, technique_ids)
    if result.get("success", false):
        _run_state.changed.emit()
    return result

func _purchase_practice_offer(group: String, slot_index: int) -> Dictionary:
    if not navigation.can_open_practice():
        return {"success": false, "reason": "当前节点尚未完成，不能修习"}
    var result: Dictionary = _practice_service.purchase(
        growth, group, slot_index, navigation.can_open_practice())
    if result.get("success", false):
        _run_state.changed.emit()
    return result

func _open_practice_pack(
        group: String,
        slot_index: int,
        selected_ids: Array,
        preparation_token: String = "") -> Dictionary:
    var result: Dictionary = _practice_service.open_pack(
        growth, group, slot_index, selected_ids,
        navigation.can_open_practice(),
        navigation.seed, navigation.act, preparation_token)
    if result.get("success", false) and not result.has("preview"):
        _run_state.changed.emit()
    return result

func _meditate() -> Dictionary:
    var result: Dictionary = _practice_service.meditate(
        growth, navigation.seed, navigation.act, navigation.can_open_practice())
    if result.get("success", false):
        _run_state.changed.emit()
    return result

func _practice_snapshot() -> Dictionary:
    var shop_state: Dictionary = _practice_service.ensure_shop(
        growth, navigation.seed, navigation.act)
    var offer_ids: Array[String] = _consumable_repository.practice_offers()
    var offers: Array = []
    for consumable_id in offer_ids:
        var definition: Dictionary = _consumable_repository.get_consumable(consumable_id).duplicate(true)
        if definition.is_empty():
            continue
        var price := int(definition.get("price", 0))
        var purchased: bool = growth.practice_purchases.has(consumable_id)
        definition["purchased"] = purchased
        definition["can_purchase"] = (
            navigation.can_open_practice()
            and not purchased
            and growth.experience >= price
            and growth.consumable_ids.size() < GrowthInventoryScript.CONSUMABLE_LIMIT)
        offers.append(definition)
    var normal := _decorate_practice_slots(
        shop_state.get("normal", []), "normal")
    var packs := _decorate_practice_slots(
        shop_state.get("packs", []), "packs")
    var items := _decorate_practice_slots(
        shop_state.get("items", []), "items")
    return {
        "available": navigation.can_open_practice(),
        "offer_ids": offer_ids,
        "offers": offers,
        "purchased_ids": growth.practice_purchases.keys(),
        "shop": shop_state,
        "normal": normal,
        "packs": packs,
        "items": items,
        "meditation_count": int(shop_state.get("meditation_count", 0)),
        "next_meditation_cost": int(shop_state.get("next_meditation_cost", 5)),
    }

func _decorate_practice_slots(values: Array, group: String) -> Array:
    var result: Array = []
    for value in values:
        if not value is Dictionary or value.is_empty():
            result.append({})
            continue
        var definition: Dictionary = value.duplicate(true)
        var can_purchase: bool = bool(navigation.can_open_practice()) \
            and growth.experience >= int(definition.get("price", 0))
        if str(definition.get("kind", "")) == "consumable":
            can_purchase = can_purchase \
                and growth.consumable_ids.size() < GrowthInventoryScript.CONSUMABLE_LIMIT
        elif str(definition.get("kind", "")) == "consumable_pack":
            can_purchase = can_purchase \
                and growth.consumable_ids.size() < GrowthInventoryScript.CONSUMABLE_LIMIT
        elif str(definition.get("kind", "")) == "item":
            can_purchase = can_purchase \
                and not growth.item_ids.has(str(definition.get("id", "")))
        definition["can_purchase"] = can_purchase
        definition["group"] = group
        result.append(definition)
    return result

func _growth_snapshot() -> Dictionary:
    var consumables: Array = []
    for consumable_id in growth.consumable_ids:
        consumables.append(
            _consumable_repository.get_consumable(consumable_id).duplicate(true))
    var items: Array = []
    for item_id in growth.item_ids:
        items.append(_content_catalog.get_by_id("item", item_id))
    return {
        "life": growth.life,
        "max_life": growth.max_life,
        "consumable_limit": 3,
        "consumable_ids": growth.consumable_ids.duplicate(),
        "consumables": consumables,
        "item_ids": growth.item_ids.duplicate(),
        "items": items,
        "hand_technique_progression": growth.hand_technique_progression.duplicate(true),
        "practice_shop_state": growth.practice_shop_snapshot(),
        "learned_technique_ids": growth.learned_technique_ids.duplicate(),
        "forgotten_inner_skill_count": growth.forgotten_inner_skill_count,
        "run_deck": growth.run_deck.to_snapshot(),
        "run_deck_count": growth.run_deck.card_count(),
        "last_recallable_consumable_id": growth.last_recallable_consumable_id,
        "base_hand_limit_modifier": growth.base_hand_limit_modifier,
        "hand_technique_multiplier_modifiers": growth.hand_technique_multiplier_modifiers.duplicate(true),
        "used_unique_consumable_ids": growth.used_unique_consumable_ids.duplicate(),
    }

func _player_max_life_for_act(act: int) -> int:
    for entry in _content_catalog.definition("act_progression").get("acts", []):
        if int(entry.get("act", 0)) == act:
            return int(entry.get("player", {}).get("max_life", 0))
    return 0

func _settle_node_experience_interest() -> Dictionary:
    return growth.apply_experience_interest()

func _capture_persistence_state() -> Dictionary:
    return {
        "seed": navigation.seed,
        "act": navigation.act,
        "graph": navigation.graph.duplicate(true),
        "phase": navigation.phase,
        "current_node_id": navigation.current_node_id,
        "completed_node_ids": navigation.completed_node_ids.duplicate(true),
        "starter_build_id": selected_starter_build_id,
        "growth": growth.capture_mutation_state(),
        "pending_reward": (
            _pending_reward.to_dict() if _pending_reward != null else {}),
        "pending_node_interaction": (
            _node_interaction_service.capture_pending()
            if _node_interaction_service != null else {}),
        "terminal_result": (
            _run_state.terminal_result.to_dict()
            if _run_state.terminal_result != null else {}),
    }

func _record_command_rejected(command_type: String, reason: String) -> void:
    var entry: Dictionary = game_log.record_system(
        "warning",
        "run_command",
        "本局命令被拒绝",
        reason,
        {"command": command_type, "act": navigation.act, "phase": navigation.phase})
    _queue_event("command_rejected", entry, {
        "command": command_type,
        "reason": reason,
    })

func _queue_event(event_type: String, log_entry: Dictionary, values: Dictionary = {}) -> void:
    _event_queue.append(RunEventScript.create(
        event_type,
        _event_serial,
        int(log_entry.get("serial", -1)),
        values))
    _event_serial += 1

func _on_run_state_changed() -> void:
    _persistent_change_serial += 1
    state_changed.emit()
