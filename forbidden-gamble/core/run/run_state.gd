class_name RunState
extends RefCounted

# 组挑战·run 状态机（组挑战·代码设计 v1.4 §4.1）：唯一事实源；场景只读、按钮调方法。
# 纯逻辑：不碰 IO（存档走 RunSaver 检查点）、不碰 DataRepo（数据由调用方传入字典）。
# 一组＝3 战；血量组内带入（百分之一定点）、组终/败即终；内力每胜+1、首战锁死；
# 槽位起始 1/1/1（deck.slots）、修习可解锁至 5；修习货架存于本档（购买态跨恢复保真——
# 三选一不存，恢复时按种子重摇同款）。数值全占位。

const GROUP_SIZE := 3
const NEILI_MAX_PER := 15  # §14：单项最高 15（总量上限由胜场自然封顶）

var deck_id := ""
var deck: Dictionary = {}
var phase := "hub"  # hub | battle | settlement | xiuxi | over | victory（后两者不入档——立即 clear）
var hp_fp := 0
var lianli := 0
var last_grant := 0     # 最近一次历练入账（结算屏展示用）
var neili := {"jin": 1, "gu": 1, "qi": 1}  # 当前分配（洗点重排）
var neili_points := 3                       # 内力总量（开局 3；每胜+1——分配的守恒上界）
var neili_locked := true
var slot_caps := {"gongfa": 1, "xinfa": 1, "hushen": 1}
var loadout := {"gongfa": [], "xinfa": [], "hushen": []}
var owned_ids: Array[String] = []      # 武学＋牌灵合一已购账（三选一/货架共用去重）
var pailing := {}                      # 牌种 key（"万3"，MJTile.key() 同型）-> 牌灵 id
var battle_index := 0                  # 0/1/2
var wins := 0
var total_beats := 0
var run_seed := 0
var reroll_count := 0
var heal_bought_this_visit := false
var shelf: Array = []                  # 当前修习货架：[{id, cat: "wuxue"|"pailing", kind, price, bought}]


# deck_def＝DataRepo.mj_decks()[id] 的值拷贝；seed 由入口派生。
func start(deck_def: Dictionary, seed_value: int) -> void:
	deck_id = str(deck_def.get("id", "basic"))
	deck = deck_def.duplicate(true)
	run_seed = seed_value
	phase = "hub"
	hp_fp = int(deck.get("base_max_hp", 100)) * 100
	lianli = 0
	var dn: Dictionary = deck.get("neili", {})
	neili = {"jin": int(dn.get("jin", 1)), "gu": int(dn.get("gu", 1)), "qi": int(dn.get("qi", 1))}
	neili_points = int(neili["jin"]) + int(neili["gu"]) + int(neili["qi"])
	neili_locked = true
	var ds: Dictionary = deck.get("slots", {})
	slot_caps = {"gongfa": int(ds.get("gongfa", 1)), "xinfa": int(ds.get("xinfa", 1)), "hushen": int(ds.get("hushen", 1))}
	var dl: Dictionary = deck.get("loadout", {})
	loadout = {"gongfa": [], "xinfa": [], "hushen": []}
	owned_ids = []
	for kind in ["gongfa", "xinfa", "hushen"]:
		for wid in dl.get(kind, []):
			var id_str := str(wid)
			(loadout[kind] as Array).append(id_str)
			if not owned_ids.has(id_str):
				owned_ids.append(id_str)
	pailing = {}
	battle_index = 0
	wins = 0
	total_beats = 0
	reroll_count = 0
	heal_bought_this_visit = false
	shelf = []


func battle_seed() -> int:
	return run_seed + battle_index * 1000  # 同战重打＝同墙（存档恢复可复现）


func is_group_clear() -> bool:
	return battle_index >= GROUP_SIZE


