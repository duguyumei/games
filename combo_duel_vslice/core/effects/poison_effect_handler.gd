class_name PoisonEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return [
        "trigger_poison_captured", "trigger_all_poison_simultaneously",
        "trigger_highest_poison",
    ]

func group_name() -> String:
    return "poison"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("毒效果缺少战斗端口")
    match str(effect.get("op", "")):
        "trigger_poison_captured":
            var results: Array = []
            for card in runtime.captures.get(str(effect.get("capture", "")), []).duplicate():
                var holder = runtime.actor if str(effect.get("holder", "actor")) == "actor" else runtime.target
                if holder == null or not card.has_anomaly("state", "poison"):
                    continue
                var frozen: int = runtime.ports.current_effective_qi(holder, card)
                var triggered: Dictionary = runtime.ports.trigger_poison_card(
                    holder, card, runtime.action_token, false, frozen)
                if triggered.get("success", false):
                    results.append(triggered)
            runtime.captures[str(effect.get("result_capture", "poison_results"))] = results
            return EffectResultScript.succeeded("立即触发毒 %d 张" % results.size())
        "trigger_all_poison_simultaneously":
            return _trigger_all(effect, runtime)
        "trigger_highest_poison":
            return _trigger_highest(effect, runtime)
    return EffectResultScript.failed("毒处理器不支持此操作")

func _trigger_all(effect: Dictionary, runtime):
    var frozen: Array = []
    for holder in [runtime.actor, runtime.target]:
        if holder == null:
            continue
        for zone in ["hand", "draw_pile"]:
            for card in runtime.ports.zone_cards(holder, zone):
                if card.is_card_kind("normal") and card.has_anomaly("state", "poison"):
                    frozen.append({
                        "holder": holder, "card": card, "zone": zone,
                        "amount": runtime.ports.current_effective_qi(holder, card),
                    })
    var totals: Dictionary = {}
    for item in frozen:
        var holder_key := str(item["holder"].owner_id)
        totals[holder_key] = int(totals.get(holder_key, 0)) + int(item["amount"])
    runtime.ports.begin_synchronized_damage([
        {"actor": runtime.actor}, {"actor": runtime.target},
    ])
    for holder in [runtime.actor, runtime.target]:
        if holder != null:
            runtime.ports.deal_damage(
                holder, holder, int(totals.get(str(holder.owner_id), 0)),
                "同步毒爆", false, runtime.action_token, "poison")
    var resolutions: Array = runtime.ports.flush_synchronized_damage()
    var resolution_by_holder: Dictionary = {}
    for resolution in resolutions:
        resolution_by_holder[str(resolution["target"].owner_id)] = resolution
    var remaining_loss: Dictionary = {}
    for holder_key in resolution_by_holder:
        remaining_loss[holder_key] = int(
            resolution_by_holder[holder_key].get("result", {}).get("life_lost", 0))
    var results: Array = []
    for item in frozen:
        var holder_key := str(item["holder"].owner_id)
        var life_lost := mini(int(item["amount"]), int(remaining_loss.get(holder_key, 0)))
        remaining_loss[holder_key] = int(remaining_loss.get(holder_key, 0)) - life_lost
        runtime.ports.remove_card_anomaly(
            item["card"], "state", "poison", runtime.technique_name)
        var actual := {
            "success": true,
            "requested": int(item["amount"]),
            "final_amount": int(item["amount"]),
            "defense_lost": 0,
            "life_lost": life_lost,
            "actual_life_loss": life_lost,
            "damage_type": "poison",
            "true_damage": false,
        }
        runtime.ports.notify_poison_triggered(
            item["holder"], item["card"], int(item["amount"]),
            actual, runtime.action_token, false)
        results.append({
            "card": item["card"],
            "holder": item["holder"],
            "frozen_amount": int(item["amount"]),
            "life_lost": life_lost,
            "actual_life_loss": life_lost,
            "damage_result": actual,
        })
    runtime.captures[str(effect.get("result_capture", "poison_results"))] = results
    return EffectResultScript.succeeded("同步触发毒 %d 张" % frozen.size())

func _trigger_highest(effect: Dictionary, runtime):
    var holder = runtime.target if str(effect.get("holder", "target")) == "target" else runtime.actor
    if holder == null:
        return EffectResultScript.succeeded()
    var maximum := int(effect.get("maximum", 1))
    var threshold_value: int = value_resolver.resolve(effect.get("extra_when_value", 0), runtime)
    if threshold_value >= int(effect.get("extra_threshold", 24)):
        maximum += int(effect.get("extra_count", 1))
    var results: Array = []
    for _index in range(maximum):
        var candidates: Array = holder.hand.filter(func(card):
            return card.is_card_kind("normal") and card.has_anomaly("state", "poison"))
        if candidates.is_empty():
            candidates = holder.draw_pile.filter(func(card):
                return card.is_card_kind("normal") and card.has_anomaly("state", "poison"))
        if candidates.is_empty():
            break
        var highest := -1
        for card in candidates:
            highest = maxi(highest, runtime.ports.current_effective_qi(holder, card))
        var tied: Array = candidates.filter(func(card):
            return runtime.ports.current_effective_qi(holder, card) == highest)
        var chosen = tied[0]
        if tied.size() > 1 and runtime.ports.battle_rng() != null:
            chosen = tied[runtime.ports.battle_rng().randi_range(0, tied.size() - 1)]
        var triggered: Dictionary = runtime.ports.trigger_poison_card(
            holder, chosen, runtime.action_token)
        if triggered.get("success", false):
            results.append(triggered)
    runtime.captures[str(effect.get("result_capture", "poison_results"))] = results
    return EffectResultScript.succeeded("优先触发毒 %d 张" % results.size())

func validate_effect(_effect: Dictionary, _validator, _scope: String) -> void:
    pass
