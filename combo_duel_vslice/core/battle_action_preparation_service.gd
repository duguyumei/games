class_name BattleActionPreparationService
extends RefCounted

## 玩家行动提案在牌区 staging 之后、行动事务开始之前的准备服务。
##
## 本服务只负责协同提案、正式冻结、正式确认和功法值形成事务；不移动牌区、
## 不消费行动次数、不锁定意图，也不开始或推进 BattleActionTransaction。

const SequenceBookScript = preload("res://core/sequence_book.gd")
const SameQiRuleScript = preload("res://core/same_qi_rule.gd")
const ChoiceRequestScript = preload(
    "res://core/effects/battle_choice_request.gd")

var player
var enemy
var action_resolver
var sequence_book
var preview_for_side: Callable
var turn_number_reader: Callable
var _confirmation_serial: int = 0
var _confirmation_state: Dictionary = {}


func _init(
        player_side,
        enemy_side,
        resolver,
        player_sequence_book,
        preview_callback: Callable,
        read_turn_number: Callable) -> void:
    player = player_side
    enemy = enemy_side
    action_resolver = resolver
    sequence_book = player_sequence_book
    preview_for_side = preview_callback
    turn_number_reader = read_turn_number


func reset() -> void:
    if not _confirmation_state.is_empty():
        rollback_confirmation("行动准备服务重置")
    _confirmation_serial = 0


func begin_confirmation(side, proposal, mode: String) -> Dictionary:
    if not _confirmation_state.is_empty():
        return {"success": false, "reason": "已有未完成的行动确认支付事务"}
    _confirmation_serial += 1
    var action_token := "%s:action-confirm:%06d" % [
        str(side.owner_id), _confirmation_serial]
    var transaction: Dictionary = \
        action_resolver.effect_ports.begin_effect_mutation_transaction()
    transaction["passive_effect_state"] = \
        action_resolver.passive_rule_runtime.capture_battle_effect_command_state()
    _confirmation_state = {
        "side": side,
        "proposal": proposal,
        "mode": mode,
        "action_token": action_token,
        "transaction": transaction,
        "preview_before": proposal.preview.duplicate(true),
        "groups_before": proposal.groups.duplicate(true),
        "entries": [],
        "entry_index": 0,
        "choice_request": null,
        "choice_snapshot": {},
        "resolved_request_ids": [],
        "payment_receipts": [],
        "plans_built": false,
    }
    _assign_group_action_tokens(proposal, action_token)
    return {"success": true, "action_token": action_token}


func prepare_confirmation_payments(side, proposal) -> Dictionary:
    if _confirmation_state.is_empty() \
            or _confirmation_state.get("side") != side \
            or _confirmation_state.get("proposal") != proposal:
        return {"success": false, "reason": "行动确认支付事务与当前提案不匹配"}
    if not bool(_confirmation_state.get("plans_built", false)):
        var built := _build_payment_entries(side, proposal)
        if not built.get("success", false):
            return _fail_confirmation(str(built.get(
                "reason", "行动确认支付计划建立失败")))
        _confirmation_state["plans_built"] = true
    return _continue_confirmation_payments()


func has_pending_choice() -> bool:
    return not _confirmation_state.is_empty() \
        and _confirmation_state.get("choice_request") != null


func pending_choice_snapshot() -> Dictionary:
    return _confirmation_state.get("choice_snapshot", {}).duplicate(true) \
        if has_pending_choice() else {}


func resolve_confirmation_choice(
        request_id: String, selected_card_ids: Array) -> Dictionary:
    if not has_pending_choice():
        return {"success": false, "reason": "当前没有等待中的行动确认支付选择"}
    var request = _confirmation_state.get("choice_request")
    if request_id == "" or request_id != str(request.request_id):
        return _pending_failure("选择 request_id 与行动确认支付请求不匹配")
    if _confirmation_state.get(
            "resolved_request_ids", []).has(request_id):
        return _pending_failure("行动确认支付请求已经成功提交")
    var check: Dictionary = request.validate_selection(selected_card_ids)
    if not check.get("ok", false):
        return _pending_failure(str(check.get("reason", "支付目标选择不合法")))
    var entry: Dictionary = _current_payment_entry()
    var applied := _apply_payment_entry(
        entry, request.selected_cards(selected_card_ids), request_id)
    if not applied.get("success", false):
        return _fail_confirmation(str(applied.get(
            "reason", "行动确认资源支付失败")))
    _confirmation_state["resolved_request_ids"].append(request_id)
    _confirmation_state["choice_request"] = null
    _confirmation_state["choice_snapshot"] = {}
    _confirmation_state["entry_index"] = int(
        _confirmation_state.get("entry_index", 0)) + 1
    return _continue_confirmation_payments()


