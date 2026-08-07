class_name ArtAssetValidator
extends RefCounted

const REQUIRED_METADATA := ["asset_id", "category", "version", "source", "generation", "edits", "approval", "anchors", "transparent_padding"]
const NAME_PATTERNS := {
    "cards": "^card_[a-z0-9]+_(?:a|[2-9]|10|j|q|k)_v[0-9]{3}$",
    "portraits": "^portrait_[a-z0-9]+_[a-z0-9]+_v[0-9]{3}$",
    "backgrounds": "^bg_[a-z0-9]+_[a-z0-9]+_v[0-9]{3}$",
    "icons": "^icon_[a-z0-9]+_[a-z0-9]+_v[0-9]{3}$",
    "vfx": "^fx_[a-z0-9]+_[a-z0-9]+_v[0-9]{3}$",
    "audio": "^audio_[a-z0-9]+_[a-z0-9]+_v[0-9]{3}$",
    "fonts": "^font_[a-z0-9]+_v[0-9]{3}$"
}
const ALLOWED_APPROVALS := ["draft", "approved", "rejected"]
const TEXTURE_CATEGORIES := ["cards", "portraits", "backgrounds", "icons", "vfx"]

func validate_assets(root_path: String, profiles_path: String) -> Dictionary:
    var result := {"errors": [], "warnings": [], "checked": 0}
    var profiles_file := FileAccess.open(profiles_path, FileAccess.READ)
    if profiles_file == null:
        result.errors.append("import profiles missing: %s" % profiles_path)
        return result
    var profiles = JSON.parse_string(profiles_file.get_as_text())
    if not profiles is Dictionary or not profiles.has("profiles"):
        result.errors.append("import profiles are not a valid object")
        return result
    _validate_profiles(profiles, result)
    var root := DirAccess.open(root_path)
    if root == null:
        result.errors.append("asset root missing: %s" % root_path)
        return result
    for category in profiles.profiles.keys():
        var category_path := root_path.path_join(str(category))
        if not DirAccess.dir_exists_absolute(category_path):
            result.warnings.append("asset category has no files yet: %s" % category)
            continue
        _scan_dir(category_path, str(category), profiles.profiles[category], result)
    return result

func _validate_profiles(profiles: Dictionary, result: Dictionary) -> void:
    for category in TEXTURE_CATEGORIES:
        var profile = profiles.profiles.get(category, null)
        if not profile is Dictionary:
            result.errors.append("import profile missing texture category: %s" % category)
            continue
        for key in ["extensions", "canvas", "filter", "mipmaps", "compress", "atlas", "pixel_density", "transparent_safe_margin_px"]:
            if not profile.has(key):
                result.errors.append("import profile %s missing %s" % [category, key])
        if profile.get("extensions", []).is_empty():
            result.errors.append("import profile %s has no extensions" % category)
        if profile.get("pixel_density", 0.0) <= 0.0:
            result.errors.append("import profile %s has invalid pixel_density" % category)
    for category in ["audio", "fonts"]:
        var profile = profiles.profiles.get(category, null)
        if not profile is Dictionary or not profile.has("extensions"):
            result.errors.append("import profile missing category or extensions: %s" % category)
    if not profiles.has("platform_overrides"):
        result.errors.append("import profiles missing platform_overrides")

func _scan_dir(path: String, category: String, profile: Dictionary, result: Dictionary) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        if entry.begins_with("."):
            entry = dir.get_next()
            continue
        var full_path := path.path_join(entry)
        if dir.current_is_dir():
            _scan_dir(full_path, category, profile, result)
        elif not entry.ends_with(".asset.json") and not entry.ends_with(".md") and not entry.ends_with(".import"):
            _check_asset(full_path, category, profile, result)
        entry = dir.get_next()
    dir.list_dir_end()

func _check_asset(path: String, category: String, profile: Dictionary, result: Dictionary) -> void:
    result.checked += 1
    var file_name := path.get_file()
    var stem := file_name.get_basename()
    var extension := file_name.get_extension().to_lower()
    var allowed: Array = profile.get("extensions", [])
    if not allowed.has(extension):
        result.errors.append("%s: extension .%s is not allowed for %s" % [path, extension, category])
    var pattern_text: String = NAME_PATTERNS.get(category, "")
    if pattern_text != "" and not RegEx.create_from_string(pattern_text).search(stem):
        result.errors.append("%s: filename does not match %s" % [path, pattern_text])
    var metadata_path := path + ".asset.json"
    if not FileAccess.file_exists(metadata_path):
        result.errors.append("%s: missing authorization/source metadata (%s)" % [path, metadata_path])
        return
    var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
    var metadata = JSON.parse_string(metadata_file.get_as_text()) if metadata_file != null else null
    if not metadata is Dictionary:
        result.errors.append("%s: metadata is not valid JSON" % metadata_path)
        return
    for key in REQUIRED_METADATA:
        if not metadata.has(key):
            result.errors.append("%s: metadata missing %s" % [metadata_path, key])
    if str(metadata.get("asset_id", "")) != stem:
        result.errors.append("%s: asset_id must equal filename stem" % metadata_path)
    if str(metadata.get("category", "")) != category:
        result.errors.append("%s: metadata category mismatch" % metadata_path)
    var source = metadata.get("source", {})
    if not source is Dictionary or str(source.get("kind", "")) == "" or str(source.get("license", "")) == "":
        result.errors.append("%s: source.kind and source.license are required" % metadata_path)
    var generation = metadata.get("generation", {})
    if not generation is Dictionary or str(generation.get("prompt", "")) == "" or not generation.has("seed"):
        result.errors.append("%s: generation.prompt and generation.seed are required" % metadata_path)
    var approval = metadata.get("approval", {})
    if not approval is Dictionary or not ALLOWED_APPROVALS.has(str(approval.get("status", ""))):
        result.errors.append("%s: approval.status must be draft, approved, or rejected" % metadata_path)
    if not metadata.get("anchors", {}) is Dictionary:
        result.errors.append("%s: anchors must be an object" % metadata_path)
    if not metadata.get("transparent_padding", {}) is Dictionary:
        result.errors.append("%s: transparent_padding must be an object" % metadata_path)
    if profile.has("canvas"):
        var size := _read_dimensions(path, extension)
        var expected: Array = profile.canvas
        if size.x != int(expected[0]) or size.y != int(expected[1]):
            result.errors.append("%s: dimensions %dx%d, expected %dx%d" % [path, size.x, size.y, expected[0], expected[1]])

func _read_dimensions(path: String, extension: String) -> Vector2i:
    if extension == "svg":
        var text := FileAccess.get_file_as_string(path)
        var width_match := RegEx.create_from_string("width=[\\\"']([0-9]+)").search(text)
        var height_match := RegEx.create_from_string("height=[\\\"']([0-9]+)").search(text)
        if width_match and height_match:
            return Vector2i(int(width_match.get_string(1)), int(height_match.get_string(1)))
        var viewbox_match := RegEx.create_from_string("viewBox=[\\\"']0 0 ([0-9]+) ([0-9]+)").search(text)
        if viewbox_match:
            return Vector2i(int(viewbox_match.get_string(1)), int(viewbox_match.get_string(2)))
        return Vector2i.ZERO
    var image := Image.load_from_file(path)
    return image.get_size() if image != null else Vector2i.ZERO
