class_name MJHooks
extends RefCounted

# 内容协议（真气语法 v3 §12 实装纪律二）：事件表＋Input/Output DTO——
# 分离轴裁定：墙砌在内容协议上，内容（功法/心法/词条）只准走协议，不准直摸流程。
# 学我地麻（90 接口＋125 DTO）裁剪为 v3 首发事件集；扩展＝加一行常量＋补头注键表＋引擎侧一个 emit 点。
#
# ## 事件表（Input 键 → Output 键）
# | 事件 | 时机 | Input | Output |
# |---|---|---|---|
# | POSTURE | 架势弃牌确定 | {side, batch: Array[MJTile]} | {} |
# | CLAIM_DONE | 截牌成立（碰/杠入副露） | {side, claim_type, symbol, tile} | {} |
# | SHIKI_BASIC | 式基本招触发 | {side, symbol, source: "明"|"暗"} | {damage_bonus: int = 0} |
# | TECH_FIRE | 功法发射进在途 | {side, tech_id} | {} |
# | TECH_RESOLVE | 在途结算（发射者可行动拍开头） | {side, tech_id, power} | {damage_bonus: int = 0, guard_set: int < 0 不变, break_enemy_pending: bool = false, notes: Array[String]} |
# | PENDING_BROKEN | 在途被断势击碎 | {side, tech_id} | {} |
# | DAMAGE_DEALT | 伤害落地后 | {side: 受击方, amount, source} | {} |
# | BEAT_END | 一拍结束 | {beat, actor} | {} |
#
# 监听者异常吞掉并告警（内容坏不毁局）；输出按订阅序收集，引擎侧 reduce。

const POSTURE := "posture"
const CLAIM_DONE := "claim_done"
const SHIKI_BASIC := "shiki_basic"
const TECH_FIRE := "tech_fire"
const TECH_RESOLVE := "tech_resolve"
const PENDING_BROKEN := "pending_broken"
const DAMAGE_DEALT := "damage_dealt"
const BEAT_END := "beat_end"

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
