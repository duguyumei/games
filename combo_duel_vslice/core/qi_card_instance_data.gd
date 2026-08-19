class_name QiCardInstanceData
extends RefCounted

const QiCardScript = preload("res://core/qi_card.gd")

const VERSION := 5

static func migrate_persistent(values: Dictionary, content_catalog) -> Dictionary:
    var version := int(values.get("version", 0))
    if version == VERSION:
        return {"success": true, "values": values.duplicate(true), "migrated": false}
    if version != 4:
        return {"success": false, "reason": "真气实例版本不受支持：%s" % version}
    if values.has("anomalies") or values.has("suppressed_reshapes"):
        return {"success": false, "reason": "旧战斗异状/压制快照不能迁移为 RunDeck"}
    var migrated := values.duplicate(true)
    migrated["version"] = VERSION
    var origin: Dictionary = migrated.get("reshapes", {}).get("origin", {})
    migrated["origin_base_identity"] = {}
    if not origin.is_empty():
        var recovered := _recover_legacy_origin_identity(migrated, origin, content_catalog)
        if not recovered.get("success", false):
            return recovered
        migrated["origin_base_identity"] = recovered["identity"]
    return {"success": true, "values": migrated, "migrated": true}

static func _recover_legacy_origin_identity(
        values: Dictionary,
        origin: Dictionary,
        content_catalog) -> Dictionary:
    var origin_id := str(origin.get("id", ""))
    if origin_id == "attribute_change":
        return {
            "success": false,
            "reason": "旧转属真气缺少改造前属性，不能静默猜测原始身份",
        }
    var definition: Dictionary = {}
    if origin_id == "awakening":
        definition = content_catalog.get_by_id("card", str(values.get("definition_id", "")))
    elif origin_id == "rank_change":
        var direction := str(origin.get("payload", {}).get("direction", ""))
        var original_order := int(values.get("rank_order", 0)) + (-1 if direction == "up" else 1)
        var base_deck: Dictionary = content_catalog.definition("base_deck")
        var original_rank := ""
        for rank in base_deck.get("ranks", []):
            if int(rank.get("order", 0)) == original_order:
                original_rank = str(rank.get("id", ""))
                break
        definition = content_catalog.get_by_id(
            "card", "%s_%s" % [str(values.get("attribute", "")), original_rank])
    if definition.is_empty():
        return {"success": false, "reason": "旧本源真气无法恢复改造前基础身份"}
    return {"success": true, "identity": {
        "definition_id": str(definition.get("id", "")),
        "rank_name": str(definition.get("rank", "")),
        "rank_order": int(definition.get("order", 0)),
        "qi_value": int(definition.get("qi", 0)),
        "attribute": str(definition.get("attribute", "")),
        "attribute_name": str(definition.get("attribute_name", "")),
    }}

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
        "origin_base_identity": _normalized_origin_base_identity(
            card.origin_base_identity),
        "reshapes": (
            card.active_reshape_state()
            if include_combat_state
            else card.persistent_reshape_state()),
        "original_owner_id": str(card.original_owner_id),
        "temporary_card": bool(card.temporary_card),
    }
    if include_combat_state:
        values["anomalies"] = card.anomaly_snapshot()
        values["temporary_reshapes"] = card.temporary_reshapes.duplicate(true)
        values["temporary_blazing_layers"] = \
            card.temporary_blazing_layers.duplicate(true)
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
    card.origin_base_identity = _normalized_origin_base_identity(
        values.get("origin_base_identity", {}))
    var anomalies: Dictionary = values.get("anomalies", {})
    if not anomalies.is_empty():
        card.restore_anomaly_snapshot(anomalies)
    card.temporary_reshapes = values.get("temporary_reshapes", {
        "enhancement": "",
        "attribute": "",
        "rank": {},
    }).duplicate(true)
    if not card.temporary_reshapes.has("rank"):
        card.temporary_reshapes["rank"] = {}
    card.temporary_blazing_layers = values.get(
        "temporary_blazing_layers", {}).duplicate(true)
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
    _validate_origin_base_identity(values, content_catalog, errors)
    if include_combat_state:
        _validate_anomalies(values.get("anomalies", {}), content_catalog, errors)
        _validate_temporary_reshapes(
            values.get("temporary_reshapes", {}), content_catalog, errors)
        _validate_temporary_blazing_layers(
            values.get("temporary_blazing_layers", {}), errors)
        if values.has("suppressed_reshapes"):
            errors.append("战斗真气实例不得包含旧 suppressed_reshapes")
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
    if values.has("poison") or values.has("others"):
        errors.append("战斗真气实例包含旧 poison/others 异状结构")
    for field in ["buffs", "debuffs"]:
        var entries = values.get(field, {})
        if not entries is Dictionary:
            errors.append("异状 %s 必须是对象" % field)
            continue
        for anomaly_id in entries:
            if not entries[anomaly_id] is int or int(entries[anomaly_id]) <= 0:
                errors.append("异状 %s 层数必须是正整数" % str(anomaly_id))
            var definition: Dictionary = content_catalog.get_by_id("anomaly", str(anomaly_id))
            if definition.is_empty():
                errors.append("真气实例引用未知异状：%s" % str(anomaly_id))
            elif str(definition.get("category", "")) != field.trim_suffix("s"):
                errors.append("异状 %s 不属于类别 %s" % [str(anomaly_id), field.trim_suffix("s")])
    var state = values.get("state", {})
    if not state is Dictionary:
        errors.append("异状 state 必须是对象")
    elif not state.is_empty():
        if not state.has_all(["id", "layers", "payload"]) or state.size() != 3:
            errors.append("state 必须且只能包含 id/layers/payload")
        var state_id := str(state.get("id", ""))
        var definition: Dictionary = content_catalog.get_by_id("anomaly", state_id)
        if definition.is_empty() or str(definition.get("category", "")) != "state":
            errors.append("真气实例引用未知或非 state 异状：%s" % state_id)
        if not state.get("layers") is int or int(state.get("layers", 0)) <= 0:
            errors.append("state layers 必须是正整数")
        if not state.get("payload") is Dictionary:
            errors.append("state payload 必须是对象")
    var marks = values.get("marks", {})
    if not marks is Dictionary:
        errors.append("异状 marks 必须是对象")
    else:
        for anomaly_id in marks:
            if not marks[anomaly_id] is Dictionary:
                errors.append("mark payload 必须是对象：%s" % str(anomaly_id))
            var definition: Dictionary = content_catalog.get_by_id("anomaly", str(anomaly_id))
            if definition.is_empty() or str(definition.get("category", "")) != "mark":
                errors.append("真气实例引用未知或非 mark 异状：%s" % str(anomaly_id))
    for field in ["buffs", "debuffs", "state", "marks"]:
        if not values.has(field):
            errors.append("anomalies 缺少字段 %s" % field)
    for field in values:
        if str(field) not in ["buffs", "debuffs", "state", "marks"]:
            errors.append("anomalies 包含旧版或未知字段 %s" % str(field))