func commit_confirmation() -> Dictionary:
    if _confirmation_state.is_empty():
        return {"success": false, "reason": "当前没有可提交的行动确认支付事务"}
    if has_pending_choice():
        return {"success": false, "reason": "行动确认支付仍在等待选择"}
    var transaction: Dictionary = _confirmation_state.get("transaction", {})
    var committed: Dictionary = \
        action_resolver.effect_ports.commit_effect_mutation_transaction(
            transaction)
    if not committed.get("success", false):
        return _fail_confirmation(str(committed.get(
            "reason", "行动确认支付事务提交失败")))
    var receipts: Array = _confirmation_state.get(
        "payment_receipts", []).duplicate(true)
    _confirmation_state.clear()
    return {"success": true, "payment_receipts": receipts}


func rollback_confirmation(reason: String = "行动确认失败") -> Dictionary:
    if _confirmation_state.is_empty():
        return {"success": true, "rolled_back": false, "reason": reason}
    var side = _confirmation_state.get("side")
    var proposal = _confirmation_state.get("proposal")
    var transaction: Dictionary = _confirmation_state.get("transaction", {})
    var rolled_back: bool = \
        action_resolver.effect_ports.rollback_effect_mutation_transaction(
            transaction)
    action_resolver.passive_rule_runtime.restore_battle_effect_command_state(
        transaction.get("passive_effect_state", {}))
    if proposal != null:
        proposal.preview.clear()
        proposal.preview.merge(
            _confirmation_state.get("preview_before", {}).duplicate(true), true)
        proposal.groups.assign(
            _confirmation_state.get("groups_before", []).duplicate(true))
    _confirmation_state.clear()
    return {
        "success": rolled_back,
        "rolled_back": true,
        "reason": reason,
        "owner_id": str(side.owner_id) if side != null else "",
    }


func confirmation_snapshot() -> Dictionary:
    if _confirmation_state.is_empty():
        return {}
    return {
        "action_token": str(_confirmation_state.get("action_token", "")),
        "mode": str(_confirmation_state.get("mode", "")),
        "entry_index": int(_confirmation_state.get("entry_index", 0)),
        "entry_count": _confirmation_state.get("entries", []).size(),
        "pending_choice": has_pending_choice(),
        "choice_request": pending_choice_snapshot(),
        "payment_receipts": _confirmation_state.get(
            "payment_receipts", []).duplicate(true),
    }


func _assign_group_action_tokens(proposal, action_token: String) -> void:
    proposal.preview["reshape_action_token"] = action_token
    for group_index in range(1, proposal.groups.size()):
        var group: Dictionary = proposal.groups[group_index]
        var preview: Dictionary = group.get("preview", {})
        preview["reshape_action_token"] = "%s:group:%d" % [
            action_token, group_index]


func _build_payment_entries(side, proposal) -> Dictionary:
    var entries: Array = []
    var groups := _proposal_group_previews(proposal)
    for group_entry in groups:
        var preview: Dictionary = group_entry["preview"]
        var context_values := {
            "owner": side,
            "actor": side,
            "target": _target_for(side),
            "round_number": int(turn_number_reader.call()),
            "payload": {
                "action_token": str(preview.get(
                    "reshape_action_token", "")),
                "group_index": int(group_entry["group_index"]),
                "group_kind": str(group_entry["group_kind"]),
                "hand_id": str(preview.get("hand", {}).get("id", "")),
                "effect_context_values": {
                    "actor": side,
                    "target": _target_for(side),
                    "owner": side,
                    "hand_result": preview.get("hand", {}),
                    "played_cards": preview.get("cards", []),
                    "values": preview.get("values", {}),
                    "group_snapshot": preview.get("group_snapshot", {}),
                    "action_token": str(preview.get(
                        "reshape_action_token", "")),
                    "source_kind": "action_confirmation",
                    "ports": action_resolver.effect_ports,
                    "card_identity_policy": side.card_identity_policy,
                },
            },
        }
        var plan = action_resolver.passive_rule_runtime.build_execution_plan(
            "action_confirmation_payment", context_values)
        if not plan.is_valid():
            return {"success": false, "reason": "；".join(plan.errors)}
        for invocation_index in range(plan.invocations.size()):
            var invocation = plan.invocations[invocation_index]
            var invocation_context = invocation.context.for_invocation(invocation)
            var executed: Dictionary = \
                action_resolver.passive_rule_runtime.execute_invocation(
                    invocation, invocation_context, "read")
            if not executed.get("success", false):
                return executed
            var plans = executed.get("result", {}).get("payment_plans", [])
            if not plans is Array:
                return {"success": false, "reason": "支付 Handler 必须返回 payment_plans 数组"}
            for plan_index in range(plans.size()):
                entries.append({
                    "group_index": int(group_entry["group_index"]),
                    "group_kind": str(group_entry["group_kind"]),
                    "preview": preview,
                    "invocation": invocation,
                    "invocation_context": invocation_context,
                    "invocation_index": invocation_index,
                    "plan_index": plan_index,
                    "plan": plans[plan_index].duplicate(true),
                })
    _confirmation_state["entries"] = entries
    return {"success": true, "entry_count": entries.size()}


