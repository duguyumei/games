class_name BattlePassiveEffectPorts
extends RefCounted

## 单次 PassiveRuleInvocation 可见的战斗写操作门面。
##
## Handler 只能用稳定 scope 和卡牌实例 ID 表达意图；真实 BattleSide、统一 RNG、
## StatusSystem 与牌区数组都留在 BattleEffectPorts 之后。

const MAX_COMMANDS_PER_CHAIN := 64
const TARGET_SCOPES := ["owner", "actor", "target", "opponent"]
const ACTIVE_ZONES := ["draw_pile", "hand", "staging", "discard_pile"]

var _effect_ports_ref: WeakRef
var _context
var _receipt_store: Dictionary
var _chain_state: Dictionary
var _scenario_error: Callable
var _command_index: int = 0
var _failed_reason: String = ""

func _init(
        effect_ports,
        context,
        receipt_store: Dictionary = {},
        chain_state: Dictionary = {},
        scenario_error_callback: Callable = Callable()) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null
    _context = context
    _receipt_store = receipt_store
    _chain_state = chain_state
    if not _chain_state.has("command_count"):
        _chain_state["command_count"] = 0
    _scenario_error = scenario_error_callback

func draw_cards(
        target_scope: String,
        count: int,
        source_kind: String = "") -> Dictionary:
    var command := _begin_command("draw_cards")
    if not command["success"]:
        return command["result"]
    if count < 0:
        return _failure(command["token"], "抽牌数量不能为负数")
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var drawn: Array = _effect_ports().draw(target["side"], count, source_kind)
    return _success(command["token"], not drawn.is_empty(), {
        "target_scope": target_scope,
        "requested_count": count,
        "drawn_count": drawn.size(),
        "card_instance_ids": _card_ids(drawn),
        "source_kind": source_kind,
    })

func discard_random_cards(
        target_scope: String,
        count: int,
        source_kind: String = "") -> Dictionary:
    var command := _begin_command("discard_random_cards")
    if not command["success"]:
        return command["result"]
    if count < 0:
        return _failure(command["token"], "随机弃牌数量不能为负数")
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var rng = _effect_ports().battle_rng()
    if rng == null:
        return _failure(command["token"], "战斗统一 RNG 尚未接入")
    var discarded: Array = _effect_ports().discard_random(
        target["side"], count, rng)
    return _success(command["token"], not discarded.is_empty(), {
        "target_scope": target_scope,
        "requested_count": count,
        "discarded_count": discarded.size(),
        "card_instance_ids": _card_ids(discarded),
        "source_kind": source_kind,
    })

func discard_all_cards(
        target_scope: String,
        source_kind: String = "") -> Dictionary:
    var command := _begin_command("discard_all_cards")
    if not command["success"]:
        return command["result"]
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var discarded: Array = _effect_ports().discard_all(target["side"])
    return _success(command["token"], not discarded.is_empty(), {
        "target_scope": target_scope,
        "discarded_count": discarded.size(),
        "card_instance_ids": _card_ids(discarded),
        "source_kind": source_kind,
    })

func gain_defense(
        target_scope: String,
        amount: int,
        source_kind: String = "",
        action_token: String = "") -> Dictionary:
    var command := _begin_command("gain_defense")
    if not command["success"]:
        return command["result"]
    if amount < 0:
        return _failure(command["token"], "防御增加量不能为负数")
    var token_check := _resolve_action_token(action_token, command["token"])
    if not token_check["success"]:
        return token_check["result"]
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var before := int(target["side"].defense)
    var applied: Dictionary = _effect_ports().add_defense_result(
        target["side"], amount, source_kind, token_check["action_token"])
    if not applied.get("success", false):
        return _failure(command["token"], str(applied.get(
            "reason", "防御增加查询失败")))
    var gained: int = int(applied.get("gained", 0))
    return _success(command["token"], gained > 0, {
        "target_scope": target_scope,
        "requested_amount": amount,
        "gained": gained,
        "before": before,
        "after": int(target["side"].defense),
        "source_kind": source_kind,
        "action_token": token_check["action_token"],
    })

