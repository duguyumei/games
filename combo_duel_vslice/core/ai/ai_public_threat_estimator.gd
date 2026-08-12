class_name AiPublicThreatEstimator
extends RefCounted

## 只使用战斗开始即公开的完整构筑、公开牌数和公开历史伤害。不枚举玩家
## 当前合法候选，也不读取当前手牌身份或选牌草稿。

func estimate(opponent, public_events: Array = []) -> Dictionary:
    var highest_qi := 0
    for card in opponent.all_cards_for_run_sync():
        highest_qi = maxi(highest_qi, int(card.qi_value))
    var recent_damage: Array[int] = []
    for event in public_events:
        if str(event.get("event_type", "")) != "damage_resolved" \
                or str(event.get("actor_id", "")) != str(opponent.owner_id):
            continue
        recent_damage.append(maxi(0, int(event.get("payload", {}).get("amount", 0))))
    if recent_damage.size() > 4:
        recent_damage = recent_damage.slice(recent_damage.size() - 4)
    var recent_expected := 0
    if not recent_damage.is_empty():
        var sorted := recent_damage.duplicate()
        sorted.sort()
        recent_expected = int(sorted[(sorted.size() - 1) / 2])
    var public_build_upper := maxi(0, highest_qi * mini(5, maxi(1, opponent.hand.size())))
    var expected := recent_expected if recent_expected > 0 else int(floor(float(public_build_upper) * 0.25))
    return {
        "minimum": 0,
        "expected": maxi(0, expected),
        "maximum": maxi(expected, public_build_upper),
        "confidence": "medium" if recent_damage.size() >= 2 else "low",
        "basis": "public_build_history",
    }
