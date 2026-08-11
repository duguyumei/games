class_name BattlePassiveCounterMutationPort
extends "res://core/passives/battle_passive_counter_read_port.gd"

func write(counter_id: String, value) -> Dictionary:
    if not value is int:
        _record_error(counter_id, "write value 必须是整数")
        return {"success": false, "reason": errors()[-1]}
    var resolved := _resolve(counter_id)
    if not resolved.get("success", false):
        return {"success": false, "reason": errors()[-1]}
    var result: Dictionary = _store.set_value(
        resolved["key"], resolved["definition"], value)
    if not result.get("success", false):
        _record_error(counter_id, str(result.get("reason", "计数器写入失败")))
        return {"success": false, "reason": errors()[-1]}
    return result

func increment(counter_id: String, amount) -> Dictionary:
    if not amount is int:
        _record_error(counter_id, "increment amount 必须是整数")
        return {"success": false, "reason": errors()[-1]}
    var resolved := _resolve(counter_id)
    if not resolved.get("success", false):
        return {"success": false, "reason": errors()[-1]}
    var before: int = _store.get_value(
        resolved["key"], resolved["definition"])
    var result := write(counter_id, before + int(amount))
    if result.get("success", false):
        result["before"] = before
    return result

func reset(counter_id: String) -> Dictionary:
    var resolved := _resolve(counter_id)
    if not resolved.get("success", false):
        return {"success": false, "reason": errors()[-1]}
    return write(counter_id, int(resolved["definition"].default_value))
