class_name MarkerValueSpecHandler
extends RefCounted

const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")

const REGISTERED_KINDS := [
    "source_marker_value", "source_marker_sum", "equipped_source_marker_sum",
    "consumed_marker_value",
]

func kind_ids() -> Array[String]:
    return REGISTERED_KINDS.duplicate()

func validate(kind: String, spec: Dictionary, _registry, report_error: Callable, scope: String) -> bool:
    var valid := true
    if spec.has("side") and str(spec["side"]) not in [
            "actor", "target", "owner", "opponent"]:
        report_error.call(scope + ".side", "必须为 actor、target、owner 或 opponent")
        valid = false
    for field in ["marker_id", "source_instance_key"]:
        if spec.has(field) and not spec[field] is String:
            report_error.call(scope + "." + field, "必须是字符串")
            valid = false
    if spec.has("source_kind") \
            and str(spec["source_kind"]) not in [
                "technique", "inner_skill", "item"]:
        report_error.call(scope + ".source_kind", "引用未知来源类型")
        valid = false
    if spec.has("scope") and str(spec["scope"]) not in ["", "battle", "run"]:
        report_error.call(scope + ".scope", "必须为空、battle 或 run")
        valid = false
    if kind in ["source_marker_sum", "equipped_source_marker_sum"] \
            and spec.has("filters") and not spec["filters"] is Dictionary:
        report_error.call(scope + ".filters", "必须是对象")
        valid = false
    return valid

func resolve(kind: String, spec: Dictionary, runtime, resolver, _registry) -> int:
    match kind:
        "source_marker_value":
            var side = resolver.side(runtime, str(spec.get("side", "actor")))
            if side == null or side.source_marker_store == null:
                return 0
            var source_kind := str(spec.get(
                "source_kind", runtime.source_kind))
            var source_instance_key := str(spec.get(
                "source_instance_key", ""))
            # 未显式跨来源寻址时，读写必须共享同一个地址协议。尤其功法的
            # run 标识以稳定内容 ID 为键，不能误读战斗槽位实例键。
            if source_instance_key == "":
                var address: Dictionary = SourceMarkerAddressResolverScript.new() \
                    .resolve(spec, runtime)
                if address.get("success", false):
                    source_kind = str(address.get("source_kind", source_kind))
                    source_instance_key = str(address.get(
                        "source_instance_key", runtime.source_instance_key))
                else:
                    source_instance_key = str(runtime.source_instance_key)
            return side.source_marker_store.value(
                source_kind, source_instance_key,
                str(spec.get("marker_id", "")), str(spec.get("scope", "")))
        "source_marker_sum":
            var side = resolver.side(runtime, str(spec.get("side", "actor")))
            if side == null or side.source_marker_store == null:
                return 0
            var filters: Dictionary = spec.get("filters", {}).duplicate(true)
            if spec.has("marker_id"):
                filters["marker_id"] = str(spec["marker_id"])
            if spec.has("scope"):
                filters["scope"] = str(spec["scope"])
            return side.source_marker_store.sum(filters)
        "equipped_source_marker_sum":
            var side = resolver.side(runtime, str(spec.get("side", "actor")))
            if side == null or side.source_marker_store == null:
                return 0
            var filters: Dictionary = spec.get("filters", {}).duplicate(true)
            if spec.has("marker_id"):
                filters["marker_id"] = str(spec["marker_id"])
            if spec.has("scope"):
                filters["scope"] = str(spec["scope"])
            if side.has_method("active_source_marker_sum"):
                return int(side.active_source_marker_sum(filters))
            var active: Dictionary = side.active_source_content_ids() \
                if side.has_method("active_source_content_ids") else {}
            var total := 0
            for entry_value in side.source_marker_store.entries(filters):
                var entry: Dictionary = entry_value
                var bucket = active.get(str(entry.get("source_kind", "")))
                if bucket is Dictionary and bucket.has(str(
                        entry.get("content_id", ""))):
                    total += int(entry.get("value", 0))
            return total
        "consumed_marker_value":
            return runtime.consumed_marker_value
    return 0