func _continue_confirmation_payments() -> Dictionary:
    var entries: Array = _confirmation_state.get("entries", [])
    while int(_confirmation_state.get("entry_index", 0)) < entries.size():
        var entry: Dictionary = _current_payment_entry()
        var request_result := _build_payment_request(entry)
        if not request_result.get("success", false):
            return _fail_confirmation(str(request_result.get(
                "reason", "行动确认支付候选查询失败")))
        if bool(request_result.get("skip", false)):
            _record_skipped_payment(entry, str(request_result.get("reason", "")))
            _confirmation_state["entry_index"] = int(
                _confirmation_state.get("entry_index", 0)) + 1
            continue
        var request = request_result["request"]
        if request.should_auto_resolve():
            var applied := _apply_payment_entry(
                entry, request.selected_cards(request.candidate_ids()),
                str(request.request_id))
            if not applied.get("success", false):
                return _fail_confirmation(str(applied.get(
                    "reason", "行动确认资源自动支付失败")))
            _confirmation_state["resolved_request_ids"].append(
                str(request.request_id))
            _confirmation_state["entry_index"] = int(
                _confirmation_state.get("entry_index", 0)) + 1
            continue
        _confirmation_state["choice_request"] = request
        _confirmation_state["choice_snapshot"] = request.snapshot()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": request.snapshot(),
            "payment_receipts": _confirmation_state.get(
                "payment_receipts", []).duplicate(true),
        }
    return {
        "success": true,
        "pending_choice": false,
        "payment_receipts": _confirmation_state.get(
            "payment_receipts", []).duplicate(true),
    }


func _build_payment_request(entry: Dictionary) -> Dictionary:
    var payment_plan: Dictionary = entry.get("plan", {})
    var invocation = entry.get("invocation")
    var context = entry.get("invocation_context").effect_context_for(
        invocation.source)
    context.ports = action_resolver.effect_ports
    var query_spec: Dictionary = payment_plan.get("query", {}).duplicate(true)
    query_spec["side"] = str(query_spec.get("side", "actor"))
    query_spec["zone"] = str(query_spec.get("zone", "staging"))
    query_spec["card_identity_policy"] = \
        _confirmation_state.get("side").card_identity_policy
    var query_result: Dictionary = action_resolver.effect_ports.query_effect_targets(
        context, query_spec, action_resolver.rng)
    if not query_result.get("success", false):
        return query_result
    var preview: Dictionary = entry.get("preview", {})
    var contributing: Array = preview.get(
        "group_snapshot", {}).get("contributing_cards", [])
    if contributing.is_empty():
        contributing = preview.get("hand", {}).get("contributing", [])
    var contributing_ids: Array[String] = []
    for card in contributing:
        contributing_ids.append(str(card.id))
    var candidates: Array = []
    for card in query_result.get("cards", []):
        if not contributing_ids.has(str(card.id)):
            continue
        if str(payment_plan.get("payment_kind", "")) == "blazing_layers" \
                and int(card.total_blazing_layers()) <= 0:
            continue
        candidates.append(card)
    var optional := bool(payment_plan.get("optional", false))
    if candidates.is_empty():
        if optional or str(payment_plan.get(
                "insufficient_policy", "skip")) == "skip":
            return {"success": true, "skip": true, "reason": "没有合法支付目标"}
        return {"success": false, "reason": "行动确认支付缺少合法目标"}
    var request_id := "%s:payment:%d:%d:%d:%s" % [
        str(entry.get("preview", {}).get("reshape_action_token", "")),
        int(entry.get("group_index", 0)),
        int(entry.get("invocation_index", 0)),
        int(entry.get("plan_index", 0)),
        str(invocation.source.source_instance_key).sha256_text().left(12),
    ]
    var request = ChoiceRequestScript.new().configure({
        "request_id": request_id,
        "prompt": str(payment_plan.get("prompt", "请选择支付资源的真气")),
        "chooser": "actor",
        "minimum": 0 if optional else 1,
        "maximum": 1,
        "insufficient_policy": str(payment_plan.get(
            "insufficient_policy", "skip")),
        "ordered": false,
        "candidates": candidates,
        "metadata": {
            "choice_kind": "action_confirmation_resource_payment",
            "group_index": int(entry.get("group_index", 0)),
            "group_kind": str(entry.get("group_kind", "")),
            "hand_id": str(entry.get("preview", {}).get(
                "hand", {}).get("id", "")),
            "source_kind": str(invocation.source.source_kind),
            "source_id": str(invocation.source.content_id),
            "source_instance_key": str(invocation.source.source_instance_key),
            "payment_kind": str(payment_plan.get("payment_kind", "")),
            "payment_method": str(payment_plan.get("payment_method", "")),
        },
    })
    var validation: Dictionary = request.validate_definition()
    if not validation.get("ok", false):
        return {"success": false, "reason": validation.get(
            "reason", "行动确认支付请求无效")}
    if request.requires_failure():
        return {"success": false, "reason": "行动确认支付候选不足"}
    return {"success": true, "request": request}


