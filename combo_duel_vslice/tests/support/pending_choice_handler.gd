extends EffectHandler

## 测试探针：验证等待选择状态不会被执行链当作普通失败吞掉。
##
## 必须是独立文件而不是内部类：内部类继承全局 class_name 会让
## Godot 4.7.1 在加载阶段卡死（无报错、无超时）。

const ResultScript = preload("res://core/effects/technique_effect_result.gd")

func operation_ids() -> Array[String]:
    return ["test_pending_choice"]

func group_name() -> String:
    return "test"

func execute(_effect: Dictionary, _context):
    return ResultScript.pending_choice(
        "请选择一张真气",
        {"request_id": "choice-001", "minimum": 1, "maximum": 1})

func summarize(_effect: Dictionary, _context, _intent: Dictionary, _state: Dictionary) -> void:
    pass
