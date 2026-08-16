class_name BattleActionPreparationService
extends RefCounted

## 玩家行动提案在牌区 staging 之后、行动事务开始之前的准备服务。
##
## 本服务只负责协同提案、正式冻结、正式确认和功法值形成事务；不移动牌区、
## 不消费行动次数、不锁定意图，也不开始或推进 BattleActionTransaction。

const SequenceBookScript = preload("res://core/sequence_book.gd")
const SameQiRuleScript = preload("res://core/same_qi_rule.gd")

var player
var enemy
var action_resolver
var sequence_book
var preview_for_side: Callable
var turn_number_reader: Callable


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


func _target_for(side):
    return enemy if side == player else player
