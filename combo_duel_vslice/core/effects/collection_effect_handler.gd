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
            runtime.captures[str(effect.get("capture", "group_cards"))] = cards
            return EffectResultScript.succeeded("捕获组内真气 %d 张" % cards.size())
        "select_random_captured":
            var source: Array = runtime.captures.get(str(effect.get("capture", "")), [])
            var selected: Array = []
            if not source.is_empty() and rng != null:
                selected.append(source[rng.randi_range(0, source.size() - 1)])
            runtime.captures[str(effect.get("result_capture", "selected"))] = selected
            return EffectResultScript.succeeded("随机捕获 %d 张" % selected.size())
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
                    var value = card.remove_anomaly(
                        str(effect.get("category", "")), str(effect.get("anomaly", "")))
                    if value != null:
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
            var base_card = runtime.group_snapshot.get("contributing_cards", [null])[0]
            if base_card == null:
                return EffectResultScript.succeeded()
            var generated = runtime.ports.generate_temporary_normal_card(
                runtime.actor, str(base_card.attribute))
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [generated] if generated != null else []
            return EffectResultScript.succeeded("生成临时真气" if generated != null else "")
    return EffectResultScript.failed("集合处理器不支持此操作")

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) == "for_each_captured":
        validator.validate_nested_battle_effects(effect.get("effects", []), scope + ".effects")
