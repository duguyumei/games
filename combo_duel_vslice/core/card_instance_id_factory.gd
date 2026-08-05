class_name CardInstanceIdFactory
extends RefCounted

var id_namespace: String
var _next_serial: int = 1

func _init(namespace_value: String = "run") -> void:
    id_namespace = namespace_value if namespace_value != "" else "run"

func reset(next_serial: int = 1) -> void:
    _next_serial = maxi(1, next_serial)

func next_id(definition_id: String) -> String:
    var instance_id := "%s:%06d:%s" % [id_namespace, _next_serial, definition_id]
    _next_serial += 1
    return instance_id

func next_serial() -> int:
    return _next_serial
