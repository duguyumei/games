class_name FakeEnemyAiValueProvider
extends RefCounted

var responses: Dictionary = {}
var calls: Array = []
var mutate_actor: bool = false

func configure(values: Dictionary = {}):
    responses = values.duplicate(true)
    return self

func query(hook: String, context: Dictionary) -> Dictionary:
    calls.append({
        "hook": hook,
        "card_id": str(context.get("card").id) if context.get("card") != null else "",
    })
    if mutate_actor and context.get("actor") != null:
        context["actor"].defense += 1
    return responses.get(
        hook, {"success": true, "estimated_value": 0.0}).duplicate(true)
