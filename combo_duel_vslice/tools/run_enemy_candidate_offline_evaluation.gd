extends SceneTree

const EvaluatorScript = preload(
    "res://tools/ai/enemy_candidate_offline_evaluator.gd")

func _initialize() -> void:
    var arguments := _arguments(OS.get_cmdline_user_args())
    var input_path := str(arguments.get(
        "input", "res://tools/ai/enemy_candidate_evaluation.example.json"))
    var output_path := str(arguments.get(
        "output", "/tmp/taiwu-enemy-candidate-evaluation.json"))
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(input_path))
    if not parsed is Dictionary:
        _fail("无法解析离线候选评估输入：%s" % input_path, 2)
        return
    var report: Dictionary = EvaluatorScript.new().evaluate(parsed)
    var file := FileAccess.open(output_path, FileAccess.WRITE)
    if file == null:
        _fail("无法写入离线候选评估报告：%s" % output_path, 2)
        return
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    if not report.get("success", false):
        _fail(str(report.get("reason", "离线候选评估失败")), 1)
        return
    var totals: Dictionary = report["aggregate"]["totals"]
    print("ENEMY CANDIDATE OFFLINE EVALUATION PASS: %d cases | full %d | pareto %d | selected %d | report %s" % [
        int(report["case_count"]), int(totals["full"]),
        int(totals["pareto"]), int(totals["selected"]), output_path])
    quit(0)

func _arguments(values: Array) -> Dictionary:
    var result: Dictionary = {}
    for value in values:
        var text := str(value)
        if text.begins_with("--input="):
            result["input"] = text.trim_prefix("--input=")
        elif text.begins_with("--output="):
            result["output"] = text.trim_prefix("--output=")
    return result

func _fail(message: String, code: int) -> void:
    push_error("ENEMY CANDIDATE OFFLINE EVALUATION ERROR: %s" % message)
    quit(code)
