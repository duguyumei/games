class_name RunPassiveEffectPorts
extends RefCounted

## Handler 只能经由这个窄端口提交已登记的本局效果，不能接触 RunSession。

var _growth
var _mutation_service
var _context_metadata: Dictionary

func _init(growth, mutation_service, context_metadata: Dictionary = {}) -> void:
    _growth = growth
    _mutation_service = mutation_service
    _context_metadata = context_metadata.duplicate(true)

## 为单个 Invocation 建立来源收窄后的端口。来源地址由统一 Resolver 产生并
## 随 Invocation 注入；具体 Handler 不得自行拼 source_instance_key。
func for_invocation(current_invocation):
    if current_invocation == null:
        return get_script().new(_growth, _mutation_service, _context_metadata)
    return for_source(
        current_invocation.source,
        int(current_invocation.execution_index),
        int(current_invocation.execution_count))

func for_source(
        source,
        execution_index: int = 0,
        execution_count: int = 1):
    var metadata := _context_metadata.duplicate(true)
    if source != null:
        metadata["source_kind"] = str(source.source_kind)
        metadata["source_id"] = str(source.content_id)
        metadata["source_name"] = str(source.definition.get("name", ""))
        metadata["source_instance_key"] = str(source.source_instance_key)
        metadata["source_behavior_id"] = str(source.behavior_id)
        metadata["source_behavior_index"] = int(source.behavior_index)
        metadata["source_marker_definitions"] = source.definition.get(
            "marker_definitions",
            source.definition.get("source_marker_definitions", [])).duplicate(true)
        metadata["trigger_mode"] = "direct"
        metadata["fact_source"] = {
            "source_kind": str(source.source_kind),
            "source_id": str(source.content_id),
            "source_name": str(source.definition.get("name", "")),
            "source_instance_key": str(source.source_instance_key),
            "trigger_mode": "direct",
        }
        metadata["source_execution_index"] = execution_index
        metadata["source_execution_count"] = execution_count
        if str(metadata.get("hook", "")) == "experience_change_resolved":
            var ancestry: Array = metadata.get(
                "experience_response_ancestry",
                metadata.get("payload", {}).get(
                    "experience_response_ancestry", [])).duplicate()
            var behavior_key := "%s|%s" % [
                str(source.source_instance_key), str(source.behavior_id)]
            if not ancestry.has(behavior_key):
                ancestry.append(behavior_key)
            metadata["experience_response_ancestry"] = ancestry
        var parent_event_token := str(metadata.get("event_token", ""))
        if parent_event_token != "":
            metadata["transaction_token"] = "%s:source:%s:%d" % [
                parent_event_token,
                str(source.source_instance_key),
                execution_index,
            ]
        # 只有历练响应需要为每个子 Invocation 重新生成 operation token；其他
        # Run 事实沿用既有来源端口 token 语义，避免改变 marker/card fact 的
        # 兼容回执。历练子效果让 RunMutationService 用来源身份、分支
        # transaction token 和效果序号生成稳定 token，避免来源被误判重放。
        if str(metadata.get("hook", "")) == "experience_change_resolved":
            metadata.erase("operation_token")
    return get_script().new(_growth, _mutation_service, metadata)

func apply_effects(
        effects: Array,
        invocation_metadata: Dictionary = {}) -> Dictionary:
    if _mutation_service == null:
        return {"success": false, "reason": "本局被动效果端口未配置 RunMutationService"}
    var metadata := _context_metadata.duplicate(true)
    metadata.merge(invocation_metadata, true)
    return _mutation_service.apply_effects(
        effects, _growth, metadata)

func growth_snapshot() -> Dictionary:
    return {
        "experience": int(_growth.experience),
        "life": int(_growth.life),
        "max_life": int(_growth.max_life),
        "consumable_ids": _growth.consumable_ids.duplicate(),
        "item_ids": _growth.item_ids.duplicate(),
        "learned_inner_skill_ids": _growth.learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": _growth.equipped_inner_skill_ids.duplicate(),
        "forgotten_inner_skill_count": int(_growth.forgotten_inner_skill_count),
        "run_combat_history_state": _growth.run_combat_history.snapshot(),
    }
