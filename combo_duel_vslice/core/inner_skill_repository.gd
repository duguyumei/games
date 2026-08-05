class_name InnerSkillRepository
extends RefCounted

const DATA_PATH := "res://data/inner_skills.json"

var inner_skills: Dictionary = {}

func load_from_file(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("内功数据无法解析：%s" % path)
        return false
    return configure(parsed)

func configure(value: Dictionary) -> bool:
    var parsed := value.duplicate(true)
    inner_skills.clear()
    for definition in parsed.get("inner_skills", []):
        if not definition is Dictionary or str(definition.get("id", "")) == "":
            continue
        inner_skills[str(definition["id"])] = definition.duplicate(true)
    return true

func get_inner_skill(inner_skill_id: String) -> Dictionary:
    return inner_skills.get(inner_skill_id, {}).duplicate(true)