# 装配对局 cfg（值拷贝快照；对手卡由调用方传入——DataRepo 不进本类）。
func build_match_cfg(opponent: Dictionary) -> Dictionary:
	var cfg := {
		"seed": battle_seed(),
		"player_name": str(deck.get("name", "挑战者")),
		"player_base_attack": int(deck.get("base_attack", 10)),
		"player_base_defense": int(deck.get("base_defense", 0)),
		"player_base_max_hp": int(deck.get("base_max_hp", 100)),
		"player_start_hp_fp": hp_fp,
		"player_jin_li": int(neili["jin"]),
		"player_gu_li": int(neili["gu"]),
		"player_qi_li": int(neili["qi"]),
		"player_techniques": (loadout["gongfa"] as Array).duplicate(),
		"player_defenses": (loadout["hushen"] as Array).duplicate(),
		"player_xinfa": (loadout["xinfa"] as Array).duplicate(),
		"player_pailing": _pailing_list(),
		"enemy_name": str(opponent.get("name", "对手")),
		"enemy_base_attack": int(opponent.get("base_attack", 10)),
		"enemy_base_defense": int(opponent.get("base_defense", 0)),
		"enemy_base_max_hp": int(opponent.get("base_max_hp", 100)),
		"enemy_jin_li": int((opponent.get("neili", {}) as Dictionary).get("jin", 1)),
		"enemy_gu_li": int((opponent.get("neili", {}) as Dictionary).get("gu", 1)),
		"enemy_qi_li": int((opponent.get("neili", {}) as Dictionary).get("qi", 1)),
		"enemy_techniques": (opponent.get("techniques", []) as Array).duplicate(),
		"enemy_defenses": (opponent.get("defenses", []) as Array).duplicate(),
		"enemy_xinfa": (opponent.get("xinfa", []) as Array).duplicate(),
	}
	return cfg


func _pailing_list() -> Array:
	var list: Array = []
	for tile_key in pailing:
		var suit := String(tile_key).substr(0, 1)
		var value := int(String(tile_key).substr(1))
		list.append({"id": pailing[tile_key], "tile": tile_key, "suit": suit, "value": value})
	return list


# 战斗终局回写。返回 "settlement"（胜且还有下一战）|"victory"（组终）|"defeat"。
func apply_result(winner: String, player_hp_fp: int, beats: int) -> String:
	total_beats += maxi(beats, 0)
	if winner != "player":
		phase = "over"
		return "defeat"
	hp_fp = maxi(player_hp_fp, 0)
	wins += 1
	battle_index += 1
	if battle_index >= GROUP_SIZE:
		phase = "victory"  # D14：组终不发内力/历练/三选一
		return "victory"
	phase = "settlement"
	neili_points += 1  # 每胜+1（D4）；第一胜解锁洗点（首战锁死＝只在开局）
	neili_locked = false
	return "settlement"


# 历练入账：仅前两战有值（reward_lianli 首两元素；组终战无）。
func grant_lianli(rewards: Array) -> int:
	var amount := 0
	if battle_index - 1 < rewards.size():
		amount = int(rewards[battle_index - 1])
	lianli += amount
	last_grant = amount
	return amount


func neili_total() -> int:
	return neili_points


# 洗点：总量守恒＋单项上限；锁死态拒绝（数据锁，UI 亦可禁）。
func alloc_neili(jin: int, gu: int, qi: int) -> bool:
	if neili_locked:
		return false
	if jin + gu + qi != neili_points:
		return false
	if jin < 0 or gu < 0 or qi < 0 or jin > NEILI_MAX_PER or gu > NEILI_MAX_PER or qi > NEILI_MAX_PER:
		return false
	neili = {"jin": jin, "gu": gu, "qi": qi}
	return true


func free_slots(kind: String) -> int:
	return int(slot_caps.get(kind, 0)) - (loadout.get(kind, []) as Array).size()


# 入手武学：kind 槽有空位且未持有；调用方负责 CodexState.discover。
func acquire_wuxue(id: String, kind: String) -> bool:
	if owned_ids.has(id) or free_slots(kind) <= 0:
		return false
	(loadout[kind] as Array).append(id)
	owned_ids.append(id)
	return true


