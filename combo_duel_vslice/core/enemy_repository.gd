class_name EnemyRepository
extends RefCounted

const EnemyDeckEncodingScript = preload("res://core/enemy_deck_encoding.gd")

var content_catalog
var enemies: Dictionary = {}
var default_ai: Dictionary = {}

func _init(content_catalog_override = null) -> void:
    content_catalog = content_catalog_override

func configure(definition: Dictionary) -> bool:
    enemies.clear()
    default_ai = definition.get("default_ai", {}).duplicate(true)
    for value in definition.get("enemies", []):
        if value is Dictionary:
            enemies[str(value.get("id", ""))] = value.duplicate(true)
    return not enemies.is_empty()

func select(
        act: int,
        node_type: String,
        content_seed: int,
        boss_variant: int = -1) -> Dictionary:
    var candidates: Array = []
    for value in enemies.values():
        var entry: Dictionary = value
        var acts_match := false
        for act_value in entry.get("acts", []):
            if int(act_value) == act:
                acts_match = true
                break
        if not acts_match:
            continue
        if not entry.get("node_types", []).has(node_type):
            continue
        candidates.append(entry)
    candidates.sort_custom(func(left, right): return str(left.get("id", "")) < str(right.get("id", "")))
    if candidates.is_empty():
        return {
            "success": false,
            "reason": "敌人池不存在匹配组合：第 %d 层 / %s" % [act, node_type],
        }
    var rng := RandomNumberGenerator.new()
    rng.seed = content_seed
    var index := rng.randi_range(0, candidates.size() - 1)
    if node_type == "boss" and boss_variant >= 0:
        index = posmod(index + boss_variant, candidates.size())
    var entry: Dictionary = candidates[index].duplicate(true)
    var parsed := EnemyDeckEncodingScript.parse(
        entry.get("deck", []),
        content_catalog,
        "enemy-%d-%s-%d" % [act, node_type, content_seed])
    if not parsed.get("success", false):
        return {
            "success": false,
            "reason": "敌人 %s 牌组解析失败：%s" % [
                entry.get("id", ""), "; ".join(parsed.get("errors", []))],
        }
    var ai_policy := default_ai.duplicate(true)
    ai_policy.merge(entry.get("ai", {}), true)
    return {
        "success": true,
        "entry": entry,
        "cards": parsed["cards"],
        "ai_policy": ai_policy,
    }
