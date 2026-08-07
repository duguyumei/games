class_name NodeRewardService
extends RefCounted

const RewardBundleScript = preload("res://core/reward_bundle.gd")

const IMPLEMENTED_KINDS := ["experience"]

var _definition: Dictionary = {}

func _init(definition: Dictionary = {}) -> void:
    configure(definition)

func configure(definition: Dictionary) -> void:
    _definition = definition.duplicate(true)

func create_bundle(node: Dictionary, context: Dictionary = {}):
    var node_type := str(node.get("type", ""))
    var entries: Array = []
    for entry_value in _definition.get("node_rewards", {}).get(node_type, []):
        entries.append(entry_value.duplicate(true))
    var seed_value := int(context.get("seed", 0))
    var act_value := int(context.get("act", 1))
    var node_id := str(node.get("id", ""))
    return RewardBundleScript.new({
        "id": "reward-%d-%d-%s" % [seed_value, act_value, node_id],
        "seed": seed_value,
        "act": act_value,
        "node_id": node_id,
        "node_type": node_type,
        "entries": entries,
    })

func apply_bundle(bundle, growth) -> Dictionary:
    if bundle == null:
        return {"success": false, "reason": "奖励包不存在"}
    for entry_value in bundle.entries():
        var kind := str(entry_value.get("kind", ""))
        if not IMPLEMENTED_KINDS.has(kind):
            return {"success": false, "reason": "奖励类型尚未接入：%s" % kind}
    var applied: Array = []
    for entry_value in bundle.entries():
        var entry: Dictionary = entry_value
        var kind := str(entry.get("kind", ""))
        if kind == "experience":
            var amount := int(entry.get("amount", 0))
            growth.experience += amount
            applied.append({"kind": kind, "amount": amount})
    return {
        "success": true,
        "bundle_id": bundle.bundle_id(),
        "applied": applied,
        "experience": growth.experience,
    }
