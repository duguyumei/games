class_name StatusRecordIdAllocator
extends RefCounted

var _serial: int = 0


func next_id(prefix: String) -> String:
    var record_id := "%s-%06d" % [prefix, _serial]
    _serial += 1
    return record_id


func current_serial() -> int:
    return _serial


func restore_serial(value: int) -> void:
    _serial = maxi(0, value)


func reset() -> void:
    _serial = 0