func deal_damage(
        actor_scope: String,
        target_scope: String,
        amount: int,
        source_kind: String,
        true_damage: bool = false,
        action_token: String = "") -> Dictionary:
    var command := _begin_command("deal_damage")
    if not command["success"]:
        return command["result"]
    if amount < 0:
        return _failure(command["token"], "伤害量不能为负数")
    var token_check := _resolve_action_token(action_token, command["token"])
    if not token_check["success"]:
        return token_check["result"]
    var actor := _resolve_scope(actor_scope, command["token"])
    if not actor["success"]:
        return actor["result"]
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var resolved: Dictionary = _effect_ports().deal_damage(
        actor["side"], target["side"], amount, source_kind,
        true_damage, token_check["action_token"])
    if not resolved.get("success", false):
        return _failure(command["token"], str(resolved.get(
            "reason", "伤害结算失败")))
    return _success(command["token"], int(resolved.get(
        "final_amount", resolved.get("requested", 0))) > 0, {
        "actor_scope": actor_scope,
        "target_scope": target_scope,
        "requested_amount": amount,
        "final_amount": int(resolved.get(
            "final_amount", resolved.get("requested", 0))),
        "defense_lost": int(resolved.get("defense_lost", 0)),
        "life_lost": int(resolved.get("life_lost", 0)),
        "true_damage": true_damage,
        "source_kind": source_kind,
        "action_token": token_check["action_token"],
    })

func move_card(
        card_instance_id: String,
        from_zone: String,
        to_zone: String,
        reason: String,
        placement: String = "top",
        source_kind: String = "") -> Dictionary:
    var command := _begin_command("move_card")
    if not command["success"]:
        return command["result"]
    if card_instance_id == "":
        return _failure(command["token"], "移动卡牌缺少实例 ID")
    if from_zone not in ACTIVE_ZONES or to_zone not in ACTIVE_ZONES:
        return _failure(command["token"], "移动卡牌使用了未知牌区")
    if placement not in ["top", "bottom"]:
        return _failure(command["token"], "移动卡牌 placement 必须是 top 或 bottom")
    var located: Dictionary = _effect_ports().locate_active_card(card_instance_id)
    if not located.get("success", false):
        return _failure(command["token"], str(located.get(
            "reason", "当前战斗不存在目标卡牌")))
    if str(located["zone"]) != from_zone:
        return _failure(command["token"], "目标卡牌不在声明的来源牌区")
    var moved: Dictionary = _effect_ports().move_card(
        located["side"], from_zone, located["side"], to_zone,
        located["card"], reason, placement, source_kind)
    if not moved.get("success", false):
        return _failure(command["token"], str(moved.get(
            "reason", "移动卡牌失败")))
    return _success(command["token"], from_zone != to_zone or placement != "top", {
        "card_instance_id": card_instance_id,
        "from_zone": from_zone,
        "to_zone": to_zone,
        "reason": reason,
        "placement": placement,
        "source_kind": source_kind,
    })

func temporarily_remove_card(
        target_scope: String,
        card_instance_id: String,
        reason: String) -> Dictionary:
    var command := _begin_command("temporarily_remove_card")
    if not command["success"]:
        return command["result"]
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var located: Dictionary = _effect_ports().locate_active_card(card_instance_id)
    if not located.get("success", false) or located.get("side") != target["side"]:
        return _failure(command["token"], "目标作用域中不存在要临时移除的卡牌")
    var removed: Dictionary = _effect_ports().temporarily_remove_card(
        target["side"], card_instance_id, reason)
    if not removed.get("success", false):
        return _failure(command["token"], str(removed.get(
            "reason", "临时移除卡牌失败")))
    return _success(command["token"], true, {
        "target_scope": target_scope,
        "card_instance_id": card_instance_id,
        "from_zone": str(removed.get("from", "")),
        "to_zone": "temporarily_removed",
        "reason": reason,
    })

func apply_card_anomaly(
        card_instance_id: String,
        category: String,
        anomaly_id: String,
        payload: Dictionary,
        source: String,
        layers: int = 1,
        replace_state: bool = false) -> Dictionary:
    var command := _begin_command("apply_card_anomaly")
    if not command["success"]:
        return command["result"]
    if card_instance_id == "" or category == "" or anomaly_id == "" or layers <= 0:
        return _failure(command["token"], "卡牌异状参数无效")
    var located: Dictionary = _effect_ports().locate_active_card(card_instance_id)
    if not located.get("success", false):
        return _failure(command["token"], str(located.get(
            "reason", "当前战斗不存在目标卡牌")))
    var permission: Dictionary = _effect_ports().can_apply_card_anomaly(
        located["card"], category, anomaly_id, replace_state)
    var permitted: bool = (
        bool(permission["allowed"])
        if permission.has("allowed")
        else bool(permission.get("success", false)))
    if not permitted:
        return _failure(command["token"], str(permission.get(
            "reason", "卡牌异状被拒绝")))
    var applied: Dictionary = _effect_ports().apply_card_anomaly(
        located["card"], category, anomaly_id, payload,
        source, layers, replace_state)
    if not applied.get("success", false):
        return _failure(command["token"], str(applied.get(
            "reason", "施加卡牌异状失败")))
    return _success(command["token"], true, {
        "card_instance_id": card_instance_id,
        "category": category,
        "anomaly_id": anomaly_id,
        "layers": layers,
        "replace_state": replace_state,
        "source": source,
    })

