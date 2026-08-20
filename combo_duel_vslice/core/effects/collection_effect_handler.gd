class_name CollectionEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
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
        "generate_shared_template_temporary_normal_cards",
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
            var frozen_cards: Array = runtime.captures.get(
                str(effect.get("capture", "")), []).duplicate()
            for card_index in range(frozen_cards.size()):
                var card = frozen_cards[card_index]
                var parent_effect_token: String = runtime.effect_execution_token
                if parent_effect_token == "":
                    parent_effect_token = runtime.technique_execution_token \
                        if runtime.technique_execution_token != "" \
                        else runtime.action_token
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
                    "root_action_token": runtime.root_action_token,
                    "invocation_token": runtime.invocation_token,
                    "caller_technique_id": runtime.caller_technique_id,
                    "slot_instance_id": runtime.slot_instance_id,
                    "technique_execution_token": runtime.technique_execution_token,
                    "effect_execution_scope_token": "%s:for-each:%d:%s" % [
                        parent_effect_token, card_index, str(card.id)],
                    "technique_execution_state": runtime.technique_execution_state,
                    "source_kind": runtime.source_kind,
                    "source_id": runtime.source_id, "source_name": runtime.source_name,
                    "source_instance_key": runtime.source_instance_key,
                    "trigger_mode": runtime.trigger_mode,
                    "round_number": runtime.round_number,
                    "captures": {"each": [card]},
                    "sequence_book": runtime.sequence_book,
                    "card_identity_policy": runtime.card_identity_policy,
                    "group_snapshot": runtime.group_snapshot,
                    "effect_command_limit": runtime.effect_command_limit,
                    "effect_chain_state": runtime.effect_chain_state,
                    "passive_rule_runtime": runtime.passive_rule_runtime,
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
                        str(effect.get("anomaly", "")), runtime.source_name, {
                            "source_actor": runtime.actor,
                            "target": runtime.target,
                            "action_token": runtime.action_token,
                            "technique_id": runtime.technique_id,
                            "source_kind": runtime.source_kind,
                            "source_id": runtime.source_id,
                            "source_name": runtime.source_name,
                            "source_instance_key": runtime.source_instance_key,
                            "trigger_mode": runtime.trigger_mode,
                        })
                    if result.get("changed", false):
                        removed.append(card)
            runtime.captures[str(effect.get("result_capture", "removed"))] = removed
            return EffectResultScript.succeeded("移除异状 %d 张" % removed.size())
        "gain_battle_experience":
            var change: Dictionary = runtime.ports.gain_battle_experience(
                runtime.actor,
                value_resolver.resolve(effect.get("amount", 0), runtime), {
                    "action_token": runtime.action_token,
                    "root_execution_token": runtime.action_token,
                    "source_kind": runtime.source_kind,
                    "source_id": runtime.source_id,
                    "source_name": runtime.source_name,
                    "source_instance_key": runtime.source_instance_key,
                    "trigger_mode": runtime.trigger_mode,
                    "effect_execution_token": runtime.effect_execution_token,
                    "experience_response_ancestry": runtime.effect_chain_state.get(
                        "experience_response_ancestry", []).duplicate(),
                })
            if not change.get("success", false):
                return EffectResultScript.failed(str(change.get(
                    "reason", "战斗历练修改失败")))
            var gained := int(change.get("actual_delta", 0))
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
            var generation_options: Dictionary = runtime.source_metadata()
            generation_options.merge({
                    "rank_mode": str(effect.get("rank_mode", "same_current")),
                    "attribute_mode": str(effect.get("attribute_mode", "same_base")),
                    "add_void": bool(effect.get("add_void", true)),
                    "clone_source": bool(effect.get("clone_source", false)),
                    "action_token": runtime.action_token,
                }, true)
            var generated = runtime.ports.generate_temporary_normal_card(
                runtime.actor, base_card, generation_options)
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [generated] if generated != null else []
            return EffectResultScript.succeeded("生成临时真气" if generated != null else "")
        "generate_shared_template_temporary_normal_cards":
            if runtime.ports == null:
                return EffectResultScript.failed("批量生成临时真气缺少战斗端口")
            var generation_options: Dictionary = runtime.source_metadata()
            generation_options.merge({
                "destination": str(effect.get("destination", "hand")),
                "shuffle_destination": bool(effect.get(
                    "shuffle_destination", false)),
                "add_void": bool(effect.get("add_void", true)),
                "origin_id": str(effect.get("origin_id", "")),
                "origin_payload": effect.get(
                    "origin_payload", {}).duplicate(true),
                "action_token": runtime.action_token,
            }, true)
            var generated: Dictionary = (
                runtime.ports
                .generate_shared_template_temporary_normal_cards(
                    runtime.actor,
                    value_resolver.resolve(effect.get("count", 0), runtime),
                    generation_options))
            if not generated.get("success", false):
                return EffectResultScript.failed(str(generated.get(
                    "reason", "批量生成临时真气失败")))
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = generated.get(
                    "cards", []).duplicate()
            return EffectResultScript.succeeded(
                "生成同模板临时真气 %d 张" % int(generated.get("count", 0)))
        "repeat_effects":
            if runtime.trigger_mode == "echo":
                return EffectResultScript.succeeded("回响不递归")
            var count: int = value_resolver.resolve(effect.get("count", 0), runtime)
            if runtime.source_kind != "technique":
                return EffectResultScript.failed("回响缺少正式功法执行上下文")
            # 仅保留给直接 EffectExecutor 内容测试的低层兼容路径；正式战斗入口
            # 都显式提供 execution token，并走下方的推进前计划队列。
            if runtime.technique_execution_token == "":
                return _execute_legacy_echoes(
                    runtime, maxi(0, count), effect.get("effects", []))
            var planned: Dictionary = runtime.ports.append_current_technique_echo(
                runtime, maxi(0, count), effect.get("effects", []))
            if not planned.get("success", false):
                return EffectResultScript.failed(str(planned.get(
                    "reason", "功法回响计划写入失败")))
            return EffectResultScript.succeeded("登记功法回响%d次" % maxi(0, count))
    return EffectResultScript.failed("集合处理器不支持此操作")