# 绑牌灵：同 id 不重复、同牌种限一枚；tile_key 形如 "万3"（MJTile.key()）。
func acquire_pailing(id: String, tile_key: String) -> bool:
	if owned_ids.has(id) or pailing.has(tile_key):
		return false
	pailing[tile_key] = id
	owned_ids.append(id)
	return true


func unlock_slot(kind: String, new_cap: int) -> bool:
	if new_cap != int(slot_caps.get(kind, 0)) + 1 or new_cap > 5:
		return false
	slot_caps[kind] = new_cap
	return true


func heal_fp(amount: int) -> int:
	var max_fp := int(deck.get("base_max_hp", 100)) * 100
	var healed := mini(maxi(amount, 0), maxi(max_fp - hp_fp, 0))
	hp_fp += healed
	return healed


# 进入修习屏：重置本访计数（货架由 RunShop 另行生成/重掷）。
func begin_visit() -> void:
	reroll_count = 0
	heal_bought_this_visit = false


func to_dict() -> Dictionary:
	return {
		"deck_id": deck_id,
		"deck": deck,
		"phase": phase,
		"hp_fp": hp_fp,
		"lianli": lianli,
		"last_grant": last_grant,
		"neili": neili.duplicate(),
		"neili_points": neili_points,
		"neili_locked": neili_locked,
		"slot_caps": slot_caps.duplicate(),
		"loadout": {"gongfa": (loadout["gongfa"] as Array).duplicate(),
			"xinfa": (loadout["xinfa"] as Array).duplicate(),
			"hushen": (loadout["hushen"] as Array).duplicate()},
		"owned_ids": owned_ids.duplicate(),
		"pailing": pailing.duplicate(),
		"battle_index": battle_index,
		"wins": wins,
		"total_beats": total_beats,
		"run_seed": run_seed,
		"reroll_count": reroll_count,
		"heal_bought_this_visit": heal_bought_this_visit,
		"shelf": shelf.duplicate(true),
	}


static func from_dict(d: Dictionary) -> RunState:
	var state := RunState.new()
	state.deck_id = str(d.get("deck_id", "basic"))
	state.deck = d.get("deck", {})
	state.phase = str(d.get("phase", "hub"))
	state.hp_fp = int(d.get("hp_fp", 0))
	state.lianli = int(d.get("lianli", 0))
	state.last_grant = int(d.get("last_grant", 0))
	var dn: Dictionary = d.get("neili", {})
	state.neili = {"jin": int(dn.get("jin", 1)), "gu": int(dn.get("gu", 1)), "qi": int(dn.get("qi", 1))}
	state.neili_points = int(d.get("neili_points", 3))
	state.neili_locked = bool(d.get("neili_locked", true))
	var sc: Dictionary = d.get("slot_caps", {})
	state.slot_caps = {"gongfa": int(sc.get("gongfa", 1)), "xinfa": int(sc.get("xinfa", 1)), "hushen": int(sc.get("hushen", 1))}
	var lo: Dictionary = d.get("loadout", {})
	state.loadout = {"gongfa": (lo.get("gongfa", []) as Array).duplicate(),
		"xinfa": (lo.get("xinfa", []) as Array).duplicate(),
		"hushen": (lo.get("hushen", []) as Array).duplicate()}
	state.owned_ids = []
	for id_str in d.get("owned_ids", []):
		state.owned_ids.append(str(id_str))
	state.pailing = d.get("pailing", {}).duplicate()
	state.battle_index = int(d.get("battle_index", 0))
	state.wins = int(d.get("wins", 0))
	state.total_beats = int(d.get("total_beats", 0))
	state.run_seed = int(d.get("run_seed", 0))
	state.reroll_count = int(d.get("reroll_count", 0))
	state.heal_bought_this_visit = bool(d.get("heal_bought_this_visit", false))
	state.shelf = d.get("shelf", [])
	return state
