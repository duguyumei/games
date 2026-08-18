class_name BattleSide
extends RefCounted

const DamageResolverScript = preload("res://core/damage_resolver.gd")
const CardZoneServiceScript = preload("res://core/card_zone_service.gd")
const InnerSkillCapacityPolicyScript = preload(
    "res://core/passives/inner_skill_capacity_policy.gd")
const RunPassiveCounterStoreScript = preload(
    "res://core/passives/run_passive_counter_store.gd")
const BattlePassiveCounterStoreScript = preload(
    "res://core/passives/battle_passive_counter_store.gd")
const SourceMarkerStoreScript = preload("res://core/source_marker_store.gd")
const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")
const SourceContributedStatServiceScript = preload(
    "res://core/source_contributed_stat_service.gd")
const ConditionSpecRegistryScript = preload(
    "res://core/specs/condition_spec_registry.gd")
const TechniqueLoadoutPolicyScript = preload(
    "res://core/technique_loadout_policy.gd")
const InsightGrowthServiceScript = preload(
    "res://core/insight_growth_service.gd")
const PassiveIntPolicyResolverScript = preload(
    "res://core/passives/passive_int_policy_resolver.gd")

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

var name: String
var owner_id: String
var max_life: int = 100
var base_max_life: int = 100
var life: int = 100
var defense: int = 0
var experience: int = 0
var hand_limit: int = 8
var base_hand_limit_modifier: int = 0
var direct_power_fixed: int = 0
var direct_power_percent: int = 0
var momentum_value: int = 0
var same_qi_value: int = 0
var last_successful_technique_hand_id: String = ""
var momentum_write_receipts: Array = []
var momentum_preservation_sources: Array = []
var current_reflection_percent: int = 0
var current_reflection_source_token: String = ""
## 限时战斗来源是当前反震、格挡、邀战与下一功法修正的事实源。
## 聚合字段 current_reflection_percent 仅供旧调用方与界面读取。
var reflection_sources: Array = []
var reflection_true_damage_sources: Array = []
var block_sources: Array = []
var challenge_records: Array = []
var pending_power_fixed_sources: Array = []
var defense_retention_sources: Array = []
var poison_damage_modifier_sources: Array = []
var poison_damage_modifier_receipts: Dictionary = {}
var _combat_source_serial: int = 0
var draw_pile: Array = []
var hand: Array = []
var staging: Array = []
var discard_pile: Array = []
var temporarily_removed_cards: Array = []
## 真气代价支付的幂等回执随 BattleSide 运行时快照回滚，不进入局外成长状态。
var qi_consumption_receipts: Dictionary = {}
## 可提交本局状态在战斗内使用工作副本；正式结算前不写回 GrowthInventory。
var learned_inner_skill_ids: Array[String] = []
var equipped_inner_skill_ids: Array[String] = []
var item_ids: Array[String] = []
var technique_slot_index: int = 0
var forgotten_inner_skill_count: int = 0
var consumable_ids: Array[String] = []
var consumable_limit: int = 3
var consumable_use_sequence: int = 0
var last_recallable_consumable_id: String = ""
var used_unique_consumable_ids: Array[String] = []
var hand_proficiency_fixed: Dictionary = {}
var hand_technique_progression: Dictionary = {}
var hand_technique_progression_active: bool = false
var hand_technique_multiplier_modifiers: Dictionary = {}
var owned_technique_ids: Array[String] = []
var permanently_removed_card_ids: Array[String] = []
var card_state_lifecycle
var status_system
var card_zone_service := CardZoneServiceScript.new()
var passive_rule_runtime = null
var technique_loadout_policy = TechniqueLoadoutPolicyScript.new()
## 本局持久状态在战斗内使用独立副本；战后只通过绝对快照回写。
var passive_counter_store = null
## 只存在于当前战斗，不进入 RunProgressSnapshot 或存档。
var battle_passive_counter_store = null
var source_marker_store = SourceMarkerStoreScript.new()
var source_marker_address_resolver = SourceMarkerAddressResolverScript.new()
var source_contributed_stat_service = SourceContributedStatServiceScript.new()
var technique_sequence_book = null
var _battle_effect_ports_ref: WeakRef
var condition_spec_registry = ConditionSpecRegistryScript.new()
var battle_rule_query_service = null
var hand_recognition_policy = null
var card_identity_policy = null
var battle_permission_service = null
var last_hand_limit_query_result: Dictionary = {}
var last_same_qi_capacity_query_result: Dictionary = {}

func _init(side_name: String = "", stable_owner_id: String = "") -> void:
    name = side_name
    owner_id = stable_owner_id if stable_owner_id != "" else side_name

func use_card_state_lifecycle(lifecycle) -> void:
    card_state_lifecycle = lifecycle
    card_zone_service.use_card_state_lifecycle(lifecycle)

func use_status_system(system) -> void:
    status_system = system
    card_zone_service.use_status_system(system)

func use_card_reshape_runtime(runtime) -> void:
    card_zone_service.use_card_reshape_runtime(runtime)

func use_committed_event_service(service, round_reader: Callable = Callable()) -> void:
    card_zone_service.use_committed_event_service(service, round_reader)

func use_passive_rule_runtime(runtime) -> void:
    passive_rule_runtime = runtime
    var catalog = (
        runtime.source_resolver._catalog
        if runtime != null and runtime.source_resolver != null
        else null)
    passive_counter_store = RunPassiveCounterStoreScript.new(catalog)
    battle_passive_counter_store = BattlePassiveCounterStoreScript.new()
    technique_loadout_policy = TechniqueLoadoutPolicyScript.new(
        catalog,
        PassiveIntPolicyResolverScript.new(runtime) if runtime != null else null)

func use_battle_rule_query_service(service) -> void:
    battle_rule_query_service = service

func use_card_policies(recognition_policy, identity_policy) -> void:
    hand_recognition_policy = recognition_policy
    card_identity_policy = identity_policy
    for card in all_zone_cards():
        if card.has_method("configure_identity_policy"):
            card.configure_identity_policy(identity_policy)

func use_battle_permission_service(service) -> void:
    battle_permission_service = service
    card_zone_service.use_battle_permission_service(service)
    for card in all_zone_cards():
        if card.has_method("configure_battle_permission_service"):
            card.configure_battle_permission_service(service)

func use_technique_sequence_book(book) -> void:
    technique_sequence_book = book

func use_battle_effect_ports(ports) -> void:
    _battle_effect_ports_ref = weakref(ports) if ports != null else null

func charging_technique_instances(public_only: bool = false) -> Array:
    var ports = _battle_effect_ports_ref.get_ref() \
        if _battle_effect_ports_ref != null else null
    if ports == null:
        return []
    return ports.charging_technique_instances(self, public_only)

func reset(
        cards: Array,
        rng: RandomNumberGenerator,
        shuffle_cards: bool = true,
        restore_life: bool = true) -> void:
    if restore_life:
        life = max_life
    defense = 0
    experience = 0
    hand_limit = 8
    base_hand_limit_modifier = 0
    direct_power_fixed = 0
    direct_power_percent = 0
    momentum_value = 0
    same_qi_value = 0
    last_successful_technique_hand_id = ""
    momentum_write_receipts.clear()
    momentum_preservation_sources.clear()
    current_reflection_percent = 0
    current_reflection_source_token = ""
    reflection_sources.clear()
    reflection_true_damage_sources.clear()
    block_sources.clear()
    challenge_records.clear()
    pending_power_fixed_sources.clear()
    defense_retention_sources.clear()
    poison_damage_modifier_sources.clear()
    poison_damage_modifier_receipts.clear()
    qi_consumption_receipts.clear()
    _combat_source_serial = 0
    learned_inner_skill_ids.clear()
    equipped_inner_skill_ids.clear()
    item_ids.clear()
    technique_slot_index = 0
    forgotten_inner_skill_count = 0
    consumable_ids.clear()
    consumable_limit = 3
    consumable_use_sequence = 0
    last_recallable_consumable_id = ""
    used_unique_consumable_ids.clear()
    hand_proficiency_fixed.clear()
    hand_technique_progression.clear()
    hand_technique_progression_active = false
    hand_technique_multiplier_modifiers.clear()
    owned_technique_ids.clear()
    permanently_removed_card_ids.clear()
    if passive_counter_store != null:
        passive_counter_store.clear()
    if battle_passive_counter_store != null:
        battle_passive_counter_store.clear()
    source_marker_store.clear_scope("battle")
    source_marker_store.clear_scope("run")
    last_hand_limit_query_result.clear()
    last_same_qi_capacity_query_result.clear()
    card_zone_service.reset_zones(self, cards, rng, shuffle_cards)

