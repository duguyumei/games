class_name BattlePendingActionTransaction
extends RefCounted

const SCHEMA_VERSION := 1

var kind: String = ""
var record = null
var records: Array = []
var action_preview: Dictionary = {}
var player_preview: Dictionary = {}
var enemy_preview: Dictionary = {}
var enemy_will_act: bool = false
var metadata: Dictionary = {}

func configure_single(
        transaction_kind: String,
        action_record,
        preview: Dictionary,
        transaction_metadata: Dictionary = {}):
    clear()
    kind = transaction_kind
    record = action_record
    action_preview = preview
    metadata = transaction_metadata.duplicate(true)
    return self

func configure_synchronized(
        action_records: Array,
        player_action_preview: Dictionary,
        enemy_action_preview: Dictionary,
        will_enemy_act: bool):
    clear()
    kind = "synchronized"
    records = action_records.duplicate()
    player_preview = player_action_preview
    enemy_preview = enemy_action_preview
    enemy_will_act = will_enemy_act
    return self

func is_empty() -> bool:
    return kind == ""

func clear() -> void:
    kind = ""
    record = null
    records.clear()
    action_preview.clear()
    player_preview.clear()
    enemy_preview.clear()
    enemy_will_act = false
    metadata.clear()

func snapshot() -> Dictionary:
    var record_snapshots: Array = []
    for action_record in records:
        record_snapshots.append(action_record.snapshot())
    return {
        "schema_version": SCHEMA_VERSION,
        "kind": kind,
        "record": record.snapshot() if record != null else {},
        "records": record_snapshots,
        "enemy_will_act": enemy_will_act,
        "metadata": metadata.duplicate(true),
    }
