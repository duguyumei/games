class_name BattleObservation
extends RefCounted

var actor_id: String = ""
var actor_name: String = ""
var actor_hand: Array = []
var actor_life: int = 0
var actor_max_life: int = 0
var actor_defense: int = 0
var actor_draw_count: int = 0
var actor_discard_count: int = 0
var opponent_id: String = ""
var opponent_name: String = ""
var opponent_life: int = 0
var opponent_max_life: int = 0
var opponent_defense: int = 0
var opponent_hand_count: int = 0
var opponent_draw_count: int = 0
var opponent_discard_count: int = 0
var expected_incoming_damage: int = -1
var opponent_threat: Dictionary = {
    "minimum": 0, "expected": 0, "maximum": 0,
    "confidence": "low", "basis": "public_build_history",
}
var sequence_positions: Dictionary = {}
var action_state: Dictionary = {}

func capture(actor, opponent, sequence_book, battle_flow):
    actor_id = str(actor.owner_id)
    actor_name = str(actor.name)
    actor_hand = actor.hand.duplicate()
    actor_life = int(actor.life)
    actor_max_life = int(actor.max_life)
    actor_defense = int(actor.defense)
    actor_draw_count = actor.draw_pile.size()
    actor_discard_count = actor.discard_pile.size()
    opponent_id = str(opponent.owner_id)
    opponent_name = str(opponent.name)
    opponent_life = int(opponent.life)
    opponent_max_life = int(opponent.max_life)
    opponent_defense = int(opponent.defense)
    opponent_hand_count = opponent.hand.size()
    opponent_draw_count = opponent.draw_pile.size()
    opponent_discard_count = opponent.discard_pile.size()
    sequence_positions = sequence_book.positions.duplicate(true)
    action_state = battle_flow.snapshot_for(actor)
    return self

func public_snapshot() -> Dictionary:
    return {
        "actor_id": actor_id,
        "actor_name": actor_name,
        "actor_hand_count": actor_hand.size(),
        "actor_life": actor_life,
        "actor_max_life": actor_max_life,
        "actor_defense": actor_defense,
        "actor_draw_count": actor_draw_count,
        "actor_discard_count": actor_discard_count,
        "opponent_id": opponent_id,
        "opponent_name": opponent_name,
        "opponent_life": opponent_life,
        "opponent_max_life": opponent_max_life,
        "opponent_defense": opponent_defense,
        "opponent_hand_count": opponent_hand_count,
        "opponent_draw_count": opponent_draw_count,
        "opponent_discard_count": opponent_discard_count,
        "expected_incoming_damage": expected_incoming_damage,
        "opponent_threat": opponent_threat.duplicate(true),
        "sequence_positions": sequence_positions.duplicate(true),
        "action_state": action_state.duplicate(true),
    }
