## VC 制卡效果族（2026-11-07 逆向重构轮）。
## 对应原版 Nosebleed.Pancake.GameCommands 效果族（CardEffect/DamageEffect/ArmorEffect/
## KillEffect/TakeDamageEffect＋DamageParams）——职责与方法名对齐，证据住
## references/吸血鬼爬行者_伤害管线逆向_v0.1.md。
## 分工：伤害类（dmg op）→ 生成 DamageParams 交 QiVcTargeting.calculate（模拟单链）；
## 非伤害类（draw/armor_stat/…）→ 本文件的处理器注册表（对应各 CardEffect 子类的 Execute）。
extends RefCounted

const DATA := preload("res://qiforge/QiVcData.gd")
const TARGETING := preload("res://qiforge/QiVcTargeting.gd")

## 一次攻击的参数快照（对应原版 DamageParams——GenerateDamageParams 的产物）。
## 双轴说明：原版 AmountScalesWithCombo/DamageScalesWithCombo 分开——我方卡表默认
## 「伤吃连击、弹数不吃」（damage_per_hit 已乘 mult）；将来 amount 轴在卡表补
## "amount_scales_with_combo": true 时 hits 也乘。
static func generate_damage_params(op: Dictionary, card_def: Dictionary, mult: int,
		battle) -> Dictionary:
	var hits: int = maxi(1, int(op.get("hits", 1)))
	if bool(card_def.get("amount_scales_with_combo", false)) and mult > 1:
		hits = maxi(1, hits * mult)   # 原版 Amount 轴（预留：现役卡不用）
	var params := {
		"damage_per_hit": maxi(1, int(round(float(op.get("value", 1)) * float(mult)
			* battle.stat_mult("might")))),   # 2026-11-07 属性轮：might 乘区（100 基=×1）
		"hits": clampi(hits + battle.stat_val("amount"), 1, 15),   # amount 弹数轴（+N 弹）
		"targeting": _targeting_of(op, card_def),
		"pierce": int(card_def.get("pierce", 0)),
		"pierce_type": int(card_def.get("pierce_type", TARGETING.PIERCE_MULTI_HIT)),
		"crit_chance": clampf(float(DATA.CRIT_CHANCE) + 0.002 * float(battle.stat_val("luck") - 100),
			0.0, 0.8) if bool(op.get("crit", false)) else 0.0,   # luck：每 1% 运气 +0.2% 暴击率（自拟曲线）
		"crit_mult": float(DATA.CRIT_MULT),
		"might_pct": int(battle.might_pct),
		"knockback": float(card_def.get("knockback", 0.0)),
		"freeze": int(op.get("freeze", 0)),
		"bouncy": card_def.get("bouncy", {}),
		"crit_explosion": card_def.get("crit_explosion", {}),
	}
	return params

## 索敌型解析：卡表 targeting 字段优先（原版＝武器 prefab 上配 Targeting 组件），
## 兼容旧 op.hit 写法（sweep→right_left / all→front_row / front→single / multi→front_row）
static func _targeting_of(op: Dictionary, card_def: Dictionary) -> String:
	var t := String(card_def.get("targeting", ""))
	if t != "":
		return t
	match String(op.get("hit", "front")):
		"sweep":
			return "right_left"
		"all":
			return "front_row"
		"multi":
			return "front_row"
	return "single"

