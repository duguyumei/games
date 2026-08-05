class_name StackEffectHandler
extends RefCounted

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["add_stack", "add_target_stack", "add_stack_per_captured_card"]

func group_name() -> String:
    return "stack"

func execute(effect: Dictionary, context: Dictionary) -> Dictionary:
    match str(effect.get("op", "")):
        "add_stack":
            var amount: int = context["actor"].add_stack(
                effect["stack"], value_resolver.resolve(effect.get("amount", {}), context))
            return {"success": true, "detail": "%s +%d" % [effect["stack"], amount]}
        "add_target_stack":
            var amount: int = context["target"].add_stack(
                effect["stack"], value_resolver.resolve(effect.get("amount", {}), context))
            return {"success": true, "detail": "敌方 %s +%d" % [effect["stack"], amount]}
        "add_stack_per_captured_card":
            var cards: Array = context["captures"].get(effect.get("capture", ""), [])
            var total := 0
            for card in cards:
                total += int(effect.get("attribute_values", {}).get(
                    card.attribute, effect.get("default", 0)))
            context["actor"].add_stack(effect["stack"], total)
            return {"success": true, "detail": "%s +%d" % [effect["stack"], total]}
    return {"success": false, "detail": "层数处理器不支持：%s" % str(effect.get("op", ""))}

func summarize(_effect: Dictionary, _context: Dictionary, _intent: Dictionary, _state: Dictionary) -> void:
    pass
