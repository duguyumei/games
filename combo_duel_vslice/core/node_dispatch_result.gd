class_name NodeDispatchResult
extends RefCounted

const SCHEMA_VERSION := 1

var success: bool = false
var reason: String = ""
var route: String = ""
var node_id: String = ""
var node_type: String = ""
var generation_type: String = ""
var content_id: String = ""
var content_status: String = ""
var title: String = ""
var message: String = ""
var description: String = ""
var act: int = 1
var row: int = -1
var column: int = -1
var content_seed: int = 0
var boss_variant: int = -1
var battle: Dictionary = {}

func configure(values: Dictionary):
    success = bool(values.get("success", false))
    reason = str(values.get("reason", ""))
    route = str(values.get("route", ""))
    node_id = str(values.get("node_id", ""))
    node_type = str(values.get("node_type", ""))
    generation_type = str(values.get("generation_type", ""))
    content_id = str(values.get("content_id", ""))
    content_status = str(values.get("content_status", ""))
    title = str(values.get("title", ""))
    message = str(values.get("message", ""))
    description = str(values.get("description", ""))
    act = int(values.get("act", 1))
    row = int(values.get("row", -1))
    column = int(values.get("column", -1))
    content_seed = int(values.get("content_seed", 0))
    boss_variant = int(values.get("boss_variant", -1))
    battle = values.get("battle", {}).duplicate(true)
    return self

func snapshot() -> Dictionary:
    var result := {
        "schema_version": SCHEMA_VERSION,
        "success": success,
        "reason": reason,
        "route": route,
        "node_id": node_id,
        "node_type": node_type,
        "generation_type": generation_type,
        "content_id": content_id,
        "content_status": content_status,
        "title": title,
        "message": message,
        "description": description,
        "act": act,
        "row": row,
        "column": column,
        "content_seed": content_seed,
        "boss_variant": boss_variant,
    }
    if not battle.is_empty():
        result["battle"] = battle.duplicate(true)
    return result

func to_dict() -> Dictionary:
    return snapshot()
