class_name SourceContributedStatService
extends RefCounted

func effective_max_life(base_max_life: int, marker_store,
        equipped_content_ids: Dictionary) -> int:
    var bonus := 0
    if marker_store != null:
        for entry_value in marker_store.entries({
                "scope": "run", "contributes_to": "max_life"}):
            var entry: Dictionary = entry_value
            if equipped_content_ids.has(str(entry.get("content_id", ""))):
                bonus += int(entry.get("value", 0))
    return maxi(1, base_max_life + bonus)

func apply_to_side(side, equipped_content_ids: Dictionary) -> int:
    if side == null:
        return 0
    side.max_life = effective_max_life(
        int(side.base_max_life), side.source_marker_store, equipped_content_ids)
    side.life = mini(int(side.life), int(side.max_life))
    return int(side.max_life)
