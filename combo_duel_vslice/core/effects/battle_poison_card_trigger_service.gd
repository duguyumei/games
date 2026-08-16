class_name BattlePoisonCardTriggerService
extends RefCounted

## BattleEffectPorts 内部的毒真气触发事务服务。
##
## 本服务只组合既有真气状态与生存结算能力：有效真气值和毒状态移除仍由
## BattleCardEffectService 负责，毒伤写入、同步 flush 与完成事件仍由
## BattleSurvivalEffectService 负责。这里集中维护冻结、成功后清毒和同步事件时点。

var _card_effect_service
var _survival_effect_service


func _init(card_effect_service, survival_effect_service) -> void:
    assert(card_effect_service != null,
        "BattlePoisonCardTriggerService requires BattleCardEffectService")
    assert(survival_effect_service != null,
        "BattlePoisonCardTriggerService requires BattleSurvivalEffectService")
    _card_effect_service = card_effect_service
    _survival_effect_service = survival_effect_service


func trigger_poison_card(
        holder,
        card,
        action_token: String = "",
        replayed: bool = false,
        frozen_amount_override = null) -> Dictionary:
    if holder == null or card == null or not card.has_anomaly("state", "poison"):
        return {"success": false, "reason": "毒触发目标无效"}
    var frozen_amount: int = (
        _card_effect_service.current_effective_qi(holder, card)
        if frozen_amount_override == null
        else maxi(0, int(frozen_amount_override)))
    var source_metadata := _poison_source_metadata(card)
    var damage: Dictionary = _survival_effect_service.deal_damage(
        holder,
        holder,
        frozen_amount,
        str(source_metadata["source_kind"]),
        false,
        action_token,
        "poison",
        {
            "kind": "poison_card_trigger",
            "holder": holder,
            "card": card,
            "frozen_amount": frozen_amount,
            "action_token": action_token,
            "poison_modifier_receipt_token": "%s:poison:%s" % [
                action_token, str(card.id)],
            "replayed": replayed,
        },
        source_metadata)
    if not damage.get("success", false):
        return damage
    var removed: Dictionary = _card_effect_service.remove_card_anomaly(
        card, "state", "poison", "毒触发", source_metadata)
    if not removed.get("changed", false):
        return {
            "success": false,
            "reason": "毒伤完成后清除毒失败",
            "damage_result": damage,
        }
    if not bool(damage.get("buffered", false)):
        notify_poison_triggered(
            holder, card, frozen_amount, damage, action_token, replayed)
    return {
        "success": true,
        "card": card,
        "frozen_amount": frozen_amount,
        "life_lost": int(damage.get("life_lost", 0)),
        "actual_life_loss": int(damage.get("life_lost", 0)),
        "damage_result": damage,
        "buffered": bool(damage.get("buffered", false)),
    }


func flush_synchronized_damage() -> Array:
    var resolutions: Array = _survival_effect_service.flush_synchronized_damage()
    for resolution_value in resolutions:
        var resolution: Dictionary = resolution_value
        var metadata: Dictionary = resolution.get("resolution_metadata", {})
        if str(metadata.get("kind", "")) != "poison_card_trigger":
            continue
        notify_poison_triggered(
            metadata.get("holder"),
            metadata.get("card"),
            int(metadata.get("frozen_amount", 0)),
            resolution.get("result", {}),
            str(metadata.get("action_token", "")),
            bool(metadata.get("replayed", false)))
    return resolutions


func notify_poison_triggered(
        holder,
        card,
        frozen_amount: int,
        damage_result: Dictionary,
        action_token: String = "",
        replayed: bool = false) -> void:
    _survival_effect_service.notify_poison_triggered(
        holder, card, frozen_amount, damage_result, action_token, replayed)


func _poison_source_metadata(card) -> Dictionary:
    return {
        "source_kind": "card_status",
        "source_id": "poison",
        "source_name": "毒",
        "source_instance_key": "card_status:%s:poison" % str(card.id),
        "trigger_mode": "direct",
    }
