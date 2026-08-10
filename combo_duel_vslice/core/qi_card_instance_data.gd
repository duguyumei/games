class_name QiCardInstanceData
extends RefCounted

const QiCardScript = preload("res://core/qi_card.gd")

const VERSION := 4

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

static func restore(values: Dictionary, reshape_rules = null):
    var card = QiCardScript.new(
        str(values.get("instance_id", "")),
        str(values.get("rank_name", "")),
        int(values.get("rank_order", 0)),
        int(values.get("qi_value", 0)),
        str(values.get("attribute", "")),
        str(values.get("attribute_name", "")),
        str(values.get("definition_id", "")))
    if reshape_rules != null:
        card.configure_reshape_rule_service(reshape_rules)
    var reshapes: Dictionary = values.get("reshapes", {})
    var origin = reshapes.get("origin", {})
    card.reshape_origin = origin.duplicate(true) if origin is Dictionary else {}
    card.reshape_enhancement = str(reshapes.get("enhancement", ""))
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
    else:
        _validate_base_identity(values, content_catalog.get_by_id("card", definition_id), errors)
    _validate_reshapes(
        values.get("reshapes", {}),
        str(values.get("attribute", "")),
        content_catalog,
        errors)
    if include_combat_state:
        _validate_anomalies(values.get("anomalies", {}), content_catalog, errors)
        _validate_reshapes(
            values.get("suppressed_reshapes", {}),
            str(values.get("attribute", "")),
            content_catalog,
            errors,
            true)
    return errors

static func _validate_reshapes(
        values,
        base_attribute: String,
        content_catalog,
        errors: Array[String],
        partial: bool = false) -> void:
    if not values is Dictionary:
        errors.append("reshapes 必须是对象")
        return
    _validate_origin(
        values.get("origin", {}),
        base_attribute,
        content_catalog,
        errors)
    _validate_optional_reference(values, "enhancement", "enhancement", content_catalog, errors)
    _validate_optional_reference(values, "imprint", "imprint", content_catalog, errors)
    var others = values.get("others", {})
    if not others is Dictionary:
        errors.append("重塑·其他必须是对象")
    else:
        for reshape_id in others:
            if not content_catalog.has_id("other_reshape", str(reshape_id)):
                errors.append("真气实例引用未知重塑·其他：%s" % str(reshape_id))
    if not partial:
        for field in ["origin", "enhancement", "imprint", "others"]:
            if not values.has(field):
                errors.append("reshapes 缺少字段 %s" % field)
    for field in values:
        if not ["origin", "enhancement", "imprint", "others"].has(str(field)):
            errors.append("reshapes 包含旧版或未知字段 %s" % str(field))

static func _validate_origin(
        values,
        base_attribute: String,
        content_catalog,
        errors: Array[String]) -> void:
    if not values is Dictionary:
        errors.append("重塑·本源必须是对象")
        return
    if values.is_empty():
        return
    if values.size() != 2 or not values.has("id") or not values.has("payload"):
        errors.append("本源必须且只能包含 id 与 payload")
        return
    var origin_id := str(values.get("id", ""))
    if origin_id == "" or not content_catalog.has_id("origin", origin_id):
        errors.append("真气实例引用未知本源：%s" % origin_id)
    var payload = values.get("payload")
    if not payload is Dictionary:
        errors.append("本源 payload 必须是对象")
        return
    var payload_values: Dictionary = payload
    match origin_id:
        "attribute_change":
            if payload_values.size() != 1 or not payload_values.get("attribute") is String:
                errors.append("转属 payload 必须且只能包含字符串 attribute")
            else:
                var legal_attributes: Array[String] = []
                for attribute in content_catalog.definition("base_deck").get("attributes", []):
                    legal_attributes.append(str(attribute.get("id", "")))
                if not legal_attributes.has(str(payload_values.get("attribute", ""))):
                    errors.append("转属引用未知基础属性：%s" % str(payload_values.get("attribute", "")))
        "rank_change":
            if payload_values.size() != 1 or not payload_values.get("direction") is String:
                errors.append("易阶 payload 必须且只能包含字符串 direction")
            elif not ["up", "down"].has(str(payload_values.get("direction", ""))):
                errors.append("易阶 direction 只能为 up 或 down")
        "awakening":
            if payload_values.size() != 1 or not payload_values.get("attribute") is String:
                errors.append("觉醒 payload 必须且只能包含字符串 attribute")
            elif str(payload_values.get("attribute", "")) != base_attribute:
                errors.append("觉醒属性必须与真气当前基础属性一致")

static func _validate_base_identity(
        values: Dictionary,
        definition: Dictionary,
        errors: Array[String]) -> void:
    var expected := {
        "rank_name": str(definition.get("rank", "")),
        "rank_order": int(definition.get("order", 0)),
        "qi_value": int(definition.get("qi", 0)),
        "attribute": str(definition.get("attribute", "")),
        "attribute_name": str(definition.get("attribute_name", "")),
    }
    for field in expected:
        if values.get(field) != expected[field]:
            errors.append("真气实例 %s 与 definition_id 的基础定义不一致" % field)

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
