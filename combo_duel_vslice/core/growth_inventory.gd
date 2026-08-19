class_name GrowthInventory
extends RefCounted

const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const BattleSetupServiceScript = preload("res://core/battle_setup_service.gd")
const RunDeckScript = preload("res://core/run_deck.gd")
const PassiveCounterStoreScript = preload(
    "res://core/passives/run_passive_counter_store.gd")
const TechniqueLoadoutPolicyScript = preload(
    "res://core/technique_loadout_policy.gd")
const InsightGrowthServiceScript = preload(
    "res://core/insight_growth_service.gd")
const SourceMarkerStoreScript = preload("res://core/source_marker_store.gd")
const SourceContributedStatServiceScript = preload(
    "res://core/source_contributed_stat_service.gd")
const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")
const RunCombatHistoryScript = preload("res://core/run_combat_history.gd")
const IntQueryRequestScript = preload(
    "res://core/passives/passive_int_query_request.gd")

const BASE_CONSUMABLE_CAPACITY := 2
## 旧调用方只可把它当作基础值别名；正式规则必须调用
## effective_consumable_capacity_result()。
const CONSUMABLE_LIMIT := BASE_CONSUMABLE_CAPACITY
const EXPERIENCE_INTEREST_STEP := 5
const EXPERIENCE_INTEREST_CAP := 5
const PLAYER_INITIAL_SEQUENCES_PATH := "res://data/production_sequences.json"

var experience: int = 0
var free_meditation_charge: int = 0
var experience_operation_receipts: Dictionary = {}
var consumable_ids: Array[String] = []
var consumable_capacity_at_last_commit: int = BASE_CONSUMABLE_CAPACITY
var consumable_overflow_count: int = 0
var item_ids: Array[String] = []
var learned_technique_ids: Array[String] = []
var learned_inner_skill_ids: Array[String] = []
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0
var forgotten_inner_skill_count: int = 0
var run_deck
var practice_purchases: Dictionary = {}
var life: int = 100
var max_life: int = 100
var base_max_life: int = 100
var source_marker_store = SourceMarkerStoreScript.new()
var source_contributed_stat_service = SourceContributedStatServiceScript.new()
var source_marker_address_resolver = SourceMarkerAddressResolverScript.new()
var hand_technique_progression: Dictionary = {}
var practice_shop_state: Dictionary = {}
var consumable_use_sequence: int = 0
var last_recallable_consumable_id: String = ""
var base_hand_limit_modifier: int = 0
var hand_technique_multiplier_modifiers: Dictionary = {}
var used_unique_consumable_ids: Array[String] = []
var run_combat_history = RunCombatHistoryScript.new()
var passive_counter_store
var technique_loadout_policy
var _content_catalog
var _int_policy_resolver = null

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

func _init(content_catalog = null, initialize_standard_deck: bool = true) -> void:
    _content_catalog = content_catalog
    passive_counter_store = PassiveCounterStoreScript.new(content_catalog)
    technique_loadout_policy = TechniqueLoadoutPolicyScript.new(content_catalog)
    run_deck = RunDeckScript.new(content_catalog)
    _initialize_hand_technique_progression(
        _player_initial_sequences())
    if initialize_standard_deck:
        run_deck.reset_standard()

func reset(
        run_namespace: String = "run",
        run_deck_override = null,
        initial_max_life: int = 100) -> void:
    experience = 0
    free_meditation_charge = 0
    experience_operation_receipts.clear()
    consumable_capacity_at_last_commit = BASE_CONSUMABLE_CAPACITY
    consumable_overflow_count = 0
    max_life = initial_max_life
    base_max_life = initial_max_life
    life = max_life
    consumable_ids.clear()
    item_ids.clear()
    learned_technique_ids.clear()
    learned_inner_skill_ids.clear()
    equipped_inner_skill_ids.clear()
    technique_slot_index = 0
    forgotten_inner_skill_count = 0
    if run_deck_override != null:
        run_deck = run_deck_override
    else:
        run_deck.reset_standard(run_namespace)
    practice_purchases.clear()
    _initialize_hand_technique_progression(
        _player_initial_sequences())
    practice_shop_state.clear()
    consumable_use_sequence = 0
    last_recallable_consumable_id = ""
    base_hand_limit_modifier = 0
    hand_technique_multiplier_modifiers.clear()
    used_unique_consumable_ids.clear()
    run_combat_history.clear()
    passive_counter_store.clear()
    source_marker_store.restore_snapshot({
        "schema_version": SourceMarkerStoreScript.SCHEMA_VERSION,
        "entries": [],
    })

