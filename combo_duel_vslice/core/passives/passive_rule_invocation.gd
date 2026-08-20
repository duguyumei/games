class_name PassiveRuleInvocation
extends RefCounted

var source = null
var hook: String = ""
var execution_index: int = 0
var execution_count: int = 1
var repeat_origin: Array[String] = []
var context = null

func configure(values: Dictionary):
    source = values.get("source")
    hook = str(values.get("hook", ""))
    execution_index = int(values.get("execution_index", 0))
    execution_count = int(values.get("execution_count", 1))
    repeat_origin.clear()
    for value in values.get("repeat_origin", []):
        repeat_origin.append(str(value))
    context = values.get("context")
    return self

func to_dict() -> Dictionary:
    return {
        "source": source.to_dict() if source != null else {},
        "hook": hook,
        "execution_index": execution_index,
        "execution_count": execution_count,
        "repeat_origin": repeat_origin.duplicate(),
        "projection": source.projection.duplicate(true) \
            if source != null else {},
    }
