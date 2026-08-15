class_name CollectionEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")
const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")

var value_resolver
var rng: RandomNumberGenerator

func _init(resolver, random_source: RandomNumberGenerator = null) -> void:
    value_resolver = resolver
    rng = random_source

func operation_ids() -> Array[String]:
    return [
        "capture_group_cards", "for_each_captured", "remove_card_anomaly_from_captured",
        "gain_battle_experience", "generate_temporary_normal_card",
        "select_random_captured",
        "select_highest_random_captured", "capture_event_cards",
        "capture_value",
        "capture_difference",
        "filter_captured", "repeat_effects",
    ]

func group_name() -> String:
    return "collection"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    match str(effect.get("op", "")):
        "capture_group_cards":
            var kind := str(effect.get("kind", "played"))
            var cards: Array = runtime.group_snapshot.get(
                "%s_cards" % kind, []).duplicate()
            if kind in ["pair_component", "three_component"]:
                cards = _frozen_rank_component(
                    runtime.group_snapshot,
                    2 if kind == "pair_component" else 3)
            if kind == "on_play_success":
                cards = runtime.group_snapshot.get("on_play_success_cards", []).duplicate()
            if bool(effect.get("require_non_attribute", false)):
                var excluded := str(effect.get("attribute", ""))
                cards = cards.filter(func(card):
                    return HandGroupSnapshotScript.has_non_attribute_identity(
                        runtime.group_snapshot, card, excluded))
            if effect.has("attribute") and not bool(effect.get("require_non_attribute", false)):
                var wanted := str(effect["attribute"])
                var filtered: Array = []
                for card in cards:
                    var matches: bool = card.is_attribute(wanted)
                    if runtime.card_identity_policy != null:
                        var identity: Dictionary = runtime.card_identity_policy.resolve(card, {
                            "owner": runtime.actor, "actor": runtime.actor,
                            "target": runtime.target,
                        })
                        matches = identity.get("success", false) \
                            and identity["facts"].has_attribute(wanted)
                    if matches:
                        filtered.append(card)
                cards = filtered
            if effect.has("anomaly"):
                var anomaly: Dictionary = effect["anomaly"]
                cards = cards.filter(func(card): return card.has_anomaly(
                    str(anomaly.get("category", "")), str(anomaly.get("id", ""))) \
                    == bool(anomaly.get("present", true)))
            if effect.has("reshape"):
                var reshape: Dictionary = effect["reshape"]
                var category := str(reshape.get("category", ""))
                var reshape_id := str(reshape.get("id", ""))
                cards = cards.filter(func(card):
                    return _matches_reshape(card, category, reshape_id) \
                        == bool(reshape.get("present", true)))
            for anomaly_value in effect.get("anomalies", []):
                var anomaly: Dictionary = anomaly_value
                cards = cards.filter(func(card): return card.has_anomaly(
                    str(anomaly.get("category", "")), str(anomaly.get("id", ""))) \
                    == bool(anomaly.get("present", true)))
            if effect.has("can_apply_anomaly") and runtime.ports != null:
                var apply_spec: Dictionary = effect["can_apply_anomaly"]
                cards = cards.filter(func(card):
                    return runtime.ports.can_apply_card_anomaly(
                        card, str(apply_spec.get("category", "")),
                        str(apply_spec.get("id", "")),
                        bool(apply_spec.get("replace_state", false))).get(
                            "allowed", false))
            if bool(effect.get("require_active_permanent_reshape", false)):
                cards = cards.filter(func(card):
                    return not card.return_to_origin_active() and (
                        not card.reshape_origin.is_empty()
                        or card.reshape_enhancement != ""
                        or card.reshape_imprint != ""
                        or not card.reshape_others.is_empty()))
            if bool(effect.get("require_active_any_reshape", false)):
                cards = cards.filter(func(card):
                    return not card.return_to_origin_active() and (
                        not card.reshape_origin.is_empty()
                        or card.reshape_enhancement != ""
                        or card.reshape_imprint != ""
                        or not card.reshape_others.is_empty()
                        or str(card.temporary_reshapes.get("enhancement", "")) != ""
                        or str(card.temporary_reshapes.get("attribute", "")) != ""
                        or not card.temporary_reshapes.get("rank", {}).is_empty()))
            runtime.captures[str(effect.get("capture", "group_cards"))] = cards
            return EffectResultScript.succeeded("捕获组内真气 %d 张" % cards.size())
        "select_random_captured":
            var frozen_key := str(effect.get("result_capture", "selected"))
            if runtime.captures.has(frozen_key):
                return EffectResultScript.succeeded(
                    "复用随机捕获 %d 张" % runtime.captures[frozen_key].size())
            var source: Array = runtime.captures.get(str(effect.get("capture", "")), [])
            var selected: Array = []
            if not source.is_empty() and rng != null:
                selected.append(source[rng.randi_range(0, source.size() - 1)])
            runtime.captures[frozen_key] = selected
            return EffectResultScript.succeeded("随机捕获 %d 张" % selected.size())
        "select_highest_random_captured":
            var frozen_key := str(effect.get("result_capture", "selected"))
            if runtime.captures.has(frozen_key):
                return EffectResultScript.succeeded(
                    "复用随机最高值真气 %d 张" % runtime.captures[frozen_key].size())
            var source: Array = runtime.captures.get(str(effect.get("capture", "")), [])
            var owner = runtime.target if str(effect.get("side", "actor")) == "target" else runtime.actor
            var selected: Array = []
            var maximum := -1
            for card in source:
                maximum = maxi(maximum, runtime.ports.current_effective_qi(owner, card))
            var tied: Array = source.filter(func(card):
                return runtime.ports.current_effective_qi(owner, card) == maximum)
            if not tied.is_empty() and rng != null:
                selected.append(tied[rng.randi_range(0, tied.size() - 1)])
            runtime.captures[frozen_key] = selected
            return EffectResultScript.succeeded("随机选择最高值真气 %d 张" % selected.size())
        "capture_event_cards":
            var events: Array = runtime.captures.get("event", [])
            var cards: Array = []
            if not events.is_empty():
                cards = events[0].get(str(effect.get("field", "event_cards")), []).duplicate()
            runtime.captures[str(effect.get("capture", "event_cards"))] = cards
            return EffectResultScript.succeeded("捕获事件真气 %d 张" % cards.size())
        "capture_value":
            var amount: int = value_resolver.resolve(effect.get("value", 0), runtime)
            runtime.captures[str(effect.get("capture", "value"))] = [{"amount": amount}]
            return EffectResultScript.succeeded("冻结数值 %d" % amount)
        "capture_difference":
            var source: Array = runtime.captures.get(str(effect.get("capture", "")), [])
            var excluded: Array = runtime.captures.get(str(effect.get("exclude_capture", "")), [])
            runtime.captures[str(effect.get("result_capture", "difference"))] = source.filter(
                func(card): return not excluded.has(card))
            return EffectResultScript.succeeded("捕获差集")
        "filter_captured":
            var cards: Array = runtime.captures.get(str(effect.get("capture", "")), []).duplicate()
            var filters: Dictionary = effect.get("filters", {})
            if effect.has("zone"):
                var zone_side = runtime.target \
                    if str(effect.get("side", "actor")) == "target" else runtime.actor
                var zone_cards: Array = runtime.ports.zone_cards(
                    zone_side, str(effect.get("zone", "hand"))) \
                    if runtime.ports != null and zone_side != null else []
                cards = cards.filter(func(card): return zone_cards.has(card))
            if filters.has("anomaly"):
                var anomaly: Dictionary = filters["anomaly"]
                cards = cards.filter(func(card):
                    return card.has_anomaly(
                        str(anomaly.get("category", "")), str(anomaly.get("id", ""))) \
                        == bool(anomaly.get("present", true)))
            for anomaly_value in filters.get("anomalies", []):
                var anomaly: Dictionary = anomaly_value
                cards = cards.filter(func(card):
                    return card.has_anomaly(
                        str(anomaly.get("category", "")), str(anomaly.get("id", ""))) \
                        == bool(anomaly.get("present", true)))
            if filters.has("anomaly_layers_at_least"):
                var layer: Dictionary = filters["anomaly_layers_at_least"]
                cards = cards.filter(func(card):
                    return card.anomaly_layers(
                        str(layer.get("category", "buff")), str(layer.get("id", ""))) \
                        >= int(layer.get("value", 1)))
            if bool(filters.get("explicit_discard_allowed", false)):
                var side = runtime.target if str(effect.get("side", "actor")) == "target" else runtime.actor
                cards = cards.filter(func(card):
                    return runtime.ports.can_explicit_discard(side, card).get("allowed", false))
            runtime.captures[str(effect.get("result_capture", "filtered"))] = cards
            return EffectResultScript.succeeded("过滤冻结集合 %d 张" % cards.size())
        "for_each_captured":
            if runtime.ports == null:
                return EffectResultScript.failed("逐张效果缺少战斗端口")
            var processed := 0
            for card in runtime.captures.get(str(effect.get("capture", "")), []).duplicate():
                var child_context = EffectContextScript.new().configure({
                    "ports": runtime.ports, "actor": runtime.actor, "target": runtime.target,
                    "hand_result": runtime.hand_result, "played_cards": runtime.played_cards,
                    "power": runtime.power, "initial_power": runtime.initial_power,
                    "direct_power_fixed": runtime.direct_power_fixed,
                    "direct_power_percent": runtime.direct_power_percent,
                    "pre_momentum_power": runtime.pre_momentum_power,
                    "momentum_used": runtime.momentum_used,
                    "technique_id": runtime.technique_id, "technique_name": runtime.technique_name,
                    "actual_hand_id": runtime.actual_hand_id, "branch_hand_id": runtime.branch_hand_id,
                    "technique_pool": runtime.technique_pool, "action_token": runtime.action_token,
                    "source_kind": runtime.source_kind, "captures": {"each": [card]},
                    "sequence_book": runtime.sequence_book,
                    "card_identity_policy": runtime.card_identity_policy,
                    "group_snapshot": runtime.group_snapshot,
                })
                var result: Dictionary = runtime.ports.execute_effect_chain(
                    effect.get("effects", []), child_context)
                if result.get("success", false):
                    processed += 1
            return EffectResultScript.succeeded("逐张处理 %d 张" % processed)
        "remove_card_anomaly_from_captured":
            var removed: Array = []
            for card in runtime.captures.get(str(effect.get("capture", "")), []):
                if card.has_anomaly(str(effect.get("category", "")), str(effect.get("anomaly", ""))):
                    var result: Dictionary = runtime.ports.remove_card_anomaly(
                        card, str(effect.get("category", "")),
                        str(effect.get("anomaly", "")), runtime.technique_name, {
                            "source_actor": runtime.actor,
                            "target": runtime.target,
                            "action_token": runtime.action_token,
                            "technique_id": runtime.technique_id,
                            "source_kind": runtime.source_kind,
                        })
                    if result.get("changed", false):
                        removed.append(card)
            runtime.captures[str(effect.get("result_capture", "removed"))] = removed
            return EffectResultScript.succeeded("移除异状 %d 张" % removed.size())
        "gain_battle_experience":
            var gained: int = int(runtime.ports.gain_battle_experience(
                runtime.actor, value_resolver.resolve(effect.get("amount", 0), runtime)))
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [{"gained": gained}]
            return EffectResultScript.succeeded("获得 %d 历练" % gained)
        "generate_temporary_normal_card":
            var source_capture: Array = runtime.captures.get(
                str(effect.get("source_capture", "")), [])
            var contributing: Array = runtime.group_snapshot.get(
                "contributing_cards", [])
            var base_card = source_capture[0] if not source_capture.is_empty() \
                else contributing[0] if not contributing.is_empty() else null
            if base_card == null:
                if effect.has("capture"):
                    runtime.captures[str(effect["capture"])] = []
                return EffectResultScript.succeeded()
            var generated = runtime.ports.generate_temporary_normal_card(
                runtime.actor, base_card, {
                    "rank_mode": str(effect.get("rank_mode", "same_current")),
                    "attribute_mode": str(effect.get("attribute_mode", "same_base")),
                    "add_void": bool(effect.get("add_void", true)),
                })
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [generated] if generated != null else []
            return EffectResultScript.succeeded("生成临时真气" if generated != null else "")
        "repeat_effects":
            if runtime.source_kind == "technique_echo":
                return EffectResultScript.succeeded("回响不递归")
            var count: int = value_resolver.resolve(effect.get("count", 0), runtime)
            var completed := 0
            for index in range(maxi(0, count)):
                var child_context = EffectContextScript.new().configure({
                    "ports": runtime.ports, "actor": runtime.actor, "target": runtime.target,
                    "hand_result": runtime.hand_result, "played_cards": runtime.played_cards,
                    "power": runtime.power, "initial_power": runtime.initial_power,
                    "direct_power_fixed": runtime.direct_power_fixed,
                    "direct_power_percent": runtime.direct_power_percent,
                    "pre_momentum_power": runtime.pre_momentum_power,
                    "momentum_used": runtime.momentum_used,
                    "technique_id": runtime.technique_id,
                    "technique_name": runtime.technique_name,
                    "actual_hand_id": runtime.actual_hand_id,
                    "branch_hand_id": runtime.branch_hand_id,
                    "technique_pool": runtime.technique_pool,
                    "action_token": "%s:echo:%d" % [runtime.action_token, index],
                    "source_kind": "technique_echo", "captures": {},
                    "sequence_book": runtime.sequence_book,
                    "card_identity_policy": runtime.card_identity_policy,
                    "group_snapshot": runtime.group_snapshot,
                })
                var result: Dictionary = runtime.ports.execute_effect_chain(
                    effect.get("effects", []), child_context)
                if not result.get("success", false):
                    return EffectResultScript.failed(str(result.get("reason", "功法回响失败")))
                completed += 1
            return EffectResultScript.succeeded("功法回响%d次" % completed)
    return EffectResultScript.failed("集合处理器不支持此操作")

