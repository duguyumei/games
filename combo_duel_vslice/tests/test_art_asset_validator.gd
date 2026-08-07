extends SceneTree

const ValidatorScript = preload("res://tools/art_asset_validator.gd")

var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
    var validator = ValidatorScript.new()
    var assets_path := ProjectSettings.globalize_path("res://assets")
    var profiles_path := ProjectSettings.globalize_path("res://config/art_import_profiles.json")
    var valid: Dictionary = validator.validate_assets(assets_path, profiles_path)
    _assert_equal(valid.errors.size(), 0, "规范占位样本通过尺寸、命名和元数据校验")
    _assert_equal(valid.checked, 5, "只扫描五个可加载占位样本")

    var fixture_root := "/tmp/taiwu-art-validator-fixture-%d" % Time.get_ticks_msec()
    DirAccess.make_dir_recursive_absolute(fixture_root.path_join("icons"))
    _write_file(fixture_root.path_join("icons/bad-name.svg"), _svg(64, 64))
    _write_file(fixture_root.path_join("icons/icon_bad_default_v001.svg"), _svg(64, 64))
    _write_file(fixture_root.path_join("icons/icon_bad_default_v001.svg.asset.json"), _metadata("icon_bad_default_v001", "icons", ""))
    var invalid: Dictionary = validator.validate_assets(fixture_root, profiles_path)
    _assert_contains(invalid.errors, "filename does not match", "非法命名被检测")
    _assert_contains(invalid.errors, "missing authorization/source metadata", "缺少元数据被检测")
    _assert_contains(invalid.errors, "dimensions 64x64, expected 128x128", "非法尺寸被检测")
    _assert_contains(invalid.errors, "source.kind and source.license are required", "缺授权字段被检测")
    if failures.is_empty():
        print("ART TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("ART TEST FAIL: %s" % failure)
    print("ART TEST FAILURES: %d / %d assertions" % [failures.size(), assertions])
    quit(1)

func _write_file(path: String, value: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(value)

func _svg(width: int, height: int) -> String:
    return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\"><rect width=\"%d\" height=\"%d\"/></svg>" % [width, height, width, height]

func _metadata(asset_id: String, category: String, license_text: String) -> String:
    return JSON.stringify({
        "asset_id": asset_id,
        "category": category,
        "version": 1,
        "source": {"kind": "generated_placeholder", "provider": "test", "license": license_text},
        "generation": {"model": "n/a", "prompt": "fixture", "seed": 0},
        "edits": [],
        "approval": {"status": "draft", "reviewer": "test", "reviewed_at": "2026-08-07", "notes": "fixture"},
        "anchors": {"x": 0.5, "y": 0.5},
        "transparent_padding": {"left": 0, "top": 0, "right": 0, "bottom": 0}
    })

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_contains(values: Array, expected: String, label: String) -> void:
    assertions += 1
    for value in values:
        if str(value).contains(expected):
            return
    failures.append("%s：未找到 %s" % [label, expected])