func _apply_payment_entry(
        entry: Dictionary, selected_cards: Array, request_id: String) -> Dictionary:
    var payment_plan: Dictionary = entry.get("plan", {})
    var invocation = entry.get("invocation")
    var receipt := _payment_receipt_base(entry, request_id)
    if selected_cards.is_empty():
        if not bool(payment_plan.get("optional", false)):
            return {"success": false, "reason": "必选支付不能跳过"}
        receipt["skipped"] = true
        receipt["success"] = true
        _append_payment_receipt(entry, receipt)
        return {"success": true, "receipt": receipt}
    var card = selected_cards[0]
    var paid := 0
    var mutation: Dictionary = {}
    match [str(payment_plan.get("payment_kind", "")),
            str(payment_plan.get("payment_method", ""))]:
        ["blazing_layers", "remove_all_layers"]:
            mutation = action_resolver.effect_ports.remove_all_blazing_layers(
                card,
                str(invocation.source.definition.get(
                    "name", invocation.source.content_id)), {
                    "action_token": str(entry.get("preview", {}).get(
                        "reshape_action_token", "")),
                    "source_kind": str(invocation.source.source_kind),
                    "source_id": str(invocation.source.content_id),
                    "source_instance_key": str(
                        invocation.source.source_instance_key),
                    "trigger_mode": "action_confirmation",
                    "payment_request_id": request_id,
                })
            paid = int(mutation.get("removed_layers", 0))
        _:
            return {"success": false, "reason": "未知行动确认支付方式"}
    if not mutation.get("success", false):
        return mutation
    var fixed_delta := paid * int(payment_plan.get(
        "power_fixed_per_unit", 0))
    var preview: Dictionary = entry["preview"]
    preview["action_confirmation_power_fixed"] = int(preview.get(
        "action_confirmation_power_fixed", 0)) + fixed_delta
    receipt.merge({
        "success": true,
        "skipped": false,
        "card_instance_id": str(card.id),
        "paid": paid,
        "power_fixed_per_unit": int(payment_plan.get(
            "power_fixed_per_unit", 0)),
        "power_fixed_delta": fixed_delta,
        "mutation": mutation.duplicate(true),
    }, true)
    _append_payment_receipt(entry, receipt)
    return {"success": true, "receipt": receipt}


func _record_skipped_payment(entry: Dictionary, reason: String) -> void:
    var receipt := _payment_receipt_base(entry, "")
    receipt.merge({
        "success": true, "skipped": true, "paid": 0,
        "power_fixed_delta": 0, "reason": reason,
    }, true)
    _append_payment_receipt(entry, receipt)


