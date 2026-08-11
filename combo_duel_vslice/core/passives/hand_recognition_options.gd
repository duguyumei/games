class_name HandRecognitionOptions
extends RefCounted

const DEFAULT_STRAIGHT_ALLOWED_SIZES := [5]

var straight_allowed_sizes: Array[int] = [5]
var straight_max_step: int = 1
var ace_low_allowed: bool = true
var ace_high_allowed: bool = true

func configure(values: Dictionary = {}):
    straight_allowed_sizes.clear()
    var sizes = values.get("straight_allowed_sizes", DEFAULT_STRAIGHT_ALLOWED_SIZES)
    if sizes is Array:
        for value in sizes:
            var size := int(value)
            if size > 0 and size <= 5 and not straight_allowed_sizes.has(size):
                straight_allowed_sizes.append(size)
    straight_allowed_sizes.sort()
    if straight_allowed_sizes.is_empty():
        straight_allowed_sizes.assign(DEFAULT_STRAIGHT_ALLOWED_SIZES)
    straight_max_step = clampi(int(values.get("straight_max_step", 1)), 1, 13)
    ace_low_allowed = bool(values.get("ace_low_allowed", true))
    ace_high_allowed = bool(values.get("ace_high_allowed", true))
    return self

func duplicate_options():
    return get_script().new().configure(to_dict())

func to_dict() -> Dictionary:
    return {
        "straight_allowed_sizes": straight_allowed_sizes.duplicate(),
        "straight_max_step": straight_max_step,
        "ace_low_allowed": ace_low_allowed,
        "ace_high_allowed": ace_high_allowed,
    }

