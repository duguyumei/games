class_name EnemyActionPlanningService
extends RefCounted

## 敌方行动生成与锁定。
##
## 生成方式可以是脚本、Utility 或远程候选，但最终都在本地复核后锁定；
## 这里不执行伤害与牌区提交，也不允许远程响应直接成为领域动作。

const BattleObservationScript = preload("res://core/battle_observation.gd")
const AiValueQueryServiceScript = preload(
    "res://core/ai/enemy_ai_value_query_service.gd")
const CandidateReducerScript = preload(
    "res://core/ai/enemy_candidate_reducer.gd")
const IntentProjectorScript = preload(
    "res://core/ai/enemy_intent_public_projector.gd")
const ThreatEstimatorScript = preload(
    "res://core/ai/ai_public_threat_estimator.gd")

var enemy
var player
var battle_flow
var enemy_action_controller
var enemy_sequence_book
var scenario
var preview_for_side: Callable
var action_unavailable_reason: Callable
var set_scenario_error: Callable
var read_turn_number: Callable
var read_action_index: Callable
var trigger_queue
var game_log

var enemy_ai_enabled: bool = false
var external_enemy_action_mode: bool = false
var enemy_ai_policy: Dictionary = {}
var locked_enemy_card_ids: Array = []
var locked_enemy_action_proposal = null
var enemy_plan: Dictionary = {}
var possible_enemy_intents: Array = []
var last_candidate_reduction: Dictionary = {}
## 本地私有诊断：包含完整候选卡牌实例和评分，不进入快照或远程请求。
var last_candidate_diagnostics: Dictionary = {}
var public_ai_events: Array = []
var candidate_reducer
var intent_projector := IntentProjectorScript.new()
var threat_estimator := ThreatEstimatorScript.new()

func _init(
        enemy_side,
        player_side,
        flow,
        action_controller,
        sequence_book,
        scripted_scenario,
        preview_callback: Callable,
        unavailable_reason_callback: Callable,
        scenario_error_callback: Callable,
        turn_reader: Callable,
        action_index_reader: Callable,
        history,
        log,
        passive_rule_runtime = null) -> void:
    enemy = enemy_side
    player = player_side
    battle_flow = flow
    enemy_action_controller = action_controller
    enemy_sequence_book = sequence_book
    scenario = scripted_scenario
    preview_for_side = preview_callback
    action_unavailable_reason = unavailable_reason_callback
    set_scenario_error = scenario_error_callback
    read_turn_number = turn_reader
    read_action_index = action_index_reader
    trigger_queue = history
    game_log = log
    candidate_reducer = CandidateReducerScript.new(
        AiValueQueryServiceScript.new(passive_rule_runtime))

func reset() -> void:
    locked_enemy_card_ids.clear()
    locked_enemy_action_proposal = null
    enemy_plan.clear()
    possible_enemy_intents.clear()
    last_candidate_reduction.clear()
    last_candidate_diagnostics.clear()
    public_ai_events.clear()
    enemy_ai_policy.clear()

func set_modes(ai_enabled: bool, uses_external_enemy_actions: bool) -> void:
    enemy_ai_enabled = ai_enabled
    external_enemy_action_mode = uses_external_enemy_actions

func set_policy(policy: Dictionary) -> void:
    enemy_ai_policy = candidate_reducer.normalize_policy(policy)

func use_game_log_queue(history, log) -> void:
    trigger_queue = history
    game_log = log

func decision_observation():
    var observation = BattleObservationScript.new().capture(
        enemy,
        player,
        enemy_sequence_book,
        battle_flow)
    observation.opponent_threat = threat_estimator.estimate(
        player, public_ai_events)
    observation.expected_incoming_damage = int(
        observation.opponent_threat.get("expected", 0))
    return observation

func record_public_ai_event(event: Dictionary) -> void:
    public_ai_events.append(event.duplicate(true))

func remote_action_proposals() -> Array:
    return prepare_candidate_set().get("proposals", [])

func prepare_candidate_set() -> Dictionary:
    possible_enemy_intents.clear()
    last_candidate_reduction.clear()
    last_candidate_diagnostics.clear()
    if not battle_flow.can_act(enemy):
        return {
            "success": true, "full_count": 0, "records": [], "proposals": [],
            "possible_enemy_intents": [],
        }
    var observation = decision_observation()
    var full_proposals: Array = enemy_action_controller.propose_utility_candidates(
        observation,
        func(card_ids: Array): return preview_for_side.call(
            enemy, card_ids, enemy_sequence_book),
        enemy_ai_policy)
    var reduced: Dictionary = candidate_reducer.reduce(
        full_proposals, observation, enemy, player, enemy_ai_policy,
        int(read_turn_number.call()))
    if not reduced.get("success", false):
        set_scenario_error.call(str(reduced.get("reason", "敌方候选压缩失败")))
        return reduced
    possible_enemy_intents = intent_projector.project(reduced["records"])
    reduced["possible_enemy_intents"] = possible_enemy_intents.duplicate(true)
    last_candidate_reduction = {
        "full_count": int(reduced.get("full_count", 0)),
        "pareto_count": int(reduced.get("pareto_count", 0)),
        "reduced_count": reduced.get("proposals", []).size(),
        "candidate_limit": int(reduced.get("candidate_limit", 5)),
    }
    last_candidate_diagnostics = reduced.get(
        "diagnostics", {}).duplicate(true)
    return reduced