func use_technique_loadout_policy_resolver(resolver) -> void:
    technique_loadout_policy.use_int_policy_resolver(resolver)

func use_int_policy_resolver(resolver) -> void:
    _int_policy_resolver = resolver
    refresh_consumable_capacity_state()

func clear_practice_purchases() -> void:
    practice_purchases.clear()

func migrate_legacy_practice_shop_state() -> void:
    practice_shop_state = normalized_practice_shop_state(practice_shop_state)

func practice_shop_snapshot() -> Dictionary:
    return normalized_practice_shop_state(practice_shop_state)

static func normalized_practice_shop_state(value: Dictionary) -> Dictionary:
    if value.is_empty():
        return {}
    var result := value.duplicate(true)
    if not result.has("items") and result.has("coupons"):
        result["items"] = result["coupons"]
    if not result.has("item_candidates") and result.has("coupon_candidates"):
        result["item_candidates"] = result["coupon_candidates"]
    if not result.has("item_slots") and result.has("coupon_slots"):
        result["item_slots"] = result["coupon_slots"]
    result.erase("coupons")
    result.erase("coupon_candidates")
    result.erase("coupon_slots")
    var normal = result.get("normal", [])
    if not normal is Array:
        normal = []
        result["normal"] = normal
    result["normal_slot_count"] = normal.size()
    if not result.has("strategy_source_fingerprint"):
        result["strategy_source_fingerprint"] = "legacy"
    if not result.has("strategy_source_snapshot_fingerprint"):
        result["strategy_source_snapshot_fingerprint"] = "legacy"
    if not result.has("strategy_operation"):
        result["strategy_operation"] = "legacy_restore"
    if not result.has("meditation_operation_sequence"):
        result["meditation_operation_sequence"] = int(result.get(
            "meditation_count", 0))
    result["normal"] = normal
    return result

## 捕获本局效果事务所需的完整可变状态。
##
## 这不同于 RunProgressSnapshot 的部分快照：事务副本必须覆盖所有本局库存，
## 才能保证未来的牌组或装备 Handler 失败时不会留下部分修改。
func capture_mutation_state() -> Dictionary:
    return {
        "experience": experience,
        "free_meditation_charge": free_meditation_charge,
        "experience_operation_receipts": experience_operation_receipts.duplicate(true),
        "consumable_capacity_at_last_commit": consumable_capacity_at_last_commit,
        "consumable_overflow_count": consumable_overflow_count,
        "life": life,
        "max_life": max_life,
        "base_max_life": base_max_life,
        "source_marker_state": source_marker_store.snapshot("run"),
        "consumable_ids": consumable_ids.duplicate(),
        "item_ids": item_ids.duplicate(),
        "learned_technique_ids": learned_technique_ids.duplicate(),
        "learned_inner_skill_ids": learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(),
        "technique_slot_index": technique_slot_index,
        "forgotten_inner_skill_count": forgotten_inner_skill_count,
        "run_deck": run_deck.to_snapshot(),
        "practice_purchases": practice_purchases.duplicate(true),
        "hand_technique_progression": hand_technique_progression.duplicate(true),
        "practice_shop_state": practice_shop_snapshot(),
        "consumable_use_sequence": consumable_use_sequence,
        "last_recallable_consumable_id": last_recallable_consumable_id,
        "base_hand_limit_modifier": base_hand_limit_modifier,
        "hand_technique_multiplier_modifiers": hand_technique_multiplier_modifiers.duplicate(true),
        "used_unique_consumable_ids": used_unique_consumable_ids.duplicate(),
        "run_combat_history_state": run_combat_history.snapshot(),
        "passive_counter_state": passive_counter_store.capture_state(),
    }

func create_mutation_copy():
    var working := GrowthInventory.new(_content_catalog, false)
    working.use_technique_loadout_policy_resolver(
        technique_loadout_policy.int_policy_resolver())
    working.use_int_policy_resolver(_int_policy_resolver)
    var errors: Array[String] = working.replace_mutation_state(
        capture_mutation_state())
    if not errors.is_empty():
        push_error("无法建立成长库存事务副本：%s" % "；".join(errors))
        return null
    return working