static func _validate_temporary_reshapes(
        values,
        content_catalog,
        errors: Array[String]) -> void:
    if not values is Dictionary:
        errors.append("temporary_reshapes 必须是对象")
        return
    if values.size() != 3 or not values.has_all(["enhancement", "attribute", "rank"]):
        errors.append("temporary_reshapes 必须且只能包含 enhancement/attribute/rank")
    var enhancement_id := str(values.get("enhancement", ""))
    if enhancement_id != "" and not content_catalog.has_id("enhancement", enhancement_id):
        errors.append("临时强化引用未知强化：%s" % enhancement_id)
    var attribute_id := str(values.get("attribute", ""))
    if attribute_id != "" and attribute_id not in ["wind", "forest", "fire", "mountain"]:
        errors.append("临时属性引用未知基础属性：%s" % attribute_id)
    var rank = values.get("rank", {})
    if not rank is Dictionary:
        errors.append("临时牌阶必须是对象")
    elif not rank.is_empty():
        if rank.size() != 3 or not rank.has_all(["rank_name", "rank_order", "qi_value"]):
            errors.append("临时牌阶必须且只能包含 rank_name/rank_order/qi_value")
        else:
            var matched := false
            for definition in content_catalog.definition("base_deck").get("ranks", []):
                if str(definition.get("id", "")) == str(rank.get("rank_name", "")) \
                        and int(definition.get("order", 0)) == int(rank.get("rank_order", 0)) \
                        and int(definition.get("qi", 0)) == int(rank.get("qi_value", -1)):
                    matched = true
                    break
            if not matched:
                errors.append("临时牌阶不是标准牌阶")

static func _validate_temporary_blazing_layers(
        values, errors: Array[String]) -> void:
    if not values is Dictionary:
        errors.append("temporary_blazing_layers 必须是对象")
        return
    for source_instance_key in values:
        if str(source_instance_key) == "":
            errors.append("临时炽气来源实例不能为空")
        if not values[source_instance_key] is int \
                or int(values[source_instance_key]) <= 0:
            errors.append("临时炽气来源层数必须是正整数")

static func _validate_origin_base_identity(
        values: Dictionary,
        content_catalog,
        errors: Array[String]) -> void:
    var identity = values.get("origin_base_identity", {})
    if not identity is Dictionary:
        errors.append("origin_base_identity 必须是对象")
        return
    var origin = values.get("reshapes", {}).get("origin", {})
    if origin.is_empty():
        if not identity.is_empty():
            errors.append("无本源真气不得保存 origin_base_identity")
        return
    var required := [
        "definition_id", "rank_name", "rank_order", "qi_value",
        "attribute", "attribute_name"]
    if identity.size() != required.size() or not identity.has_all(required):
        errors.append("有本源真气必须完整保存 origin_base_identity")
        return
    var definition_id := str(identity.get("definition_id", ""))
    if not content_catalog.has_id("card", definition_id):
        errors.append("origin_base_identity 引用未知 definition_id：%s" % definition_id)

static func _normalized_origin_base_identity(values) -> Dictionary:
    if not values is Dictionary or values.is_empty():
        return {}
    return {
        "definition_id": str(values.get("definition_id", "")),
        "rank_name": str(values.get("rank_name", "")),
        "rank_order": int(values.get("rank_order", 0)),
        "qi_value": int(values.get("qi_value", 0)),
        "attribute": str(values.get("attribute", "")),
        "attribute_name": str(values.get("attribute_name", "")),
    }

static func _validate_optional_reference(
        values: Dictionary,
        field: String,
        content_type: String,
        content_catalog,
        errors: Array[String]) -> void:
    var content_id := str(values.get(field, ""))
    if content_id != "" and not content_catalog.has_id(content_type, content_id):
        errors.append("真气实例引用未知%s：%s" % [field, content_id])
