class_name AiTraceReporter
extends RefCounted

const SCHEMA_VERSION := 1

func report_directory(directory: String) -> Dictionary:
    var absolute := ProjectSettings.globalize_path(directory)
    var dir := DirAccess.open(absolute)
    if dir == null:
        return _empty_report(directory)
    var paths: Array[String] = []
    dir.list_dir_begin()
    var filename := dir.get_next()
    while filename != "":
        if not dir.current_is_dir() and filename.ends_with(".json"):
            paths.append("%s/%s" % [absolute.rstrip("/"), filename])
        filename = dir.get_next()
    dir.list_dir_end()
    paths.sort()
    return report_paths(paths, directory)

func report_paths(paths: Array, source: String = "") -> Dictionary:
    var valid: Array = []
    var damaged: Array = []
    for path_value in paths:
        var path := str(path_value)
        var parsed = null
        if FileAccess.file_exists(path):
            var parser := JSON.new()
            if parser.parse(FileAccess.get_file_as_string(path)) == OK:
                parsed = parser.data
        if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
            damaged.append({"path": path, "error": "损坏或不受支持的轨迹文件"})
            continue
        valid.append(parsed)
    if valid.is_empty():
        var empty := _empty_report(source)
        empty["damaged_files"] = damaged
        return empty
    var aggregate := _aggregate(valid)
    return {
        "success": true,
        "schema_version": SCHEMA_VERSION,
        "status": "ok",
        "source": source,
        "battle_count": valid.size(),
        "damaged_file_count": damaged.size(),
        "damaged_files": damaged,
        "aggregate": aggregate,
        "human_summary": _summary(aggregate, valid.size(), damaged.size()),
    }

func _aggregate(traces: Array) -> Dictionary:
    var windows := 0
    var full := 0
    var pareto := 0
    var published := 0
    var remote := 0
    var fallback := 0
    var validation_failures := 0
    var timeouts := 0
    var elapsed := 0
    var elapsed_count := 0
    var prompt_tokens := 0
    var completion_tokens := 0
    var missed_lethal := 0
    var missed_survival := 0
    var damage_error := 0.0
    var damage_error_count := 0
    var defense_error := 0.0
    var defense_error_count := 0
    var direction_appearances: Dictionary = {}
    var direction_selections: Dictionary = {}
    var enemies: Dictionary = {}
    for trace in traces:
        for window in trace.get("windows", []):
            windows += 1
            var pipeline: Dictionary = window.get("candidate_pipeline", {})
            full += int(pipeline.get("full_count", 0))
            pareto += int(pipeline.get("pareto_count", 0))
            published += int(pipeline.get("published_count", 0))
            var diagnostics: Dictionary = window.get("candidate_diagnostics", {})
            for candidate in diagnostics.get("candidates", []):
                if bool(candidate.get("selection", {}).get("selected", false)):
                    _increment(direction_appearances, str(candidate.get(
                        "direction", {}).get("primary", "unknown")))
            var selected: Dictionary = window.get("selected", {})
            var source := str(selected.get("source", ""))
            remote += 1 if source == "remote" else 0
            fallback += 1 if source == "local_utility" else 0
            if not selected.is_empty():
                _increment(direction_selections, str(selected.get(
                    "primary_direction", "unknown")))
                elapsed += int(selected.get("elapsed_msec", 0))
                elapsed_count += 1
                prompt_tokens += int(selected.get("usage", {}).get("prompt_tokens", 0))
                completion_tokens += int(selected.get("usage", {}).get("completion_tokens", 0))
            var actual: Dictionary = window.get("actual_result", {})
            var estimate := _selected_estimate(window)
            if not actual.is_empty() and not estimate.is_empty():
                damage_error += absf(float(actual.get("actual_damage", 0)) \
                    - float(estimate.get("damage", 0)))
                defense_error += absf(float(actual.get("actual_defense", 0)) \
                    - float(estimate.get("defense", 0)))
                damage_error_count += 1
                defense_error_count += 1
        var summary: Dictionary = trace.get("battle_summary", {})
        validation_failures += int(summary.get("validation_failure_count", 0))
        timeouts += int(summary.get("timeout_count", 0))
        missed_lethal += int(summary.get("missed_lethal_count", 0))
        missed_survival += int(summary.get("missed_survival_count", 0))
        var enemy_id := str(summary.get("enemy_id", "unknown"))
        if not enemies.has(enemy_id):
            enemies[enemy_id] = {"battles": 0, "wins": 0, "rounds": 0}
        enemies[enemy_id]["battles"] += 1
        enemies[enemy_id]["wins"] += 1 if str(summary.get("battle_result", "")) == "enemy_won" else 0
        enemies[enemy_id]["rounds"] += int(summary.get("total_rounds", 0))
    return {
        "action_window_count": windows,
        "average_full_candidate_count": _ratio(full, windows),
        "average_pareto_candidate_count": _ratio(pareto, windows),
        "average_published_candidate_count": _ratio(published, windows),
        "direction_appearance_counts": _stable(direction_appearances),
        "direction_selection_counts": _stable(direction_selections),
        "remote_success_rate": _ratio(remote, windows),
        "local_fallback_rate": _ratio(fallback, windows),
        "format_error_rate": _ratio(validation_failures, windows),
        "timeout_rate": _ratio(timeouts, windows),
        "average_elapsed_msec": _ratio(elapsed, elapsed_count),
        "token_usage": {"prompt": prompt_tokens, "completion": completion_tokens},
        "missed_lethal_count": missed_lethal,
        "missed_survival_count": missed_survival,
        "mean_absolute_damage_error": _ratio(damage_error, damage_error_count),
        "mean_absolute_defense_error": _ratio(defense_error, defense_error_count),
        "enemies": _enemy_report(enemies),
    }

