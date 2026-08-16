class_name LifeEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["heal_life"]

func group_name() -> String:
    return "life"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("生命处理器缺少战斗端口")
    var side = runtime.resolve_side(str(effect.get("side", "actor")))
    if side == null:
        return EffectResultScript.failed("生命恢复目标作用域不存在")
    var amount: int = int(value_resolver.resolve(effect.get("amount", 0), runtime))
    var result: Dictionary = runtime.ports.recover_life(
        side, amount, runtime.source_kind, runtime.action_token, runtime.actor)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get("reason", "生命恢复失败")))
    var capture_id := str(effect.get("capture", ""))
    if capture_id != "":
        runtime.captures[capture_id] = [{"amount": int(result.get("recovered", 0))}]
    return EffectResultScript.succeeded("恢复 %d 生命" % int(result.get("recovered", 0)))

func summarize(effect: Dictionary, context, intent: Dictionary, _state: Dictionary) -> void:
    intent["healing"] = int(intent.get("healing", 0)) + maxi(
        0, value_resolver.resolve(effect.get("amount", 0), context))
