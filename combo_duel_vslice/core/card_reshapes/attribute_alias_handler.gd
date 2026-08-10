class_name CardReshapeAttributeAliasHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

const ATTRIBUTE_IDS := ["wind", "forest", "fire", "mountain"]

func behavior_id() -> String:
    return "attribute_alias"

func triggers() -> Array[String]:
    return ["attribute_check"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    var attributes = behavior.get("attributes")
    if not attributes is Array or attributes.is_empty():
        validator.report_error(scope + ".attributes", "必须是非空数组")
        return
    for index in range(attributes.size()):
        if not ATTRIBUTE_IDS.has(str(attributes[index])):
            validator.report_error(
                "%s.attributes[%d]" % [scope, index],
                "未知属性 %s" % str(attributes[index]))

func execute(behavior: Dictionary, context) -> Dictionary:
    var attributes: Array = behavior.get("attributes", [])
    return {
        "success": true,
        "matches": attributes.has(context.attribute_id),
        "attributes": attributes.duplicate(),
    }
