class_name EnemyDeckEncoding
extends RefCounted

const CardInstanceIdFactoryScript = preload("res://core/card_instance_id_factory.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")
const CardOriginServiceScript = preload("res://core/card_origin_service.gd")

## 敌人牌组只表达基础牌与预置重塑；战斗异状由战斗效果产生。
## 无参数的强化/印记仍可使用 card+reshape*count 简写；需要参数的本源只能使用
## 显式对象，避免把本源压成无法表达 payload 的字符串。

static func parse(
        values: Array,
        content_catalog,
        instance_namespace: String = "enemy") -> Dictionary:
    var errors: Array[String] = []
    var cards: Array = []
    var factory := CardInstanceIdFactoryScript.new(instance_namespace)
    for index in range(values.size()):
        var parsed := _parse_entry(values[index])
        if not parsed.get("success", false):
            errors.append("牌组[%d]：%s" % [index, parsed.get("reason", "编码无效")])
            continue
        var definition_id := str(parsed["definition_id"])
        var definition: Dictionary = content_catalog.get_by_id("card", definition_id)
        if definition.is_empty():
            errors.append("牌组[%d]：引用未知真气 %s" % [index, definition_id])
            continue
        var normalized := _normalize_runtime_reshapes(
            parsed, content_catalog, "牌组[%d]" % index)
        errors.append_array(normalized.get("errors", []))
        if not normalized.get("errors", []).is_empty():
            continue
        for _copy in range(int(parsed["count"])):
            var card = DeckFactoryScript.create_card_instance(
                definition,
                factory.next_id(definition_id),
                content_catalog.card_reshape_rules if content_catalog != null else null)
            var apply_result := _apply_reshapes(card, normalized["reshapes"], content_catalog)
            if not apply_result.get("success", false):
                errors.append("牌组[%d]：%s" % [index, str(apply_result.get("reason", "预置重塑失败"))])
                continue
            cards.append(card)
    return {"success": errors.is_empty(), "cards": cards, "errors": errors}

static func validate_tokens(
        values: Array,
        card_ids: Dictionary,
        origin_ids: Dictionary,
        enhancement_ids: Dictionary,
        imprint_ids: Dictionary,
        attribute_ids: Array) -> Dictionary:
    var errors: Array[String] = []
    var expanded_count := 0
    for index in range(values.size()):
        var parsed := _parse_entry(values[index])
        if not parsed.get("success", false):
            errors.append("牌组[%d]：%s" % [index, parsed.get("reason", "编码无效")])
            continue
        var definition_id := str(parsed["definition_id"])
        if not card_ids.has(definition_id):
            errors.append("牌组[%d]：引用未知真气 %s" % [index, definition_id])
        errors.append_array(_validate_parsed_reshapes(
            parsed, origin_ids, enhancement_ids, imprint_ids,
            attribute_ids,
            definition_id.get_slice("_", 0),
            "牌组[%d]" % index))
        expanded_count += int(parsed["count"])
    return {"errors": errors, "expanded_count": expanded_count}

static func _parse_entry(value) -> Dictionary:
    if value is Dictionary:
        var definition_id := str(value.get("definition_id", ""))
        if definition_id == "":
            return {"success": false, "reason": "对象编码缺少 definition_id"}
        var count = value.get("count", 1)
        if not count is int or int(count) <= 0:
            return {"success": false, "reason": "重复数量必须是正整数"}
        var reshapes = value.get("reshapes", {})
        if not reshapes is Dictionary:
            return {"success": false, "reason": "对象编码 reshapes 必须是对象"}
        return {
            "success": true,
            "definition_id": definition_id,
            "reshape_ids": [],
            "reshapes": reshapes.duplicate(true),
            "count": int(count),
            "structured": true,
        }
    if not value is String:
        return {"success": false, "reason": "编码必须是字符串或对象"}
    return _parse_token(str(value))