## 用一个已完整验证的事务状态替换真实库存。
##
## RunDeck 先在独立实例中恢复并校验；只有成功后才替换所有字段，避免提交阶段
## 因牌组错误把真实库存写到一半。
func replace_mutation_state(state: Dictionary) -> Array[String]:
    var replacement_deck = RunDeckScript.new(_content_catalog)
    var deck_errors: Array[String] = replacement_deck.restore_snapshot(
        state["run_deck"])
    if not deck_errors.is_empty():
        return deck_errors
    var replacement_counter_store = PassiveCounterStoreScript.new(
        _content_catalog)
    var counter_errors: Array[String] = replacement_counter_store.replace_state(
        state.get("passive_counter_state", {
            "version": PassiveCounterStoreScript.SCHEMA_VERSION,
            "entries": [],
        }))
    if not counter_errors.is_empty():
        return counter_errors
    var replacement_marker_store = SourceMarkerStoreScript.new()
    var marker_errors: Array[String] = replacement_marker_store.restore_snapshot(
        state.get("source_marker_state", {
            "schema_version": SourceMarkerStoreScript.SCHEMA_VERSION,
            "entries": [],
        }))
    if not marker_errors.is_empty():
        return marker_errors
    var replacement_history = RunCombatHistoryScript.new()
    var history_errors: Array[String] = replacement_history.restore_snapshot(
        state.get("run_combat_history_state", {}))
    if not history_errors.is_empty():
        return history_errors
    experience = int(state["experience"])
    free_meditation_charge = clampi(int(state.get(
        "free_meditation_charge", 0)), 0, 1)
    experience_operation_receipts = state.get(
        "experience_operation_receipts", {}).duplicate(true)
    consumable_capacity_at_last_commit = maxi(0, int(state.get(
        "consumable_capacity_at_last_commit", BASE_CONSUMABLE_CAPACITY)))
    life = int(state["life"])
    max_life = int(state["max_life"])
    base_max_life = int(state.get("base_max_life", state["max_life"]))
    source_marker_store = replacement_marker_store
    consumable_ids.assign(state["consumable_ids"])
    consumable_overflow_count = maxi(0, int(state.get(
        "consumable_overflow_count",
        maxi(consumable_ids.size() - consumable_capacity_at_last_commit, 0))))
    item_ids.assign(state.get("item_ids", []))
    learned_technique_ids.assign(state["learned_technique_ids"])
    learned_inner_skill_ids.assign(state["learned_inner_skill_ids"])
    equipped_inner_skill_ids.assign(state["equipped_inner_skill_ids"])
    technique_slot_index = int(state["technique_slot_index"])
    forgotten_inner_skill_count = int(
        state.get("forgotten_inner_skill_count", 0))
    run_deck = replacement_deck
    practice_purchases = state["practice_purchases"].duplicate(true)
    hand_technique_progression = state["hand_technique_progression"].duplicate(true)
    practice_shop_state = normalized_practice_shop_state(
        state["practice_shop_state"])
    consumable_use_sequence = int(state.get("consumable_use_sequence", 0))
    last_recallable_consumable_id = str(
        state.get("last_recallable_consumable_id", ""))
    base_hand_limit_modifier = int(state.get("base_hand_limit_modifier", 0))
    hand_technique_multiplier_modifiers = state.get(
        "hand_technique_multiplier_modifiers", {}).duplicate(true)
    used_unique_consumable_ids.assign(
        state.get("used_unique_consumable_ids", []))
    run_combat_history = replacement_history
    passive_counter_store = replacement_counter_store
    passive_counter_store.clear_unowned(
        learned_inner_skill_ids, item_ids)
    return []

func _initialize_hand_technique_progression(sequence_definition: Dictionary) -> void:
    hand_technique_progression.clear()
    for hand_id in HAND_IDS:
        var sequence: Array = sequence_definition.get(hand_id, [])
        var initial: Array = []
        if not sequence.is_empty():
            var technique_id := str(sequence[0])
            initial.append(technique_id)
            if _content_catalog != null \
                    and not technique_loadout_policy.is_built_in(technique_id) \
                    and not learned_technique_ids.has(technique_id):
                learned_technique_ids.append(technique_id)
        hand_technique_progression[hand_id] = {
            "slot_count": 1,
            "sequence": initial,
        }

func _player_initial_sequences() -> Dictionary:
    if not FileAccess.file_exists(PLAYER_INITIAL_SEQUENCES_PATH):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(
        PLAYER_INITIAL_SEQUENCES_PATH))
    return parsed if parsed is Dictionary else {}

func hand_progression(hand_id: String) -> Dictionary:
    var value: Dictionary = hand_technique_progression.get(hand_id, {})
    return value.duplicate(true)