func _payment_receipt_base(entry: Dictionary, request_id: String) -> Dictionary:
    var invocation = entry.get("invocation")
    return {
        "request_id": request_id,
        "action_token": str(entry.get("preview", {}).get(
            "reshape_action_token", "")),
        "group_index": int(entry.get("group_index", 0)),
        "group_kind": str(entry.get("group_kind", "")),
        "source_kind": str(invocation.source.source_kind),
        "source_id": str(invocation.source.content_id),
        "source_instance_key": str(invocation.source.source_instance_key),
        "behavior_id": str(invocation.source.behavior_id),
        "behavior_index": int(invocation.source.behavior_index),
        "execution_index": int(invocation.execution_index),
        "plan_index": int(entry.get("plan_index", 0)),
        "payment_kind": str(entry.get("plan", {}).get("payment_kind", "")),
        "payment_method": str(entry.get("plan", {}).get("payment_method", "")),
    }


func _append_payment_receipt(entry: Dictionary, receipt: Dictionary) -> void:
    _confirmation_state["payment_receipts"].append(receipt.duplicate(true))
    var preview: Dictionary = entry["preview"]
    if not preview.has("action_confirmation_payment_receipts"):
        preview["action_confirmation_payment_receipts"] = []
    preview["action_confirmation_payment_receipts"].append(
        receipt.duplicate(true))


func _proposal_group_previews(proposal) -> Array:
    var result: Array = [{
        "group_index": 0, "group_kind": "main", "preview": proposal.preview}]
    for group_index in range(1, proposal.groups.size()):
        var group: Dictionary = proposal.groups[group_index]
        result.append({
            "group_index": group_index,
            "group_kind": str(group.get("kind", "cooperation")),
            "preview": group.get("preview", {}),
        })
    return result


func _current_payment_entry() -> Dictionary:
    return _confirmation_state.get("entries", [])[int(
        _confirmation_state.get("entry_index", 0))]


func _pending_failure(reason: String) -> Dictionary:
    return {
        "success": false,
        "pending_choice": true,
        "choice_request": pending_choice_snapshot(),
        "reason": reason,
    }


func _fail_confirmation(reason: String) -> Dictionary:
    rollback_confirmation(reason)
    return {"success": false, "pending_choice": false, "reason": reason}


func prepare_cooperation(
        proposal,
        cooperation_card_ids: Array) -> Dictionary:
    if cooperation_card_ids.is_empty():
        return {"success": true}
    var cooperation: Dictionary = proposal.preview.get("cooperation", {})
    if cooperation.is_empty():
        return {"success": false, "reason": "当前功法不能建立协同"}
    if not proposal.preview.get("condition", {}).get("ok", false):
        return {"success": false, "reason": "当前功法条件不满足，不能建立协同"}
    if not proposal.preview.get(
            "technique_activation", {}).get("allowed", false):
        return {"success": false, "reason": "当前功法启动被拒绝，不能建立协同"}
    if cooperation_card_ids.size() < 1 or cooperation_card_ids.size() > 5:
        return {"success": false, "reason": "协同组必须选择1～5张真气"}
    if cooperation.has("exact_card_count") \
            and cooperation_card_ids.size() != int(
                cooperation["exact_card_count"]):
        return {
            "success": false,
            "reason": "协同组必须精确选择%d张真气" % int(
                cooperation["exact_card_count"]),
        }
    for card_id in cooperation_card_ids:
        if proposal.card_ids.has(str(card_id)):
            return {
                "success": false,
                "reason": "同一张真气不能被主组和协同组重复使用",
            }

    var preview_book = SequenceBookScript.new()
    preview_book.sequences = sequence_book.sequences.duplicate(true)
    preview_book.positions = sequence_book.positions.duplicate(true)
    preview_book.advance(str(proposal.preview["hand"]["id"]))
    var cooperation_preview: Dictionary = preview_for_side.call(
        player, cooperation_card_ids, preview_book)
    if not cooperation_preview.get("valid", false):
        return {
            "success": false,
            "reason": cooperation_preview.get("reason", "协同组无效"),
        }
    if str(cooperation_preview["hand"]["id"]) != str(cooperation["hand_id"]):
        return {
            "success": false,
            "reason": "协同组必须组成%s" % str(cooperation["hand_id"]),
        }
    if not _cooperation_cards_match(
            cooperation_preview.get("cards", []), cooperation,
            proposal.preview.get("cards", [])):
        return {"success": false, "reason": "协同牌不满足功法声明的异状限制"}

    var permission_result := _query_cooperation_permission(
        proposal.preview, cooperation_preview, "preview")
    proposal.preview["cooperation_permission"] = permission_result.duplicate(true)
    if not permission_result.get("errors", []).is_empty():
        return {
            "success": false,
            "reason": permission_result.get("reason", "协同权限查询失败"),
        }
    if not permission_result.get("allowed", false):
        return {
            "success": false,
            "reason": permission_result.get("reason", "当前不能建立协同"),
        }

    var main_individual_power := int(
        proposal.preview["values"]["technique_value"])
    var cooperation_individual_power := int(
        cooperation_preview["values"]["technique_value"])
    var shared_power: int = int(floor(
        main_individual_power + cooperation_individual_power * 0.5))
    proposal.preview["values"]["technique_value"] = shared_power
    cooperation_preview["values"]["technique_value"] = shared_power
    proposal.groups.append({
        "group_index": 1,
        "kind": "cooperation",
        "card_ids": cooperation_card_ids.duplicate(),
        "preview": cooperation_preview,
        "cooperation": cooperation.duplicate(true),
        "cooperation_permission": permission_result.duplicate(true),
        "shared_power": shared_power,
        "main_individual_power": main_individual_power,
        "cooperation_individual_power": cooperation_individual_power,
    })
    var same_qi_gain_result := _refresh_same_qi_gain(proposal, false)
    if not same_qi_gain_result.get("success", false):
        proposal.groups.pop_back()
        proposal.preview["values"]["technique_value"] = main_individual_power
        return same_qi_gain_result
    return {"success": true, "shared_power": shared_power}


