class_name BattleTimingEvent
extends RefCounted

var timing: String = ""
var serial: int = -1
var round_number: int = 0
var actor = null
var actors: Array = []
var context: Dictionary = {}
var handler_results: Array = []

func configure(
        timing_id: String,
        event_serial: int,
        timing_context: Dictionary = {}):
    timing = timing_id
    serial = event_serial
    context = timing_context.duplicate(true)
    round_number = int(context.get("round_number", 0))
    actor = context.get("actor")
    actors = context.get("actors", []).duplicate()
    return self

func snapshot() -> Dictionary:
    var actor_ids: Array[String] = []
    var actor_names: Array[String] = []
    for side in actors:
        actor_ids.append(str(side.owner_id))
        actor_names.append(str(side.name))
    return {
        "timing": timing,
        "serial": serial,
        "round_number": round_number,
        "actor_id": str(actor.owner_id) if actor != null else "",
        "actor_name": str(actor.name) if actor != null else "",
        "actor_ids": actor_ids,
        "actor_names": actor_names,
        "metadata": context.get("metadata", {}).duplicate(true),
        "handler_results": handler_results.duplicate(true),
    }