func get_hand_technique_loadout(hand_id: String) -> Dictionary:
    return hand_progression(hand_id)

func set_hand_technique_loadout(hand_id: String, technique_ids: Array) -> Dictionary:
    if not HAND_IDS.has(hand_id):
        return {"success": false, "reason": "未知牌型：%s" % hand_id}
    var progression: Dictionary = hand_technique_progression.get(
        hand_id, {}).duplicate(true)
    var normalized: Array[String] = []
    for technique_id_value in technique_ids:
        normalized.append(str(technique_id_value))
    var proposed := hand_technique_progression.duplicate(true)
    progression["sequence"] = normalized
    proposed[hand_id] = progression
    var validation: Dictionary = technique_loadout_policy.validate_complete(
        self, proposed, learned_technique_ids, hand_id)
    if not validation.get("success", false):
        return validation
    hand_technique_progression = proposed
    recalculate_effective_max_life()
    return {"success": true, "hand_id": hand_id, "sequence": normalized.duplicate()}

## 物品获得/遗失只修改当前事务工作副本；外层 RunMutationService 或购买
## 事务负责原子提交。初始 run marker 在 item_id 正式写入后才建立，因而
## 不会污染购买价格、资格或获得前的事件来源快照。
func grant_item(item_id: String) -> Dictionary:
    if item_id == "" or _content_catalog == null:
        return {"success": false, "reason": "物品获得缺少内容目录或 ID"}
    if item_ids.has(item_id):
        return {"success": false, "reason": "物品已持有，不能重复发放：%s" % item_id}
    var definition: Dictionary = _content_catalog.get_by_id(
        "item", item_id) if _content_catalog.has_method("get_by_id") else {}
    item_ids.append(item_id)
    # 旧的 RunContentProbeCatalog 只提供 ID/资格查询而不暴露完整内容定义；
    # 这类无 marker 物品仍可获得，正式内容则由 marker_definitions 继续走
    # 下方统一地址与状态写入。
    if definition.is_empty():
        recalculate_effective_max_life()
        var capacity_result := refresh_consumable_capacity_state()
        if not capacity_result.get("success", false):
            return capacity_result
        return {
            "success": true,
            "item_id": item_id,
            "marker_changes": [],
            "max_life": max_life,
        }
    var marker_changes: Array = []
    for marker_value in definition.get("marker_definitions", []):
        if not marker_value is Dictionary or not marker_value.has("initial_value"):
            continue
        var marker: Dictionary = marker_value
        if str(marker.get("scope", "battle")) != "run":
            return {"success": false, "reason": "物品初始 marker 必须是 run scope"}
        var address := source_marker_address_resolver.resolve_item(
            self, item_id, marker)
        if not address.get("success", false):
            return address
        var existing := source_marker_store.entries({
            "source_kind": "item",
            "source_instance_key": address["source_instance_key"],
            "marker_id": address["marker_id"],
            "scope": "run",
        })
        # retain 条目在重新获得时继续复用其持久数据，不重新执行一次获得
        # 效果；clear 条目已经被 remove_entries 删除，会从声明初始值重建。
        if not existing.is_empty() and str(existing[0].get(
                "forget_policy", "clear")) == "retain":
            continue
        var written: Dictionary = source_marker_store.write(
            "item", address["source_instance_key"], item_id,
            address["marker_id"], "run", "set", int(marker["initial_value"]),
            address)
        if not written.get("success", false):
            return written
        if written.get("changed", false):
            marker_changes.append(_source_marker_change(
                address, "initial", written))
    recalculate_effective_max_life()
    var capacity_result := refresh_consumable_capacity_state()
    if not capacity_result.get("success", false):
        return capacity_result
    return {
        "success": true,
        "item_id": item_id,
        "marker_changes": marker_changes,
        "max_life": max_life,
    }

