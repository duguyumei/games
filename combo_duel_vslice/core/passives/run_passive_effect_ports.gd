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

func apply_effects(effects: Array) -> Dictionary:
    if _mutation_service == null:
        return {"success": false, "reason": "本局被动效果端口未配置 RunMutationService"}
    return _mutation_service.apply_effects(
        effects, _growth, _context_metadata)

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
