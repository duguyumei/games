class_name RunEffectContext
extends RefCounted

## 单次本局事务的运行上下文。
##
## growth 始终是独立工作副本；metadata 只携带来源、奖励包等编排信息。

var growth
var metadata: Dictionary

func _init(growth_override, metadata_override: Dictionary = {}) -> void:
    growth = growth_override
    metadata = metadata_override.duplicate(true)
