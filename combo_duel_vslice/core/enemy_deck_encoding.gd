class_name EnemyDeckEncoding
extends RefCounted

const CardInstanceIdFactoryScript = preload("res://core/card_instance_id_factory.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")

## 敌人牌组只表达基础牌与预置重塑；战斗异状由战斗效果产生。
## 解析器独立于 CombatEngine，便于内容校验和正式装配共用同一语法。
static func parse(
        values: Array,
        content_catalog,
        instance_namespace: String = "enemy") -> Dictionary:
    var errors: Array[String] = []
    var cards: Array = []
    var factory := CardInstanceIdFactoryScript.new(instance_namespace)
    for index in range(values.size()):
        var token := str(values[index])
        var parsed := _parse_token(token)
        if not parsed.get("success", false):
            errors.append("牌组[%d]：%s" % [index, parsed.get("reason", "编码无效")])
            continue
        var definition_id := str(parsed["definition_id"])
        var definition: Dictionary = content_catalog.get_by_id("card", definition_id)
        if definition.is_empty():
            errors.append("牌组[%d]：引用未知真气 %s" % [index, definition_id])
            continue
        var reshape_check := _validate_reshapes(
            parsed["reshapes"], content_catalog, "牌组[%d]" % index)
        errors.append_array(reshape_check)
        if not reshape_check.is_empty():
            continue
        for _copy in range(int(parsed["count"])):
            var card = DeckFactoryScript.create_card_instance(
                definition, factory.next_id(definition_id))
            _apply_reshapes(card, parsed["reshapes"])
            cards.append(card)
    return {"success": errors.is_empty(), "cards": cards, "errors": errors}

static func validate_tokens(
        values: Array,
        card_ids: Dictionary,
        enhancement_ids: Dictionary,
        finish_ids: Dictionary,
        imprint_ids: Dictionary) -> Dictionary:
    var errors: Array[String] = []
    var expanded_count := 0
    for index in range(values.size()):
        var token := str(values[index])
        var parsed := _parse_token(token)
        if not parsed.get("success", false):
            errors.append("牌组[%d]：%s" % [index, parsed.get("reason", "编码无效")])
            continue
        var definition_id := str(parsed["definition_id"])
        if not card_ids.has(definition_id):
            errors.append("牌组[%d]：引用未知真气 %s" % [index, definition_id])
        errors.append_array(_validate_token_reshapes(
            parsed["reshapes"], enhancement_ids, finish_ids, imprint_ids,
            "牌组[%d]" % index))
        expanded_count += int(parsed["count"])
    return {"errors": errors, "expanded_count": expanded_count}

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
    var reshapes: Array[String] = []
    for reshape_index in range(1, parts.size()):
        var reshape_id := str(parts[reshape_index])
        if reshape_id.is_empty():
            return {"success": false, "reason": "重塑 ID 不能为空"}
        reshapes.append(reshape_id)
    return {
        "success": true,
        "definition_id": definition_id,
        "reshapes": reshapes,
        "count": count,
    }

static func _validate_token_reshapes(
        reshapes: Array,
        enhancement_ids: Dictionary,
        finish_ids: Dictionary,
        imprint_ids: Dictionary,
        scope: String) -> Array[String]:
    var errors: Array[String] = []
    var seen: Dictionary = {}
    for reshape in reshapes:
        var reshape_id := str(reshape)
        var category := ""
        if reshape_id == "gold" and enhancement_ids.has("gold") \
                and imprint_ids.has("gold"):
            category = "imprint" if seen.has("enhancement") else "enhancement"
        elif enhancement_ids.has(reshape_id):
            category = "enhancement"
        elif finish_ids.has(reshape_id):
            category = "finish"
        elif imprint_ids.has(reshape_id):
            category = "imprint"
        else:
            errors.append("%s：引用未知重塑 %s" % [scope, reshape_id])
            continue
        if seen.has(category):
            errors.append("%s：每类重塑最多预置一个" % scope)
        seen[category] = true
    return errors

static func _validate_reshapes(reshapes: Array, content_catalog, scope: String) -> Array[String]:
    var errors: Array[String] = []
    var seen_categories: Dictionary = {}
    for reshape in reshapes:
        var reshape_id := str(reshape)
        var category := ""
        if reshape_id == "gold" and content_catalog.has_id("enhancement", "gold") \
                and content_catalog.has_id("imprint", "gold"):
            category = "imprint" if seen_categories.has("enhancement") else "enhancement"
        elif content_catalog.has_id("enhancement", reshape_id):
            category = "enhancement"
        elif content_catalog.has_id("finish", reshape_id):
            category = "finish"
            var finish: Dictionary = content_catalog.get_by_id("finish", reshape_id)
            if not finish.get("allowed_carriers", []).has("card"):
                errors.append("%s：品相 %s 不能用于真气" % [scope, reshape_id])
        elif content_catalog.has_id("imprint", reshape_id):
            category = "imprint"
        else:
            errors.append("%s：引用未知重塑 %s" % [scope, reshape_id])
            continue
        if seen_categories.has(category):
            errors.append("%s：每类重塑最多预置一个" % scope)
        seen_categories[category] = true
    return errors

static func _apply_reshapes(card, reshapes: Array) -> void:
    for reshape in reshapes:
        var reshape_id := str(reshape)
        if reshape_id == "gold":
            if card.reshape_enhancement == "":
                card.set_enhancement(reshape_id)
            else:
                card.set_imprint(reshape_id)
        elif reshape_id in ["bonus", "multiplier", "wild", "glass", "steel", "stone", "lucky"]:
            card.set_enhancement(reshape_id)
        elif reshape_id in ["foil", "holographic", "polychrome", "negative"]:
            card.set_finish(reshape_id)
        else:
            card.set_imprint(reshape_id)
