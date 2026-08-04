class_name TechniqueEffectExecutor
extends RefCounted

var rng: RandomNumberGenerator

func _init(random_source: RandomNumberGenerator) -> void:
    rng = random_source

func execute_all(effects: Array, context: Dictionary) -> Dictionary:
    if not context.has("captures"):
        context["captures"] = {}
    var details: Array[String] = []
    for effect in effects:
        if not _effect_condition_met(effect.get("when", {}), context):
            continue
        var result := _execute_effect(effect, context)
        if not result.get("success", false):
            return {"success": false, "detail": result.get("detail", "未知效果失败")}
        if result.get("detail", "") != "":
            details.append(result["detail"])
    return {"success": true, "detail": "；".join(details)}

func _execute_effect(effect: Dictionary, context: Dictionary) -> Dictionary:
    var op: String = effect.get("op", "")
    var actor = context["actor"]
    var target = context["target"]
    var engine = context["engine"]
    match op:
        "damage":
            var damage := _resolve_amount(effect.get("amount", {}), context)
            var result: Dictionary = engine.deal_damage(actor, target, damage, "technique")
            return {"success": true, "detail": "伤害 %d（防御-%d / 生命-%d）" % [damage, result["defense_lost"], result["life_lost"]]}
        "defense":
            var defense: int = actor.add_defense(_resolve_amount(effect.get("amount", {}), context))
            return {"success": true, "detail": "获得 %d 防御" % defense}
        "draw":
            var drawn: Array = actor.draw(_resolve_amount(effect.get("count", {}), context))
            if effect.has("capture"):
                context["captures"][effect["capture"]] = drawn
            return {"success": true, "detail": "抽 %d 张" % drawn.size()}
        "draw_if_captured_attribute":
            var captured: Array = context["captures"].get(effect.get("capture", ""), [])
            var matches := false
            for card in captured:
                if card.attribute == effect.get("attribute", ""):
                    matches = true
                    break
            var conditional_drawn: Array = actor.draw(int(effect.get("count", 1))) if matches else []
            return {"success": true, "detail": "属性追加抽 %d 张" % conditional_drawn.size() if matches else ""}
        "discard_random":
            var discarded: Array = actor.random_discard(_resolve_amount(effect.get("count", {}), context), rng)
            return {"success": true, "detail": "随机弃 %d 张" % discarded.size()}
        "discard_all_hand":
            var all_discarded: Array = actor.discard_all()
            context["captures"][effect.get("capture", "discarded")] = all_discarded
            return {"success": true, "detail": "弃掉全部剩余手牌 %d 张" % all_discarded.size()}
        "apply_random_card_status":
            var zone: String = effect.get("zone", "hand")
            var slot: String = effect.get("slot", "outplay")
            var status_id: String = effect.get("status", "")
            var source_cards: Array = []
            match zone:
                "hand": source_cards = target.hand
                "draw_pile": source_cards = target.draw_pile
                "discard_pile": source_cards = target.discard_pile
            var candidates: Array = []
            for card in source_cards:
                if not card.has_combat_status(slot):
                    candidates.append(card)
            var applied: Array = []
            var wanted := mini(_resolve_amount(effect.get("count", 1), context), candidates.size())
            for _index in range(wanted):
                var chosen_index := rng.randi_range(0, candidates.size() - 1)
                var chosen = candidates.pop_at(chosen_index)
                chosen.set_combat_status(slot, status_id)
                applied.append(chosen)
            if effect.has("capture"):
                context["captures"][effect["capture"]] = applied
            return {"success": true, "detail": "%s获得%s：%d 张" % [zone, status_id, applied.size()]}
        "add_stack":
            var stack_amount: int = actor.add_stack(effect["stack"], _resolve_amount(effect.get("amount", {}), context))
            return {"success": true, "detail": "%s +%d" % [effect["stack"], stack_amount]}
        "add_target_stack":
            var target_stack_amount: int = target.add_stack(effect["stack"], _resolve_amount(effect.get("amount", {}), context))
            return {"success": true, "detail": "敌方 %s +%d" % [effect["stack"], target_stack_amount]}
        "add_stack_per_captured_card":
            var cards: Array = context["captures"].get(effect.get("capture", ""), [])
            var total := 0
            for card in cards:
                total += int(effect.get("attribute_values", {}).get(card.attribute, effect.get("default", 0)))
            actor.add_stack(effect["stack"], total)
            return {"success": true, "detail": "%s +%d" % [effect["stack"], total]}
        "gain_extra_action":
            var actions := _resolve_amount(effect.get("amount", {}), context)
            engine.gain_extra_actions_for(actor, actions, "功法")
            return {"success": true, "detail": "连击机会 +%d" % actions}
        "multi_damage":
            return _execute_multi_damage(effect, context)
        "register_attack_counter_delay":
            var delay_damage := _resolve_amount(effect.get("damage", {}), context)
            engine.register_attack_counter_delay(
                context.get("technique_name", "延迟功法"),
                int(effect.get("turn_ends", 1)),
                int(context["power"]),
                delay_damage,
                actor,
                target)
            return {"success": true, "detail": "记录 P=%d，延迟伤害/段=%d" % [context["power"], delay_damage]}
        _:
            return {"success": false, "detail": "未支持的功法效果操作：%s" % op}

