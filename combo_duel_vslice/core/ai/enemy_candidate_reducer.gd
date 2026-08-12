class_name EnemyCandidateReducer
extends RefCounted

const ProjectorScript = preload(
    "res://core/ai/enemy_candidate_feature_projector.gd")
const DominanceScript = preload(
    "res://core/ai/enemy_candidate_dominance_filter.gd")
const ClassifierScript = preload(
    "res://core/ai/enemy_candidate_direction_classifier.gd")
const DiagnosticsScript = preload(
    "res://core/ai/enemy_candidate_reduction_diagnostics.gd")

const MINIMUM_LIMIT := 1
const MAXIMUM_LIMIT := 5

var feature_projector
var dominance_filter := DominanceScript.new()
var direction_classifier := ClassifierScript.new()

func _init(value_query_service = null) -> void:
    feature_projector = ProjectorScript.new(value_query_service)

func reduce(
        proposals: Array,
        observation,
        actor,
        target,
        policy: Dictionary = {},
        round_number: int = 0) -> Dictionary:
    var normalized_policy := normalize_policy(policy)
    if proposals.is_empty():
        return {
            "success": true, "full_count": 0, "pareto_count": 0,
            "records": [], "proposals": [], "candidate_limit": _limit(policy),
            "diagnostics": DiagnosticsScript.new().build(
                [], {"kept": [], "dominated": []}, [],
                normalized_policy, [], {"rounds": []}, {}),
        }
    var before: Dictionary = actor.capture_passive_query_state() \
        if actor != null and actor.has_method("capture_passive_query_state") else {}
    var records: Array = []
    for serial in range(proposals.size()):
        var projected: Dictionary = feature_projector.project(
            proposals[serial], observation, actor, target,
            normalized_policy, round_number)
        if not projected.get("success", false):
            return {
                "success": false,
                "reason": str(projected.get("reason", "候选画像失败")),
                "full_count": proposals.size(), "records": [], "proposals": [],
            }
        var features: Dictionary = direction_classifier.classify(
            projected["features"], normalized_policy)
        records.append({
            "proposal": proposals[serial],
            "features": features,
            "serial": serial,
            "diagnostic_candidate_id": "local-%03d" % serial,
        })
    _mark_unique_hard_candidates(records)
    var dominance: Dictionary = dominance_filter.analyze(records)
    var pareto: Array = dominance["kept"]
    var protected: Array = _hard_protected(records)
    var limit: int = _limit(policy)
    var selected: Array = []
    var hard_trace := _hard_trace(protected, limit)
    for protected_index in range(protected.size()):
        if selected.size() >= limit:
            break
        var record = protected[protected_index]
        record["selection_stage"] = "hard_protection"
        record["selection_reason"] = ",".join(
            record["features"]["internal"]["hard_reasons"])
        selected.append(record)
    # 先让六个方向分别产生可审计的代表，再由 MMR 从这些代表中决定有限
    # 席位。若在这里按方向直接填满上限，六个方向会令 MMR 永远不可达。
    var direction_trace: Array = []
    var direction_representatives: Array = []
    for direction in ClassifierScript.DIRECTIONS:
        var direction_result := _direction_representative(
            pareto, direction, selected)
        direction_trace.append(direction_result["diagnostics"])
        var representative = direction_result.get("winner")
        if representative != null and not direction_representatives.has(
                representative):
            direction_representatives.append(representative)
    var mmr_trace: Dictionary = _fill_mmr(
        selected, direction_representatives, limit, normalized_policy)
    if selected.is_empty():
        var fallback = _best_quality(records)
        fallback["selection_stage"] = "fallback_quality"
        fallback["selection_reason"] = "no_hard_pareto_direction_or_mmr_selection"
        selected.append(fallback)
    if actor != null and not before.is_empty() \
            and actor.capture_passive_query_state() != before:
        actor.replace_passive_query_state(before)
        return {
            "success": false,
            "reason": "候选压缩不得修改战斗状态或推进 RNG",
            "full_count": proposals.size(), "records": [], "proposals": [],
        }
    var diagnostics := DiagnosticsScript.new().build(
        records, dominance, selected, normalized_policy,
        direction_trace, mmr_trace, hard_trace)
    return {
        "success": true,
        "full_count": proposals.size(),
        "pareto_count": pareto.size(),
        "records": selected,
        "proposals": selected.map(func(record): return record["proposal"]),
        "candidate_limit": limit,
        "diagnostics": diagnostics,
    }