func place_on_draw_pile_top(
        target_scope: String,
        card_instance_id: String) -> Dictionary:
    var command := _begin_command("place_on_draw_pile_top")
    if not command["success"]:
        return command["result"]
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var located: Dictionary = _effect_ports().locate_active_card(card_instance_id)
    if not located.get("success", false) or located.get("side") != target["side"] \
            or str(located.get("zone", "")) != "draw_pile":
        return _failure(command["token"], "目标卡牌不在作用域的抽牌堆中")
    var placed: Dictionary = _effect_ports().place_on_draw_pile_top(
        target["side"], located["card"])
    if not placed.get("success", false):
        return _failure(command["token"], str(placed.get(
            "reason", "卡牌置顶失败")))
    return _success(command["token"], true, {
        "target_scope": target_scope,
        "card_instance_id": card_instance_id,
    })

func gain_battle_experience(target_scope: String, amount: int) -> Dictionary:
    var command := _begin_command("gain_battle_experience")
    if not command["success"]:
        return command["result"]
    if amount < 0:
        return _failure(command["token"], "战斗历练增加量不能为负数")
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var gained: int = int(_effect_ports().gain_battle_experience(
        target["side"], amount))
    return _success(command["token"], gained > 0, {
        "target_scope": target_scope,
        "requested_amount": amount,
        "gained": gained,
    })

func grant_extra_actions(
        target_scope: String,
        amount: int,
        source_kind: String = "") -> Dictionary:
    var command := _begin_command("grant_extra_actions")
    if not command["success"]:
        return command["result"]
    if amount < 0:
        return _failure(command["token"], "额外行动增加量不能为负数")
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var gained: int = int(_effect_ports().gain_extra_actions(
        target["side"], amount, source_kind))
    return _success(command["token"], gained > 0, {
        "target_scope": target_scope,
        "requested_amount": amount,
        "gained": gained,
        "source_kind": source_kind,
    })

func gain_same_qi(
        target_scope: String,
        amount: int,
        source_kind: String = "",
        action_token: String = "") -> Dictionary:
    var command := _begin_command("gain_same_qi")
    if not command["success"]:
        return command["result"]
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var stable_token: String = (
        action_token if action_token != "" else str(command["token"]))
    var applied: Dictionary = _effect_ports().gain_same_qi(
        target["side"], amount, source_kind, stable_token)
    if not applied.get("success", false):
        return _failure(command["token"], str(applied.get(
            "reason", "同气写入失败")))
    return _success(command["token"], not applied.get("reused", false), {
        "target_scope": target_scope,
        "amount": amount,
        "source_kind": source_kind,
        "action_token": stable_token,
        "same_qi_change": applied.duplicate(true),
    })

func add_momentum(target_scope: String, amount: int) -> Dictionary:
    var command := _begin_command("add_momentum")
    if not command["success"]:
        return command["result"]
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var before := int(target["side"].momentum_value)
    var delta: int = int(_effect_ports().add_momentum(target["side"], amount))
    var after := int(target["side"].momentum_value)
    return _success(command["token"], after != before, {
        "target_scope": target_scope,
        "amount": amount,
        "delta": delta,
        "before": before,
        "after": after,
    })

func set_momentum(target_scope: String, value: int) -> Dictionary:
    var command := _begin_command("set_momentum")
    if not command["success"]:
        return command["result"]
    var target := _resolve_scope(target_scope, command["token"])
    if not target["success"]:
        return target["result"]
    var before := int(target["side"].momentum_value)
    var after: int = int(_effect_ports().set_momentum(target["side"], value))
    return _success(command["token"], after != before, {
        "target_scope": target_scope,
        "requested_value": value,
        "before": before,
        "after": after,
    })