static func _parse_token(token: String) -> Dictionary:
    if token.is_empty():
        return {"success": false, "reason": "编码不能为空"}
    var base_and_reshapes := token
    var count := 1
    var star_index := token.rfind("*")
    if star_index >= 0:
        base_and_reshapes = token.substr(0, star_index)
        var count_text := token.substr(star_index + 1)
        if count_text.is_empty() or not count_text.is_valid_int():
            return {"success": false, "reason": "重复数量必须是正整数"}
        count = int(count_text)
        if count <= 0:
            return {"success": false, "reason": "重复数量必须是正整数"}
    if base_and_reshapes.is_empty() or base_and_reshapes.find("*") >= 0:
        return {"success": false, "reason": "编码只能包含一个重复数量后缀"}
    var parts := base_and_reshapes.split("+")
    var definition_id := str(parts[0])
    if definition_id.is_empty():
        return {"success": false, "reason": "基础真气 ID 不能为空"}
    var reshape_ids: Array[String] = []
    for reshape_index in range(1, parts.size()):
        var reshape_id := str(parts[reshape_index])
        if reshape_id.is_empty():
            return {"success": false, "reason": "重塑 ID 不能为空"}
        reshape_ids.append(reshape_id)
    return {
        "success": true,
        "definition_id": definition_id,
        "reshape_ids": reshape_ids,
        "reshapes": {},
        "count": count,
        "structured": false,
    }

static func _validate_parsed_reshapes(
        parsed: Dictionary,
        origin_ids: Dictionary,
        enhancement_ids: Dictionary,
        imprint_ids: Dictionary,
        attribute_ids: Array,
        base_attribute: String,
        scope: String) -> Array[String]:
    var errors: Array[String] = []
    if bool(parsed.get("structured", false)):
        var reshapes: Dictionary = parsed.get("reshapes", {})
        for field in reshapes:
            if not ["origin", "enhancement", "imprint", "others"].has(str(field)):
                errors.append("%s：未知预置重塑字段 %s" % [scope, str(field)])
        errors.append_array(_validate_origin(
            reshapes.get("origin", {}), origin_ids, attribute_ids,
            base_attribute, scope))
        _validate_optional_id(
            reshapes.get("enhancement", ""), enhancement_ids, "强化", scope, errors)
        _validate_optional_id(
            reshapes.get("imprint", ""), imprint_ids, "印记", scope, errors)
        var others = reshapes.get("others", {})
        if not others is Dictionary:
            errors.append("%s：预置重塑·其他必须是对象" % scope)
        return errors

    var seen: Dictionary = {}
    for reshape_id_value in parsed.get("reshape_ids", []):
        var reshape_id := str(reshape_id_value)
        var category := ""
        if origin_ids.has(reshape_id):
            errors.append("%s：本源 %s 必须显式提供 origin 与 payload 对象" % [scope, reshape_id])
            continue
        if enhancement_ids.has(reshape_id):
            category = "enhancement"
        elif imprint_ids.has(reshape_id):
            category = "imprint"
        else:
            errors.append("%s：引用未知重塑 %s" % [scope, reshape_id])
            continue
        if seen.has(category):
            errors.append("%s：每类重塑最多预置一个" % scope)
        seen[category] = true
    return errors

static func _validate_origin(
        origin,
        origin_ids: Dictionary,
        attribute_ids: Array,
        base_attribute: String,
        scope: String) -> Array[String]:
    var errors: Array[String] = []
    if not origin is Dictionary:
        errors.append("%s：预置本源必须是对象" % scope)
        return errors
    if origin.is_empty():
        return errors
    if origin.size() != 2 or not origin.has("id") or not origin.has("payload"):
        errors.append("%s：预置本源必须且只能包含 id 与 payload" % scope)
        return errors
    var origin_id := str(origin.get("id", ""))
    if not origin_ids.has(origin_id):
        errors.append("%s：引用未知本源 %s" % [scope, origin_id])
    var payload = origin.get("payload")
    if not payload is Dictionary:
        errors.append("%s：预置本源 payload 必须是对象" % scope)
        return errors
    match origin_id:
        "attribute_change":
            if payload.size() != 1 or not payload.get("attribute") is String:
                errors.append("%s：转属 payload 必须且只能包含字符串 attribute" % scope)
            elif not attribute_ids.has(str(payload.get("attribute", ""))):
                errors.append("%s：转属引用未知基础属性 %s" % [scope, str(payload.get("attribute", ""))])
        "rank_change":
            if payload.size() != 1 or not payload.get("direction") is String:
                errors.append("%s：易阶 payload 必须且只能包含字符串 direction" % scope)
            elif not ["up", "down"].has(str(payload.get("direction", ""))):
                errors.append("%s：易阶 direction 只能为 up 或 down" % scope)
        "awakening":
            if not payload.is_empty() and (
                    payload.size() != 1 or not payload.get("attribute") is String):
                errors.append("%s：觉醒 payload 必须为空或只包含字符串 attribute" % scope)
            elif payload.has("attribute") \
                    and str(payload.get("attribute", "")) != base_attribute:
                errors.append("%s：觉醒属性必须与真气当前基础属性一致" % scope)
    return errors