func remove_item(item_id: String) -> Dictionary:
    if not item_ids.has(item_id):
        return {"success": false, "reason": "物品未持有：%s" % item_id}
    var state_before := capture_mutation_state()
    var overflow_before := consumable_overflow_count
    var removed_markers: Array = []
    for entry_value in source_marker_store.entries({
            "source_kind": "item", "content_id": item_id, "scope": "run"}):
        var entry: Dictionary = entry_value
        if str(entry.get("forget_policy", "clear")) != "clear":
            continue
        removed_markers.append(_source_marker_change(
            entry, "remove", {
                "before": int(entry.get("value", 0)),
                "after": 0,
                "delta": -int(entry.get("value", 0)),
                "consumed": int(entry.get("value", 0)),
                "created": false,
                "removed": true,
                "existed_before": true,
                "exists_after": false,
                "changed": true,
            }))
    source_marker_store.remove_entries({
        "source_kind": "item", "content_id": item_id, "scope": "run"}, true)
    item_ids.erase(item_id)
    recalculate_effective_max_life()
    var capacity_result := refresh_consumable_capacity_state()
    if not capacity_result.get("success", false) \
            or int(capacity_result.get("overflow_count", 0)) > overflow_before:
        var restore_errors := replace_mutation_state(state_before)
        if not restore_errors.is_empty():
            return {"success": false, "reason": "物品移除回滚失败：%s" % (
                "；".join(restore_errors))}
        return {
            "success": false,
            "reason": (
                str(capacity_result.get("reason", "消耗品容量查询失败"))
                if not capacity_result.get("success", false)
                else "移除该来源会使共享消耗品栏立即超容量"),
        }
    return {
        "success": true,
        "item_id": item_id,
        "removed_markers": removed_markers,
        "max_life": max_life,
        "consumable_capacity": capacity_result,
    }

func _source_marker_change(
        source: Dictionary, operation: String, result: Dictionary) -> Dictionary:
    return {
        "event_type": "source_marker_changed",
        "operation": operation,
        "source_kind": str(source.get("source_kind", "item")),
        "source_instance_key": str(source.get("source_instance_key", "")),
        "content_id": str(source.get("content_id", "")),
        "marker_id": str(source.get("marker_id", "")),
        "scope": str(source.get("scope", "run")),
        "public": bool(source.get("public", true)),
        "display_name": str(source.get("display_name", source.get(
            "marker_id", ""))),
        "contributes_to": str(source.get("contributes_to", "")),
        "forget_policy": str(source.get("forget_policy", "clear")),
        "before": int(result.get("before", 0)),
        "after": int(result.get("after", 0)),
        "delta": int(result.get("delta", 0)),
        "consumed": int(result.get("consumed", 0)),
        "created": bool(result.get("created", false)),
        "removed": bool(result.get("removed", false)),
        "existed_before": bool(result.get("existed_before", false)),
        "exists_after": bool(result.get("exists_after", false)),
    }

func apply_insight_growth(
        hand_id: String,
        candidates: Array = [],
        rng: RandomNumberGenerator = null,
        _source_metadata: Dictionary = {}) -> Dictionary:
    var progression: Dictionary = hand_technique_progression.get(hand_id, {
        "slot_count": 1,
        "sequence": [],
    }).duplicate(true)
    var rng_state_before := rng.state if rng != null else 0
    var plan: Dictionary = InsightGrowthServiceScript.resolve(
        self,
        technique_loadout_policy,
        hand_id,
        progression,
        hand_technique_progression,
        learned_technique_ids,
        candidates,
        rng)
    if not plan.get("success", false):
        if rng != null:
            rng.state = rng_state_before
        return plan
    hand_technique_progression = plan["proposed_progression"].duplicate(true)
    learned_technique_ids.assign(plan["proposed_learned_ids"])
    return InsightGrowthServiceScript.public_result(plan)

func apply_insight(
        hand_id: String,
        candidates: Array = [],
        rng: RandomNumberGenerator = null) -> Dictionary:
    return apply_insight_growth(hand_id, candidates, rng)

func experience_interest_parameters() -> Dictionary:
    return {
        "step": EXPERIENCE_INTEREST_STEP,
        "cap": EXPERIENCE_INTEREST_CAP,
    }

## Run 资源整数查询的唯一 Growth 入口。该方法只读状态；正式获得路径由
## RunMutationService 负责把失败传播到事务边界。
func effective_experience_gain_result(
        requested_gain: int,
        context: Dictionary = {}) -> Dictionary:
    var requested := maxi(0, requested_gain)
    var resolved := _resolve_run_int_query(
        "experience_gain_query", "run_resource", "experience",
        requested, context.get("metadata", {}),
        context.get("source_snapshot", []))
    if not resolved.get("success", false):
        return resolved
    var effective := int(resolved.get("effective_value", requested))
    if effective < 0 or effective > requested:
        return {
            "success": false,
            "reason": "历练获得查询结果必须位于 0～%d" % requested,
            "query": resolved,
        }
    resolved["requested_gain"] = requested
    resolved["effective_gain"] = effective
    return resolved

