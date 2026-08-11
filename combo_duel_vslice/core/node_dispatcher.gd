class_name ComboNodeDispatcher
extends RefCounted

const DATA_PATH := "res://data/node_content.json"
const NodeDispatchResultScript = preload("res://core/node_dispatch_result.gd")

var definition: Dictionary = {}

func _init(definition_override: Dictionary = {}) -> void:
    if definition_override.is_empty():
        load_from_file()
    else:
        configure(definition_override)

func load_from_file(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary or not parsed.get("node_types", {}) is Dictionary:
        push_error("节点调度配置无法解析：%s" % path)
        definition.clear()
        return false
    return configure(parsed)

func configure(value: Dictionary) -> bool:
    definition = value.duplicate(true)
    return not definition.is_empty()

func dispatch(node: Dictionary, context: Dictionary = {}) -> Dictionary:
    return dispatch_dto(node, context).to_dict()

func dispatch_dto(node: Dictionary, context: Dictionary = {}):
    if node.is_empty():
        return _failure("节点数据为空")
    var type_id := str(node.get("type", ""))
    var node_types: Dictionary = definition.get("node_types", {})
    if type_id == "" or not node_types.has(type_id):
        return _failure("节点类型没有调度配置：%s" % type_id)
    var content: Dictionary = node_types[type_id]
    var route := str(content.get("route", ""))
    if route not in ["battle", "interaction", "placeholder"]:
        return _failure("节点调度路由无效：%s" % route)

    var act := int(context.get("act", 1))
    var result := {
        "success": true,
        "route": route,
        "node_id": str(node.get("id", "")),
        "node_type": type_id,
        "generation_type": str(node.get("generation_type", type_id)),
        "content_id": str(content.get("content_id", type_id)),
        "content_status": str(content.get("content_status", "unconfirmed")),
        "title": str(content.get("title", type_id)),
        "message": str(content.get("message", "")),
        "description": str(content.get("description", "")),
        "act": act,
        "row": int(node.get("row", -1)),
        "column": int(node.get("column", -1)),
        "content_seed": _content_seed(node, context, int(content.get("seed_offset", 0))),
        "boss_variant": int(context.get("boss_variant", -1)) if type_id == "boss" else -1,
    }
    if route == "battle":
        var battle: Dictionary = content.get("battle", {})
        var scenario_path := str(battle.get("scenario_path", ""))
        if scenario_path == "":
            return _failure("战斗节点缺少场景配置：%s" % type_id)
        result["battle"] = {
            "entry_kind": str(battle.get("entry_kind", "scripted")),
            "scenario_path": scenario_path,
            "use_enemy_ai": bool(battle.get("use_enemy_ai", true)),
            "use_remote_ai": bool(battle.get("use_remote_ai", false)),
        }
    elif route == "interaction":
        var interaction = content.get("interaction")
        if not interaction is Dictionary:
            return _failure("交互节点缺少 interaction 配置：%s" % type_id)
        result["interaction"] = interaction.duplicate(true)
    return NodeDispatchResultScript.new().configure(result)

func _content_seed(node: Dictionary, context: Dictionary, seed_offset: int) -> int:
    return (
        int(context.get("seed", 0))
        + int(context.get("act", 1)) * 1000003
        + (int(node.get("row", -1)) + 2) * 9176
        + (int(node.get("column", -1)) + 1) * 131
        + seed_offset)

func _failure(reason: String):
    return NodeDispatchResultScript.new().configure({
        "success": false,
        "reason": reason,
    })