func finalize_staged_proposal(side, proposal) -> Dictionary:
    _restore_individual_cooperation_power(proposal)
    var target = _target_for(side)
    var main_result: Dictionary = action_resolver.finalize_action_preview(
        side, proposal.preview, target, turn_number_reader.call())
    if not main_result.get("success", false):
        return main_result
    for group in proposal.groups.slice(1):
        var group_preview: Dictionary = group.get("preview", {})
        var group_result: Dictionary = action_resolver.finalize_action_preview(
            side, group_preview, target, turn_number_reader.call())
        if not group_result.get("success", false):
            return group_result
    if proposal.groups.size() > 1:
        if not proposal.preview.get("technique_activation", {}).get(
                "allowed", false):
            return {
                "success": false,
                "reason": "正式确认时主功法启动被拒绝，协同行动整体失效",
            }
        var cooperation_preview: Dictionary = proposal.groups[1].get(
            "preview", {})
        var cooperation_definition: Dictionary = proposal.groups[1].get(
            "cooperation", {})
        if cooperation_definition.has("exact_card_count") \
                and cooperation_preview.get("cards", []).size() != int(
                    cooperation_definition["exact_card_count"]):
            return {"success": false, "reason": "正式确认时协同牌数量不符"}
        if not _cooperation_cards_match(
                cooperation_preview.get("cards", []), cooperation_definition,
                proposal.preview.get("cards", [])):
            return {"success": false, "reason": "正式确认时协同牌异状限制不符"}
        var cooperation_permission := _query_cooperation_permission(
            proposal.preview, cooperation_preview, "action_confirmed")
        cooperation_permission["frozen"] = true
        cooperation_permission["main_action_token"] = str(
            proposal.preview.get("reshape_action_token", ""))
        proposal.preview["cooperation_permission"] = \
            cooperation_permission.duplicate(true)
        proposal.groups[1]["cooperation_permission"] = \
            cooperation_permission.duplicate(true)
        if not cooperation_permission.get("errors", []).is_empty():
            return {
                "success": false,
                "reason": cooperation_permission.get(
                    "reason", "协同权限查询失败"),
            }
        if not cooperation_permission.get("allowed", false):
            return {
                "success": false,
                "reason": cooperation_permission.get(
                    "reason", "正式确认时协同被拒绝"),
            }
    var same_qi_freeze := _refresh_same_qi_gain(proposal, true)
    if not same_qi_freeze.get("success", false):
        return same_qi_freeze
    _write_payment_results_to_group_snapshots(proposal)
    var formation_commit := _commit_power_formation_transactions(side, proposal)
    if not formation_commit.get("success", false):
        rollback_power_formation(side, proposal)
        return formation_commit
    _refresh_cooperation_shared_power(proposal)
    return {"success": true}


func confirm_finalized_proposal(side, proposal) -> Dictionary:
    var target = _target_for(side)
    var main_result: Dictionary = action_resolver.confirm_finalized_action(
        side, proposal.preview, target, turn_number_reader.call())
    if not main_result.get("success", false):
        rollback_power_formation(side, proposal)
        return main_result
    for group in proposal.groups.slice(1):
        var group_result: Dictionary = action_resolver.confirm_finalized_action(
            side, group.get("preview", {}), target, turn_number_reader.call())
        if not group_result.get("success", false):
            rollback_power_formation(side, proposal)
            return group_result
    return {"success": true}