func _execute_multi_damage(effect: Dictionary, context: Dictionary) -> Dictionary:
    var actor = context["actor"]
    var target = context["target"]
    var engine = context["engine"]
    var segments := int(effect.get("segments", 1))
    var life_hits := 0
    var previous_life_hit := false
    var chase_count := 0
    for _index in range(segments):
        if not engine.damage_actor_can_continue(actor) or not engine.damage_target_can_receive(target):
            break
        var amount := _resolve_amount(effect.get("amount", {}), context)
        var hit: Dictionary = engine.deal_damage(actor, target, amount, "technique")
        var current_life_hit: bool = int(hit["life_lost"]) > 0
        if current_life_hit:
            life_hits += 1
        var after_stack: Dictionary = effect.get("after_each_stack", {})
        if not after_stack.is_empty():
            actor.add_stack(after_stack["stack"], int(after_stack.get("amount", 0)))
        if previous_life_hit and current_life_hit and int(effect.get("chase_on_consecutive_life_hits_percent", 0)) > 0:
            var chase_amount := int(floor(amount * int(effect["chase_on_consecutive_life_hits_percent"]) / 100.0))
            engine.deal_damage(actor, target, chase_amount, "chase")
            actor.add_stack("momentum", int(effect.get("chase_stack", 0)))
            chase_count += 1
        previous_life_hit = current_life_hit
    return {"success": true, "detail": "多段 %d，伤及生命 %d 段，追击 %d 段" % [segments, life_hits, chase_count]}

func _resolve_amount(spec, context: Dictionary) -> int:
    if spec is int or spec is float:
        return int(spec)
    if not spec is Dictionary:
        return 0
    match spec.get("kind", "constant"):
        "constant":
            return int(spec.get("value", 0))
        "power":
            return int(context.get("power", 0))
        "power_fraction":
            var value := int(floor(
                int(context.get("power", 0))
                * int(spec.get("numerator", 1))
                / float(maxi(1, int(spec.get("denominator", 1))))))
            return maxi(int(spec.get("minimum", 0)), value)
        "n60":
            return maxi(1, int(floor(int(context.get("power", 0)) / 60.0)))
        "hand_map":
            return int(spec.get("values", {}).get(context["hand_result"]["id"], 0))
        "max":
            var maximum := 0
            for child in spec.get("values", []):
                maximum = maxi(maximum, _resolve_amount(child, context))
            return maximum
    return 0

func _effect_condition_met(condition: Dictionary, context: Dictionary) -> bool:
    if condition.is_empty():
        return true
    if condition.has("pure_attribute"):
        var attribute: String = condition["pure_attribute"]
        var contributing: Array = context["hand_result"].get("contributing", [])
        if contributing.is_empty():
            return false
        for card in contributing:
            if card.attribute != attribute:
                return false
    if condition.has("capture_nonempty"):
        var captured: Array = context.get("captures", {}).get(condition["capture_nonempty"], [])
        if captured.is_empty():
            return false
    return true
