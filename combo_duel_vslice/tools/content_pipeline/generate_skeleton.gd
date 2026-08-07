extends SceneTree

const GeneratorScript = preload("res://tools/content_pipeline/content_skeleton_generator.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var options := {"type": "", "id": "", "name": "", "output": ""}
    var arguments := OS.get_cmdline_user_args()
    var index := 0
    while index < arguments.size():
        var argument := str(arguments[index])
        if argument in ["--type", "--id", "--name", "--output"] and index + 1 < arguments.size():
            index += 1
            options[argument.trim_prefix("--")] = str(arguments[index])
        else:
            printerr("参数错误：%s" % argument)
            quit(2)
            return
        index += 1
    for key in options:
        if str(options[key]) == "":
            printerr("缺少参数 --%s" % key)
            quit(2)
            return
    if FileAccess.file_exists(options["output"]):
        printerr("拒绝覆盖已有文件：%s" % options["output"])
        quit(2)
        return
    var rendered: Dictionary = GeneratorScript.new().render(options["type"], options["id"], options["name"])
    if not rendered.get("success", false):
        printerr(str(rendered.get("error", "生成失败")))
        quit(2)
        return
    var file := FileAccess.open(options["output"], FileAccess.WRITE)
    if file == null:
        printerr("无法写入：%s" % options["output"])
        quit(2)
        return
    file.store_string(str(rendered["text"]))
    print(JSON.stringify({"success": true, "type": options["type"], "id": options["id"], "output": options["output"]}))
    quit(0)
