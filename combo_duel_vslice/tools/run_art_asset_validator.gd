extends SceneTree

const ValidatorScript = preload("res://tools/art_asset_validator.gd")

func _initialize() -> void:
    var validator = ValidatorScript.new()
    var result: Dictionary = validator.validate_assets(
        ProjectSettings.globalize_path("res://assets"),
        ProjectSettings.globalize_path("res://config/art_import_profiles.json"))
    for warning in result.warnings:
        print("ART WARNING: %s" % warning)
    for error in result.errors:
        push_error("ART ERROR: %s" % error)
    print("ART CHECK: %d assets, %d errors" % [result.checked, result.errors.size()])
    quit(1 if not result.errors.is_empty() else 0)
