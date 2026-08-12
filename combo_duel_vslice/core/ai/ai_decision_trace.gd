class_name AiDecisionTrace
extends RefCounted

const SCHEMA_VERSION := 1

var battle_id: String = ""
var windows: Array = []
var battle_summary: Dictionary = {}

func configure(id: String):
    battle_id = id
    return self

func begin_window(values: Dictionary) -> void:
    var decision_id := str(values.get("decision_id", ""))
    if decision_id == "" or _index_of(decision_id) >= 0:
        return
    windows.append({
        "schema_version": SCHEMA_VERSION,
        "battle_id": battle_id,
        "decision_id": decision_id,
        "round_number": int(values.get("round_number", 0)),
        "action_index": int(values.get("action_index", 0)),
        "versions": values.get("versions", {}).duplicate(true),
        "provider": values.get("provider", {}).duplicate(true),
        "observation_fingerprint": str(values.get("observation_fingerprint", "")),
        "candidate_pipeline": values.get("candidate_pipeline", {}).duplicate(true),
        "candidate_map": values.get("candidate_map", []).duplicate(true),
        "candidate_diagnostics": values.get("candidate_diagnostics", {}).duplicate(true),
        "selected": {},
        "actual_result": {},
    })

func record_selected(decision_id: String, values: Dictionary) -> void:
    var index := _index_of(decision_id)
    if index >= 0:
        windows[index]["selected"] = values.duplicate(true)

func record_actual_result(decision_id: String, values: Dictionary) -> void:
    var index := _index_of(decision_id)
    if index >= 0:
        windows[index]["actual_result"] = values.duplicate(true)

func complete_battle(values: Dictionary) -> void:
    battle_summary = values.duplicate(true)

func snapshot() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "battle_id": battle_id,
        "windows": windows.duplicate(true),
        "battle_summary": battle_summary.duplicate(true),
    }

func _index_of(decision_id: String) -> int:
    for index in range(windows.size()):
        if str(windows[index].get("decision_id", "")) == decision_id:
            return index
    return -1

