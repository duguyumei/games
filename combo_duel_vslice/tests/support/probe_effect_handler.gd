extends EffectHandler

## 测试探针：验证外部处理器可以通过注册表接口接入统一执行链。
##
## 必须是独立文件而不是 test_runner.gd 的内部类：内部类继承全局 class_name
## 会让 Godot 4.7.1 在加载阶段卡死（无报错、无超时）。

func operation_ids() -> Array[String]:
    return ["probe_effect"]

func group_name() -> String:
    return "test_probe"

func execute(_effect: Dictionary, context):
    context["probe_count"] = int(context.get("probe_count", 0)) + 1
    return {"success": true, "detail": "探针已执行"}

func summarize(_effect: Dictionary, _context, intent: Dictionary, _state: Dictionary) -> void:
    intent["defense"] = int(intent.get("defense", 0)) + 7
