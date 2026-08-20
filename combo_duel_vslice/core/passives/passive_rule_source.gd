class_name PassiveRuleSource
extends RefCounted

var source_kind: String = ""
var content_id: String = ""
var source_instance_key: String = ""
var definition: Dictionary = {}
var behavior_id: String = ""
var behavior_index: int = 0
var state_key: String = ""
var configuration: Dictionary = {}
var source_order: int = 0
var slot_index: int = -1
## 同一内容在当前配装中的第几个副本；不受其他内容插入或换位影响。
var content_instance_ordinal: int = 0
var behavior_copyable: bool = true
## 投影行为仍以复制者作为公开来源；这里只保存目标行为的稳定描述，
## 不复制目标内容对象，也不允许再次参与投影。
var projection: Dictionary = {}
## 计数器的拥有者身份仍由 source_kind/content_id 决定。投影行为额外用
## counter_instance_key 隔离不同复制槽位和目标行为，并用 definition_* 字段
## 从目标正文恢复计数器定义。
var counter_instance_key: String = ""
var counter_definition_source_kind: String = ""
var counter_definition_content_id: String = ""
var counter_definition_behavior_id: String = ""
var counter_definition_behavior_index: int = -1
## 来源 marker 随被复制正文投影，但写入地址仍属于复制者。
var source_marker_definitions: Array = []

func configure(values: Dictionary):
    source_kind = str(values.get("source_kind", ""))
    content_id = str(values.get("content_id", ""))
    source_instance_key = str(values.get("source_instance_key", ""))
    definition = values.get("definition", {}).duplicate(true)
    behavior_id = str(values.get("behavior_id", ""))
    behavior_index = int(values.get("behavior_index", 0))
    state_key = str(values.get("state_key", ""))
    configuration = values.get("configuration", {}).duplicate(true)
    source_order = int(values.get("source_order", 0))
    slot_index = int(values.get("slot_index", -1))
    content_instance_ordinal = int(values.get("content_instance_ordinal", 0))
    behavior_copyable = bool(values.get("behavior_copyable", true))
    projection = values.get("projection", {}).duplicate(true)
    counter_instance_key = str(values.get("counter_instance_key", ""))
    counter_definition_source_kind = str(values.get(
        "counter_definition_source_kind", ""))
    counter_definition_content_id = str(values.get(
        "counter_definition_content_id", ""))
    counter_definition_behavior_id = str(values.get(
        "counter_definition_behavior_id", ""))
    counter_definition_behavior_index = int(values.get(
        "counter_definition_behavior_index", -1))
    source_marker_definitions = values.get(
        "source_marker_definitions",
        definition.get("marker_definitions",
            definition.get("source_marker_definitions", []))).duplicate(true)
    return self

func is_projected() -> bool:
    return not projection.is_empty()

func projection_key() -> String:
    return str(projection.get("projection_key", ""))

func plan_identity() -> String:
    var projected_key := projection_key()
    if projected_key != "":
        return projected_key
    return "%s|%d" % [source_instance_key, behavior_index]

func behavior_ancestry_key() -> String:
    if is_projected():
        return "%s|%s" % [plan_identity(), behavior_id]
    return "%s|%s" % [source_instance_key, behavior_id]

func to_dict() -> Dictionary:
    return {
        "source_kind": source_kind,
        "content_id": content_id,
        "source_instance_key": source_instance_key,
        "definition": definition.duplicate(true),
        "behavior_id": behavior_id,
        "behavior_index": behavior_index,
        "state_key": state_key,
        "configuration": configuration.duplicate(true),
        "source_order": source_order,
        "slot_index": slot_index,
        "content_instance_ordinal": content_instance_ordinal,
        "behavior_copyable": behavior_copyable,
        "projection": projection.duplicate(true),
        "counter_instance_key": counter_instance_key,
        "counter_definition_source_kind": counter_definition_source_kind,
        "counter_definition_content_id": counter_definition_content_id,
        "counter_definition_behavior_id": counter_definition_behavior_id,
        "counter_definition_behavior_index": counter_definition_behavior_index,
        "source_marker_definitions": source_marker_definitions.duplicate(true),
    }
