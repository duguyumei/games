class_name HandResultDto
extends RefCounted

const SCHEMA_VERSION := 1

var id: String = ""
var name: String = ""
var multiplier: int = 0
var strength: int = 0
var contributing: Array = []
var royal: bool = false

func configure(values: Dictionary):
    id = str(values.get("id", ""))
    name = str(values.get("name", ""))
    multiplier = int(values.get("multiplier", 0))
    strength = int(values.get("strength", 0))
    contributing = values.get("contributing", []).duplicate()
    royal = bool(values.get("royal", false))
    return self

func is_empty() -> bool:
    return id == ""

func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "id": id,
        "name": name,
        "multiplier": multiplier,
        "strength": strength,
        "contributing": contributing.duplicate(),
        "royal": royal,
    }

func duplicate(_deep: bool = false) -> Dictionary:
    return to_dict()
