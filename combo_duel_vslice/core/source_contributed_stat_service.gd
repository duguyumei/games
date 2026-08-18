class_name SourceContributedStatService
extends RefCounted

func effective_max_life(base_max_life: int, marker_store,
        active_sources: Dictionary) -> int:
    var bonus := 0
    if marker_store != null:
        for entry_value in marker_store.entries({
                "scope": "run", "contributes_to": "max_life"}):
            var entry: Dictionary = entry_value
            if _is_active(active_sources, entry):
                bonus += int(entry.get("value", 0))
    return maxi(1, base_max_life + bonus)

func apply_to_side(side, equipped_content_ids: Dictionary) -> int:
    if side == null:
        return 0
    side.max_life = effective_max_life(
        int(side.base_max_life), side.source_marker_store, equipped_content_ids)
    side.life = mini(int(side.life), int(side.max_life))
    return int(side.max_life)

func _is_active(active_sources: Dictionary, entry: Dictionary) -> bool:
    var source_kind := str(entry.get("source_kind", ""))
    var content_id := str(entry.get("content_id", ""))
    var bucket = active_sources.get(source_kind)
    if bucket is Dictionary:
        return bool(bucket.get(content_id, false))
    # 保留旧调用方传入扁平 content_id 集合的兼容性；正式入口使用按
    # source_kind 分桶的 active_source_content_ids，避免同名内容串源。
    return active_sources.has(content_id)
