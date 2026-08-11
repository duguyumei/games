class_name PassiveRuleExecutionPlan
extends RefCounted

var hook: String = ""
var invocations: Array = []
var activations: Array = []
var errors: Array[String] = []

func configure(values: Dictionary):
    hook = str(values.get("hook", ""))
    invocations = values.get("invocations", []).duplicate()
    activations = values.get("activations", []).duplicate()
    errors.clear()
    for value in values.get("errors", []):
        errors.append(str(value))
    return self

func is_valid() -> bool:
    return errors.is_empty()

func to_dict() -> Dictionary:
    var invocation_values: Array = []
    for invocation in invocations:
        invocation_values.append(invocation.to_dict())
    return {
        "hook": hook,
        "invocations": invocation_values,
        "activations": activations.duplicate(true),
        "errors": errors.duplicate(),
    }
