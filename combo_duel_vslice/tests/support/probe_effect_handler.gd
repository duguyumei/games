extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")

var _operation_ids: Array[String] = ["probe_effect"]
var _default_phase: String = "zones"

func _init(
        operation_ids_override: Array[String] = ["probe_effect"],
        default_phase_override: String = "zones") -> void:
    _operation_ids = operation_ids_override.duplicate()
    _default_phase = default_phase_override

## 测试探针：验证外部处理器可以通过注册表接口接入统一执行链。
##
## 必须是独立文件而不是 test_runner.gd 的内部类：内部类继承全局 class_name
## 会让 Godot 4.7.1 在加载阶段卡死（无报错、无超时）。

func operation_ids() -> Array[String]:
    return _operation_ids.duplicate()

func group_name() -> String:
    return "test_probe"

func default_phase(_operation_id: String) -> String:
    return _default_phase

func execute(effect: Dictionary, context):
    if context is Dictionary:
        context["probe_count"] = int(context.get("probe_count", 0)) + 1
    var runtime = EffectContextScript.coerce(context)
    var amount := int(effect.get("amount", 7))
    if runtime.actor != null:
        if runtime.ports != null:
            runtime.ports.add_defense(runtime.actor, amount)
        else:
            runtime.actor.add_defense(amount)
    return {"success": true, "detail": "探针已执行"}

func summarize(effect: Dictionary, _context, intent: Dictionary, _state: Dictionary) -> void:
    intent["defense"] = int(intent.get("defense", 0)) + int(effect.get("amount", 7))

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    validator.validate_positive_integer(effect.get("amount"), scope + ".amount", "amount")