func normalize_policy(policy: Dictionary) -> Dictionary:
    var result := policy.duplicate(true)
    result["candidate_limit"] = _limit(policy)
    result["diversity_penalty"] = clampf(
        float(policy.get("diversity_penalty", 0.35)), 0.0, 1.0)
    result["future_value_discount"] = clampf(
        float(policy.get("future_value_discount", 0.5)), 0.0, 1.0)
    var weights: Dictionary = policy.get("direction_weights", {}).duplicate(true)
    for direction in ClassifierScript.DIRECTIONS:
        weights[direction] = maxf(0.0, float(weights.get(direction, 1.0)))
    result["direction_weights"] = weights
    return result

func _limit(policy: Dictionary) -> int:
    return clampi(
        int(policy.get("candidate_limit", MAXIMUM_LIMIT)),
        MINIMUM_LIMIT,
        MAXIMUM_LIMIT)

func _mark_unique_hard_candidates(records: Array) -> void:
    var predicates := {
        "lethal": func(features): return bool(features["immediate"]["lethal"]),
        "survival": func(features): return bool(features["immediate"]["avoids_immediate_death"]),
        "severe_cleanup": func(features): return float(features["card_state"]["negative_card_cleanup_value"]) > 0.0,
        "decisive_progress": func(features):
            for entry in features["passives"].get("progress_entries", []):
                if entry is Dictionary and bool(entry.get("trigger_ready", false)):
                    return true
            return false,
    }
    for reason in predicates:
        var matches: Array = []
        for record in records:
            if predicates[reason].call(record["features"]):
                matches.append(record)
        if matches.size() == 1:
            matches[0]["features"]["internal"]["hard_reasons"].append(reason)

func _hard_protected(records: Array) -> Array:
    var result: Array = records.filter(func(record):
        return not record["features"]["internal"]["hard_reasons"].is_empty())
    result.sort_custom(func(left, right):
        var left_priority := _hard_priority(left["features"])
        var right_priority := _hard_priority(right["features"])
        if left_priority != right_priority:
            return left_priority > right_priority
        if not is_equal_approx(float(left["features"]["quality"]), float(right["features"]["quality"])):
            return float(left["features"]["quality"]) > float(right["features"]["quality"])
        return int(left["serial"]) < int(right["serial"]))
    return result

func _hard_priority(features: Dictionary) -> int:
    var reasons: Array = features["internal"]["hard_reasons"]
    if reasons.has("survival"):
        return 4
    if reasons.has("lethal"):
        return 3
    if reasons.has("severe_cleanup"):
        return 2
    return 1

func _best_for_direction(records: Array, direction: String, selected: Array):
    return _direction_representative(records, direction, selected).get("winner")