func active_source_content_ids() -> Dictionary:
    var active := {
        "technique": {},
        "inner_skill": {},
        "item": {},
    }
    for progression_value in hand_technique_progression.values():
        var progression: Dictionary = progression_value
        for technique_id_value in progression.get("sequence", []):
            active["technique"][str(technique_id_value)] = true
    for inner_skill_id in equipped_inner_skill_ids:
        active["inner_skill"][str(inner_skill_id)] = true
    for item_id in item_ids:
        var content_id := str(item_id)
        if _item_source_contribution_active(content_id):
            active["item"][content_id] = true
    return active

## 兼容旧查询调用方；新代码应使用 active_source_content_ids()，其中
## source_kind 分桶防止同名物品/内功/功法互相激活。
func equipped_source_content_ids() -> Dictionary:
    var flattened: Dictionary = {}
    for bucket_value in active_source_content_ids().values():
        if bucket_value is Dictionary:
            for content_id in bucket_value:
                flattened[str(content_id)] = true
    return flattened

func _item_source_contribution_active(content_id: String) -> bool:
    if passive_rule_runtime == null:
        return true
    if not passive_rule_runtime.has_method("is_source_identity_active"):
        return true
    var key := source_marker_address_resolver.item_source_instance_key(
        self, content_id)
    return passive_rule_runtime.is_source_identity_active(
        "item", content_id, key, "source_contribution", self)

func recalculate_effective_max_life() -> int:
    return source_contributed_stat_service.apply_to_side(
        self, active_source_content_ids())

func grant_poison_damage_modifier(
        fixed: int,
        percent: int,
        remaining_hits: int,
        expiry: String,
        source_token: String,
        is_public: bool = true,
        remaining_rounds: int = 1,
        source_metadata: Dictionary = {}) -> Dictionary:
    _combat_source_serial += 1
    var resolved_token := source_token if source_token != "" \
        else "poison-modifier:%s:%06d" % [owner_id, _combat_source_serial]
    var source := {
        "source_token": resolved_token,
        "fixed": fixed,
        "percent": percent,
        "remaining_hits": remaining_hits,
        "expiry": expiry,
        "remaining_rounds": remaining_rounds,
        "affected_side": owner_id,
        "public": is_public,
        "insertion_serial": _combat_source_serial,
    }
    source.merge(source_metadata, false)
    poison_damage_modifier_sources.append(source)
    return source.duplicate(true)

func freeze_poison_damage_modifiers(
        base_amount: int,
        receipt_token: String = "",
        additional_fixed: int = 0) -> Dictionary:
    if receipt_token != "" and poison_damage_modifier_receipts.has(
            receipt_token):
        var reused: Dictionary = poison_damage_modifier_receipts[
            receipt_token].duplicate(true)
        reused["reused"] = true
        return reused
    var fixed_total := additional_fixed
    var percent_total := 0
    var applicable_tokens: Array[String] = []
    poison_damage_modifier_sources.sort_custom(func(left, right):
        return int(left.get("insertion_serial", 0)) < int(right.get("insertion_serial", 0)))
    for source in poison_damage_modifier_sources:
        if int(source.get("remaining_hits", -1)) == 0:
            continue
        fixed_total += int(source.get("fixed", 0))
        percent_total += int(source.get("percent", 0))
        if int(source.get("remaining_hits", -1)) > 0:
            applicable_tokens.append(str(source.get("source_token", "")))
    var after_fixed := maxi(0, base_amount + fixed_total)
    var final_amount := maxi(0, int(floor(
        after_fixed * (100 + percent_total) / 100.0)))
    var result := {
        "base": base_amount, "fixed": fixed_total,
        "after_fixed": after_fixed, "percent": percent_total,
        "final_amount": final_amount,
        "receipt_token": receipt_token,
        "applicable_source_tokens": applicable_tokens,
        "consumed_source_tokens": [],
        "committed": false, "reused": false,
    }
    if receipt_token != "":
        poison_damage_modifier_receipts[receipt_token] = result.duplicate(true)
    return result

func active_technique_marker_sum(filters: Dictionary = {}) -> int:
    var technique_filters := filters.duplicate(true)
    technique_filters["source_kind"] = "technique"
    return active_source_marker_sum(technique_filters)

func active_source_marker_sum(filters: Dictionary = {}) -> int:
    if source_marker_store == null:
        return 0
    var entries: Array = source_marker_store.entries(filters)
    var active := active_source_content_ids()
    var active_slot_ids: Dictionary = {}
    if technique_sequence_book != null:
        for slot_value in technique_sequence_book.find_slots({}):
            active_slot_ids[str(slot_value.get("slot_instance_id", ""))] = true
    var total := 0
    for entry_value in entries:
        var entry: Dictionary = entry_value
        var source_kind := str(entry.get("source_kind", ""))
        if source_kind == "technique" and technique_sequence_book != null:
            if not active_slot_ids.has(str(entry.get("source_instance_key", ""))):
                continue
        else:
            var bucket = active.get(source_kind)
            if not bucket is Dictionary or not bucket.has(str(
                    entry.get("content_id", ""))):
                continue
        if source_kind in ["technique", "inner_skill", "item"]:
            total += int(entry.get("value", 0))
    return total

func commit_poison_damage_modifier_receipt(receipt: Dictionary) -> Dictionary:
    var receipt_token := str(receipt.get("receipt_token", ""))
    if receipt_token != "" and poison_damage_modifier_receipts.has(receipt_token) \
            and bool(poison_damage_modifier_receipts[receipt_token].get(
                "committed", false)):
        var reused: Dictionary = poison_damage_modifier_receipts[
            receipt_token].duplicate(true)
        reused["reused"] = true
        return reused
    var consumed_tokens: Array[String] = []
    for source_token_value in receipt.get("applicable_source_tokens", []):
        var source_token := str(source_token_value)
        for source in poison_damage_modifier_sources:
            if str(source.get("source_token", "")) != source_token \
                    or int(source.get("remaining_hits", -1)) <= 0:
                continue
            source["remaining_hits"] = int(source["remaining_hits"]) - 1
            consumed_tokens.append(source_token)
            break
    poison_damage_modifier_sources = poison_damage_modifier_sources.filter(
        func(source): return int(source.get("remaining_hits", -1)) != 0)
    var committed := receipt.duplicate(true)
    committed["committed"] = true
    committed["reused"] = false
    committed["consumed_source_tokens"] = consumed_tokens
    if receipt_token != "":
        poison_damage_modifier_receipts[receipt_token] = committed.duplicate(true)
    return committed

func resolve_poison_damage_modifiers(base_amount: int) -> Dictionary:
    return freeze_poison_damage_modifiers(base_amount)

func public_poison_damage_modifier_sources() -> Array:
    return poison_damage_modifier_sources.filter(
        func(source): return bool(source.get("public", true))).map(
            func(source): return source.duplicate(true))

func replace_deck(cards: Array, rng: RandomNumberGenerator, shuffle_cards: bool = true) -> void:
    card_zone_service.reset_zones(self, cards, rng, shuffle_cards)

func all_zone_cards() -> Array:
    var cards: Array = []
    for zone in [draw_pile, hand, staging, discard_pile]:
        cards.append_array(zone)
    return cards

func all_cards_for_run_sync() -> Array:
    var cards := all_zone_cards()
    cards.append_array(temporarily_removed_cards)
    return cards

func mark_permanently_removed(instance_id: String) -> void:
    if instance_id != "" and not permanently_removed_card_ids.has(instance_id):
        permanently_removed_card_ids.append(instance_id)

func _shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
    card_zone_service.shuffle(cards, rng)

func draw(
        count: int,
        draw_reason: String = "rule_draw",
        source_metadata: Dictionary = {}) -> Array:
    return card_zone_service.draw(self, count, draw_reason, source_metadata)

