class_name EnemyCandidateDirectionClassifier
extends RefCounted

const DIRECTIONS := ["assault", "survival", "prepare", "cycle", "develop", "control"]

func classify(features: Dictionary, policy: Dictionary = {}) -> Dictionary:
    var immediate: Dictionary = features["immediate"]
    var flow: Dictionary = features["card_flow"]
    var future: Dictionary = features["future"]
    var state: Dictionary = features["card_state"]
    var passives: Dictionary = features["passives"]
    var scores := {
        "assault": float(immediate["damage"]) + (30.0 if immediate["lethal"] else 0.0) + (4.0 if immediate["combo"] else 0.0),
        "survival": float(immediate["defense"]) + (30.0 if immediate["avoids_immediate_death"] else 0.0),
        "prepare": float(future["retained_hand_value"]) + float(future["next_hand_potential"]) + float(state["positive_retention_value"]) - float(flow["played_count"]) * 0.25,
        "cycle": float(flow["expected_next_normal_draw"]) + float(flow["extra_played_count"]) + float(state["negative_card_cleanup_value"]) * 2.0 - float(state["negative_retention_cost"]),
        "develop": float(future["sequence_progress_value"]) * 4.0 + float(passives["progress_value"]) + float(passives["immediate_value"]) * 0.25,
        "control": float(passives["control_value"]),
    }
    var weights: Dictionary = policy.get("direction_weights", {})
    for direction in DIRECTIONS:
        scores[direction] = float(scores[direction]) * float(weights.get(direction, 1.0))
    var primary := DIRECTIONS[0]
    for direction in DIRECTIONS:
        if float(scores[direction]) > float(scores[primary]):
            primary = direction
    features["direction_scores"] = scores
    features["primary_direction"] = primary
    return features
