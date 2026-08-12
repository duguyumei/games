class_name EnemyIntentPublicProjector
extends RefCounted

const DISPLAY_NAMES := {
    "assault": "强攻", "survival": "防守", "prepare": "蓄势",
    "cycle": "换气", "develop": "运功", "control": "控制",
}

func project(records: Array) -> Array:
    var result: Array = []
    for index in range(records.size()):
        var features: Dictionary = records[index]["features"]
        var direction := str(features.get("primary_direction", "prepare"))
        result.append({
            "public_id": "intent-%03d" % (index + 1),
            "direction": direction,
            "display_name": str(DISPLAY_NAMES.get(direction, direction)),
            "damage": maxi(0, int(features["immediate"]["damage"])),
            "defense": maxi(0, int(features["immediate"]["defense"])),
            "played_count": maxi(0, int(features["card_flow"]["played_count"])),
            "expected_next_normal_draw": maxi(
                0, int(features["card_flow"]["expected_next_normal_draw"])),
            "combo": bool(features["immediate"]["combo"]),
            "public_tags": _public_tags(features),
        })
    return result

func _public_tags(features: Dictionary) -> Array[String]:
    var tags: Array[String] = []
    if bool(features["immediate"]["lethal"]):
        tags.append("可能造成致命打击")
    if bool(features["immediate"]["avoids_immediate_death"]):
        tags.append("优先保障生存")
    if int(features["card_flow"]["played_count"]) <= 2:
        tags.append("打出较少真气")
    if int(features["card_flow"]["retained_count"]) >= 3:
        tags.append("保留较多真气")
    if int(features["card_flow"]["expected_next_normal_draw"]) >= 3:
        tags.append("下回合补牌较多")
    if float(features["card_state"]["negative_card_cleanup_value"]) > 0.0:
        tags.append("清理不利真气状态")
    if float(features["future"]["sequence_progress_value"]) > 0.0:
        tags.append("推进功法序列")
    if float(features["passives"]["progress_value"]) > 0.0:
        tags.append("推进内功运转")
    if bool(features["immediate"]["combo"]):
        tags.append("可能获得连击")
    return tags.slice(0, 3)
