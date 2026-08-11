class_name NodeInteractionHandlerRegistry
extends RefCounted

var _handlers_by_kind: Dictionary = {}
var _registration_errors: Array[String] = []
var _kind_pattern := RegEx.new()

func _init() -> void:
    _kind_pattern.compile("^[a-z][a-z0-9_]*$")

func register_handler(handler) -> bool:
    if handler == null \
            or not handler.has_method("interaction_kind") \
            or not handler.has_method("validate_configuration") \
            or not handler.has_method("prepare") \
            or not handler.has_method("commit"):
        _registration_errors.append(
            "节点交互处理器必须实现 interaction_kind、validate_configuration、prepare 与 commit")
        return false
    var kind := str(handler.interaction_kind())
    if kind == "":
        _registration_errors.append("节点交互 kind 不能为空")
        return false
    if _kind_pattern.search(kind) == null:
        _registration_errors.append(
            "节点交互 kind 必须使用稳定 snake_case：%s" % kind)
        return false
    if _handlers_by_kind.has(kind):
        _registration_errors.append("节点交互 kind 重复注册：%s" % kind)
        return false
    _handlers_by_kind[kind] = handler
    return true

func unregister_handler(kind: String) -> bool:
    return _handlers_by_kind.erase(kind)

func has_handler(kind: String) -> bool:
    return _handlers_by_kind.has(kind)

func handler_for(kind: String):
    return _handlers_by_kind.get(kind)

func require_handler(kind: String) -> Dictionary:
    var handler = handler_for(kind)
    if handler == null:
        return {
            "success": false,
            "reason": "未注册的节点交互 kind：%s" % kind,
        }
    return {"success": true, "handler": handler}

func interaction_kinds() -> Array[String]:
    var result: Array[String] = []
    for kind in _handlers_by_kind:
        result.append(str(kind))
    result.sort()
    return result

func registration_errors() -> Array[String]:
    return _registration_errors.duplicate()
