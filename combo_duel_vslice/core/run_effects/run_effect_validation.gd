class_name RunEffectValidation
extends RefCounted

## RunMutationService 使用的轻量校验收集器，与 ContentValidator 共享
## report_error(scope, message) 这一窄接口。

var errors: Array[String] = []

func report_error(scope: String, message: String) -> void:
    errors.append("%s: %s" % [scope, message])

func is_valid() -> bool:
    return errors.is_empty()