func draw_to_limit(
        draw_reason: String = "normal_draw",
        source_metadata: Dictionary = {}) -> Array:
    var limit := current_hand_limit()
    if limit < 1:
        return []
    var drawn: Array = []
    while occupied_meridian_count() < limit and not draw_pile.is_empty():
        var step := draw(1, draw_reason, source_metadata)
        if step.is_empty():
            break
        drawn.append_array(step)
    return drawn

func actual_hand_count() -> int:
    return hand.size()

func occupied_meridian_count() -> int:
    var count := 0
    for card in hand:
        if not card.has_anomaly("mark", "meridian"):
            count += 1
    return count

func poison_totals() -> Dictionary:
    var result := {
        "hand_count": 0, "hand_amount": 0,
        "draw_pile_count": 0, "draw_pile_amount": 0,
        "total_count": 0, "total_amount": 0,
    }
    for zone_entry in [["hand", hand], ["draw_pile", draw_pile]]:
        var zone_name: String = zone_entry[0]
        for card in zone_entry[1]:
            if not card.is_card_kind("normal") or not card.has_anomaly("state", "poison"):
                continue
            result["%s_count" % zone_name] += 1
            if battle_rule_query_service != null:
                var query = battle_rule_query_service.resolve_effective_qi(
                    self, card, {
                        "actor": self,
                        "purpose": "effect_value",
                        "evaluation_mode": "runtime",
                        "cards": zone_entry[1],
                        "participating_card_ids": [],
                        "source_kind": "battle_state",
                    })
                if query.success:
                    result["%s_amount" % zone_name] += int(query.effective_value)
                else:
                    battle_rule_query_service.report_failure(
                        query, "battle_side_poison_totals")
            else:
                result["%s_amount" % zone_name] += card.effective_qi_value()
    result["total_count"] = int(result["hand_count"]) + int(result["draw_pile_count"])
    result["total_amount"] = int(result["hand_amount"]) + int(result["draw_pile_amount"])
    return result

func current_hand_limit() -> int:
    var result := effective_hand_limit_result()
    if not result.get("success", false):
        return 0
    return int(result["effective_value"])

func base_hand_limit() -> int:
    return maxi(1, hand_limit + base_hand_limit_modifier)

func effective_hand_limit_result() -> Dictionary:
    var base_value := base_hand_limit()
    if battle_rule_query_service == null:
        last_hand_limit_query_result = {
            "success": true, "base_value": base_value,
            "effective_value": base_value, "source_breakdown": [],
            "fingerprint": "", "errors": [],
        }
        return last_hand_limit_query_result.duplicate(true)
    var resolved = battle_rule_query_service.resolve_values({
        "hook": "hand_limit_query",
        "owner": self,
        "actor": self,
        "subject_kind": "battle_side",
        "subject_id": owner_id,
        "base_value": base_value,
        "metadata": {"base_hand_limit": base_value},
    })
    last_hand_limit_query_result = resolved.to_dict()
    if not resolved.success:
        battle_rule_query_service.report_failure(resolved, "hand_limit")
        return last_hand_limit_query_result.duplicate(true)
    last_hand_limit_query_result["effective_value"] = maxi(
        1, int(last_hand_limit_query_result["effective_value"]))
    return last_hand_limit_query_result.duplicate(true)

func effective_same_qi_capacity_result(context: Dictionary = {}) -> Dictionary:
    const BASE_CAPACITY := 5
    if battle_rule_query_service == null:
        last_same_qi_capacity_query_result = {
            "success": true, "base_value": BASE_CAPACITY,
            "effective_value": BASE_CAPACITY, "source_breakdown": [],
            "fingerprint": "", "errors": [],
        }
        return last_same_qi_capacity_query_result.duplicate(true)
    var resolved = battle_rule_query_service.resolve_values({
        "hook": "same_qi_capacity_query",
        "owner": self, "actor": self,
        "target": context.get("target"),
        "subject_kind": "battle_side",
        "subject_id": owner_id,
        "base_value": BASE_CAPACITY,
        "round_number": int(context.get("round_number", 0)),
        "action_token": str(context.get("action_token", "")),
        "source_kind": str(context.get("source_kind", "same_qi_capacity")),
        "metadata": context.get("metadata", {}).duplicate(true),
    })
    last_same_qi_capacity_query_result = resolved.to_dict()
    if not resolved.success:
        battle_rule_query_service.report_failure(resolved, "same_qi_capacity")
        return last_same_qi_capacity_query_result.duplicate(true)
    last_same_qi_capacity_query_result["effective_value"] = maxi(
        1, int(last_same_qi_capacity_query_result["effective_value"]))
    return last_same_qi_capacity_query_result.duplicate(true)

func capture_passive_query_state() -> Dictionary:
    var card_states: Dictionary = {}
    for card in all_cards_for_run_sync():
        card_states[str(card.id)] = {
            "id": str(card.id),
            "definition_id": str(card.definition_id),
            "rank_name": str(card.rank_name),
            "rank_order": int(card.rank_order),
            "qi_value": int(card.qi_value),
            "attribute": str(card.attribute),
            "attribute_name": str(card.attribute_name),
            "is_true_qi": bool(card.is_true_qi),
            "reshape_origin": card.reshape_origin.duplicate(true),
            "reshape_enhancement": str(card.reshape_enhancement),
            "reshape_imprint": str(card.reshape_imprint),
            "reshape_others": card.reshape_others.duplicate(true),
            "anomalies": card.anomalies.duplicate(true),
            "temporary_reshapes": card.temporary_reshapes.duplicate(true),
            "origin_base_identity": card.origin_base_identity.duplicate(true),
            "original_owner_id": str(card.original_owner_id),
            "temporary_card": bool(card.temporary_card),
            "reshape_rule_service": card.reshape_rule_service,
        }
    var status_state: Dictionary = {}
    if status_system != null:
        status_state = status_system.capture_runtime_state()
    return {
        "max_life": max_life,
        "base_max_life": base_max_life,
        "life": life, "defense": defense, "experience": experience,
        "hand_limit": hand_limit,
        "base_hand_limit_modifier": base_hand_limit_modifier,
        "direct_power_fixed": direct_power_fixed,
        "direct_power_percent": direct_power_percent,
        "momentum_value": momentum_value,
        "same_qi_value": same_qi_value,
        "last_successful_technique_hand_id": last_successful_technique_hand_id,
        "momentum_write_receipts": momentum_write_receipts.duplicate(true),
        "momentum_preservation_sources": momentum_preservation_sources.duplicate(true),
        "current_reflection_percent": current_reflection_percent,
        "current_reflection_source_token": current_reflection_source_token,
        "reflection_sources": reflection_sources.duplicate(true),
        "reflection_true_damage_sources": reflection_true_damage_sources.duplicate(true),
        "block_sources": block_sources.duplicate(true),
        "challenge_records": challenge_records.duplicate(true),
        "pending_power_fixed_sources": pending_power_fixed_sources.duplicate(true),
        "defense_retention_sources": defense_retention_sources.duplicate(true),
        "poison_damage_modifier_sources": (
            poison_damage_modifier_sources.duplicate(true)),
        "poison_damage_modifier_receipts": (
            poison_damage_modifier_receipts.duplicate(true)),
        "combat_source_serial": _combat_source_serial,
        "draw_ids": draw_pile.map(func(card): return str(card.id)),
        "hand_ids": hand.map(func(card): return str(card.id)),
        "staging_ids": staging.map(func(card): return str(card.id)),
        "discard_ids": discard_pile.map(func(card): return str(card.id)),
        "draw_cards": draw_pile.duplicate(),
        "hand_cards": hand.duplicate(),
        "staging_cards": staging.duplicate(),
        "discard_cards": discard_pile.duplicate(),
        "temporarily_removed_cards": temporarily_removed_cards.duplicate(),
        "qi_consumption_receipts": qi_consumption_receipts.duplicate(true),
        "learned_inner_skill_ids": learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(),
        "item_ids": item_ids.duplicate(),
        "technique_slot_index": technique_slot_index,
        "forgotten_inner_skill_count": forgotten_inner_skill_count,
        "consumable_ids": consumable_ids.duplicate(),
        "consumable_limit": consumable_limit,
        "consumable_use_sequence": consumable_use_sequence,
        "last_recallable_consumable_id": last_recallable_consumable_id,
        "used_unique_consumable_ids": used_unique_consumable_ids.duplicate(),
        "hand_proficiency_fixed": hand_proficiency_fixed.duplicate(true),
        "hand_technique_progression": hand_technique_progression.duplicate(true),
        "hand_technique_progression_active": hand_technique_progression_active,
        "hand_technique_multiplier_modifiers": (
            hand_technique_multiplier_modifiers.duplicate(true)),
        "owned_technique_ids": owned_technique_ids.duplicate(),
        "permanently_removed_card_ids": permanently_removed_card_ids.duplicate(),
        "card_states": card_states,
        "status_state": status_state,
        "persistent_counters": passive_counter_store.capture_state() \
            if passive_counter_store != null else {},
        "battle_counters": battle_passive_counter_store.capture_state() \
            if battle_passive_counter_store != null else {},
        "source_marker_state": source_marker_store.snapshot(),
        "last_same_qi_capacity_query_result": (
            last_same_qi_capacity_query_result.duplicate(true)),
        "last_hand_limit_query_result": last_hand_limit_query_result.duplicate(true),
        "technique_sequence_state": technique_sequence_book.snapshot() \
            if technique_sequence_book != null else {},
    }