func rollback_power_formation(side, proposal) -> void:
    for group in proposal.groups.slice(1).duplicate():
        action_resolver.action_preview_service.rollback_power_formation(
            side, group.get("preview", {}))
    action_resolver.action_preview_service.rollback_power_formation(
        side, proposal.preview)


func _refresh_same_qi_gain(proposal, frozen: bool) -> Dictionary:
    var cards: Array = proposal.preview.get("cards", []).duplicate()
    for group in proposal.groups.slice(1):
        for card in group.get("preview", {}).get("cards", []):
            if not cards.has(card):
                cards.append(card)
    var action_result: Dictionary = SameQiRuleScript.analyze(
        cards, player.card_identity_policy, {
            "owner": player,
            "actor": player,
            "target": enemy,
            "action_token": str(proposal.preview.get(
                "reshape_action_token", "")),
        })
    if not action_result.get("success", false):
        return {
            "success": false,
            "reason": str(action_result.get("reason", "同气行动分组失败")),
        }
    action_result["frozen"] = frozen
    action_result["action_token"] = str(
        proposal.preview.get("reshape_action_token", ""))
    var excluded_ids: Array[String] = []
    for card in cards:
        excluded_ids.append(str(card.id))
    var legal_after := false
    for card in player.hand:
        if excluded_ids.has(str(card.id)):
            continue
        if player.status_system == null or bool(
                player.status_system.can_play_card(player, card).get(
                    "allowed", false)):
            legal_after = true
            break
    var projection: Dictionary = action_resolver.effect_ports.same_qi_projection(
        player, int(action_result.get("gain", 0)), {
            "target": enemy,
            "round_number": int(turn_number_reader.call()),
            "action_token": action_result["action_token"],
            "source_kind": "action_confirmed" if frozen else "preview",
            "legal_card_available": legal_after,
        })
    if not projection.get("success", false):
        return projection
    var technique_combo := bool(
        proposal.preview.get("intent", {}).get("technique_combo", false))
    for group in proposal.groups.slice(1):
        technique_combo = (
            technique_combo
            or bool(group.get("preview", {}).get(
                "intent", {}).get("technique_combo", false)))
    proposal.preview["same_qi"] = action_result.duplicate(true)
    var main_snapshot: Dictionary = proposal.preview.get(
        "group_snapshot", {}).duplicate(true)
    main_snapshot["action_same_qi_gain"] = int(action_result.get("gain", 0))
    main_snapshot["action_same_qi_trigger_count"] = int(
        projection.get("same_qi_trigger_count", 0))
    main_snapshot["action_same_qi_common_attributes"] = action_result.get(
        "common_attributes", []).duplicate()
    proposal.preview["group_snapshot"] = main_snapshot
    for field in [
            "same_qi_gain", "same_qi_before", "same_qi_capacity",
            "same_qi_after", "same_qi_trigger_count"]:
        proposal.preview[field] = int(projection.get(field, 0))
    for group in proposal.groups.slice(1):
        var group_preview: Dictionary = group.get("preview", {})
        var group_snapshot: Dictionary = group_preview.get(
            "group_snapshot", {}).duplicate(true)
        group_snapshot["action_same_qi_gain"] = int(
            action_result.get("gain", 0))
        group_snapshot["action_same_qi_trigger_count"] = int(
            projection.get("same_qi_trigger_count", 0))
        group_snapshot["action_same_qi_common_attributes"] = action_result.get(
            "common_attributes", []).duplicate()
        group_preview["group_snapshot"] = group_snapshot
    proposal.preview["intent"]["combo"] = (
        int(projection.get("same_qi_trigger_count", 0)) > 0
        or technique_combo)
    proposal.preview["intent"]["same_qi_gain"] = int(
        projection.get("same_qi_gain", 0))
    proposal.preview["intent"]["same_qi_trigger_count"] = int(
        projection.get("same_qi_trigger_count", 0))
    return {"success": true, "same_qi": action_result}


