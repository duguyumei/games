class_name QiCardInstanceData
extends RefCounted

const QiCardScript = preload("res://core/qi_card.gd")

const VERSION := 3

static func capture(card, include_combat_state: bool = false) -> Dictionary:
    var values := {
        "version": VERSION,
        "instance_id": str(card.id),
        "definition_id": str(card.definition_id),
        "rank_name": str(card.rank_name),
        "rank_order": int(card.rank_order),
        "qi_value": int(card.qi_value),
        "attribute": str(card.attribute),
        "attribute_name": str(card.attribute_name),
        "reshapes": (
            card.active_reshape_state()
            if include_combat_state
            else card.persistent_reshape_state()),
        "original_owner_id": str(card.original_owner_id),
        "temporary_card": bool(card.temporary_card),
    }
    if include_combat_state:
        values["anomalies"] = card.anomaly_snapshot()
        values["suppressed_reshapes"] = card.suppressed_reshapes.duplicate(true)
    return values

static func restore(values: Dictionary):
    var card = QiCardScript.new(
        str(values.get("instance_id", "")),
        str(values.get("rank_name", "")),
        int(values.get("rank_order", 0)),
        int(values.get("qi_value", 0)),
        str(values.get("attribute", "")),
        str(values.get("attribute_name", "")),
        str(values.get("definition_id", "")))
    var reshapes: Dictionary = values.get("reshapes", {})
    card.reshape_enhancement = str(reshapes.get("enhancement", ""))
    card.reshape_finish = str(reshapes.get("finish", ""))
    card.reshape_imprint = str(reshapes.get("imprint", ""))
    card.reshape_others = reshapes.get("others", {}).duplicate(true)
    var anomalies: Dictionary = values.get("anomalies", {})
    card.anomaly_poison = str(anomalies.get("poison", ""))
    card.anomaly_state = str(anomalies.get("state", ""))
    card.anomaly_marks = anomalies.get("marks", {}).duplicate(true)
    card.anomaly_others = anomalies.get("others", {}).duplicate(true)
    card.suppressed_reshapes = values.get("suppressed_reshapes", {}).duplicate(true)
    card.original_owner_id = str(values.get("original_owner_id", ""))
    card.temporary_card = bool(values.get("temporary_card", false))
    return card

static func validate(values: Dictionary, content_catalog, include_combat_state: bool = false) -> Array[String]:
    var errors: Array[String] = []
    if int(values.get("version", 0)) != VERSION:
        errors.append("真气实例版本不受支持：%s" % str(values.get("version", "")))
    if str(values.get("instance_id", "")) == "":
        errors.append("真气实例缺少 instance_id")
    if content_catalog == null:
        errors.append("真气实例校验缺少内容目录")
        return errors
    var definition_id := str(values.get("definition_id", ""))
    if definition_id == "" or not content_catalog.has_id("card", definition_id):
        errors.append("真气实例引用未知 definition_id：%s" % definition_id)
    _validate_reshapes(values.get("reshapes", {}), content_catalog, errors)
    if include_combat_state:
        _validate_anomalies(values.get("anomalies", {}), content_catalog, errors)
        _validate_reshapes(values.get("suppressed_reshapes", {}), content_catalog, errors, true)
    return errors

static func _validate_reshapes(
        values,
        content_catalog,
        errors: Array[String],
        partial: bool = false) -> void:
    if not values is Dictionary:
        errors.append("reshapes 必须是对象")
        return
    _validate_optional_reference(values, "enhancement", "enhancement", content_catalog, errors)
    _validate_optional_reference(values, "finish", "finish", content_catalog, errors)
    _validate_optional_reference(values, "imprint", "imprint", content_catalog, errors)
    var others = values.get("others", {})
    if not others is Dictionary:
        errors.append("重塑·其他必须是对象")
    else:
        for reshape_id in others:
            if not content_catalog.has_id("other_reshape", str(reshape_id)):
                errors.append("真气实例引用未知重塑·其他：%s" % str(reshape_id))
    if not partial:
        for field in ["enhancement", "finish", "imprint", "others"]:
            if not values.has(field):
                errors.append("reshapes 缺少字段 %s" % field)

static func _validate_anomalies(values, content_catalog, errors: Array[String]) -> void:
    if not values is Dictionary:
        errors.append("anomalies 必须是对象")
        return
    for category in ["poison", "state"]:
        var anomaly_id := str(values.get(category, ""))
        if anomaly_id == "":
            continue
        var definition: Dictionary = content_catalog.get_by_id("anomaly", anomaly_id)
        if definition.is_empty():
            errors.append("真气实例引用未知异状：%s" % anomaly_id)
        elif str(definition.get("category", "")) != category:
            errors.append("异状 %s 不属于类别 %s" % [anomaly_id, category])
    for category in ["mark", "other"]:
        var field := "marks" if category == "mark" else "others"
        var entries = values.get(field, {})
        if not entries is Dictionary:
            errors.append("异状·%s必须是对象" % category)
            continue
        for anomaly_id in entries:
            var definition: Dictionary = content_catalog.get_by_id("anomaly", str(anomaly_id))
            if definition.is_empty():
                errors.append("真气实例引用未知异状：%s" % str(anomaly_id))
            elif str(definition.get("category", "")) != category:
                errors.append("异状 %s 不属于类别 %s" % [str(anomaly_id), category])

static func _validate_optional_reference(
        values: Dictionary,
        field: String,
        content_type: String,
        content_catalog,
        errors: Array[String]) -> void:
    var content_id := str(values.get(field, ""))
    if content_id != "" and not content_catalog.has_id(content_type, content_id):
        errors.append("真气实例引用未知%s：%s" % [field, content_id])
