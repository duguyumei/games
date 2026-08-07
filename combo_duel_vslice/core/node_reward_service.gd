class_name NodeRewardService
extends RefCounted

## 数据驱动的节点奖励创建与应用服务。
##
## 这里只把节点定义转换为奖励包并应用已实现的奖励类型，不推进地图阶段，
## 也不负责奖励界面的领取时机；生命周期由 RunSession 编排。

const RewardBundleScript = preload("res://core/reward_bundle.gd")
const RewardHandlerRegistryScript = preload(
    "res://core/rewards/reward_handler_registry.gd")

var _definition: Dictionary = {}
var handler_registry

func _init(definition: Dictionary = {}, registry_override = null) -> void:
    handler_registry = (
        registry_override
        if registry_override != null
        else RewardHandlerRegistryScript.new())
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
        if not handler_registry.has_handler(kind):
            return {"success": false, "reason": "奖励类型尚未接入：%s" % kind}
    var applied: Array = []
    for entry_value in bundle.entries():
        var entry: Dictionary = entry_value
        var result: Dictionary = handler_registry.apply(entry, growth)
        if not result.get("success", false):
            return result
        applied.append(result.get("applied", {}).duplicate(true))
    return {
        "success": true,
        "bundle_id": bundle.bundle_id(),
        "applied": applied,
        "experience": growth.experience,
    }