func replace_passive_query_state(state: Dictionary) -> void:
    max_life = int(state.get("max_life", max_life))
    base_max_life = int(state.get("base_max_life", base_max_life))
    life = int(state.get("life", life))
    defense = int(state.get("defense", defense))
    experience = int(state.get("experience", experience))
    hand_limit = int(state.get("hand_limit", hand_limit))
    base_hand_limit_modifier = int(state.get("base_hand_limit_modifier", base_hand_limit_modifier))
    direct_power_fixed = int(state.get("direct_power_fixed", direct_power_fixed))
    direct_power_percent = int(state.get("direct_power_percent", direct_power_percent))
    momentum_value = int(state.get("momentum_value", momentum_value))
    same_qi_value = int(state.get("same_qi_value", same_qi_value))
    momentum_write_receipts.assign(state.get(
        "momentum_write_receipts", momentum_write_receipts))
    momentum_preservation_sources.assign(state.get(
        "momentum_preservation_sources", momentum_preservation_sources))
    last_same_qi_capacity_query_result = state.get(
        "last_same_qi_capacity_query_result",
        last_same_qi_capacity_query_result).duplicate(true)
    last_hand_limit_query_result = state.get(
        "last_hand_limit_query_result",
        last_hand_limit_query_result).duplicate(true)
    last_successful_technique_hand_id = str(state.get(
        "last_successful_technique_hand_id", last_successful_technique_hand_id))
    current_reflection_percent = int(state.get(
        "current_reflection_percent", current_reflection_percent))
    current_reflection_source_token = str(state.get(
        "current_reflection_source_token", current_reflection_source_token))
    reflection_sources.assign(state.get("reflection_sources", reflection_sources))
    reflection_true_damage_sources.assign(state.get(
        "reflection_true_damage_sources", reflection_true_damage_sources))
    block_sources.assign(state.get("block_sources", block_sources))
    challenge_records.assign(state.get("challenge_records", challenge_records))
    pending_power_fixed_sources.assign(state.get(
        "pending_power_fixed_sources", pending_power_fixed_sources))
    defense_retention_sources.assign(state.get(
        "defense_retention_sources", defense_retention_sources))
    poison_damage_modifier_sources.assign(state.get(
        "poison_damage_modifier_sources", poison_damage_modifier_sources))
    poison_damage_modifier_receipts = state.get(
        "poison_damage_modifier_receipts",
        poison_damage_modifier_receipts).duplicate(true)
    _combat_source_serial = int(state.get(
        "combat_source_serial", _combat_source_serial))
    _refresh_reflection_aggregate()
    draw_pile.assign(state.get("draw_cards", draw_pile))
    hand.assign(state.get("hand_cards", hand))
    staging.assign(state.get("staging_cards", staging))
    discard_pile.assign(state.get("discard_cards", discard_pile))
    temporarily_removed_cards.assign(state.get(
        "temporarily_removed_cards", temporarily_removed_cards))
    qi_consumption_receipts = state.get(
        "qi_consumption_receipts", qi_consumption_receipts).duplicate(true)
    learned_inner_skill_ids.assign(state.get(
        "learned_inner_skill_ids", learned_inner_skill_ids))
    equipped_inner_skill_ids.assign(state.get(
        "equipped_inner_skill_ids", equipped_inner_skill_ids))
    item_ids.assign(state.get("item_ids", item_ids))
    technique_slot_index = int(state.get("technique_slot_index", technique_slot_index))
    forgotten_inner_skill_count = int(state.get(
        "forgotten_inner_skill_count", forgotten_inner_skill_count))
    consumable_ids.assign(state.get("consumable_ids", consumable_ids))
    consumable_limit = int(state.get("consumable_limit", consumable_limit))
    consumable_use_sequence = int(state.get(
        "consumable_use_sequence", consumable_use_sequence))
    last_recallable_consumable_id = str(state.get(
        "last_recallable_consumable_id", last_recallable_consumable_id))
    used_unique_consumable_ids.assign(state.get(
        "used_unique_consumable_ids", used_unique_consumable_ids))
    hand_proficiency_fixed = state.get(
        "hand_proficiency_fixed", hand_proficiency_fixed).duplicate(true)
    hand_technique_progression = state.get(
        "hand_technique_progression", hand_technique_progression).duplicate(true)
    hand_technique_progression_active = bool(state.get(
        "hand_technique_progression_active", hand_technique_progression_active))
    hand_technique_multiplier_modifiers = state.get(
        "hand_technique_multiplier_modifiers",
        hand_technique_multiplier_modifiers).duplicate(true)
    owned_technique_ids.assign(state.get("owned_technique_ids", owned_technique_ids))
    permanently_removed_card_ids.assign(state.get(
        "permanently_removed_card_ids", permanently_removed_card_ids))
    var card_states: Dictionary = state.get("card_states", {})
    for card in all_cards_for_run_sync():
        var card_state: Dictionary = card_states.get(str(card.id), {})
        if card_state.is_empty():
            continue
        card.definition_id = str(card_state["definition_id"])
        card.rank_name = str(card_state["rank_name"])
        card.rank_order = int(card_state["rank_order"])
        card.qi_value = int(card_state["qi_value"])
        card.attribute = str(card_state["attribute"])
        card.attribute_name = str(card_state["attribute_name"])
        card.is_true_qi = bool(card_state.get("is_true_qi", true))
        card.reshape_origin = card_state["reshape_origin"].duplicate(true)
        card.reshape_enhancement = str(card_state["reshape_enhancement"])
        card.reshape_imprint = str(card_state["reshape_imprint"])
        card.reshape_others = card_state["reshape_others"].duplicate(true)
        card.anomalies = card_state["anomalies"].duplicate(true)
        card.temporary_reshapes = card_state["temporary_reshapes"].duplicate(true)
        card.origin_base_identity = card_state["origin_base_identity"].duplicate(true)
        card.original_owner_id = str(card_state["original_owner_id"])
        card.temporary_card = bool(card_state["temporary_card"])
        card.reshape_rule_service = card_state["reshape_rule_service"]
    var status_state: Dictionary = state.get("status_state", {})
    if status_system != null and not status_state.is_empty():
        status_system.restore_runtime_state(status_state)
    if passive_counter_store != null:
        passive_counter_store.replace_state(state.get("persistent_counters", {}))
    if battle_passive_counter_store != null:
        battle_passive_counter_store.replace_state(state.get("battle_counters", {}))
    var source_marker_state: Dictionary = state.get("source_marker_state", {})
    if not source_marker_state.is_empty():
        source_marker_store.restore_snapshot(source_marker_state)
    var sequence_state: Dictionary = state.get("technique_sequence_state", {})
    if technique_sequence_book != null and not sequence_state.is_empty():
        technique_sequence_book.restore_snapshot(sequence_state)

func stage_cards(card_ids: Array) -> bool:
    return card_zone_service.stage_cards(self, card_ids)

func rollback_staging() -> Array:
    return card_zone_service.rollback_staging(self)

func find_hand_card(card_id: String):
    for card in hand:
        if card.id == card_id:
            return card
    return null