func _matches_reshape(card, category: String, reshape_id: String) -> bool:
    match category:
        "origin":
            return not card.reshape_origin.is_empty() \
                and (reshape_id == "" or str(card.reshape_origin.get("id", "")) == reshape_id)
        "enhancement":
            return str(card.reshape_enhancement) != "" \
                and (reshape_id == "" or str(card.reshape_enhancement) == reshape_id)
        "imprint":
            return str(card.reshape_imprint) != "" \
                and (reshape_id == "" or str(card.reshape_imprint) == reshape_id)
        "other":
            return not card.reshape_others.is_empty() \
                if reshape_id == "" else card.reshape_others.has(reshape_id)
    return false

func _frozen_rank_component(snapshot: Dictionary, wanted_count: int) -> Array:
    var contributing: Array = snapshot.get("contributing_cards", []).duplicate()
    var counts: Dictionary = {}
    for card in contributing:
        var rank_order := int(snapshot.get("facts_by_id", {}).get(
            str(card.id), {}).get("rank_order_at_freeze", card.current_rank_order()))
        counts[rank_order] = int(counts.get(rank_order, 0)) + 1
    return contributing.filter(func(card):
        var rank_order := int(snapshot.get("facts_by_id", {}).get(
            str(card.id), {}).get("rank_order_at_freeze", card.current_rank_order()))
        return int(counts.get(rank_order, 0)) == wanted_count)

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) in ["for_each_captured", "repeat_effects"]:
        validator.validate_nested_battle_effects(effect.get("effects", []), scope + ".effects")