func _selected_estimate(window: Dictionary) -> Dictionary:
    var selected_id := str(window.get("selected", {}).get("diagnostic_candidate_id", ""))
    for candidate in window.get("candidate_diagnostics", {}).get("candidates", []):
        if str(candidate.get("diagnostic_candidate_id", "")) == selected_id:
            return candidate.get("features", {}).get("immediate", {}).duplicate(true)
    return {}

func _enemy_report(values: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for enemy_id in values:
        var value: Dictionary = values[enemy_id]
        result[enemy_id] = {
            "battle_count": int(value["battles"]),
            "win_rate": _ratio(value["wins"], value["battles"]),
            "average_rounds": _ratio(value["rounds"], value["battles"]),
        }
    return _stable(result)

func _empty_report(source: String) -> Dictionary:
    return {
        "success": true, "schema_version": SCHEMA_VERSION,
        "status": "no_data", "source": source, "battle_count": 0,
        "damaged_file_count": 0, "damaged_files": [], "aggregate": {},
        "human_summary": "无数据：目录中没有可用的 AI 私有决策轨迹。",
    }

func _summary(aggregate: Dictionary, battles: int, damaged: int) -> String:
    return "%d 场战斗，%d 个行动窗口；远程成功率 %.2f%%，本地接管率 %.2f%%，损坏文件 %d。" % [
        battles, int(aggregate["action_window_count"]),
        float(aggregate["remote_success_rate"]) * 100.0,
        float(aggregate["local_fallback_rate"]) * 100.0, damaged]

func _increment(target: Dictionary, key: String) -> void:
    target[key] = int(target.get(key, 0)) + 1

func _ratio(numerator, denominator) -> float:
    return 0.0 if float(denominator) == 0.0 else float(numerator) / float(denominator)

func _stable(values: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    var keys: Array = values.keys()
    keys.sort_custom(func(left, right): return str(left) < str(right))
    for key in keys:
        result[str(key)] = values[key]
    return result