func resolve_hand_definition_ids(definition_ids: Array) -> Array[String]:
    var resolved: Array[String] = []
    var used: Dictionary = {}
    for definition_id in definition_ids:
        for card in hand:
            var current_definition_id: String = card.current_definition_id() \
                if card.has_method("current_definition_id") else str(card.definition_id)
            if used.has(card.id) or current_definition_id != str(definition_id):
                continue
            used[card.id] = true
            resolved.append(str(card.id))
            break
    return resolved

func commit_staging() -> Array:
    return card_zone_service.commit_staging(self)

func commit_selected_staging(
        cards: Array, source_metadata: Dictionary = {}) -> Array:
    return card_zone_service.commit_selected_staging(
        self, cards, source_metadata)

func count_anomaly_in_zone(zone: String, category: String, anomaly_id: String) -> int:
    var cards: Array = []
    match zone:
        "hand": cards = hand
        "draw_pile": cards = draw_pile
        "staging": cards = staging
        "discard_pile": cards = discard_pile
    var count := 0
    for card in cards:
        if card.has_anomaly(category, anomaly_id):
            count += 1
    return count

func random_discard(count: int, rng: RandomNumberGenerator) -> Array:
    return card_zone_service.random_discard(self, count, rng)

func discard_all() -> Array:
    return card_zone_service.discard_all(self)

func recover_from_discard(count: int, destination: String = "draw_pile") -> Array:
    return card_zone_service.recover_from_discard(self, count, destination)

func temporarily_remove_card(
        instance_id: String,
        reason: String = "burn",
        source_metadata: Dictionary = {}) -> Dictionary:
    return card_zone_service.temporarily_remove(
        self, instance_id, reason, source_metadata)

func permanently_remove_card(instance_id: String, reason: String = "permanent_remove") -> Dictionary:
    return card_zone_service.permanently_remove(self, instance_id, reason)

func add_generated_card(card, destination: String, temporary: bool) -> Dictionary:
    return card_zone_service.add_generated(self, card, destination, temporary)

func temporarily_transfer_card_to(
        target_side,
        instance_id: String,
        destination: String = "draw_pile",
        reason: String = "temporary_transfer",
        source_metadata: Dictionary = {}) -> Dictionary:
    return card_zone_service.temporarily_transfer(
        self, target_side, instance_id, destination, reason, source_metadata)

func return_transferred_card_to(
        original_side,
        instance_id: String,
        destination: String = "draw_pile") -> Dictionary:
    return card_zone_service.return_transferred(
        self, original_side, instance_id, destination)

func add_defense(amount: int) -> int:
    var gained := maxi(0, amount)
    defense += gained
    return gained

func add_momentum(amount: int) -> int:
    return int(write_momentum(
        "add", amount, "legacy", "", "legacy").get("delta", 0))

func set_momentum(value: int) -> int:
    write_momentum("set", value, "legacy", "", "legacy")
    return momentum_value

func write_momentum(
        operation: String,
        requested: int,
        source_category: String,
        action_token: String,
        source_id: String = "") -> Dictionary:
    var before := maxi(0, momentum_value)
    var after := before
    var paid := 0
    var success := true
    match operation:
        "add":
            after = maxi(0, before + requested)
        "set":
            after = maxi(0, requested)
        "clear":
            after = 0
        "consume":
            var cost := maxi(0, requested)
            if cost <= 0 or before < cost:
                success = false
            else:
                after = before - cost
                paid = cost
        _:
            success = false
    if success:
        momentum_value = after
    var receipt := {
        "success": success,
        "operation": operation,
        "requested": requested,
        "paid": paid,
        "before": before,
        "after": momentum_value,
        "delta": momentum_value - before,
        "changed": success and momentum_value != before,
        "source_category": source_category,
        "action_token": action_token,
        "source_id": source_id,
        "receipt_index": momentum_write_receipts.size(),
        "rolled_back": false,
    }
    momentum_write_receipts.append(receipt)
    return receipt.duplicate(true)

func rollback_momentum_receipt(receipt: Dictionary) -> bool:
    if receipt.is_empty() or not bool(receipt.get("success", false)) \
            or bool(receipt.get("rolled_back", false)):
        return false
    var index := int(receipt.get("receipt_index", -1))
    if index < 0 or index >= momentum_write_receipts.size():
        return false
    var stored: Dictionary = momentum_write_receipts[index]
    if bool(stored.get("rolled_back", false)) \
            or int(momentum_value) != int(stored.get("after", momentum_value)):
        return false
    momentum_value = maxi(0, int(stored.get("before", momentum_value)))
    stored["rolled_back"] = true
    momentum_write_receipts[index] = stored
    return true

func momentum_changed_for_action(action_token: String) -> bool:
    if action_token == "":
        return false
    for receipt_value in momentum_write_receipts:
        var receipt: Dictionary = receipt_value
        var token := str(receipt.get("action_token", ""))
        if not bool(receipt.get("rolled_back", false)) \
                and bool(receipt.get("changed", false)) \
                and (token == action_token or token.begins_with(action_token + ":")) \
                and str(receipt.get("source_category", "")) != "rule_clear":
            return true
    return false

func momentum_receipts_for_action(action_token: String) -> Array:
    var result: Array = []
    if action_token == "":
        return result
    for receipt_value in momentum_write_receipts:
        var receipt: Dictionary = receipt_value
        var token := str(receipt.get("action_token", ""))
        if token == action_token or token.begins_with(action_token + ":"):
            result.append(receipt.duplicate(true))
    return result

func grant_momentum_preservation(
        action_token: String,
        source_id: String = "") -> Dictionary:
    var record := {
        "source_token": next_combat_source_token("momentum-preserve"),
        "created_by_action_token": action_token,
        "skip_current_action_token": action_token,
        "source_id": source_id,
    }
    momentum_preservation_sources.append(record)
    return record.duplicate(true)

func consume_momentum_preservation_for(action_token: String) -> Dictionary:
    for record_value in momentum_preservation_sources.duplicate():
        var record: Dictionary = record_value
        if str(record.get("skip_current_action_token", "")) == action_token:
            record["skip_current_action_token"] = ""
            var index := momentum_preservation_sources.find(record_value)
            if index >= 0:
                momentum_preservation_sources[index] = record
            return {"preserved": true, "consumed": false, "record": record}
    if momentum_preservation_sources.is_empty():
        return {"preserved": false, "consumed": false}
    var consumed: Dictionary = momentum_preservation_sources.pop_front()
    return {"preserved": true, "consumed": true, "record": consumed}

func set_reflection_percent(value: int, source_token: String = "") -> int:
    var token := source_token if source_token != "" else next_combat_source_token("reflection")
    if value <= 0:
        remove_reflection_source(token)
        return current_reflection_percent
    add_reflection_source(value, token, -1, "manual", "", "反震", true)
    return current_reflection_percent

func clear_reflection_if_source(source_token: String) -> bool:
    return remove_reflection_source(source_token)

func next_combat_source_token(prefix: String) -> String:
    var token := "%s-%s-%06d" % [prefix, owner_id, _combat_source_serial]
    _combat_source_serial += 1
    return token

func add_reflection_source(
        percent: int,
        source_token: String = "",
        remaining_rounds: int = 1,
        expiry_kind: String = "round_end",
        expiry_window_id: String = "",
        label: String = "反震",
        is_public: bool = true) -> Dictionary:
    var token := source_token if source_token != "" \
        else next_combat_source_token("reflection")
    for existing in reflection_sources.duplicate():
        if str(existing.get("source_token", "")) == token:
            reflection_sources.erase(existing)
    var record := {
        "source_token": token,
        "percent": maxi(0, percent),
        "established_order": _combat_source_serial,
        "remaining_rounds": remaining_rounds,
        "expiry_kind": expiry_kind,
        "expiry_window_id": expiry_window_id,
        "label": label,
        "public": is_public,
    }
    _combat_source_serial += 1
    if int(record["percent"]) > 0:
        reflection_sources.append(record)
    _refresh_reflection_aggregate()
    return record

func remove_reflection_source(source_token: String) -> bool:
    if source_token == "":
        return false
    var removed := false
    for record in reflection_sources.duplicate():
        if str(record.get("source_token", "")) == source_token:
            reflection_sources.erase(record)
            removed = true
    _refresh_reflection_aggregate()
    return removed