func _begin_command(operation: String) -> Dictionary:
    var token := _make_command_token(_command_index)
    _command_index += 1
    if _failed_reason != "":
        return {
            "success": false,
            "result": _result(false, false, _failed_reason, {}, token),
        }
    if _receipt_store.has(token):
        var reused: Dictionary = _receipt_store[token].duplicate(false)
        reused["reused"] = true
        return {"success": false, "result": reused}
    if int(_chain_state.get("command_count", 0)) >= MAX_COMMANDS_PER_CHAIN:
        var reason := "单次被动调用链写命令超过 %d 次" % MAX_COMMANDS_PER_CHAIN
        return {"success": false, "result": _failure(token, reason)}
    if _effect_ports() == null:
        return {
            "success": false,
            "result": _failure(token, "当前 Hook 没有战斗写端口"),
        }
    _chain_state["command_count"] = int(_chain_state.get("command_count", 0)) + 1
    return {"success": true, "token": token, "operation": operation}

func _resolve_scope(scope: String, command_token: String) -> Dictionary:
    if scope not in TARGET_SCOPES:
        return {
            "success": false,
            "result": _failure(command_token, "无效 target_scope：%s" % scope),
        }
    var side = null
    match scope:
        "owner": side = _context.owner
        "actor": side = _context.actor
        "target": side = _context.target
        "opponent":
            var origin = _context.owner if _context.owner != null else _context.actor
            side = _effect_ports().opponent_of(origin)
    if side == null or not _effect_ports().is_current_side(side):
        return {
            "success": false,
            "result": _failure(
                command_token, "target_scope 无法解析到当前战斗方：%s" % scope),
        }
    return {"success": true, "side": side}

func _resolve_action_token(value: String, command_token: String) -> Dictionary:
    var current := str(_context.battle_effect_scope.get("action_token", ""))
    if current == "":
        current = str(_context.payload.get("action_token", ""))
    if value != "" and current == "":
        return {
            "success": false,
            "result": _failure(command_token, "当前 Invocation 没有可用 action_token"),
        }
    if value != "" and current != "" and value != current:
        return {
            "success": false,
            "result": _failure(command_token, "Handler 不能改写当前 action_token"),
        }
    return {"success": true, "action_token": current if value == "" else value}

func _make_command_token(index: int) -> String:
    var effect_ports = _effect_ports()
    var battle_id: String = effect_ports.battle_instance_id() \
        if effect_ports != null else "battle-unavailable"
    var semantic_token := str(_context.battle_effect_scope.get("event_token", ""))
    if semantic_token == "":
        semantic_token = str(_context.payload.get("event_token", ""))
    if semantic_token == "":
        semantic_token = str(_context.battle_effect_scope.get("action_token", ""))
    if semantic_token == "":
        semantic_token = str(_context.payload.get("action_token", ""))
    if semantic_token == "":
        semantic_token = "%s:%s" % [
            _context.hook,
            str(_context.battle_effect_scope.get("timing_serial", -1))]
    var source_key := "unknown-source"
    var behavior_index := 0
    var execution_index := 0
    if _context.source != null:
        source_key = str(_context.source.source_instance_key)
        behavior_index = int(_context.source.behavior_index)
    if _context.invocation != null:
        execution_index = int(_context.invocation.execution_index)
    return "%s|%s|%s|%d|%d|%d" % [
        battle_id, semantic_token, source_key,
        behavior_index, execution_index, index]

func _success(token: String, changed: bool, payload: Dictionary) -> Dictionary:
    var result := _result(true, changed, "", payload, token)
    _receipt_store[token] = result.duplicate(false)
    return result

func _failure(token: String, reason: String) -> Dictionary:
    if _failed_reason == "":
        _failed_reason = reason
        _report_scenario_error(reason)
    return _result(false, false, reason, {}, token)

func _result(
        success: bool,
        changed: bool,
        reason: String,
        payload: Dictionary,
        token: String) -> Dictionary:
    return {
        "success": success,
        "changed": changed,
        "reason": reason,
        "payload": payload,
        "command_token": token,
        "reused": false,
    }

func _card_ids(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.id))
    return result

func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null

func _report_scenario_error(reason: String) -> void:
    if _scenario_error.is_valid():
        _scenario_error.call("战斗被动写命令失败：%s" % reason)
