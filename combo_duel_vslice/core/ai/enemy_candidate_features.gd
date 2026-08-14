class_name EnemyCandidateFeatures
extends RefCounted

## 敌方合法行动的一步战略画像。这里只定义稳定数据形状，不承担评分或选择。

static func empty() -> Dictionary:
    return {
        "immediate": {
            "damage": 0, "defense": 0, "segments": 0, "combo": false,
            "same_qi_gain": 0, "same_qi_trigger_count": 0,
            "lethal": false, "avoids_immediate_death": false,
        },
        "card_flow": {
            "played_count": 0, "contributing_count": 0,
            "extra_played_count": 0, "retained_count": 0,
            "expected_next_normal_draw": 0,
        },
        "future": {
            "retained_hand_value": 0.0, "next_hand_potential": 0.0,
            "sequence_progress_value": 0.0,
        },
        "card_state": {
            "positive_play_value": 0.0,
            "negative_card_cleanup_value": 0.0,
            "positive_retention_value": 0.0,
            "negative_retention_cost": 0.0,
        },
        "passives": {
            "immediate_value": 0.0, "progress_value": 0.0,
            "control_value": 0.0, "trigger_signatures": [],
            "source_breakdown": [], "progress_entries": [],
        },
        "identity": {
            "hand_type": "", "technique_id": "",
            "next_technique_id": "",
        },
        "internal": {
            "card_ids": [], "status_change_signatures": [],
            "hard_reasons": [],
        },
        "direction_scores": {},
        "primary_direction": "prepare",
        "quality": 0.0,
    }