func effective_consumable_capacity_result(
        context: Dictionary = {}) -> Dictionary:
    var metadata: Dictionary = context.get("metadata", {}).duplicate(true)
    metadata.merge({
        "base_capacity": BASE_CONSUMABLE_CAPACITY,
        "current_count": consumable_ids.size(),
    }, true)
    var resolved := _resolve_run_int_query(
        "consumable_capacity_query", "growth_inventory", "consumables",
        BASE_CONSUMABLE_CAPACITY, metadata,
        context.get("source_snapshot", []))
    if not resolved.get("success", false):
        return resolved
    var capacity := maxi(0, int(resolved.get(
        "effective_value", BASE_CONSUMABLE_CAPACITY)))
    var current_count := consumable_ids.size()
    resolved.merge({
        "base_capacity": BASE_CONSUMABLE_CAPACITY,
        "effective_capacity": capacity,
        "current_count": current_count,
        "available_slots": maxi(capacity - current_count, 0),
        "overflow_count": maxi(current_count - capacity, 0),
    }, true)
    return resolved

func refresh_consumable_capacity_state() -> Dictionary:
    var result := effective_consumable_capacity_result()
    if not result.get("success", false):
        return result
    consumable_capacity_at_last_commit = int(result["effective_capacity"])
    consumable_overflow_count = int(result["overflow_count"])
    return result

func effective_experience_interest_cap_result(
        context: Dictionary = {}) -> Dictionary:
    var resolved := _resolve_run_int_query(
        "experience_interest_cap_query", "run_resource",
        "experience_interest", EXPERIENCE_INTEREST_CAP, {
            "base_cap": EXPERIENCE_INTEREST_CAP,
            "experience": experience,
            "settlement_token": str(context.get("settlement_token", "")),
        }, context.get("source_snapshot", []))
    if not resolved.get("success", false):
        return resolved
    resolved["base_cap"] = EXPERIENCE_INTEREST_CAP
    resolved["effective_cap"] = maxi(0, int(resolved.get(
        "effective_value", EXPERIENCE_INTEREST_CAP)))
    return resolved

func _resolve_run_int_query(
        hook: String,
        subject_kind: String,
        subject_id: String,
        base_value: int,
        metadata: Dictionary,
        source_snapshot: Array = []) -> Dictionary:
    if _int_policy_resolver == null:
        return {
            "success": true,
            "hook": hook,
            "subject_kind": subject_kind,
            "subject_id": subject_id,
            "base_value": base_value,
            "effective_value": base_value,
            "modifier_breakdown": [],
            "source_fingerprint": "unconfigured",
            "errors": [],
        }
    var values := {
        "hook": hook,
        "owner": self,
        "actor": self,
        "subject_kind": subject_kind,
        "subject_id": subject_id,
        "base_value": base_value,
        "metadata": metadata.duplicate(true),
    }
    if not source_snapshot.is_empty():
        values["source_snapshot"] = source_snapshot.duplicate(true)
    var query = _int_policy_resolver.resolve(
        IntQueryRequestScript.new().configure(values))
    var result: Dictionary = query.to_dict()
    if not result.get("success", false):
        result["reason"] = "；".join(result.get("errors", []))
    return result

func apply_experience_interest() -> Dictionary:
    # 仅保留给旧工具/测试的数值兼容入口。生产节点结算必须调用
    # RunMutationService.settle_experience_interest_in_place()，以产生 canonical
    # 事实、执行上限查询并进入 RunAggregateTransaction。
    var experience_before := experience
    var parameters := experience_interest_parameters()
    var step := int(parameters["step"])
    var cap := int(parameters["cap"])
    var amount := mini(
        floori(experience_before / step),
        cap)
    experience += amount
    return {
        "amount": amount,
        "experience_before": experience_before,
        "experience_after": experience,
        "step": step,
        "cap": cap,
    }

func purchase_consumable(consumable_id: String, price: int, practice_available: bool) -> Dictionary:
    # 旧领域探针的兼容入口；RunSession/PracticeService 生产购买不调用本方法。
    if not practice_available:
        return {"success": false, "reason": "节点进行中不能修习"}
    if practice_purchases.has(consumable_id):
        return {"success": false, "reason": "本次修习已购买"}
    var capacity := effective_consumable_capacity_result()
    if not capacity.get("success", false):
        return capacity
    if int(capacity.get("available_slots", 0)) <= 0:
        return {"success": false, "reason": "共享消耗品栏已满"}
    if experience < price:
        return {"success": false, "reason": "历练不足"}
    experience -= price
    consumable_ids.append(consumable_id)
    practice_purchases[consumable_id] = true
    return {"success": true, "remaining_experience": experience}

