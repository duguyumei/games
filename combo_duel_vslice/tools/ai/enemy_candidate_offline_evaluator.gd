class_name EnemyCandidateOfflineEvaluator
extends RefCounted

const BattleSessionScript = preload("res://core/battle_session.gd")

const SCHEMA_VERSION := 1

func evaluate(configuration: Dictionary) -> Dictionary:
    var cases = configuration.get("cases", [])
    if not cases is Array or cases.is_empty():
        return _failure("离线候选评估至少需要一个 case")
    var case_reports: Array = []
    var ids: Dictionary = {}
    for index in range(cases.size()):
        if not cases[index] is Dictionary:
            return _failure("cases[%d] 必须是对象" % index)
        var case_report := _evaluate_case(cases[index], index)
        if not case_report.get("success", false):
            return {
                "success": false,
                "schema_version": SCHEMA_VERSION,
                "reason": str(case_report.get("reason", "离线 case 失败")),
                "failed_case_index": index,
                "cases": case_reports,
            }
        var case_id := str(case_report["case_id"])
        if ids.has(case_id):
            return _failure("离线候选评估 case_id 重复：%s" % case_id)
        ids[case_id] = true
        case_reports.append(case_report)
    return {
        "success": true,
        "schema_version": SCHEMA_VERSION,
        "evaluation_kind": "enemy_candidate_reduction_offline_batch",
        "case_count": case_reports.size(),
        "aggregate": aggregate(case_reports),
        "cases": case_reports,
    }

func aggregate(case_reports: Array) -> Dictionary:
    var totals := {
        "full": 0, "hard_protected": 0, "pareto": 0,
        "dominated": 0, "selected": 0,
    }
    var direction_selected_counts: Dictionary = {}
    var selection_stage_counts: Dictionary = {}
    var stop_reason_counts: Dictionary = {}
    var total_quality := 0.0
    var selected_quality := 0.0
    var selected_entries := 0
    for case_report in case_reports:
        var diagnostics: Dictionary = case_report.get("diagnostics", {})
        var counts: Dictionary = diagnostics.get("counts", {})
        for field in totals:
            totals[field] = int(totals[field]) + int(counts.get(field, 0))
        var mmr_stop := str(diagnostics.get("mmr", {}).get(
            "stop_reason", "not_reached"))
        stop_reason_counts[mmr_stop] = int(
            stop_reason_counts.get(mmr_stop, 0)) + 1
        for candidate in diagnostics.get("candidates", []):
            total_quality += float(candidate.get("features", {}).get("quality", 0.0))
            var selection: Dictionary = candidate.get("selection", {})
            if not bool(selection.get("selected", false)):
                continue
            selected_entries += 1
            selected_quality += float(candidate.get(
                "features", {}).get("quality", 0.0))
            var direction := str(candidate.get(
                "direction", {}).get("primary", "unknown"))
            direction_selected_counts[direction] = int(
                direction_selected_counts.get(direction, 0)) + 1
            var stage := str(selection.get("selection_stage", "unknown"))
            selection_stage_counts[stage] = int(
                selection_stage_counts.get(stage, 0)) + 1
    var case_count := case_reports.size()
    return {
        "totals": totals,
        "averages": {
            "full_per_case": _ratio(totals["full"], case_count),
            "pareto_per_case": _ratio(totals["pareto"], case_count),
            "selected_per_case": _ratio(totals["selected"], case_count),
            "pareto_retention_ratio": _ratio(totals["pareto"], totals["full"]),
            "selection_ratio": _ratio(totals["selected"], totals["full"]),
            "candidate_quality": _ratio(total_quality, totals["full"]),
            "selected_quality": _ratio(selected_quality, selected_entries),
        },
        "selected_primary_direction_counts": _stable_dictionary(
            direction_selected_counts),
        "selection_stage_counts": _stable_dictionary(selection_stage_counts),
        "mmr_stop_reason_counts": _stable_dictionary(stop_reason_counts),
    }

func _evaluate_case(values: Dictionary, index: int) -> Dictionary:
    var case_id := str(values.get("case_id", "case-%03d" % index))
    if case_id == "":
        return _case_failure(case_id, "case_id 不能为空")
    var seed := int(values.get("content_seed", 2308))
    var battle: Dictionary = values.get("battle", {}).duplicate(true)
    battle["use_enemy_ai"] = true
    battle["use_remote_ai"] = false
    if not battle.has("scenario_path"):
        battle["scenario_path"] = "res://data/scripted_battle.json"
    var session = BattleSessionScript.new()
    var setup := {
        "content_seed": seed,
        "content_id": "offline-ai-eval-%s" % case_id,
        "act": int(values.get("act", 1)),
        "node_type": str(values.get("node_type", "combat")),
        "boss_variant": int(values.get("boss_variant", -1)),
        "battle": battle,
    }
    if not session.setup_battle(setup):
        return _case_failure(case_id, "战斗装配失败")
    var base_policy: Dictionary = session.engine.enemy_ai_policy.duplicate(true)
    var policy_override = values.get("policy", {})
    if not policy_override is Dictionary:
        return _case_failure(case_id, "policy 必须是对象")
    base_policy.merge(policy_override, true)
    session.engine.enemy_ai_policy = base_policy
    var start_result = session.execute({"type": "start_turn"})
    if not start_result.success:
        return _case_failure(case_id, str(start_result.reason))
    var planning_service = session.engine.enemy_planning_service
    var diagnostics: Dictionary = planning_service.candidate_reduction_diagnostics()
    if diagnostics.is_empty():
        return _case_failure(case_id, "首个行动窗口没有生成候选压缩诊断")
    return {
        "success": true,
        "case_id": case_id,
        "content_seed": seed,
        "battle": {
            "entry_kind": str(battle.get("entry_kind", "scripted")),
            "scenario_path": str(battle.get("scenario_path", "")),
            "act": int(setup["act"]),
            "node_type": str(setup["node_type"]),
            "boss_variant": int(setup["boss_variant"]),
        },
        "requested_policy": policy_override.duplicate(true),
        "effective_policy": diagnostics.get("policy", {}).duplicate(true),
        "summary": planning_service.last_candidate_reduction.duplicate(true),
        "diagnostics": diagnostics,
    }

func _ratio(numerator, denominator) -> float:
    return 0.0 if float(denominator) == 0.0 \
        else float(numerator) / float(denominator)

func _stable_dictionary(values: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    var keys: Array = values.keys()
    keys.sort_custom(func(left, right): return str(left) < str(right))
    for key in keys:
        result[str(key)] = values[key]
    return result

func _case_failure(case_id: String, reason: String) -> Dictionary:
    return {"success": false, "case_id": case_id, "reason": reason}

func _failure(reason: String) -> Dictionary:
    return {
        "success": false,
        "schema_version": SCHEMA_VERSION,
        "reason": reason,
        "cases": [],
    }
