extends SceneTree

const ReporterScript = preload("res://tools/ai/ai_trace_reporter.gd")

func _initialize() -> void:
    var arguments := _arguments(OS.get_cmdline_user_args())
    var trace_dir := str(arguments.get("trace-dir", "user://ai/traces"))
    var output := str(arguments.get("output", "/tmp/taiwu-ai-trace-report.json"))
    var report: Dictionary = ReporterScript.new().report_directory(trace_dir)
    var file := FileAccess.open(output, FileAccess.WRITE)
    if file == null:
        push_error("AI TRACE REPORT ERROR: 无法写入 %s" % output)
        quit(2)
        return
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    print(report["human_summary"])
    print("AI TRACE REPORT PASS: %s" % output)
    quit(0)

func _arguments(values: Array) -> Dictionary:
    var result: Dictionary = {}
    for value in values:
        var text := str(value)
        if text.begins_with("--trace-dir="):
            result["trace-dir"] = text.trim_prefix("--trace-dir=")
        elif text.begins_with("--output="):
            result["output"] = text.trim_prefix("--output=")
    return result