## ── 非伤害效果处理器注册表（对应 CardEffect 子类的 Execute/OnExecuted）──
## 签名统一 handler(battle, op, mult, ctx)——ctx 预留（is_trigger/is_gem_effect 等原版旗标）。
## lambda 非常量表达式，注册表落 static var（Godot 4.1+）。
static var HANDLERS := {
	"draw": func(battle, op: Dictionary, mult: int, _ctx: Dictionary) -> void:
		# 对应原版 DrawCardEffect（keep_last：结算中的卡不参与洗牌回收）
		battle.draw_cards(int(op.get("count", 1)) * mult, true),
	"armor_stat": func(battle, op: Dictionary, mult: int, _ctx: Dictionary) -> void:
		# 对应 ArmorEffect（护甲属性——回合开始按属性刷新；立即生效＋成长）
		var amt := int(op.get("amount", 0)) * mult
		battle.player["armor_stat"] = int(battle.player["armor_stat"]) + amt
		battle.player["armor"] = int(battle.player["armor"]) + amt,
	"heal": func(battle, op: Dictionary, mult: int, _ctx: Dictionary) -> void:
		# 对应 HealEffect
		battle.player["hp"] = mini(int(battle.player["mhp"]), int(battle.player["hp"]) + int(op.get("amount", 0)) * mult),
	"mhp": func(battle, op: Dictionary, mult: int, _ctx: Dictionary) -> void:
		battle.player["mhp"] = int(battle.player["mhp"]) + int(op.get("amount", 0)) * mult,
	"recovery": func(battle, op: Dictionary, mult: int, _ctx: Dictionary) -> void:
		# 战后回复（红番茄族）——结构资源不吃倍率
		battle.player["recovery"] = int(battle.player.get("recovery", 0)) + int(op.get("amount", 0)),
	"hand_cap": func(battle, op: Dictionary, _mult: int, _ctx: Dictionary) -> void:
		battle.player["hand_cap_mod"] = int(battle.player["hand_cap_mod"]) + int(op.get("amount", 0)),
	"qi_max": func(battle, op: Dictionary, _mult: int, _ctx: Dictionary) -> void:
		# 气上限成长（护栏封顶；结构资源不吃倍率）
		battle.player["qi_max"] = mini(DATA.QI_CAP, int(battle.player["qi_max"]) + int(op.get("amount", 0))),
	"might": func(battle, op: Dictionary, _mult: int, _ctx: Dictionary) -> void:
		battle.might_pct = int(battle.might_pct) + int(op.get("pct", 0)),
	"burn": func(battle, op: Dictionary, mult: int, _ctx: Dictionary) -> void:
		# 对应 Santa 水系灼烧：本回合结束后全体结算
		battle.encounter["burn"] = int(battle.encounter.get("burn", 0)) + int(op.get("value", 0)) * mult,
	"disarm": func(battle, op: Dictionary, _ctx: Dictionary, _c: Dictionary) -> void:
		for e in battle._alive_active():
			e["skip"] = maxi(int(e.get("skip", 0)), int(op.get("rounds", 1))),
	"freeze": func(battle, op: Dictionary, _ctx: Dictionary, _c: Dictionary) -> void:
		# 对应原版 FreezeStacks（逐层；EnemyModel.Freeze/DecrementFreeze 管线在意图轮接线）
		for e in battle._alive_active():
			e["skip"] = maxi(int(e.get("skip", 0)), int(op.get("rounds", 1))),
	"erase": func(battle, _op: Dictionary, _mult: int, _ctx: Dictionary) -> void:
		# 对应 KillEffect（处决/Gorgeous Moon 抹除）——精确语义：不走溢出
		for e in battle._alive_active().duplicate():
			battle.event.emit("抹除：「%s」" % e["name"])
			battle._damage_enemy(e, 99999, true),
	"stat": func(battle, op: Dictionary, _mult: int, _ctx: Dictionary) -> void:
		# 2026-11-07 属性轮：黄卡三型（原版 wiki 实证「encounter 或 dungeon」＋Destroy 标签）——
		# encounter＝写 battle 层（随实例销毁清零＝原版 OnEncounterDefeated 重算回基线语义）；
		# dungeon＝写 run.dungeon_stats（三层基线第三层，跨场保留）；Destroy＝卡 exhaust 自毁
		var axis := String(op.get("axis", ""))
		var amount := int(op.get("amount", 0))
		var dur := String(op.get("duration", "encounter"))
		if axis == "" or amount == 0:
			return
		if dur == "dungeon":
			var dun: Dictionary = battle._run.get("dungeon_stats", {})
			dun[axis] = int(dun.get(axis, 0)) + amount
			battle._run["dungeon_stats"] = dun
			# dungeon 层改动＝三层基线变化——重合成 starting 再刷派生（encounter 层保持叠加）
			battle.starting_stats = DATA.get_starting_stats(battle._run.get("_meta", {}), battle._run)
			battle.apply_stats_to_player()
		else:
			battle.encounter_stats[axis] = int(battle.encounter_stats.get(axis, 0)) + amount
			battle.apply_stats_to_player()
		battle.event.emit("属性提升：%s %+d（%s）" % [String(battle.stat_cn(axis)), amount,
			"本局" if dur == "dungeon" else "本场"]),
}

## 出牌效果分发（对应 DamageEffect.Execute→各效果）：dmg 交 Targeting 单链（调用方组 ctx），
## 其余走 HANDLERS。
static func run_op(battle, op: Dictionary, mult: int, ctx: Dictionary = {}) -> void:
	var kind := String(op.get("op", ""))
	if kind == "dmg":
		push_error("dmg op 应由 play_card 组 ctx 走 QiVcTargeting.calculate 单链")
		return
	if HANDLERS.has(kind):
		(HANDLERS[kind] as Callable).call(battle, op, mult, ctx)
