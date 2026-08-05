class_name PlayerActionController
extends RefCounted

const ProposalScript = preload("res://core/battle_action_proposal.gd")

func propose(card_ids: Array, preview_action: Callable):
    var preview: Dictionary = preview_action.call(card_ids)
    if not preview.get("valid", false):
        return ProposalScript.new().configure_reject(
            "human",
            str(preview.get("reason", "选择无效")))
    return ProposalScript.new().configure_accept("human", card_ids, preview)