func candidate_reduction_diagnostics() -> Dictionary:
    return last_candidate_diagnostics.duplicate(true)

func utility_action_proposal():
    if not battle_flow.can_act(enemy):
        return null
    var candidate_set := prepare_candidate_set()
    if not candidate_set.get("success", false):
        return null
    return choose_from_candidate_set(candidate_set.get("proposals", []))

func choose_from_candidate_set(proposals: Array):
    return enemy_action_controller.choose_utility_proposal(proposals)

func lock_action() -> void:
    clear_action_lock()
    if not battle_flow.can_act(enemy):
        trigger_queue.add_history(
            "enemy_lock", "对手本击无法行动", "行动调度", "跳过",
            action_unavailable_reason.call(enemy))
        return

    if enemy_ai_enabled:
        locked_enemy_action_proposal = utility_action_proposal()
    else:
        var requested_definition_ids: Array = scenario.enemy_action_ids(
            read_turn_number.call(), read_action_index.call())
        locked_enemy_action_proposal = enemy_action_controller.propose_scripted(
            requested_definition_ids,
            func(definition_ids: Array): return enemy.resolve_hand_definition_ids(definition_ids),
            func(card_ids: Array): return preview_for_side.call(
                enemy, card_ids, enemy_sequence_book))
        if not locked_enemy_action_proposal.accepted \
                and not requested_definition_ids.is_empty():
            set_scenario_error.call(
                "第 %d 回合对手行动生成失败：%s｜%s" % [
                    read_turn_number.call(),
                    locked_enemy_action_proposal.rejection_reason,
                    str(requested_definition_ids)])
            return

    if locked_enemy_action_proposal == null \
            or not bool(locked_enemy_action_proposal.accepted):
        battle_flow.forfeit_remaining(enemy, "没有合法出牌方案")
        trigger_queue.add_history(
            "enemy_lock", "对手本击无法行动", "纵切对手", "成功", "没有可用真气或脚本动作")
        return
    var stored: Dictionary = store_action_proposal(
        locked_enemy_action_proposal, "纵切对手")
    if not stored.get("success", false):
        set_scenario_error.call(str(stored.get("reason", "对手行动提案失效")))

func store_external_action(proposal) -> Dictionary:
    if not external_enemy_action_mode:
        return {"success": false, "reason": "战斗未启用外部敌方行动端口"}
    return store_action_proposal(proposal, "远程 AI 行动窗口")

func has_locked_action() -> bool:
    return locked_enemy_action_proposal != null \
        and bool(locked_enemy_action_proposal.accepted) \
        and not locked_enemy_card_ids.is_empty()

func clear_action_lock() -> void:
    locked_enemy_card_ids.clear()
    locked_enemy_action_proposal = null
    enemy_plan.clear()

func store_action_proposal(proposal, source_label: String) -> Dictionary:
    if proposal == null or not bool(proposal.accepted):
        return {"success": false, "reason": "敌方行动提案未被接受"}
    if not battle_flow.can_act(enemy):
        return {"success": false, "reason": action_unavailable_reason.call(enemy)}
    if proposal.card_ids.is_empty():
        return {"success": false, "reason": "敌方行动提案没有真气"}
    for card_id in proposal.card_ids:
        if enemy.find_hand_card(str(card_id)) == null:
            return {"success": false, "reason": "敌方行动提案包含不在当前手牌的真气：%s" % card_id}
    var revalidated_preview: Dictionary = preview_for_side.call(
        enemy, proposal.card_ids, enemy_sequence_book)
    if not revalidated_preview.get("valid", false):
        return {"success": false, "reason": "敌方行动提案本地复核失败：%s" % revalidated_preview.get("reason", "未知错误")}

    proposal.preview = revalidated_preview
    locked_enemy_action_proposal = proposal
    locked_enemy_card_ids = proposal.card_ids.duplicate()
    enemy_plan = public_plan(revalidated_preview.get("intent", {}))
    game_log.record_system(
        "debug",
        "enemy_decision",
        "敌方行动提案已锁定",
        "控制器 %s｜优先级 %d｜评分 %.2f｜%d 张真气" % [
            proposal.controller_id,
            int(proposal.diagnostics.get("priority", 0)),
            proposal.score,
            locked_enemy_card_ids.size()],
        {
            "controller_id": proposal.controller_id,
            "priority": int(proposal.diagnostics.get("priority", 0)),
            "score": proposal.score,
            "score_components": proposal.diagnostics.get("score_components", {}).duplicate(true),
            "card_count": locked_enemy_card_ids.size(),
        })
    var detail: String = (
        "已计划" if enemy_ai_enabled or external_enemy_action_mode
        else "%d 张背面真气" % locked_enemy_card_ids.size())
    trigger_queue.add_history(
        "enemy_lock", "对手已确定本击计划", source_label, "成功", detail)
    return {"success": true, "preview": revalidated_preview}

func public_plan(intent: Dictionary) -> Dictionary:
    return {
        "damage": maxi(0, int(intent.get("damage", 0))),
        "defense": maxi(0, int(intent.get("defense", 0))),
        "segments": maxi(0, int(intent.get("segments", 0))),
        "combo": bool(intent.get("combo", false)),
        "same_qi_gain": maxi(0, int(intent.get("same_qi_gain", 0))),
        "same_qi_trigger_count": maxi(
            0, int(intent.get("same_qi_trigger_count", 0))),
    }
