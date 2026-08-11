class_name BattlePassiveIntQueryResult
extends "res://core/passives/passive_int_query_result.gd"

var request_fingerprint: String = ""

func configure(values: Dictionary):
    super.configure(values)
    request_fingerprint = str(values.get("request_fingerprint", ""))
    return self

func to_dict() -> Dictionary:
    var result := super.to_dict()
    result["source_breakdown"] = modifier_breakdown.duplicate(true)
    result["fingerprint"] = source_fingerprint
    result["request_fingerprint"] = request_fingerprint
    return result
