class_name SourceMarkerAddressResolver
extends RefCounted

const RUN_PLAYER_OWNER_ID := "player"

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
    var holder = _runtime_value(runtime, "owner")
    if holder == null:
        holder = _runtime_value(runtime, "actor")
    if runtime_source_kind == "item":
        if source_kind != "item":
            return {"success": false, "reason": "物品来源不能伪装为其他 source_kind"}
        if content_id != runtime_source_id:
            return {"success": false, "reason": "物品默认只能访问自己的来源实例"}
    if source_kind == "item":
        var item_address := resolve_item(holder, content_id, spec, runtime)
        if not item_address.get("success", false):
            return item_address
        if runtime_source_kind == "item" \
                and runtime_source_instance_key != "" \
                and runtime_source_instance_key != str(
                    item_address.get("source_instance_key", "")):
            return {"success": false, "reason": "物品运行时来源地址与权威地址不一致"}
        if explicit_key != "" and explicit_key != str(
                item_address.get("source_instance_key", "")):
            return {"success": false, "reason": "物品来源地址不能由内容任意伪造"}
        return item_address
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
    if source_kind not in ["technique", "inner_skill", "item"]:
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

## item 来源实例的唯一权威地址入口。库存顺序只参与 PassiveRuleSourceResolver
## 的 source_order，不参与持久地址；Run 的 GrowthInventory 与玩家 BattleSide
## 都解析为 player，因而同一快照往返保持完全相同的 key。
func item_source_instance_key(holder, content_id: String) -> String:
    var owner_id := stable_owner_id(holder)
    if owner_id == "" or content_id == "":
        return ""
    return "item:%s:%s" % [owner_id, content_id]

func stable_owner_id(holder) -> String:
    var owner_value = _object_value(holder, "owner_id")
    var owner_id := "" if owner_value == null else str(owner_value)
    if owner_id != "":
        return owner_id
    # GrowthInventory 只代表当前玩家本局库存且没有 owner_id 字段。该映射只
    # 存在于地址解析层，调用方不得自行使用 run/player 字符串拼接来源地址。
    if holder != null and _object_value(holder, "item_ids") != null \
            and _object_value(holder, "source_marker_store") != null:
        return RUN_PLAYER_OWNER_ID
    return ""

func resolve_item(
        holder,
        content_id: String,
        spec: Dictionary = {},
        runtime = null) -> Dictionary:
    if content_id == "":
        return {"success": false, "reason": "物品来源标识缺少 content_id"}
    var item_ids = _object_value(holder, "item_ids")
    if not item_ids is Array or not item_ids.has(content_id):
        return {"success": false, "reason": "非持有物品不能建立有效来源标识：%s" % content_id}
    var source_instance_key := item_source_instance_key(holder, content_id)
    if source_instance_key == "":
        return {"success": false, "reason": "物品来源标识缺少稳定持有者身份"}
    var marker_id := str(spec.get("marker_id", spec.get("id", "")))
    var marker_definition: Dictionary = {}
    if spec.has("id") and str(spec.get("id", "")) == marker_id:
        marker_definition = spec.duplicate(true)
    else:
        marker_definition = _item_marker_definition(
            holder, runtime, content_id, marker_id)
    if marker_id != "" and marker_definition.is_empty():
        return {
            "success": false,
            "reason": "物品未声明来源标识：%s/%s" % [content_id, marker_id],
        }
    for field in [
            "scope", "public", "display_name", "contributes_to",
            "forget_policy"]:
        if spec.has(field) and marker_definition.has(field) \
                and spec[field] != marker_definition[field]:
            return {
                "success": false,
                "reason": "物品来源标识字段与声明不一致：%s.%s" % [
                    marker_id, field],
            }
    return {
        "success": true,
        "source_kind": "item",
        "source_instance_key": source_instance_key,
        "content_id": content_id,
        "marker_id": marker_id,
        "scope": str(marker_definition.get(
            "scope", spec.get("scope", "battle"))),
        "public": bool(marker_definition.get(
            "public", spec.get("public", true))),
        "display_name": str(marker_definition.get(
            "display_name", spec.get("display_name", marker_id))),
        "contributes_to": str(marker_definition.get(
            "contributes_to", spec.get("contributes_to", ""))),
        "forget_policy": str(marker_definition.get(
            "forget_policy", spec.get("forget_policy", "clear"))),
    }

func _item_marker_definition(
        holder, runtime, content_id: String, marker_id: String) -> Dictionary:
    if marker_id == "":
        return {}
    var definitions = _runtime_value(runtime, "source_marker_definitions")
    if not definitions is Array or definitions.is_empty():
        var passive_runtime = _object_value(holder, "passive_rule_runtime")
        var source_resolver = _object_value(passive_runtime, "source_resolver")
        var catalog = source_resolver.content_catalog() \
            if source_resolver != null and source_resolver.has_method(
                "content_catalog") else null
        if catalog != null and catalog.has_method("get_by_id"):
            definitions = catalog.get_by_id(
                "item", content_id).get("marker_definitions", [])
    if not definitions is Array:
        return {}
    for value in definitions:
        if value is Dictionary and str(value.get("id", "")) == marker_id:
            return value.duplicate(true)
    return {}

func _runtime_value(runtime, property_name: String):
    if runtime == null:
        return null
    if runtime is Dictionary:
        return runtime.get(property_name)
    return _object_value(runtime, property_name)

func _object_value(value, property_name: String):
    if value == null:
        return null
    if value is Dictionary:
        return value.get(property_name)
    if not value.has_method("get_property_list"):
        return null
    for property in value.get_property_list():
        if str(property.get("name", "")) == property_name:
            return value.get(property_name)
    return null

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

## 主要蓄力值始终按实际槽位实例隔离。普通 marker 仍继续使用 resolve_for_slot，
## 因而临时功法的 share_origin 语义不会被本协议改变。
func resolve_charging_for_slot(
        charging: Dictionary, slot: Dictionary) -> Dictionary:
    var slot_instance_id := str(slot.get("slot_instance_id", ""))
    var technique_id := str(slot.get("technique_id", ""))
    if charging.is_empty() or slot_instance_id == "" or technique_id == "":
        return {"success": false, "reason": "主要蓄力值缺少真实功法槽位"}
    var marker_id := str(charging.get("primary_marker_id", ""))
    if marker_id == "":
        return {"success": false, "reason": "功法没有声明主要蓄力 marker"}
    return resolve({
        "source_kind": "technique",
        "source_instance_key": slot_instance_id,
        "content_id": technique_id,
        "marker_id": marker_id,
        "scope": "battle",
        "public": bool(charging.get("public", true)),
        "display_name": str(charging.get("display_name", marker_id)),
        "forget_policy": "clear",
        "marker_role": "charging_primary",
        "slot_instance_id": slot_instance_id,
        "technique_id": technique_id,
        "hand_id": str(slot.get("hand_id", "")),
    }, {
        "source_kind": "technique",
        "source_id": technique_id,
        "source_instance_key": slot_instance_id,
        "technique_id": technique_id,
        "slot_instance_id": slot_instance_id,
        "sequence_book": null,
    }, slot).merged({
        "marker_role": "charging_primary",
        "slot_instance_id": slot_instance_id,
        "technique_id": technique_id,
        "hand_id": str(slot.get("hand_id", "")),
    }, true)

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