func add_reflection_true_damage_source(
        source_token: String = "",
        remaining_rounds: int = 1,
        label: String = "反震真伤",
        is_public: bool = true) -> Dictionary:
    var token := source_token if source_token != "" \
        else next_combat_source_token("reflection-true")
    for existing in reflection_true_damage_sources.duplicate():
        if str(existing.get("source_token", "")) == token:
            reflection_true_damage_sources.erase(existing)
    var record := {
        "source_token": token,
        "established_order": _combat_source_serial,
        "remaining_rounds": remaining_rounds,
        "label": label,
        "public": is_public,
    }
    _combat_source_serial += 1
    reflection_true_damage_sources.append(record)
    return record

func reflection_is_true_damage() -> bool:
    return not reflection_true_damage_sources.is_empty()

func tick_round_limited_sources() -> Dictionary:
    var expired_reflection: Array[String] = []
    var expired_true_damage: Array[String] = []
    var expired_retention: Array[String] = []
    var expired_reflection_records: Array = []
    var expired_true_damage_records: Array = []
    var expired_retention_records: Array = []
    var expired_poison_modifier_records: Array = []
    for record in reflection_sources.duplicate():
        if str(record.get("expiry_kind", "round_end")) != "round_end" \
                or int(record.get("remaining_rounds", -1)) < 0:
            continue
        record["remaining_rounds"] = int(record.get("remaining_rounds", 1)) - 1
        if int(record["remaining_rounds"]) <= 0:
            expired_reflection.append(str(record.get("source_token", "")))
            expired_reflection_records.append(record.duplicate(true))
            reflection_sources.erase(record)
    for record in reflection_true_damage_sources.duplicate():
        if int(record.get("remaining_rounds", -1)) < 0:
            continue
        record["remaining_rounds"] = int(record.get("remaining_rounds", 1)) - 1
        if int(record["remaining_rounds"]) <= 0:
            expired_true_damage.append(str(record.get("source_token", "")))
            expired_true_damage_records.append(record.duplicate(true))
            reflection_true_damage_sources.erase(record)
    for record in defense_retention_sources.duplicate():
        if int(record.get("remaining_rounds", -1)) < 0:
            continue
        record["remaining_rounds"] = int(record.get("remaining_rounds", 1)) - 1
        if int(record["remaining_rounds"]) <= 0:
            expired_retention.append(str(record.get("source_token", "")))
            expired_retention_records.append(record.duplicate(true))
            defense_retention_sources.erase(record)
    for record in poison_damage_modifier_sources.duplicate():
        if str(record.get("expiry", "battle_end")) not in ["round_end", "turn_end"]:
            continue
        record["remaining_rounds"] = int(record.get("remaining_rounds", 1)) - 1
        if int(record["remaining_rounds"]) <= 0:
            expired_poison_modifier_records.append(record.duplicate(true))
            poison_damage_modifier_sources.erase(record)
    _refresh_reflection_aggregate()
    return {
        "reflection": expired_reflection,
        "true_damage": expired_true_damage,
        "retention": expired_retention,
        "reflection_records": expired_reflection_records,
        "true_damage_records": expired_true_damage_records,
        "retention_records": expired_retention_records,
        "poison_modifier_records": expired_poison_modifier_records,
    }

func expire_action_window_sources(window_id: String) -> Dictionary:
    var expired_reflection: Array[String] = []
    var expired_blocks: Array[String] = []
    var expired_deflections: Array[String] = []
    var expired_reflection_records: Array = []
    var expired_block_records: Array = []
    var expired_deflection_records: Array = []
    for record in reflection_sources.duplicate():
        if str(record.get("expiry_kind", "")) == "action_window_end" \
                and str(record.get("expiry_window_id", "")) == window_id:
            expired_reflection.append(str(record.get("source_token", "")))
            expired_reflection_records.append(record.duplicate(true))
            reflection_sources.erase(record)
    for record in block_sources.duplicate():
        if str(record.get("window_id", "")) == window_id:
            if str(record.get("cancel_kind", "block")) == "deflection":
                expired_deflections.append(str(record.get("source_token", "")))
                expired_deflection_records.append(record.duplicate(true))
            else:
                expired_blocks.append(str(record.get("source_token", "")))
                expired_block_records.append(record.duplicate(true))
            block_sources.erase(record)
    _refresh_reflection_aggregate()
    return {
        "reflection": expired_reflection, "blocks": expired_blocks,
        "deflections": expired_deflections,
        "reflection_records": expired_reflection_records,
        "block_records": expired_block_records,
        "deflection_records": expired_deflection_records,
    }

func add_block_source(
        condition,
        source_token: String = "",
        target_owner_id: String = "",
        window_id: String = "",
        label: String = "格挡",
        is_public: bool = true,
        metadata: Dictionary = {}) -> Dictionary:
    var token := source_token if source_token != "" \
        else next_combat_source_token("block")
    var record := {
        "source_token": token,
        "cancel_kind": "block",
        "condition_spec": _normalized_block_condition(condition),
        "established_order": _combat_source_serial,
        "target_owner_id": target_owner_id,
        "window_id": window_id,
        "waiting_for_action": window_id == "",
        "label": label,
        "public": is_public,
        "metadata": metadata.duplicate(true),
    }
    for field in [
            "source_kind", "source_id", "source_name",
            "source_instance_key", "trigger_mode"]:
        if metadata.has(field):
            record[field] = str(metadata[field])
    _combat_source_serial += 1
    block_sources.append(record)
    return record


func add_deflection_source(
        threshold: int,
        source_token: String = "",
        target_owner_id: String = "",
        window_id: String = "",
        label: String = "卸力",
        is_public: bool = true,
        metadata: Dictionary = {}) -> Dictionary:
    var token := source_token if source_token != "" \
        else next_combat_source_token("deflection")
    var record := {
        "source_token": token,
        "cancel_kind": "deflection",
        "threshold": maxi(0, threshold),
        "established_order": _combat_source_serial,
        "target_owner_id": target_owner_id,
        "window_id": window_id,
        "waiting_for_action": window_id == "",
        "label": label,
        "public": is_public,
        "metadata": metadata.duplicate(true),
    }
    for field in [
            "source_kind", "source_id", "source_name",
            "source_instance_key", "trigger_mode"]:
        if metadata.has(field):
            record[field] = str(metadata[field])
    _combat_source_serial += 1
    block_sources.append(record)
    return record

func bind_waiting_action_sources(acting_owner_ids: Array, window_id: String) -> void:
    for record in block_sources:
        if bool(record.get("waiting_for_action", false)) \
                and acting_owner_ids.has(str(record.get("target_owner_id", ""))):
            record["waiting_for_action"] = false
            record["window_id"] = window_id
    for record in challenge_records:
        if bool(record.get("waiting_for_action", false)) \
                and acting_owner_ids.has(str(record.get("target_owner_id", ""))):
            record["waiting_for_action"] = false
            record["window_id"] = window_id

func try_consume_block(
        amount: int,
        damage_type: String,
        attacker_owner_id: String,
        window_id: String,
        defender_hand_count: int = -1,
        attacker_hand_count: int = -1) -> Dictionary:
    if amount <= 0 or damage_type not in ["normal", "true"]:
        return {"blocked": false, "canceled": false,
            "cancel_kind": "none", "checked_source_tokens": []}
    var ordered := block_sources.duplicate()
    ordered.sort_custom(func(left, right):
        return int(left.get("established_order", 0)) \
            < int(right.get("established_order", 0)))
    for record in ordered:
        if str(record.get("cancel_kind", "block")) != "block":
            continue
        if bool(record.get("waiting_for_action", false)) \
                or str(record.get("window_id", "")) != window_id \
                or str(record.get("target_owner_id", "")) != attacker_owner_id:
            continue
        var condition_spec: Dictionary = record.get("condition_spec", {})
        if not condition_spec_registry.event_matches(condition_spec, {
                "amount": amount, "damage_type": damage_type,
                "defense": defense,
                "defender_hand_count": defender_hand_count,
                "attacker_hand_count": attacker_hand_count,
            }, self):
            continue
        block_sources.erase(record)
        return {"blocked": true, "canceled": true,
            "cancel_kind": "block", "source": record,
            "source_token": record["source_token"],
            "checked_source_tokens": [str(record.get("source_token", ""))]}
    return {"blocked": false, "canceled": false,
        "cancel_kind": "none", "checked_source_tokens": []}


