class_name MJHooks
extends RefCounted

# 内容协议（真气语法 v3 §12 实装纪律二）：事件表＋Input/Output DTO——
# 分离轴裁定：墙砌在内容协议上，内容（功法/心法/词条）只准走协议，不准直摸流程。
# 学我地麻（90 接口＋125 DTO）裁剪为 v3 首发事件集；扩展＝加一行常量＋补头注键表＋引擎侧一个 emit 点。
#
# ## 事件表（Input 键 → Output 键）
# | 事件 | 时机 | Input | Output |
# |---|---|---|---|
# | POSTURE | 打出批次确定（虚招/普攻/反击弃牌） | {side, batch: Array[MJTile], kind: "xu"|"normal"|"counter"} | {bian_charge: int = 0}（引擎回落方生效——灵变） |
# | CLAIM_DONE | 招架成立（碰/杠/暗杠入副露） | {side, claim_type, symbol, tile} | {} |
# | TECH_FIRE | 重击发射进在途 | {side, tech_id, windup, tiles: Array[MJTile]（本次耗式清单，挑战层牌灵标记用）} | {} |
# | TECH_RESOLVE | 在途结算（发射者可行动拍开头） | {side, tech_id, power, opp_flawed: bool} | {pct_bonus: int = 0, break_enemy_pending: bool = false, debuff_gu_next: int = 0（削对方下拍骨力）, notes: Array[String]} |
# | PENDING_BROKEN | 在途被断势击碎 | {side, tech_id} | {} |
# | DAMAGE_DEALT | 伤害落地后 | {side: 受击方, amount_fp, display, source} | {} |
# | BEAT_END | 一拍结束 | {beat, actor} | {} |
# | BIAN_DONE | 变招执行（换手牌/换面子组） | {side, kind: "hand"\|"group", count} | {} |
# | COUNTER_PLAYED | 反击打出（招架后的打出，v3.5 插座） | {side, batch} | {} |
# | IRON_END | 护体到期/衰减归零解除 | {side} | {} |
# | FLAW_GAINED | 破绽获得（空手兜底即时触发，v3.6） | {side} | {} |
# | TILE_DRAWN | 摸到牌（挑战层牌灵挂点）：破绽拍/正常拍/缺牌补充/岭上各一次 emit | {side, tiles: Array[MJTile], reason: "flaw"/"draw"/"topup"/"rinshan"} | {gang_qi: int = 0, iron_bonus_next: int = 0}（引擎回落方生效） |
#
# v3.5 退役：SHIKI_BASIC（式基本招伤害系统随普攻体系退役）；反击伤害为 0（插座，
# 将来"反击时造成 X%"类词条挂 COUNTER_PLAYED——明码印刷，不做系统级条件伤害）。
# v3.6 追加：FLAW_GAINED（破绽第一条生产通道＝手牌清零）。
# 监听者异常吞掉并告警（内容坏不毁局）；输出按订阅序收集，引擎侧 reduce。

const POSTURE := "posture"
const CLAIM_DONE := "claim_done"
const TECH_FIRE := "tech_fire"
const TECH_RESOLVE := "tech_resolve"
const PENDING_BROKEN := "pending_broken"
const DAMAGE_DEALT := "damage_dealt"
const BEAT_END := "beat_end"
const BIAN_DONE := "bian_done"
const COUNTER_PLAYED := "counter_played"
const IRON_END := "iron_end"
const FLAW_GAINED := "flaw_gained"
const TILE_DRAWN := "tile_drawn"

var _listeners: Dictionary = {}  # event -> Array[{owner, callable}]


func on(event: String, owner: Object, callable: Callable) -> void:
	if not _listeners.has(event):
		_listeners[event] = []
	(_listeners[event] as Array).append({"owner": owner, "callable": callable})


func off_owner(owner: Object) -> void:
	for event in _listeners.keys():
		var kept: Array = []
		for entry in _listeners[event]:
			if entry["owner"] != owner:
				kept.append(entry)
		_listeners[event] = kept


# 逐监听者调用，收集 [{owner, out}]；过滤 owner_side 不匹配的（由注册方包装，本类不感知）。
func emit_event(event: String, input: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry in (_listeners.get(event, []) as Array):
		var callable: Callable = entry["callable"]
		var out: Dictionary = {}
		if callable.is_valid():
			var value = callable.call(input.duplicate())
			if value is Dictionary:
				out = value
		results.append({"owner": entry["owner"], "out": out})
	return results
