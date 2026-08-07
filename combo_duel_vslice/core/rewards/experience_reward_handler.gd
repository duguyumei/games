class_name ExperienceRewardHandler
extends RefCounted

func kind_ids() -> Array[String]:
    return ["experience"]

func apply(entry: Dictionary, growth) -> Dictionary:
    var amount := int(entry.get("amount", 0))
    growth.experience += amount
    return {
        "success": true,
        "applied": {"kind": "experience", "amount": amount},
    }
