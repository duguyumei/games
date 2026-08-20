class_name TechniqueEffectContinuation
extends RefCounted

var effects: Array = []
var context = null
var effect_index: int = 0
var details: Array[String] = []
var effect_results: Array = []
var choice_request = null
var command_consumed_index: int = -1
## 选择暂停时保留当前 EffectSpec 的原子事务；恢复后继续使用同一边界。
var active_effect_transaction: Dictionary = {}

func configure(values: Dictionary):
    effects = values.get("effects", []).duplicate(true)
    context = values.get("context")
    effect_index = int(values.get("effect_index", 0))
    details.clear()
    for detail in values.get("details", []):
        details.append(str(detail))
    effect_results = values.get("effect_results", []).duplicate(true)
    choice_request = values.get("choice_request")
    command_consumed_index = int(values.get("command_consumed_index", -1))
    active_effect_transaction = values.get(
        "active_effect_transaction", {}).duplicate(true)
    return self

func choice_snapshot() -> Dictionary:
    if choice_request == null or not choice_request.has_method("snapshot"):
        return {}
    return choice_request.snapshot()
