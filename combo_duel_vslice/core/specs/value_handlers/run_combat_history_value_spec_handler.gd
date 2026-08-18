class_name RunCombatHistoryValueSpecHandler
extends RefCounted

const RunCombatHistoryScript = preload("res://core/run_combat_history.gd")

const REGISTERED_KINDS := ["run_combat_history"]


func kind_ids() -> Array[String]:
    return REGISTERED_KINDS.duplicate()


func validate(
        _kind: String,
        spec: Dictionary,
        _registry,
        report_error: Callable,
        scope: String) -> bool:
    var valid := true
    if str(spec.get("metric", "")) not in RunCombatHistoryScript.METRIC_IDS:
        report_error.call(scope + ".metric", "引用未知本局战斗历史指标")
        valid = false
    if spec.has("side") and str(spec["side"]) not in [
            "actor", "target", "owner", "opponent"]:
        report_error.call(
            scope + ".side", "必须为 actor、target、owner 或 opponent")
        valid = false
    if str(spec.get("metric", "")) == "hand_success_count":
        if str(spec.get("hand_id", "")) not in RunCombatHistoryScript.HAND_IDS:
            report_error.call(scope + ".hand_id", "引用未知精确牌型")
            valid = false
    elif spec.has("hand_id"):
        report_error.call(
            scope + ".hand_id", "只有 hand_success_count 可以指定 hand_id")
        valid = false
    return valid


func resolve(
        _kind: String,
        spec: Dictionary,
        runtime,
        resolver,
        _registry) -> int:
    var side = resolver.side(runtime, str(spec.get("side", "owner")))
    if side == null or not side.get("run_combat_history") is RunCombatHistory:
        return 0
    return side.run_combat_history.metric_value(
        str(spec.get("metric", "")), str(spec.get("hand_id", "")))