func _direction_representative(
        records: Array,
        direction: String,
        selected: Array) -> Dictionary:
    var best = null
    var best_score := -INF
    var considered: Array = []
    for record in records:
        if selected.has(record):
            continue
        var score := float(record["features"]["direction_scores"].get(direction, 0.0))
        considered.append({
            "diagnostic_candidate_id": _diagnostic_id(record),
            "direction_score": score,
            "quality": float(record["features"]["quality"]),
            "enumeration_index": int(record["serial"]),
        })
        if score > best_score or (is_equal_approx(score, best_score) \
                and _record_before(record, best)):
            best = record
            best_score = score
    considered.sort_custom(func(left, right):
        if not is_equal_approx(float(left["direction_score"]), float(right["direction_score"])):
            return float(left["direction_score"]) > float(right["direction_score"])
        if not is_equal_approx(float(left["quality"]), float(right["quality"])):
            return float(left["quality"]) > float(right["quality"])
        return int(left["enumeration_index"]) < int(right["enumeration_index"]))
    return {
        "winner": best,
        "diagnostics": {
            "direction": direction,
            "winner_candidate_id": _diagnostic_id(best) if best != null else "",
            "winner_score": best_score if best != null else null,
            "considered": considered,
        },
    }

func _fill_mmr(
        selected: Array,
        candidates: Array,
        limit: int,
        policy: Dictionary) -> Dictionary:
    var quality_range := _quality_range(candidates)
    var penalty := float(policy.get("diversity_penalty", 0.35))
    var trace := {
        "diversity_penalty": penalty,
        "similarity_threshold": 0.94,
        "quality_min": quality_range.x,
        "quality_max": quality_range.y,
        "rounds": [],
        "stop_reason": "",
        "stopped_candidate_id": "",
    }
    while selected.size() < limit:
        var best = null
        var best_score := -INF
        var best_similarity := 0.0
        var round_candidates: Array = []
        for candidate in candidates:
            if selected.has(candidate):
                continue
            var similarity := _maximum_similarity(candidate, selected)
            var normalized := _normalized_quality(
                float(candidate["features"]["quality"]), quality_range)
            var score := normalized - penalty * similarity
            round_candidates.append({
                "diagnostic_candidate_id": _diagnostic_id(candidate),
                "raw_quality": float(candidate["features"]["quality"]),
                "normalized_quality": normalized,
                "maximum_similarity": similarity,
                "diversity_penalty": penalty * similarity,
                "mmr_score": score,
            })
            if score > best_score or (is_equal_approx(score, best_score) \
                    and _record_before(candidate, best)):
                best = candidate
                best_score = score
                best_similarity = similarity
        round_candidates.sort_custom(func(left, right):
            if not is_equal_approx(float(left["mmr_score"]), float(right["mmr_score"])):
                return float(left["mmr_score"]) > float(right["mmr_score"])
            return str(left["diagnostic_candidate_id"]) < str(right["diagnostic_candidate_id"]))
        var round_entry := {
            "round_index": trace["rounds"].size(),
            "selected_before": selected.map(func(record): return _diagnostic_id(record)),
            "candidates": round_candidates,
            "winner_candidate_id": _diagnostic_id(best) if best != null else "",
            "winner_score": best_score if best != null else null,
            "winner_similarity": best_similarity if best != null else null,
        }
        trace["rounds"].append(round_entry)
        if best == null:
            trace["stop_reason"] = "no_remaining_candidate"
            return trace
        # 近乎同一画像不为凑满名额重复公开；合法候选仍留在本地完整集合中。
        if best_similarity >= 0.94 and not selected.is_empty():
            trace["stop_reason"] = "similarity_threshold"
            trace["stopped_candidate_id"] = _diagnostic_id(best)
            return trace
        best["selection_stage"] = "direction_representative_mmr"
        best["selection_reason"] = "direction_representative_quality_minus_similarity_penalty"
        selected.append(best)
    trace["stop_reason"] = "candidate_limit_reached"
    return trace

func _hard_trace(protected: Array, limit: int) -> Dictionary:
    var ordered_ids: Array[String] = []
    var priority_by_id: Dictionary = {}
    var rank_by_id: Dictionary = {}
    var selected_by_id: Dictionary = {}
    for index in range(protected.size()):
        var candidate_id := _diagnostic_id(protected[index])
        ordered_ids.append(candidate_id)
        priority_by_id[candidate_id] = _hard_priority(protected[index]["features"])
        rank_by_id[candidate_id] = index
        selected_by_id[candidate_id] = index < limit
    return {
        "ordered_ids": ordered_ids,
        "priority_by_id": priority_by_id,
        "rank_by_id": rank_by_id,
        "selected_by_id": selected_by_id,
        "overflow_count": maxi(0, protected.size() - limit),
    }

