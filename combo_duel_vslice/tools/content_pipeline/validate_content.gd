extends SceneTree

const ContentBatchValidatorScript = preload("res://tools/content_pipeline/content_batch_validator.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var report_path := ""
    var data_root := "res://data"
    var pretty := false
    var arguments := OS.get_cmdline_user_args()
    var index := 0
    while index < arguments.size():
        var argument := str(arguments[index])
        if argument == "--report" and index + 1 < arguments.size():
            index += 1
            report_path = str(arguments[index])
        elif argument == "--data-root" and index + 1 < arguments.size():
            index += 1
            data_root = str(arguments[index])
        elif argument == "--pretty":
            pretty = true
        else:
            printerr("未知参数：%s" % argument)
            quit(2)
            return
        index += 1

    var report: Dictionary = ContentBatchValidatorScript.new().validate_project(data_root)
    var output := JSON.stringify(report, "  " if pretty else "")
    if report_path != "":
        var file := FileAccess.open(report_path, FileAccess.WRITE)
        if file == null:
            printerr("无法写入校验报告：%s" % report_path)
            quit(2)
            return
        file.store_string(output + "\n")
    print(output)
    quit(0 if bool(report["valid"]) else 1)
