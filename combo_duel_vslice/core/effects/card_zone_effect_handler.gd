class_name CardZoneEffectHandler
extends RefCounted

var value_resolver
var rng: RandomNumberGenerator

func _init(resolver, random_source: RandomNumberGenerator) -> void:
    value_resolver = resolver
    rng = random_source

func operation_ids() -> Array[String]:
    return ["draw", "draw_if_captured_attribute", "discard_random", "discard_all_hand"]

func group_name() -> String:
    return "card_zone"

func execute(effect: Dictionary, context: Dictionary) -> Dictionary:
    var actor = context["actor"]
    match str(effect.get("op", "")):
        "draw":
            var drawn: Array = actor.draw(value_resolver.resolve(effect.get("count", {}), context))
            if effect.has("capture"):
                context["captures"][effect["capture"]] = drawn
            return {"success": true, "detail": "抽 %d 张" % drawn.size()}
        "draw_if_captured_attribute":
            var captured: Array = context["captures"].get(effect.get("capture", ""), [])
            var matches := false
            for card in captured:
                if card.attribute == effect.get("attribute", ""):
                    matches = true
                    break
            var drawn: Array = actor.draw(int(effect.get("count", 1))) if matches else []
            return {
                "success": true,
                "detail": "属性追加抽 %d 张" % drawn.size() if matches else "",
            }
        "discard_random":
            var discarded: Array = actor.random_discard(
                value_resolver.resolve(effect.get("count", {}), context), rng)
            return {"success": true, "detail": "随机弃 %d 张" % discarded.size()}
        "discard_all_hand":
            var discarded: Array = actor.discard_all()
            context["captures"][effect.get("capture", "discarded")] = discarded
            return {"success": true, "detail": "弃掉全部剩余手牌 %d 张" % discarded.size()}
    return {"success": false, "detail": "牌区处理器不支持：%s" % str(effect.get("op", ""))}

func summarize(_effect: Dictionary, _context: Dictionary, _intent: Dictionary, _state: Dictionary) -> void:
    pass
