extends RefCounted

const SCHEMA_VERSION := 1
const TYPES := ["technique", "inner_skill", "consumable", "enemy", "node"]
const HAND_IDS := ["high_card", "pair", "two_pair", "three_kind", "straight", "flush", "full_house", "four_kind", "straight_flush"]

var _id_regex := RegEx.new()

func _init() -> void:
    _id_regex.compile("^[a-z][a-z0-9_]*$")

func build(content_type: String, content_id: String, display_name: String) -> Dictionary:
    if content_type not in TYPES:
        return {"success": false, "error": "未知内容类型 %s" % content_type}
    if _id_regex.search(content_id) == null:
        return {"success": false, "error": "ID 必须使用 snake_case 稳定格式"}
    if display_name.strip_edges() == "":
        return {"success": false, "error": "name 不能为空"}
    var content: Dictionary
    match content_type:
        "technique":
            content = {
                "id": content_id, "name": display_name, "pool": "high", "special": false,
                "description": "TODO：替换为已确认规则。", "condition": {},
                "effects": [{"op": "defense", "amount": {"kind": "constant", "value": 1}}],
            }
        "inner_skill":
            content = {
                "id": content_id, "name": display_name, "status": "draft", "timing": "on_play_resolve",
                "description": "TODO：替换为已确认规则。",
                "effects": [{"op": "defense", "amount": {"kind": "constant", "value": 1}}],
            }
        "consumable":
            content = {
                "id": content_id, "name": display_name, "kind": "draft", "price": 0,
                "description": "TODO：替换为已确认规则。",
                "targeting": {"zone": "none", "minimum": 0, "maximum": 0},
                "effects": [{"op": "gain_insight", "hand": "high_card", "multiplier": 1, "pools": ["high"]}],
            }
        "enemy":
            var sequences := {}
            for hand_id in HAND_IDS:
                sequences[hand_id] = []
            content = {
                "version": 1, "id": content_id, "name": display_name,
                "player": {"inner_skills": [], "consumables": [], "technique_slot_index": 0},
                "enemy": {
                    "life": 100, "inner_skills": [], "technique_slot_index": 0,
                    "opening_hand": [], "draw_order": [], "ai": {}, "sequences": sequences,
                },
                "rounds": [],
            }
        "node":
            content = {
                "node_type": content_id, "route": "placeholder", "content_id": content_id,
                "content_status": "draft", "title": display_name, "message": "进入%s" % display_name,
                "description": "TODO：替换为已确认节点规则。", "seed_offset": 0,
            }
    return {
        "success": true,
        "envelope": {"schema_version": SCHEMA_VERSION, "content_type": content_type, "content": content},
    }

func render(content_type: String, content_id: String, display_name: String) -> Dictionary:
    var built := build(content_type, content_id, display_name)
    if not built.get("success", false):
        return built
    var envelope: Dictionary = built["envelope"]
    if content_type != "technique":
        built["text"] = JSON.stringify(envelope, "  ") + "\n"
        built["extension"] = ".content.json"
        return built
    var content: Dictionary = envelope["content"]
    built["text"] = "\n".join([
        "[gd_resource type=\"Resource\" script_class=\"TechniqueDefinition\" load_steps=2 format=3]",
        "",
        "[ext_resource type=\"Script\" path=\"res://core/technique_definition.gd\" id=\"1\"]",
        "",
        "[resource]",
        "script = ExtResource(\"1\")",
        "id = %s" % JSON.stringify(content["id"]),
        "display_name = %s" % JSON.stringify(content["name"]),
        "pool = \"high\"",
        "special = false",
        "description = %s" % JSON.stringify(content["description"]),
        "condition = {}",
        "effects = [{\"op\":\"defense\",\"amount\":{\"kind\":\"constant\",\"value\":1}}]",
        "",
    ])
    built["extension"] = ".tres"
    return built
