class_name BattlePassiveEventReceiptStore
extends RefCounted

var _receipts: Dictionary = {}

func has(event_token: String) -> bool:
    return event_token != "" and _receipts.has(event_token)

func record(event_token: String, receipt: Dictionary) -> bool:
    if event_token == "" or _receipts.has(event_token):
        return false
    _receipts[event_token] = receipt.duplicate(true)
    return true

func receipt(event_token: String) -> Dictionary:
    return _receipts.get(event_token, {}).duplicate(true)

func clear() -> void:
    _receipts.clear()

func size() -> int:
    return _receipts.size()

func snapshot() -> Dictionary:
    return _receipts.duplicate(true)

func restore_snapshot(values: Dictionary) -> void:
    _receipts = values.duplicate(true)
