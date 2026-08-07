class_name StackEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return [
        "add_stack", "add_target_stack", "add_stack_per_captured_card",
        "set_stack_minimum",
    ]

func group_name() -> String:
    return "stack"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    var operation_id := str(effect.get("op", ""))
    match operation_id:
        "add_stack":
            if runtime.actor == null:
                return EffectResultScript.failed("行动方层数处理缺少行动方")
            var amount := _add_status(
                runtime,
                runtime.actor,
                str(effect["stack"]),
                value_resolver.resolve(effect.get("amount", {}), runtime))
            return EffectResultScript.succeeded("%s +%d" % [effect["stack"], amount])
        "add_target_stack":
            if runtime.target == null:
                return EffectResultScript.failed("目标层数处理缺少目标")
            var amount := _add_status(
                runtime,
                runtime.target,
                str(effect["stack"]),
                value_resolver.resolve(effect.get("amount", {}), runtime))
            return EffectResultScript.succeeded("敌方 %s +%d" % [effect["stack"], amount])
        "add_stack_per_captured_card":
            if runtime.actor == null:
                return EffectResultScript.failed("捕获真气层数处理缺少行动方")
            var cards: Array = runtime.captures.get(effect.get("capture", ""), [])
            var total := 0
            for card in cards:
                total += int(effect.get("attribute_values", {}).get(
                    card.attribute, effect.get("default", 0)))
            _add_status(runtime, runtime.actor, str(effect["stack"]), total)
            return EffectResultScript.succeeded("%s +%d" % [effect["stack"], total])
        "set_stack_minimum":
            if runtime.actor == null:
                return EffectResultScript.failed("最低层数处理缺少行动方")
            var status_id := str(effect["stack"])
            var wanted: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            var current: int = int(runtime.actor.stacks.get(status_id, 0))
            var changed: int = _add_status(runtime, runtime.actor, status_id, maxi(0, wanted - current))
            return EffectResultScript.succeeded("%s 至少为 %d（+%d）" % [status_id, wanted, changed])
    return EffectResultScript.failed("层数处理器不支持：%s" % operation_id)

func summarize(_effect: Dictionary, _context, _intent: Dictionary, _state: Dictionary) -> void:
    pass

func _add_status(runtime, side, status_id: String, amount: int) -> int:
    if runtime.ports == null:
        return side.add_stack(status_id, amount)
    var result: Dictionary = runtime.ports.add_actor_status(
        side,
        status_id,
        amount,
        runtime.technique_name if runtime.technique_name != "" else "功法")
    return int(result.get("changed", 0)) if result.get("success", false) else 0