func _diagnostic_id(record) -> String:
    if record == null:
        return ""
    return str(record.get(
        "diagnostic_candidate_id", "local-%03d" % int(record["serial"])))

func _maximum_similarity(record: Dictionary, selected: Array) -> float:
    var result := 0.0
    for other in selected:
        result = maxf(result, _similarity(record["features"], other["features"]))
    return result

func _similarity(left: Dictionary, right: Dictionary) -> float:
    var terms: Array[float] = []
    terms.append(_jaccard(left["internal"]["card_ids"], right["internal"]["card_ids"]))
    terms.append(1.0 if left["identity"]["hand_type"] == right["identity"]["hand_type"] else 0.0)
    terms.append(1.0 if left["identity"]["technique_id"] == right["identity"]["technique_id"] else 0.0)
    terms.append(_numeric_similarity(left["immediate"]["damage"], right["immediate"]["damage"]))
    terms.append(_numeric_similarity(left["immediate"]["defense"], right["immediate"]["defense"]))
    terms.append(_numeric_similarity(left["card_flow"]["played_count"], right["card_flow"]["played_count"]))
    terms.append(_numeric_similarity(left["card_flow"]["extra_played_count"], right["card_flow"]["extra_played_count"]))
    terms.append(_numeric_similarity(left["future"]["retained_hand_value"], right["future"]["retained_hand_value"]))
    terms.append(_numeric_similarity(left["card_flow"]["expected_next_normal_draw"], right["card_flow"]["expected_next_normal_draw"]))
    terms.append(_jaccard(left["internal"]["status_change_signatures"], right["internal"]["status_change_signatures"]))
    terms.append(_jaccard(left["passives"]["trigger_signatures"], right["passives"]["trigger_signatures"]))
    terms.append(1.0 if left["identity"]["next_technique_id"] == right["identity"]["next_technique_id"] else 0.0)
    terms.append(1.0 if left["immediate"]["combo"] == right["immediate"]["combo"] else 0.0)
    var total := 0.0
    for term in terms:
        total += term
    return total / float(terms.size())

func _numeric_similarity(left_value, right_value) -> float:
    var left := absf(float(left_value))
    var right := absf(float(right_value))
    return 1.0 - absf(left - right) / maxf(1.0, maxf(left, right))

func _jaccard(left: Array, right: Array) -> float:
    var union: Dictionary = {}
    var intersection := 0
    for value in left:
        union[str(value)] = true
    for value in right:
        var key := str(value)
        if union.has(key):
            intersection += 1
        union[key] = true
    return 1.0 if union.is_empty() else float(intersection) / float(union.size())

func _quality_range(records: Array) -> Vector2:
    var minimum := INF
    var maximum := -INF
    for record in records:
        var value := float(record["features"]["quality"])
        minimum = minf(minimum, value)
        maximum = maxf(maximum, value)
    return Vector2(minimum, maximum)

func _normalized_quality(value: float, quality_range: Vector2) -> float:
    if is_equal_approx(quality_range.x, quality_range.y):
        return 1.0
    return (value - quality_range.x) / (quality_range.y - quality_range.x)

func _best_quality(records: Array):
    var best = null
    for record in records:
        if _record_before(record, best):
            best = record
    return best

func _record_before(left, right) -> bool:
    if right == null:
        return true
    var left_quality := float(left["features"]["quality"])
    var right_quality := float(right["features"]["quality"])
    if not is_equal_approx(left_quality, right_quality):
        return left_quality > right_quality
    return int(left["serial"]) < int(right["serial"])
