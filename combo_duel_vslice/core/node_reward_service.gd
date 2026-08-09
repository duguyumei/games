class_name NodeRewardService
extends RefCounted

## 数据驱动的节点奖励创建与应用服务。
##
## 这里只把节点定义转换为奖励包，并把整包交给一个本局原子事务，不推进地图阶段，
## 也不负责奖励界面的领取时机；生命周期由 RunSession 编排。

const RewardBundleScript = preload("res://core/reward_bundle.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")

var _definition: Dictionary = {}
var mutation_service
var handler_registry

func _init(definition: Dictionary = {}, mutation_service_override = null) -> void:
    mutation_service = (
        mutation_service_override
        if mutation_service_override != null
        else RunMutationServiceScript.new())
    handler_registry = mutation_service.handler_registry
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
    var result: Dictionary = mutation_service.apply_effects(
        bundle.entries(), growth, {"reward_bundle": bundle.to_dict()})
    result["bundle_id"] = bundle.bundle_id()
    result["experience"] = growth.experience
    return result
