class_name RunShop
extends RefCounted

# 修习（组挑战·代码设计 v1.4 §4.2）：货架生成/购买/重掷/开槽/疗伤丹——全部静态纯函数，
# 规则参数从 mj_shop.json 字典传入（不碰 DataRepo）。确定性：货架/三选一由
# run_seed + battle_index (+ reroll_count) 派生；货架本体存 RunState（购买态跨恢复保真），
# 三选一不存（结算屏恢复时重摇同款——owned 未变则派生稳定）。


# 生成/重掷货架：武学×2＋牌灵×1（池尽则缺位），写入 state.shelf。
# 调用时机：进入修习屏（begin_visit 后）与每次重掷（reroll_count 先自增）。
static func roll_shelf(state: RunState, shop: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _shelf_key(state)
	var wuxue: Array = _pick_pool(state, shop.get("wuxue_pool", []), "wuxue", 2, rng)
	var pailing: Array = _pick_pool(state, shop.get("pailing_pool", []), "pailing", 1, rng)
	var items: Array = []
	items.append_array(wuxue)
	items.append_array(pailing)
	var size := int(shop.get("shelf_size", 3))
	if items.size() > size:
		items = items.slice(0, size)
	state.shelf = items


# 从池抽 n 件（去重：未拥有/未上架同 id）；池尽返回短于 n 的数组（「宝山已空」由 UI 明码）。
# 货架不按槽位过滤——购买时校验（修习内开槽后原货架即可买，免中途重摇）。
static func _pick_pool(state: RunState, pool: Array, cat: String, count: int, rng: RandomNumberGenerator) -> Array:
	var candidates: Array = []
	for entry in pool:
		var e: Dictionary = entry
		if state.owned_ids.has(str(e.get("id", ""))):
			continue
		if cat == "pailing" and _pailing_owned(state, str(e.get("id", ""))):
			continue
		candidates.append({
			"id": str(e.get("id", "")), "cat": cat,
			"kind": str(e.get("kind", "")), "price": int(e.get("price", 0)),
			"bought": false,
		})
	var picked: Array = []
	for _i in range(count):
		if candidates.is_empty():
			break
		var index := rng.randi_range(0, candidates.size() - 1)
		picked.append(candidates[index])
		candidates.remove_at(index)
	return picked


static func _pailing_owned(state: RunState, id_str: String) -> bool:
	return state.pailing.values().has(id_str)


static func _shelf_key(state: RunState) -> int:
	return state.run_seed + state.battle_index * 1000 + state.reroll_count * 31


static func reroll_cost(state: RunState, shop: Dictionary) -> int:
	return int(shop.get("reroll_base", 10)) + int(shop.get("reroll_step", 5)) * state.reroll_count


# 重掷：扣历练、计数+1、重新生成（历练不足或货架已空则拒绝）。
static func reroll(state: RunState, shop: Dictionary) -> bool:
	var cost := reroll_cost(state, shop)
	if state.lianli < cost or _shelf_available(state) == 0:
		return false
	state.lianli -= cost
	state.reroll_count += 1
	roll_shelf(state, shop)
	return true


static func _shelf_available(state: RunState) -> int:
	var count := 0
	for item in state.shelf:
		if not bool((item as Dictionary).get("bought", false)):
			count += 1
	return count


# 购买货架件：扣历练、入槽/待绑（牌灵购入后由 UI 让玩家选牌种，再调 state.acquire_pailing）。
# 返回 "wuxue"|"pailing"|""（失败）。
static func buy(state: RunState, shop: Dictionary, index: int) -> String:
	if index < 0 or index >= state.shelf.size():
		return ""
	var item: Dictionary = state.shelf[index]
	if bool(item.get("bought", false)):
		return ""
	if state.lianli < int(item.get("price", 0)):
		return ""
	if item.get("cat", "") == "pailing":
		state.lianli -= int(item.get("price", 0))
		item["bought"] = true
		return "pailing"  # 调用方随即弹 27 宫选牌种 → state.acquire_pailing + CodexState
	state.lianli -= int(item.get("price", 0))
	if not state.acquire_wuxue(str(item.get("id", "")), str(item.get("kind", "gongfa"))):
		state.lianli += int(item.get("price", 0))
		return ""  # 兜底：槽位校验失败回滚
	item["bought"] = true
	return "wuxue"


# 疗伤丹：固定格、每次修习限购一枚、即买即用（回血钳于上限）。
static func buy_heal(state: RunState, shop: Dictionary) -> int:
	if state.heal_bought_this_visit:
		return -1
	var heal: Dictionary = shop.get("heal_item", {})
	if state.lianli < int(heal.get("price", 0)):
		return -1
	state.lianli -= int(heal.get("price", 0))
	state.heal_bought_this_visit = true
	return state.heal_fp(int(heal.get("heal", 0)) * 100)  # 血量档以百分之一定点记账


# 开槽价：base + step × 已解锁槽总数（三轨合计）。
static func slot_unlock_cost(state: RunState, shop: Dictionary) -> int:
	var su: Dictionary = shop.get("slot_unlock", {})
	var total := 0
	for kind in state.slot_caps:
		total += int(state.slot_caps[kind]) - int((state.deck.get("slots", {}) as Dictionary).get(kind, 1))
	return int(su.get("base", 20)) + int(su.get("step", 15)) * maxi(total, 0)


# 开槽：扣款、cap+1（达上限 5 拒绝）。
static func unlock_slot(state: RunState, shop: Dictionary, kind: String) -> bool:
	var cap: int = int((shop.get("slot_unlock", {}) as Dictionary).get("cap", 5))
	if int(state.slot_caps.get(kind, 0)) >= cap:
		return false
	var cost := slot_unlock_cost(state, shop)
	if state.lianli < cost:
		return false
	if not state.unlock_slot(kind, int(state.slot_caps.get(kind, 0)) + 1):
		return false
	state.lianli -= cost
	return true


# 三选一（结算屏）：武学只刷有空位的槽类型、牌灵补位到三——奖励永远可用
# （战斗①三槽全满时＝三枚牌灵）。派生不存档（同键同款，owned 变化即换批）。
static func roll_pick3(state: RunState, shop: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = state.run_seed + (state.battle_index - 1) * 977  # 结算屏在 battle_index 前移之后
	var picks: Array = []
	var wuxue_candidates: Array = []
	for entry in shop.get("wuxue_pool", []):
		var e: Dictionary = entry
		if state.owned_ids.has(str(e.get("id", ""))):
			continue
		if state.free_slots(str(e.get("kind", "gongfa"))) <= 0:
			continue
		wuxue_candidates.append({
			"id": str(e.get("id", "")), "cat": "wuxue",
			"kind": str(e.get("kind", "")), "price": 0, "bought": false,
		})
	while picks.size() < 3 and not wuxue_candidates.is_empty():
		var index := rng.randi_range(0, wuxue_candidates.size() - 1)
		picks.append(wuxue_candidates[index])
		wuxue_candidates.remove_at(index)
	if picks.size() < 3:
		picks.append_array(_pick_pool(state, shop.get("pailing_pool", []), "pailing", 3 - picks.size(), rng))
	return picks


# 拿一（结算屏）：武学入槽（须空位）；牌灵须同时指定绑定牌种。
static func take_pick(state: RunState, id_str: String, cat: String, kind: String, tile_key := "") -> bool:
	if cat == "pailing":
		return state.acquire_pailing(id_str, tile_key)
	return state.acquire_wuxue(id_str, kind)