static func _validate_optional_id(
        value,
        index: Dictionary,
        label: String,
        scope: String,
        errors: Array[String]) -> void:
    if not value is String:
        errors.append("%s：预置%s必须是字符串" % [scope, label])
        return
    var content_id := str(value)
    if content_id != "" and not index.has(content_id):
        errors.append("%s：引用未知%s %s" % [scope, label, content_id])

static func _normalize_runtime_reshapes(
        parsed: Dictionary,
        content_catalog,
        scope: String) -> Dictionary:
    var origin_ids: Dictionary = {}
    var enhancement_ids: Dictionary = {}
    var imprint_ids: Dictionary = {}
    for definition in content_catalog.all_of("origin"):
        origin_ids[str(definition.get("id", ""))] = true
    for definition in content_catalog.all_of("enhancement"):
        enhancement_ids[str(definition.get("id", ""))] = true
    for definition in content_catalog.all_of("imprint"):
        imprint_ids[str(definition.get("id", ""))] = true
    var attributes: Array = []
    for attribute in content_catalog.definition("base_deck").get("attributes", []):
        attributes.append(str(attribute.get("id", "")))
    var errors := _validate_parsed_reshapes(
        parsed,
        origin_ids,
        enhancement_ids,
        imprint_ids,
        attributes,
        str(content_catalog.get_by_id(
            "card", str(parsed.get("definition_id", ""))).get("attribute", "")),
        scope)
    if not errors.is_empty():
        return {"errors": errors, "reshapes": {}}
    if bool(parsed.get("structured", false)):
        var reshapes: Dictionary = parsed.get("reshapes", {}).duplicate(true)
        return {
            "errors": [],
            "reshapes": {
                "origin": reshapes.get("origin", {}).duplicate(true),
                "enhancement": str(reshapes.get("enhancement", "")),
                "imprint": str(reshapes.get("imprint", "")),
                "others": reshapes.get("others", {}).duplicate(true),
            },
        }
    var result := {"origin": {}, "enhancement": "", "imprint": "", "others": {}}
    for reshape_id_value in parsed.get("reshape_ids", []):
        var reshape_id := str(reshape_id_value)
        if enhancement_ids.has(reshape_id):
            result["enhancement"] = reshape_id
        elif imprint_ids.has(reshape_id):
            result["imprint"] = reshape_id
    return {"errors": [], "reshapes": result}

static func _apply_reshapes(card, reshapes: Dictionary, content_catalog) -> Dictionary:
    if content_catalog != null and content_catalog.card_reshape_rules != null:
        content_catalog.card_reshape_rules.bind_card(card)
    var origin: Dictionary = reshapes.get("origin", {})
    if not origin.is_empty():
        var origin_result := CardOriginServiceScript.new(
            content_catalog, content_catalog.definition("base_deck")).apply_to_card(
                card, str(origin.get("id", "")), origin.get("payload", {}))
        if not origin_result.get("success", false):
            return origin_result
    var enhancement_id := str(reshapes.get("enhancement", ""))
    if enhancement_id != "":
        card.set_enhancement(enhancement_id)
    var imprint_id := str(reshapes.get("imprint", ""))
    if imprint_id != "":
        card.set_imprint(imprint_id)
    for reshape_id in reshapes.get("others", {}):
        card.set_other_reshape(str(reshape_id), reshapes["others"][reshape_id])
    return {"success": true}
