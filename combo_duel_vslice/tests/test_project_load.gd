extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")

var failures: Array[String] = []
var loaded_resources: int = 0


func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _scan_directory("res://")
    if failures.is_empty():
        print("PROJECT LOAD PASS: %d scripts/scenes/resources/json files" % loaded_resources)
        quit(0)
        return
    for failure in failures:
        push_error("PROJECT LOAD FAIL: %s" % failure)
    print("PROJECT LOAD FAILURES: %d after %d successful loads" % [
        failures.size(),
        loaded_resources,
    ])
    quit(1)


func _scan_directory(path: String) -> void:
    var directory := DirAccess.open(path)
    if directory == null:
        failures.append("无法打开目录 %s" % path)
        return
    directory.list_dir_begin()
    var entry := directory.get_next()
    while not entry.is_empty():
        if entry != ".godot":
            var resource_path := path.path_join(entry)
            if directory.current_is_dir():
                _scan_directory(resource_path)
            else:
                _load_resource(resource_path)
        entry = directory.get_next()
    directory.list_dir_end()


func _load_resource(path: String) -> void:
    var extension := path.get_extension().to_lower()
    if extension == "json":
        _load_json(path)
        return
    if extension not in ["gd", "tscn", "tres"]:
        return
    if ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) == null:
        failures.append("无法加载 %s" % path)
        return
    loaded_resources += 1


func _load_json(path: String) -> void:
    var json := JSON.new()
    var error := json.parse(FileAccess.get_file_as_string(path))
    if error != OK:
        failures.append("JSON 解析失败 %s:%d：%s" % [
            path,
            json.get_error_line(),
            json.get_error_message(),
        ])
        return
    loaded_resources += 1
