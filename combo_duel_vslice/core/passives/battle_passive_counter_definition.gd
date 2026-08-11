class_name BattlePassiveCounterDefinition
extends RefCounted

const RESET_BATTLE := "battle"
const RESET_TURN := "turn"
const RESET_ACTION_WINDOW := "action_window"
const RESET_SCOPES := [RESET_BATTLE, RESET_TURN, RESET_ACTION_WINDOW]

var counter_id: String = ""
var default_value: int = 0
var minimum: int = 0
var maximum = null
var reset_scope: String = RESET_BATTLE

func configure(values: Dictionary):
    counter_id = str(values.get("counter_id", ""))
    if values.get("default_value") is int:
        default_value = int(values["default_value"])
    if values.get("minimum") is int:
        minimum = int(values["minimum"])
    maximum = values.get("maximum") if values.has("maximum") else null
    reset_scope = str(values.get("reset_scope", ""))
    return self

func validation_errors() -> Array[String]:
    var errors: Array[String] = []
    var pattern := RegEx.new()
    pattern.compile("^[a-z][a-z0-9_]*$")
    if pattern.search(counter_id) == null:
        errors.append("counter_id 必须使用稳定 snake_case：%s" % counter_id)
    if not default_value is int:
        errors.append("default_value 必须是整数")
    if not minimum is int:
        errors.append("minimum 必须是整数")
    if maximum != null and not maximum is int:
        errors.append("maximum 必须是整数或省略")
    if maximum is int and int(maximum) < minimum:
        errors.append("maximum 不得小于 minimum")
    if default_value < minimum:
        errors.append("default_value 不得小于 minimum")
    if maximum is int and default_value > int(maximum):
        errors.append("default_value 不得大于 maximum")
    if reset_scope not in RESET_SCOPES:
        errors.append("reset_scope 只能为 battle、turn 或 action_window")
    return errors

func to_dict() -> Dictionary:
    var result := {
        "counter_id": counter_id,
        "default_value": default_value,
        "minimum": minimum,
        "reset_scope": reset_scope,
    }
    if maximum is int:
        result["maximum"] = int(maximum)
    return result
