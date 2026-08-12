class_name AiDecisionTraceRecorder
extends RefCounted

const TraceScript = preload("res://core/ai/ai_decision_trace.gd")
const StoreScript = preload("res://core/ai/ai_decision_trace_store.gd")
const StableEncoderScript = preload("res://core/ai/ai_stable_value_encoder.gd")

var trace
var store := StoreScript.new()
var encoder := StableEncoderScript.new()
var path: String = ""
var autosave: bool = false

func configure(battle_id: String, settings: Dictionary = {}):
    trace = TraceScript.new().configure(battle_id)
    autosave = bool(settings.get("autosave_decision_trace", false))
    path = str(settings.get("decision_trace_path", ""))
    return self

func begin_window(values: Dictionary, candidates: Array) -> void:
    var candidate_map: Array = []
    for candidate in candidates:
        candidate_map.append({
            "public_candidate_id": str(candidate.candidate_id),
            "diagnostic_candidate_id": str(candidate.diagnostic_candidate_id),
        })
    var diagnostics: Dictionary = values.get("candidate_diagnostics", {})
    trace.begin_window({
        "decision_id": str(values.get("decision_id", "")),
        "round_number": int(values.get("round_number", 0)),
        "action_index": int(values.get("action_index", 0)),
        "versions": values.get("versions", {}).duplicate(true),
        "provider": values.get("provider", {}).duplicate(true),
        "observation_fingerprint": encoder.sha256(
            values.get("observation_snapshot", {})),
        "candidate_pipeline": {
            "full_count": int(diagnostics.get("counts", {}).get("full", 0)),
            "pareto_count": int(diagnostics.get("counts", {}).get("pareto", 0)),
            "published_count": candidates.size(),
            "candidate_limit": int(diagnostics.get("policy", {}).get("candidate_limit", 5)),
        },
        "candidate_map": candidate_map,
        "candidate_diagnostics": diagnostics,
    })
    persist()

func record_selected(decision_id: String, values: Dictionary) -> void:
    trace.record_selected(decision_id, values)
    persist()

func record_actual(decision_id: String, values: Dictionary) -> void:
    trace.record_actual_result(decision_id, values)
    persist()

func complete_battle(values: Dictionary) -> void:
    trace.complete_battle(values)
    persist()

func persist() -> bool:
    if not autosave or path == "":
        return true
    return store.save(path, trace)
