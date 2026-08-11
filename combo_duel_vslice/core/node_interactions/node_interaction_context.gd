class_name NodeInteractionContext
extends RefCounted

const ContentQueryScript = preload(
    "res://core/node_interactions/node_interaction_content_query.gd")

var source_kind: String
var source_id: String
var node_id: String
var node_type: String
var content_id: String
var interaction_kind: String
var act: int
var run_seed: int
var content_seed: int
var interaction_token: String
var configuration: Dictionary
var growth_snapshot: Dictionary
var content_query
var rng: RandomNumberGenerator

func _init(values: Dictionary, growth, content_catalog = null) -> void:
    source_kind = str(values.get("source_kind", ""))
    source_id = str(values.get("source_id", ""))
    node_id = str(values.get("node_id", ""))
    node_type = str(values.get("node_type", ""))
    content_id = str(values.get("content_id", ""))
    interaction_kind = str(values.get("interaction_kind", ""))
    act = int(values.get("act", 1))
    run_seed = int(values.get("run_seed", 0))
    content_seed = int(values.get("content_seed", 0))
    interaction_token = str(values.get(
        "interaction_token", values.get("token", "")))
    configuration = values.get("configuration", {}).duplicate(true)
    growth_snapshot = (
        growth.capture_mutation_state().duplicate(true)
        if growth != null and growth.has_method("capture_mutation_state")
        else values.get("growth_snapshot", {}).duplicate(true))
    content_query = ContentQueryScript.new(content_catalog)
    rng = RandomNumberGenerator.new()
    rng.seed = content_seed

func snapshot() -> Dictionary:
    return {
        "source_kind": source_kind,
        "source_id": source_id,
        "node_id": node_id,
        "node_type": node_type,
        "content_id": content_id,
        "interaction_kind": interaction_kind,
        "act": act,
        "run_seed": run_seed,
        "content_seed": content_seed,
        "interaction_token": interaction_token,
        "configuration": configuration.duplicate(true),
        "growth_snapshot": growth_snapshot.duplicate(true),
    }
