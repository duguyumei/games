class_name EnemyCandidateReductionDiagnostics
extends RefCounted

const SCHEMA_VERSION := 1

func build(
        records: Array,
        dominance: Dictionary,
        selected: Array,
        normalized_policy: Dictionary,
        direction_trace: Array,
        mmr_trace: Dictionary,
        hard_trace: Dictionary) -> Dictionary:
    var dominated_by_id: Dictionary = {}
    var dominance_comparisons: Dictionary = {}
    for entry in dominance.get("dominated", []):
        var candidate_id := _id(entry["candidate"])
        dominated_by_id[candidate_id] = _id(entry["dominated_by"])
        dominance_comparisons[candidate_id] = entry.get(
            "dimension_comparison", []).duplicate(true)
    var selection_by_id: Dictionary = {}
    for selection_index in range(selected.size()):
        var record = selected[selection_index]
        selection_by_id[_id(record)] = {
            "selected": true,
            "selection_index": selection_index,
            "selection_stage": str(record.get("selection_stage", "fallback")),
            "selection_reason": str(record.get("selection_reason", "")),
        }
    var candidates: Array = []
    for record in records:
        var candidate_id := _id(record)
        var selection: Dictionary = selection_by_id.get(candidate_id, {
            "selected": false,
            "selection_index": -1,
            "selection_stage": "not_selected",
            "selection_reason": _not_selected_reason(
                candidate_id, dominated_by_id, mmr_trace),
        }).duplicate(true)
        var proposal = record["proposal"]
        candidates.append({
            "diagnostic_candidate_id": candidate_id,
            "enumeration_index": int(record["serial"]),
            "card_ids": proposal.card_ids.duplicate(),
            "controller_id": str(proposal.controller_id),
            "legacy_utility": {
                "priority": int(proposal.diagnostics.get("priority", 0)),
                "score": float(proposal.score),
                "score_components": proposal.diagnostics.get(
                    "score_components", {}).duplicate(true),
            },
            "features": record["features"].duplicate(true),
            "hard_protection": {
                "reasons": record["features"]["internal"][
                    "hard_reasons"].duplicate(),
                "priority": int(hard_trace.get(
                    "priority_by_id", {}).get(candidate_id, 0)),
                "protected_rank": int(hard_trace.get(
                    "rank_by_id", {}).get(candidate_id, -1)),
                "selected_within_limit": bool(hard_trace.get(
                    "selected_by_id", {}).get(candidate_id, false)),
            },
            "pareto": {
                "kept": not dominated_by_id.has(candidate_id),
                "dominated_by": str(dominated_by_id.get(candidate_id, "")),
                "dimension_comparison": dominance_comparisons.get(
                    candidate_id, []).duplicate(true),
            },
            "direction": {
                "primary": str(record["features"]["primary_direction"]),
                "scores": record["features"]["direction_scores"].duplicate(true),
                "wins": _direction_wins(candidate_id, direction_trace),
            },
            "mmr": _mmr_for(candidate_id, mmr_trace),
            "selection": selection,
        })
    return {
        "schema_version": SCHEMA_VERSION,
        "algorithm": "hard_protection_then_pareto_direction_representatives_then_mmr",
        "policy": normalized_policy.duplicate(true),
        "counts": {
            "full": records.size(),
            "hard_protected": hard_trace.get("ordered_ids", []).size(),
            "pareto": dominance.get("kept", []).size(),
            "dominated": dominance.get("dominated", []).size(),
            "selected": selected.size(),
        },
        "selected_candidate_ids": selected.map(func(record): return _id(record)),
        "hard_protection": hard_trace.duplicate(true),
        "direction_rounds": direction_trace.duplicate(true),
        "mmr": mmr_trace.duplicate(true),
        "candidates": candidates,
    }

func _id(record) -> String:
    return str(record.get(
        "diagnostic_candidate_id", "local-%03d" % int(record["serial"])))

func _direction_wins(candidate_id: String, trace: Array) -> Array[String]:
    var result: Array[String] = []
    for entry in trace:
        if str(entry.get("winner_candidate_id", "")) == candidate_id:
            result.append(str(entry.get("direction", "")))
    return result

func _mmr_for(candidate_id: String, trace: Dictionary) -> Dictionary:
    var result := {
        "considered": false,
        "rounds": [],
        "rejected_as_too_similar": false,
    }
    for round_entry in trace.get("rounds", []):
        for candidate in round_entry.get("candidates", []):
            if str(candidate.get("diagnostic_candidate_id", "")) == candidate_id:
                result["considered"] = true
                result["rounds"].append(candidate.duplicate(true))
    result["rejected_as_too_similar"] = (
        str(trace.get("stopped_candidate_id", "")) == candidate_id
        and str(trace.get("stop_reason", "")) == "similarity_threshold")
    return result

func _not_selected_reason(
        candidate_id: String,
        dominated_by_id: Dictionary,
        mmr_trace: Dictionary) -> String:
    if dominated_by_id.has(candidate_id):
        return "pareto_dominated"
    if str(mmr_trace.get("stopped_candidate_id", "")) == candidate_id:
        return "mmr_similarity_threshold"
    return "lower_rank_or_limit_reached"
