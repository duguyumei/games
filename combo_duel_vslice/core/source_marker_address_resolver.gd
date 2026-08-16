class_name SourceMarkerAddressResolver
extends RefCounted

func resolve(spec: Dictionary, runtime, slot_override: Dictionary = {}) -> Dictionary:
    var runtime_source_kind := str(runtime.get("source_kind", "")) \
        if runtime is Dictionary else str(runtime.source_kind)
    var runtime_source_id := str(runtime.get("source_id", "")) \
        if runtime is Dictionary else str(runtime.source_id)
    var runtime_source_instance_key := str(runtime.get(
        "source_instance_key", "")) if runtime is Dictionary \
        else str(runtime.source_instance_key)
    var source_kind := str(spec.get("source_kind", runtime_source_kind))
    var runtime_technique_id := str(runtime.get("technique_id", "")) \
        if runtime is Dictionary else str(runtime.technique_id)
    var runtime_slot_id := str(runtime.get("slot_instance_id", "")) \
        if runtime is Dictionary else str(runtime.slot_instance_id)
    var runtime_book = runtime.get("sequence_book") \
        if runtime is Dictionary else runtime.sequence_book
    var content_id := str(spec.get(
        "content_id", runtime_source_id if runtime_source_id != "" \
        else runtime_technique_id))
    var scope := str(spec.get("scope", "battle"))
    var slot := slot_override.duplicate(true)
    if slot.is_empty() and source_kind == "technique" \
            and runtime_book != null and runtime_slot_id != "":
        slot = _slot(runtime_book, runtime_slot_id)
    var explicit_key := str(spec.get("source_instance_key", ""))
    if explicit_key == "" and source_kind != "technique":
        explicit_key = runtime_source_instance_key
    var source_instance_key := explicit_key
    if source_kind == "technique":
        if scope == "run":
            if bool(slot.get("temporary", false)) \
                    and str(slot.get("marker_mode", "independent")) != "share_origin":
                return {"success": false, "reason": "独立临时功法槽位不能写入 run 标识"}
            var stable_content_id := str(slot.get(
                "origin_technique_id", content_id)) if not slot.is_empty() else content_id
            if stable_content_id == "":
                stable_content_id = content_id
            content_id = stable_content_id
            source_instance_key = "technique:%s" % stable_content_id
        elif source_instance_key == "":
            source_instance_key = str(slot.get(
                "slot_instance_id", runtime_slot_id))
            if str(slot.get("marker_mode", "independent")) == "share_origin" \
                    and str(slot.get("origin_slot_instance_id", "")) != "":
                source_instance_key = str(slot["origin_slot_instance_id"])
    elif source_instance_key == "":
        source_instance_key = "%s:%s" % [source_kind, content_id]
    if source_kind not in ["technique", "inner_skill"]:
        return {"success": false, "reason": "来源标识暂不允许来源类型：%s" % source_kind}
    if source_instance_key == "" or content_id == "":
        return {"success": false, "reason": "来源标识缺少稳定来源地址"}
    return {
        "success": true,
        "source_kind": source_kind,
        "source_instance_key": source_instance_key,
        "content_id": content_id,
        "marker_id": str(spec.get("marker_id", "")),
        "scope": scope,
        "public": bool(spec.get("public", true)),
        "display_name": str(spec.get("display_name", spec.get("marker_id", ""))),
        "contributes_to": str(spec.get("contributes_to", "")),
        "forget_policy": str(spec.get("forget_policy", "clear")),
    }

func resolve_for_slot(spec: Dictionary, slot: Dictionary) -> Dictionary:
    var proxy := {
        "technique_id": str(slot.get("technique_id", "")),
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "source_kind": "technique",
        "source_id": str(slot.get("technique_id", "")),
        "source_instance_key": str(slot.get("slot_instance_id", "")),
        "sequence_book": null,
    }
    return resolve(spec, proxy, slot)

func entry_matches_slot(entry: Dictionary, slot: Dictionary) -> bool:
    var resolved := resolve_for_slot(entry, slot)
    return resolved.get("success", false) \
        and str(resolved.get("source_instance_key", "")) == str(
            entry.get("source_instance_key", "")) \
        and str(resolved.get("content_id", "")) == str(entry.get("content_id", ""))

func _slot(book, slot_instance_id: String) -> Dictionary:
    for slot_value in book.find_slots({}):
        var slot: Dictionary = slot_value
        if str(slot.get("slot_instance_id", "")) == slot_instance_id:
            return slot.duplicate(true)
    return {}
