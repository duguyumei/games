class_name EffectHandler
extends RefCounted

## 功法效果处理器基类。
##
## 子类声明效果 ID，并按需实现执行、预览和定义校验；`_init` 由各子类按自身依赖
## 自行定义，基类不做约束。
## 注册表按 `operation_ids()` 建立 opcode 到处理器的映射，同一 opcode 不能重复注册。

## 本处理器负责的 opcode 列表。返回空数组会被注册表拒绝。
func operation_ids() -> Array[String]:
    return []

## 能力分组名，用于结构化日志与调试展示。
func group_name() -> String:
    return ""

## 执行一条效果，返回 TechniqueEffectResult。
func execute(_effect: Dictionary, _context):
    return null

## 把效果累加进出牌预览意图，只读战斗状态，不做任何修改。
func summarize(_effect: Dictionary, _context, _intent: Dictionary, _state: Dictionary) -> void:
    pass

## 校验本处理器负责的效果定义。通用数值、目标阵营和牌区字段由校验器先处理；
## 处理器只补自身 opcode 的专有契约。
func validate_effect(_effect: Dictionary, _validator, _scope: String) -> void:
    pass