func resolve_attack_cancellation(
        amount: int,
        damage_type: String,
        attacker_owner_id: String,
        window_id: String,
        defender_hand_count: int = -1,
        attacker_hand_count: int = -1) -> Dictionary:
    var base := {
        "canceled": false, "blocked": false, "cancel_kind": "none",
        "source": {}, "source_token": "", "threshold": 0,
        "consumed": false, "pierced": false,
        "checked_source_tokens": [], "deflection_results": [],
    }
    if amount <= 0 or damage_type not in ["normal", "true"]:
        return base
    var ordered := block_sources.duplicate()
    ordered.sort_custom(func(left, right):
        return int(left.get("established_order", 0)) \
            < int(right.get("established_order", 0)))
    # 卸力严格按建立顺序消费。击穿也必须消费，并继续检查后续来源。
    for record in ordered:
        if str(record.get("cancel_kind", "block")) != "deflection":
            continue
        if bool(record.get("waiting_for_action", false)) \
                or str(record.get("window_id", "")) != window_id \
                or str(record.get("target_owner_id", "")) != attacker_owner_id:
            continue
        var token := str(record.get("source_token", ""))
        base["checked_source_tokens"].append(token)
        block_sources.erase(record)
        var threshold := maxi(0, int(record.get("threshold", 0)))
        var succeeded := amount <= threshold
        var deflection_result := {
            "source": record,
            "source_token": token,
            "threshold": threshold,
            "attack_amount": amount,
            "succeeded": succeeded,
            "pierced": not succeeded,
            "consumed": true,
        }
        base["deflection_results"].append(deflection_result)
        base.merge({
            "source": record, "source_token": token,
            "threshold": threshold, "consumed": true,
            "pierced": not succeeded,
        }, true)
        if succeeded:
            base.merge({
                "canceled": true, "cancel_kind": "deflection",
                "source": record, "source_token": token,
                "threshold": threshold, "consumed": true,
                "pierced": false,
            }, true)
            return base
    # 只有全部卸力被击穿后才检查格挡；格挡条件保持原有语义。
    for record in ordered:
        if str(record.get("cancel_kind", "block")) != "block":
            continue
        if bool(record.get("waiting_for_action", false)) \
                or str(record.get("window_id", "")) != window_id \
                or str(record.get("target_owner_id", "")) != attacker_owner_id:
            continue
        var token := str(record.get("source_token", ""))
        base["checked_source_tokens"].append(token)
        var condition_spec: Dictionary = record.get("condition_spec", {})
        if not condition_spec_registry.event_matches(condition_spec, {
                "amount": amount, "damage_type": damage_type,
                "defense": defense,
                "defender_hand_count": defender_hand_count,
                "attacker_hand_count": attacker_hand_count,
            }, self):
            continue
        block_sources.erase(record)
        base.merge({
            "canceled": true, "blocked": true, "cancel_kind": "block",
            "source": record, "source_token": token, "threshold": 0,
            "consumed": true, "pierced": false,
        }, true)
        return base
    return base


func preview_attack_cancellation(
        amount: int,
        damage_type: String,
        attacker_owner_id: String,
        window_id: String,
        defender_hand_count: int = -1,
        attacker_hand_count: int = -1) -> Dictionary:
    var snapshot := block_sources.duplicate()
    var result := resolve_attack_cancellation(
        amount, damage_type, attacker_owner_id, window_id,
        defender_hand_count, attacker_hand_count)
    block_sources.assign(snapshot)
    result["preview"] = true
    return result

func _normalized_block_condition(condition) -> Dictionary:
    if condition is Dictionary:
        return condition.duplicate(true)
    match str(condition):
        "damage_at_most_defense":
            return {"block_damage_at_most_defense": true}
        "actual_hand_more_than_attacker":
            return {"block_defender_hand_more_than_attacker": true}
    return {}

func add_pending_power_fixed_source(
        amount: int,
        source_token: String = "",
        label: String = "下一门成功功法",
        is_public: bool = true,
        metadata: Dictionary = {}) -> Dictionary:
    var token := source_token if source_token != "" \
        else next_combat_source_token("power-fixed")
    var record := {
        "source_token": token,
        "amount": maxi(0, amount),
        "established_order": _combat_source_serial,
        "label": label,
        "public": is_public,
        "source_instance_key": str(metadata.get("source_instance_key", "")),
        "content_id": str(metadata.get("content_id", "")),
    }
    _combat_source_serial += 1
    pending_power_fixed_sources.append(record)
    return record

func add_defense_retention_source(
        additional_percent: int,
        prevent_decay: bool,
        source_token: String = "",
        remaining_rounds: int = 1,
        label: String = "防御保留") -> Dictionary:
    var token := source_token if source_token != "" \
        else next_combat_source_token("defense-retention")
    var record := {
        "source_token": token,
        "additional_percent": additional_percent,
        "prevent_decay": prevent_decay,
        "remaining_rounds": remaining_rounds,
        "established_order": _combat_source_serial,
        "label": label, "public": true,
    }
    _combat_source_serial += 1
    defense_retention_sources.append(record)
    return record

func pending_power_fixed_total() -> int:
    var total := 0
    for record in pending_power_fixed_sources:
        total += int(record.get("amount", 0))
    return total

func consume_pending_power_fixed_sources(tokens: Array) -> int:
    var total := 0
    for record in pending_power_fixed_sources.duplicate():
        if tokens.has(str(record.get("source_token", ""))):
            total += int(record.get("amount", 0))
            pending_power_fixed_sources.erase(record)
    return total

func public_reflection_sources() -> Array:
    var result: Array = []
    for record in reflection_sources:
        if bool(record.get("public", true)):
            result.append(_public_source(record, ["percent", "remaining_rounds", "expiry_kind", "label"]))
    return result

func public_reflection_true_damage_sources() -> Array:
    var result: Array = []
    for record in reflection_true_damage_sources:
        if bool(record.get("public", true)):
            result.append(_public_source(record, [
                "remaining_rounds", "label"]))
    return result

func public_block_sources() -> Array:
    var result: Array = []
    for record in block_sources:
        if str(record.get("cancel_kind", "block")) == "block" \
                and bool(record.get("public", true)):
            result.append(_public_source(record, [
                "condition_spec", "waiting_for_action", "window_id", "label"]))
    return result


func public_deflection_sources() -> Array:
    var result: Array = []
    for record in block_sources:
        if str(record.get("cancel_kind", "block")) == "deflection" \
                and bool(record.get("public", true)):
            result.append(_public_source(record, [
                "threshold", "waiting_for_action", "window_id", "label"]))
    return result


func has_deflection_source() -> bool:
    for record in block_sources:
        if str(record.get("cancel_kind", "block")) == "deflection":
            return true
    return false

func public_challenge_records() -> Array:
    var result: Array = []
    for record in challenge_records:
        if bool(record.get("public", true)):
            result.append(_public_source(record, [
                "threshold", "current", "target_owner_id", "window_id",
                "waiting_for_action", "label"]))
    return result

func clear_combat_sources() -> void:
    reflection_sources.clear()
    reflection_true_damage_sources.clear()
    block_sources.clear()
    challenge_records.clear()
    pending_power_fixed_sources.clear()
    defense_retention_sources.clear()
    current_reflection_percent = 0
    current_reflection_source_token = ""

func _refresh_reflection_aggregate() -> void:
    var latest: Dictionary = {}
    for record in reflection_sources:
        if latest.is_empty() or int(record.get("established_order", 0)) \
                > int(latest.get("established_order", 0)):
            latest = record
    current_reflection_percent = int(latest.get("percent", 0))
    current_reflection_source_token = str(latest.get("source_token", ""))

func _public_source(record: Dictionary, fields: Array) -> Dictionary:
    var result := {
        "source_token": str(record.get("source_token", "")),
        "cancel_kind": str(record.get("cancel_kind", "")),
        "established_order": int(record.get("established_order", 0)),
        "source_kind": str(record.get("source_kind", "")),
        "source_id": str(record.get("source_id", "")),
        "source_name": str(record.get("source_name", "")),
        "source_instance_key": str(record.get("source_instance_key", "")),
        "trigger_mode": str(record.get("trigger_mode", "")),
    }
    for field_value in fields:
        var field := str(field_value)
        result[field] = record.get(field)
    return result