func to_progress_snapshot() -> RunProgressSnapshot:
    refresh_consumable_capacity_state()
    return RunProgressSnapshotScript.from_dict({
        "consumable_ids": consumable_ids.duplicate(),
        "item_ids": item_ids.duplicate(),
        "learned_technique_ids": learned_technique_ids.duplicate(),
        "learned_inner_skill_ids": learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(),
        "technique_slot_index": technique_slot_index,
        "forgotten_inner_skill_count": forgotten_inner_skill_count,
        "run_deck": run_deck.to_snapshot(),
        "life": life,
        "max_life": max_life,
        "base_max_life": base_max_life,
        "source_marker_state": source_marker_store.snapshot("run"),
        "experience": experience,
        "free_meditation_charge": free_meditation_charge,
        "experience_operation_receipts": experience_operation_receipts.duplicate(true),
        "consumable_capacity": consumable_capacity_at_last_commit,
        "consumable_overflow_count": consumable_overflow_count,
        "hand_technique_progression": hand_technique_progression.duplicate(true),
        "practice_shop_state": practice_shop_snapshot(),
        "consumable_use_sequence": consumable_use_sequence,
        "last_recallable_consumable_id": last_recallable_consumable_id,
        "base_hand_limit_modifier": base_hand_limit_modifier,
        "hand_technique_multiplier_modifiers": hand_technique_multiplier_modifiers.duplicate(true),
        "used_unique_consumable_ids": used_unique_consumable_ids.duplicate(),
        "run_combat_history_state": run_combat_history.snapshot(),
        "passive_counter_state": passive_counter_store.capture_state(),
    })

func apply_progress_snapshot(progress_snapshot: RunProgressSnapshot) -> void:
    if progress_snapshot.has_consumable_ids:
        consumable_ids.assign(progress_snapshot.consumable_ids)
    if progress_snapshot.has_item_ids:
        item_ids.assign(progress_snapshot.item_ids)
    if progress_snapshot.has_hand_technique_progression:
        hand_technique_progression = progress_snapshot.hand_technique_progression.duplicate(true)
    if progress_snapshot.has_practice_shop_state:
        practice_shop_state = normalized_practice_shop_state(
            progress_snapshot.practice_shop_state)
    if progress_snapshot.has_consumable_use_sequence:
        consumable_use_sequence = progress_snapshot.consumable_use_sequence
    if progress_snapshot.has_last_recallable_consumable_id:
        last_recallable_consumable_id = (
            progress_snapshot.last_recallable_consumable_id)
    if progress_snapshot.has_base_hand_limit_modifier:
        base_hand_limit_modifier = progress_snapshot.base_hand_limit_modifier
    if progress_snapshot.has_hand_technique_multiplier_modifiers:
        hand_technique_multiplier_modifiers = (
            progress_snapshot.hand_technique_multiplier_modifiers.duplicate(true))
    if progress_snapshot.has_used_unique_consumable_ids:
        used_unique_consumable_ids.assign(
            progress_snapshot.used_unique_consumable_ids)
    if progress_snapshot.has_run_combat_history_state:
        var history_errors: Array[String] = run_combat_history.restore_snapshot(
            progress_snapshot.run_combat_history_state)
        if not history_errors.is_empty():
            push_error("无法导入本局战斗历史：%s" % "；".join(history_errors))
    if progress_snapshot.has_passive_counter_state:
        var counter_errors: Array[String] = passive_counter_store.replace_state(
            progress_snapshot.passive_counter_state)
        if not counter_errors.is_empty():
            push_error("无法导入本局被动计数器：%s" % "；".join(counter_errors))
    if progress_snapshot.has_learned_technique_ids:
        learned_technique_ids.assign(progress_snapshot.learned_technique_ids)
    if progress_snapshot.has_learned_inner_skill_ids:
        learned_inner_skill_ids.assign(progress_snapshot.learned_inner_skill_ids)
    if progress_snapshot.has_equipped_inner_skill_ids:
        equipped_inner_skill_ids.assign(progress_snapshot.equipped_inner_skill_ids)
    if progress_snapshot.has_technique_slot_index:
        technique_slot_index = progress_snapshot.technique_slot_index
    if progress_snapshot.has_forgotten_inner_skill_count:
        forgotten_inner_skill_count = progress_snapshot.forgotten_inner_skill_count
    if progress_snapshot.has_equipped_inner_skill_ids \
            or progress_snapshot.has_technique_slot_index:
        technique_slot_index = clampi(
            technique_slot_index, 0, equipped_inner_skill_ids.size())
    if progress_snapshot.has_run_deck and not progress_snapshot.run_deck.is_empty():
        var errors: Array[String] = run_deck.restore_snapshot(progress_snapshot.run_deck)
        if not errors.is_empty():
            push_error("无法导入本局牌组：%s" % "；".join(errors))
    if progress_snapshot.has_max_life:
        max_life = progress_snapshot.max_life
    if progress_snapshot.has_base_max_life:
        base_max_life = progress_snapshot.base_max_life
    elif progress_snapshot.has_max_life:
        base_max_life = progress_snapshot.max_life
    if progress_snapshot.has_source_marker_state:
        var marker_errors: Array[String] = source_marker_store.restore_snapshot(
            progress_snapshot.source_marker_state)
        if not marker_errors.is_empty():
            push_error("无法导入本局来源标识：%s" % "；".join(marker_errors))
    if progress_snapshot.has_life:
        life = progress_snapshot.life
    if progress_snapshot.has_experience:
        experience = progress_snapshot.experience
    if progress_snapshot.has_free_meditation_charge:
        free_meditation_charge = progress_snapshot.free_meditation_charge
    if progress_snapshot.has_experience_operation_receipts:
        experience_operation_receipts = (
            progress_snapshot.experience_operation_receipts.duplicate(true))
    if progress_snapshot.has_consumable_capacity:
        consumable_capacity_at_last_commit = (
            progress_snapshot.consumable_capacity)
    if progress_snapshot.has_consumable_overflow_count:
        consumable_overflow_count = progress_snapshot.consumable_overflow_count
    if progress_snapshot.has_passive_counter_state \
            or progress_snapshot.has_learned_inner_skill_ids \
            or progress_snapshot.has_item_ids:
        passive_counter_store.clear_unowned(
            learned_inner_skill_ids, item_ids)
    recalculate_effective_max_life()
    # 恢复/战果同步可能发生在 Run 被动查询运行时装配之前。此时保留快照中
    # 明确迁移出的 capacity/overflow；装配 resolver 后 use_int_policy_resolver()
    # 会从当前活跃来源统一重算，避免把旧三格存档先静默改写为非 overflow。
    if _int_policy_resolver != null:
        refresh_consumable_capacity_state()