func _commit_power_formation_transactions(side, proposal) -> Dictionary:
    var previews: Array = [proposal.preview]
    for group in proposal.groups.slice(1):
        previews.append(group.get("preview", {}))
    var receipts: Array = []
    for preview_value in previews:
        var committed: Dictionary = \
            action_resolver.action_preview_service.commit_power_formation(
                side, preview_value)
        if not committed.get("success", false):
            return committed
        if committed.get("changed", false):
            receipts.append(committed.get("receipt", {}).duplicate(true))
    proposal.preview["momentum_consume_receipts"] = receipts
    return {"success": true, "receipts": receipts}


func _query_cooperation_permission(
        main_preview: Dictionary,
        cooperation_preview: Dictionary,
        source_kind: String) -> Dictionary:
    var permission = player.battle_permission_service
    if permission == null:
        return {
            "checked": true,
            "allowed": true,
            "reason": "",
            "source_breakdown": [],
            "errors": [],
        }
    var main_cards: Array = main_preview.get("cards", [])
    var cooperation_cards: Array = cooperation_preview.get("cards", [])
    var result: Dictionary = permission.can_establish_cooperation(
        player,
        str(main_preview.get("technique_id", "")),
        str(main_preview.get("hand", {}).get("id", "")),
        str(cooperation_preview.get("technique_id", "")),
        str(cooperation_preview.get("hand", {}).get("id", "")), {
            "target": enemy,
            "round_number": int(turn_number_reader.call()),
            "main_action_token": str(main_preview.get(
                "reshape_action_token", "")),
            "main_card_instance_ids": main_cards.map(
                func(card): return str(card.id)),
            "cooperation_card_instance_ids": cooperation_cards.map(
                func(card): return str(card.id)),
            "main_preview": main_preview,
            "cooperation_preview": cooperation_preview,
            "source_kind": source_kind,
        })
    result["checked"] = true
    return result


func _cooperation_cards_match(
        cards: Array,
        cooperation: Dictionary,
        main_cards: Array = []) -> bool:
    var any_anomalies: Array = cooperation.get("card_has_any_anomaly", [])
    if not any_anomalies.is_empty():
        for card in cards:
            var matched := false
            for anomaly_value in any_anomalies:
                var anomaly: Dictionary = anomaly_value
                if card.has_anomaly(
                        str(anomaly.get("category", "")),
                        str(anomaly.get("id", ""))):
                    matched = true
                    break
            if not matched:
                return false
    if bool(cooperation.get("shares_attribute_with_main", false)):
        var shared := false
        for card in cards:
            for main_card in main_cards:
                for attribute in ["wind", "forest", "fire", "mountain"]:
                    if card.is_attribute(attribute) \
                            and main_card.is_attribute(attribute):
                        shared = true
                        break
                if shared:
                    break
            if shared:
                break
        if not shared:
            return false
    return true


func _refresh_cooperation_shared_power(proposal) -> void:
    if proposal.groups.size() < 2:
        return
    var cooperation_group: Dictionary = proposal.groups[1]
    var cooperation_preview: Dictionary = cooperation_group.get("preview", {})
    var shared_power: int = int(floor(
        int(proposal.preview.get("values", {}).get("technique_value", 0))
        + int(cooperation_preview.get(
            "values", {}).get("technique_value", 0)) * 0.5))
    proposal.preview["values"]["technique_value"] = shared_power
    cooperation_preview["values"]["technique_value"] = shared_power
    cooperation_group["shared_power"] = shared_power


func _restore_individual_cooperation_power(proposal) -> void:
    if proposal.groups.size() < 2:
        return
    var cooperation_group: Dictionary = proposal.groups[1]
    proposal.preview["values"]["technique_value"] = int(
        cooperation_group.get(
            "main_individual_power",
            proposal.preview["values"].get("technique_value", 0)))
    var cooperation_preview: Dictionary = cooperation_group.get("preview", {})
    cooperation_preview["values"]["technique_value"] = int(
        cooperation_group.get(
            "cooperation_individual_power",
            cooperation_preview.get("values", {}).get("technique_value", 0)))


func _write_payment_results_to_group_snapshots(proposal) -> void:
    for group_entry in _proposal_group_previews(proposal):
        var preview: Dictionary = group_entry["preview"]
        var snapshot: Dictionary = preview.get("group_snapshot", {})
        snapshot["action_confirmation_power_fixed"] = int(preview.get(
            "action_confirmation_power_fixed", 0))
        snapshot["action_confirmation_payment_receipts"] = preview.get(
            "action_confirmation_payment_receipts", []).duplicate(true)
        preview["group_snapshot"] = snapshot


func _target_for(side):
    return enemy if side == player else player