func _execute_legacy_echoes(runtime, count: int, effects: Array):
    var completed := 0
    for index in range(count):
        var child_context = EffectContextScript.new().configure({
            "ports": runtime.ports, "actor": runtime.actor,
            "target": runtime.target, "hand_result": runtime.hand_result,
            "played_cards": runtime.played_cards, "power": runtime.power,
            "initial_power": runtime.initial_power,
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
            "root_action_token": runtime.root_action_token,
            "source_kind": runtime.source_kind,
            "source_id": runtime.source_id,
            "source_name": runtime.source_name,
            "source_instance_key": runtime.source_instance_key,
            "trigger_mode": "echo", "captures": {},
            "sequence_book": runtime.sequence_book,
            "card_identity_policy": runtime.card_identity_policy,
            "group_snapshot": runtime.group_snapshot,
        })
        var result: Dictionary = runtime.ports.execute_effect_chain(
            effects, child_context)
        if not result.get("success", false):
            return EffectResultScript.failed(str(result.get(
                "reason", result.get("detail", "功法回响失败"))))
        completed += 1
    return EffectResultScript.succeeded("功法回响%d次" % completed)

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
    if str(effect.get("op", "")) == \
            "generate_shared_template_temporary_normal_cards":
        if effect.get("count") is Dictionary:
            validator.validate_amount_spec(effect["count"], scope + ".count")
        else:
            validator.validate_positive_integer(
                effect.get("count"), scope + ".count", "count")
        if str(effect.get("destination", "hand")) not in [
                "hand", "draw_pile", "staging", "discard_pile"]:
            validator.report_error(scope + ".destination", "引用未知目标牌区")
        for field in ["shuffle_destination", "add_void"]:
            if effect.has(field) and not effect[field] is bool:
                validator.report_error(scope + "." + field, "必须是布尔值")
        if effect.has("origin_id") \
                and (not effect["origin_id"] is String \
                    or str(effect["origin_id"]) == ""):
            validator.report_error(scope + ".origin_id", "必须是非空字符串")
        if effect.has("origin_payload") \
                and not effect["origin_payload"] is Dictionary:
            validator.report_error(scope + ".origin_payload", "必须是对象")
        if effect.has("capture") and str(effect.get("capture", "")) == "":
            validator.report_error(scope + ".capture", "必须是非空字符串")