func grow_life_to(new_max_life: int) -> void:
    var increase := new_max_life - base_max_life
    base_max_life = new_max_life
    recalculate_effective_max_life()
    life = mini(life + increase, max_life)

func recalculate_effective_max_life() -> int:
    var active_sources := active_source_content_ids()
    max_life = source_contributed_stat_service.effective_max_life(
        base_max_life, source_marker_store, active_sources)
    life = mini(life, max_life)
    return max_life

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
        active["item"][str(item_id)] = true
    return active

func apply_to_battle_side(side) -> void:
    var setup_service = _battle_setup_service_for(side)
    var progress_snapshot := to_progress_snapshot()
    var non_deck_result: Dictionary = setup_service.apply_non_deck_progress(
        side, progress_snapshot)
    if not non_deck_result.get("success", false):
        push_error("无法应用玩家战斗进度：%s" % str(
            non_deck_result.get("reason", "战斗进度校验失败")))
        return
    if side.technique_sequence_book != null:
        var progression_result: Dictionary = (
            setup_service.apply_player_technique_progression(
                side, side.technique_sequence_book, progress_snapshot))
        if not progression_result.get("success", false):
            push_error("无法应用玩家功法配装：%s" % str(
                progression_result.get("reason", "配装校验失败")))
            return
    side.recalculate_effective_max_life()
    var battle_run_deck = setup_service.run_deck_from_progress(progress_snapshot)
    var no_shuffle_rng := RandomNumberGenerator.new()
    side.replace_deck(battle_run_deck.create_battle_cards(), no_shuffle_rng, false)

func sync_from_battle_side(side) -> void:
    var progress_snapshot: RunProgressSnapshot = _battle_setup_service_for(
        side).capture_progress(side, run_deck)
    apply_progress_snapshot(progress_snapshot)

func _battle_setup_service_for(side):
    var catalog = _content_catalog
    if catalog == null and side != null and side.has_method("content_catalog"):
        catalog = side.content_catalog()
    return BattleSetupServiceScript.new(catalog)

func current_base_hand_limit() -> int:
    return maxi(1, 8 + base_hand_limit_modifier)