func configure_inner_skills(
        inner_skill_ids: Array,
        dynamic_technique_slot: int = 0) -> Dictionary:
    var normalized: Array[String] = []
    for value in inner_skill_ids:
        if not value is String or str(value).strip_edges() == "":
            return {"success": false, "reason": "内功装配不能包含空 ID"}
        var content_id := str(value)
        if passive_rule_runtime != null \
                and not passive_rule_runtime.has_content("inner_skill", content_id):
            return {"success": false, "reason": "未知内功：%s" % content_id}
        normalized.append(content_id)
    var capacity := {
        "base_capacity": InnerSkillCapacityPolicyScript.BASE_INNER_SKILL_CAPACITY,
        "effective_capacity": InnerSkillCapacityPolicyScript.BASE_INNER_SKILL_CAPACITY,
        "modifiers": [],
        "errors": [],
    }
    if passive_rule_runtime != null:
        capacity = passive_rule_runtime.resolve_inner_skill_capacity(self, normalized)
    if not capacity.get("errors", []).is_empty():
        return {
            "success": false,
            "reason": "内功容量查询失败：%s" % "；".join(capacity["errors"]),
        }
    if normalized.size() > int(capacity.get("effective_capacity", 0)):
        return {
            "success": false,
            "reason": "内功有效容量为 %d，不能装备 %d 门" % [
                int(capacity.get("effective_capacity", 0)), normalized.size()],
        }
    if dynamic_technique_slot < 0 or dynamic_technique_slot > normalized.size():
        return {
            "success": false,
            "reason": "technique_slot_index 必须位于 0～装备数量之间",
        }
    equipped_inner_skill_ids.assign(normalized)
    technique_slot_index = dynamic_technique_slot
    return {
        "success": true,
        "equipped_inner_skill_ids": normalized.duplicate(),
        "technique_slot_index": technique_slot_index,
        "capacity": capacity,
    }

func configure_items(ids: Array) -> Dictionary:
    var normalized: Array[String] = []
    var seen: Dictionary = {}
    for value in ids:
        if not value is String or str(value).strip_edges() == "":
            return {"success": false, "reason": "物品装配不能包含空 ID"}
        var content_id := str(value)
        if seen.has(content_id):
            return {"success": false, "reason": "物品 ID 重复：%s" % content_id}
        if passive_rule_runtime != null \
                and not passive_rule_runtime.has_content("item", content_id):
            return {"success": false, "reason": "未知物品：%s" % content_id}
        seen[content_id] = true
        normalized.append(content_id)
    item_ids.assign(normalized)
    recalculate_effective_max_life()
    return {"success": true, "item_ids": normalized.duplicate()}

func configure_consumables(ids: Array) -> void:
    consumable_ids.clear()
    for consumable_id in ids.slice(0, consumable_limit):
        consumable_ids.append(str(consumable_id))

func grant_consumable(consumable_id: String) -> bool:
    if consumable_ids.size() >= consumable_limit:
        return false
    consumable_ids.append(consumable_id)
    return true

func consume_at(slot_index: int) -> String:
    if slot_index < 0 or slot_index >= consumable_ids.size():
        return ""
    return consumable_ids.pop_at(slot_index)

func apply_insight_growth(
        hand_id: String,
        candidates: Array = [],
        rng: RandomNumberGenerator = null,
        source_metadata: Dictionary = {}) -> Dictionary:
    var progression: Dictionary = hand_technique_progression.get(hand_id, {
        "slot_count": 1,
        "sequence": _actual_technique_ids(hand_id),
    }).duplicate(true)
    var rng_state_before := rng.state if rng != null else 0
    var plan: Dictionary = InsightGrowthServiceScript.resolve(
        self,
        technique_loadout_policy,
        hand_id,
        progression,
        hand_technique_progression,
        owned_technique_ids,
        candidates,
        rng,
        hand_technique_progression_active)
    if not plan.get("success", false):
        if rng != null:
            rng.state = rng_state_before
        return plan
    var before := int(plan["slot_count_before"])
    var slot_gain := int(plan["slot_gain"])
    var requested_gain := int(plan["slot_gain_requested"])
    var progression_before := hand_technique_progression.duplicate(true)
    var owned_before := owned_technique_ids.duplicate()
    var sequence_before: Dictionary = technique_sequence_book.snapshot() \
        if technique_sequence_book != null else {}
    hand_technique_progression = plan["proposed_progression"].duplicate(true)
    owned_technique_ids.assign(plan["proposed_learned_ids"])
    var capacity_sync := {"success": true, "changed": false}
    if slot_gain > 0 and technique_sequence_book != null:
        ## 这是工作状态与 SequenceBook 的完整性校验，不是战斗开始时
        ## 冻结永久容量；合法增长会在下方立即同步。
        if technique_sequence_book.slot_capacity(hand_id) != before:
            _rollback_insight_growth(
                progression_before, owned_before, sequence_before,
                rng, rng_state_before)
            return {
                "success": false,
                "reason": "永久功法槽容量与当前战斗容量不一致",
                "rolled_back": true,
            }
        var ports = _battle_effect_ports_ref.get_ref() \
            if _battle_effect_ports_ref != null else null
        if ports == null:
            _rollback_insight_growth(
                progression_before, owned_before, sequence_before,
                rng, rng_state_before)
            return {
                "success": false,
                "reason": "战斗中心得缺少统一功法槽容量端口",
                "rolled_back": true,
            }
        var metadata := source_metadata.duplicate(true)
        metadata["requested_delta"] = requested_gain
        metadata["minimum_capacity"] = \
            TechniqueLoadoutPolicyScript.MIN_SLOT_COUNT
        metadata["maximum_capacity"] = \
            TechniqueLoadoutPolicyScript.MAX_SLOT_COUNT
        capacity_sync = ports.change_technique_slot_capacity(
            self, hand_id, slot_gain, metadata)
        if not capacity_sync.get("success", false) \
                or int(capacity_sync.get("actual_delta", 0)) != slot_gain:
            ## 容量端口是事件/回执的事务边界：事件失败时它已撤销
            ## 容量且不会发布成功回执。此处恢复快照以同时覆盖端口
            ## 实现在返回失败前已修改 SequenceBook 的情况。
            _rollback_insight_growth(
                progression_before, owned_before, sequence_before,
                rng, rng_state_before)
            return {
                "success": false,
                "reason": str(capacity_sync.get(
                    "reason", "战斗功法槽容量同步失败")),
                "rolled_back": true,
                "capacity_sync": capacity_sync,
            }
    var result: Dictionary = InsightGrowthServiceScript.public_result(plan)
    result["battle_capacity_sync"] = capacity_sync.duplicate(true)
    return result

func _rollback_insight_growth(
        progression_before: Dictionary,
        owned_before: Array,
        sequence_before: Dictionary,
        rng: RandomNumberGenerator,
        rng_state_before: int) -> void:
    hand_technique_progression = progression_before
    owned_technique_ids.assign(owned_before)
    if technique_sequence_book != null and not sequence_before.is_empty():
        technique_sequence_book.restore_snapshot(sequence_before)
    ## apply_insight_growth 拥有“单次心得解算”的 RNG 回滚责任，
    ## 因此直接调用与消耗品外层事务都不会留下随机数推进。
    if rng != null:
        rng.state = rng_state_before

func _actual_technique_ids(hand_id: String) -> Array:
    var result: Array = []
    if technique_sequence_book == null:
        return result
    for slot_value in technique_sequence_book.ordered_slots(hand_id):
        result.append(str(slot_value.get("technique_id", "")))
    return result

func learn_technique(technique_id: String) -> bool:
    if technique_id == "" or owned_technique_ids.has(technique_id):
        return false
    owned_technique_ids.append(technique_id)
    return true

func combat_source_order(inner_skill_index: int) -> int:
    return inner_skill_index if inner_skill_index < technique_slot_index else inner_skill_index + 1

func receive_damage(amount: int, true_damage: bool = false) -> Dictionary:
    return DamageResolverScript.apply_to_target(self, amount, true_damage)
