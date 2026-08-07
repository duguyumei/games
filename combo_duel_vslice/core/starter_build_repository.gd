class_name StarterBuildRepository
extends RefCounted

const DEFAULT_BUILD_ID := "standard_52"

var _builds: Dictionary = {}

func configure(definition: Dictionary) -> bool:
    _builds.clear()
    for value in definition.get("starter_builds", []):
        if value is Dictionary:
            _builds[str(value.get("id", ""))] = value.duplicate(true)
    return not _builds.is_empty()

func get_build(build_id: String) -> Dictionary:
    return _builds.get(build_id, {}).duplicate(true)

func available_builds() -> Array:
    var result: Array = []
    for value in _builds.values():
        if bool(value.get("available", false)):
            result.append(value.duplicate(true))
    result.sort_custom(func(left, right): return str(left["id"]) < str(right["id"]))
    return result

func validate_selection(build_id: String) -> Dictionary:
    var definition := get_build(build_id)
    if definition.is_empty():
        return {"success": false, "reason": "初始构筑不存在：%s" % build_id}
    if not bool(definition.get("available", false)):
        return {"success": false, "reason": "该初始构筑当前不可选择"}
    if str(definition.get("deck_kind", "")) != "standard_52":
        return {"success": false, "reason": "当前版本不支持该初始牌组类型"}
    var card_ids = definition.get("card_ids")
    if not card_ids is Array or card_ids.size() != int(definition.get("card_count", 0)):
        return {"success": false, "reason": "初始构筑真气清单不完整"}
    return {"success": true, "definition": definition}
