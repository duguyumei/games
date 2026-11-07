## VC 制意图动作族（2026-11-07 逆向重构轮）。
## 对应原版 Nosebleed.Pancake.GameCommands 的 EnemyAction 族（EnemyActionDamage/MultiDamage/
## Armor/Wait/SpawnNewEnemy/AddPlayerStat/AddCardToPile）——execute（模型结算）＋projected
## （预估伤害，对应 GetProjectedDamage）＋display_name（意图文案）。
## 数据侧：ENEMIES.actions 平铺 {kind, value, hits}＝单阶段意图池；EnemyIntentGroup
## （血量阶段切池）为数据升级位——加 "intents": [{hp_above, actions}] 即生效。
extends RefCounted

const DATA := preload("res://qiforge/QiVcData.gd")

## IntentType（对应原版枚举）：现役四型＋三留位
const TYPES := ["attack", "armor", "multi", "wait", "spawn", "debuff", "add_card"]

## 动作执行（对应 EnemyAction.Execute→OnExecute：模型结算；视图事件走 battle.event）
static func execute(battle, e: Dictionary, act: Dictionary) -> void:
	match String(act.get("kind", "")):
		"attack":
			var amt := _scaled(battle, e, int(act.get("value", 0)))
			battle.event.emit("「%s」攻击：造成 %d 点伤害" % [String(e["name"]), amt])
			_resolve_player_damage(battle, e, amt, 1)
		"multi":
			## 多段＝每段独立结算独立过玩家甲（对应 EnemyActionMultiDamage 的逐段
			## OnUpdateView/DoDamageDelayed 语义——与合并总额数学等价，但逐段报数）
			var hits := maxi(1, int(act.get("hits", 1)))
			var per := _scaled(battle, e, int(act.get("value", 0)))
			battle.event.emit("「%s」连击：%d 点 ×%d 段" % [String(e["name"]), per, hits])
			for h in hits:
				_resolve_player_damage(battle, e, per, h)
		"armor":
			## 敌自加甲（对应 EnemyActionArmor——每敌独立甲，遭遇池已退役）
			var v := int(act.get("value", 0))
			e["armor"] = int(e.get("armor", 0)) + v
			battle.event.emit("「%s」结甲 +%d" % [String(e["name"]), v])
		"wait":
			battle.event.emit("「%s」蓄力" % String(e["name"]))
		"spawn":
			battle.event.emit("「%s」召唤（动作位就绪，遭遇数据待配）" % String(e["name"]))
		"debuff":
			battle.event.emit("「%s」施压（动作位就绪，数值待配）" % String(e["name"]))
		"add_card":
			battle.event.emit("「%s」塞牌（动作位就绪，卡待配）" % String(e["name"]))

## 预估伤害（对应 GetProjectedDamage——意图显示用；非伤害型恒 0）
static func projected(battle, e: Dictionary, act: Dictionary) -> int:
	match String(act.get("kind", "")):
		"attack":
			return _scaled(battle, e, int(act.get("value", 0)))
		"multi":
			return _scaled(battle, e, int(act.get("value", 0))) * maxi(1, int(act.get("hits", 1)))
	return 0

## 意图文案（对应 IntentView 的类型文案）
static func display_name(act: Dictionary) -> String:
	match String(act.get("kind", "")):
		"attack":
			return "攻击 %d" % int(act.get("value", 0))
		"multi":
			return "连击 %d×%d" % [int(act.get("value", 0)), maxi(1, int(act.get("hits", 1)))]
		"armor":
			return "结甲 +%d" % int(act.get("value", 0))
		"wait":
			return "蓄力"
		"spawn":
			return "召唤"
		"debuff":
			return "施压"
		"add_card":
			return "塞牌"
	return "?"

## 玩家承伤（对应 PlayerModel.ResolveDamage：甲→血＋事件；每段独立）
static func _resolve_player_damage(battle, e: Dictionary, amt: int, seg: int) -> void:
	var left := amt
	if int(battle.player["armor"]) > 0:
		var absorb := mini(int(battle.player["armor"]), left)
		battle.player["armor"] = int(battle.player["armor"]) - absorb
		left -= absorb
		battle.event.emit("护甲抵御了 %d 点（%s）" % [absorb, String(e["name"])])
	if left > 0:
		battle.player["hp"] = maxi(0, int(battle.player["hp"]) - left)
		battle.event.emit("「%s」的第 %d 段命中：受到 %d 点伤害" % [String(e["name"]), seg, left])
		battle.hit_landed.emit(battle.player, left, "敌方打击", false)

## 意图数值缩放（对应 EnemyAction.UseStatsMultiplier/GetIntentMultiplier——现役恒 1；
## 将来敌强化/诅咒轴在此乘）
static func _scaled(_battle, _e: Dictionary, value: int) -> int:
	return maxi(0, value)
