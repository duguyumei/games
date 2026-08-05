class_name EnemyActionController
extends RefCounted

const EnemyCombatAIScript = preload("res://core/enemy_combat_ai.gd")
const ProposalScript = preload("res://core/battle_action_proposal.gd")

var planner

func _init(random_source: RandomNumberGenerator) -> void:
    planner = EnemyCombatAIScript.new(random_source)

func propose_utility(observation, preview_action: Callable, policy: Dictionary):
    var choice: Dictionary = planner.choose_action(
        observation,
        preview_action,
        policy)
    if choice.is_empty():
        return ProposalScript.new().configure_reject(
            "enemy_utility",
            "没有合法出牌方案",
            {"observation": observation.public_snapshot()})
    return ProposalScript.new().configure_accept(
        "enemy_utility",
        choice.get("card_ids", []),
        choice.get("preview", {}),
        float(choice.get("score", 0.0)),
        {
            "priority": int(choice.get("priority", 0)),
            "score_components": choice.get("score_components", {}).duplicate(true),
            "observation": observation.public_snapshot(),
        })

func propose_scripted(
        definition_ids: Array,
        resolve_definition_ids: Callable,
        preview_action: Callable):
    var resolved_ids: Array = resolve_definition_ids.call(definition_ids)
    if resolved_ids.size() != definition_ids.size():
        return ProposalScript.new().configure_reject(
            "enemy_scripted",
            "脚本要求的真气不在当前手牌",
            {"requested_definition_ids": definition_ids.duplicate()})
    if resolved_ids.is_empty():
        return ProposalScript.new().configure_reject("enemy_scripted", "脚本没有配置本次行动")
    var preview: Dictionary = preview_action.call(resolved_ids)
    if not preview.get("valid", false):
        return ProposalScript.new().configure_reject(
            "enemy_scripted",
            str(preview.get("reason", "脚本行动无效")))
    return ProposalScript.new().configure_accept("enemy_scripted", resolved_ids, preview)
