class_name FighterState
extends RefCounted

var fighter_id: String
var display_name: String
var max_hp: int
var hp: int
var guard: int = 0
# 兵器系别与等级（M4：招式不受装备限制，兵器按系增幅——school 与功法一致时伤害 +level）
var weapon_school: String = ""
var weapon_level: int = 0
# 护具等级＝每次受到的气血伤害固定减免（护境吸收后的余伤再减，最低 0）
var armor_defend: int = 0
# 档次（探索侧扣行动力/道具直伤减免缺省表用）；玩家侧不使用
var tier: String = "normal"
# 道具伤害减免（0~1）；-1 = 未配置，按档次查缺省表
var item_damage_reduction := -1.0
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var techniques: Array[String] = []
# 装备心法（D-060：5 平权槽的小丑牌式被动，XinfaRuntime 注册成管线钩子；敌我同规则）
var xinfa: Array[String] = []
var ai_priority: Array[String] = []
# 提气（原暂让）：这一拍不动、交权、从丹田提 1 张；每口气限 1 次，调息时重置（敌我同限）。
# lifts_this_breath＝本口气已提次数；lift_allowance＝心法授予的额外次数（长息诀：调息后+1）。
var lifts_this_breath := 0
var lift_allowance := 0
# 战斗内状态（毒等）：status_id -> 层数。战斗结束即消失。
var statuses: Dictionary = {}
# 功法级战斗状态（26 号 §5 词条族）：
# technique_cooldowns：tech_id -> 剩余冷却次数（自己每次原子行动开始时递减，归零解锁）
var technique_cooldowns: Dictionary = {}
# 心法词条级冷却（化浊诀"触发冷却"）：键 "心法名|词条下标" -> 剩余次数
# （自己每次原子行动开始时递减，归零解锁；与功法冷却同一口钟）
var xinfa_cooldowns: Dictionary = {}
# charging：当前蓄力（蓄力 N 词条）——{technique, charge, need, cards}；选入与喂气的
# 真气都停在 cards 里，满值自动发动。同一时刻至多一门蓄力（起手占行动权，无并行）。
var charging: Dictionary = {}

func _init(new_id: String, new_name: String, new_max_hp: int) -> void:
	fighter_id = new_id
	display_name = new_name
	max_hp = new_max_hp
	hp = new_max_hp

func is_alive() -> bool:
	return hp > 0

# 冷却计时：自己的每次原子行动开始时调用（行动本身不计入自己刚触发的冷却——
# "冷却 N＝后续 N 次行动内不可再发动"，第 N+1 次行动起可用）。功法与心法同一口钟。
func tick_cooldowns() -> void:
	for tech_id in technique_cooldowns.keys():
		var left := int(technique_cooldowns[tech_id]) - 1
		if left <= 0:
			technique_cooldowns.erase(tech_id)
		else:
			technique_cooldowns[tech_id] = left
	for cd_key in xinfa_cooldowns.keys():
		var xf_left := int(xinfa_cooldowns[cd_key]) - 1
		if xf_left <= 0:
			xinfa_cooldowns.erase(cd_key)
		else:
			xinfa_cooldowns[cd_key] = xf_left

func has_active_charge() -> bool:
	return not charging.is_empty()

func has_legal_action() -> bool:
	if has_active_charge():
		return true  # 蓄力占用行动机会，充能拍由引擎自动执行
	for technique_id in techniques:
		if not TechniqueResolver.find_legal_selection(technique_id, hand, self).is_empty():
			return true
	return false

func take_damage(amount: int) -> Dictionary:
	var incoming := maxi(amount, 0)
	var guard_damage := mini(guard, incoming)
	guard -= guard_damage
	var hp_damage := maxi(incoming - guard_damage - armor_defend, 0)
	hp = maxi(hp - hp_damage, 0)
	return {"guard_damage": guard_damage, "hp_damage": hp_damage}

func add_status(status_id: String, delta: int) -> void:
	var stacks := int(statuses.get(status_id, 0)) + delta
	if stacks <= 0:
		statuses.erase(status_id)
	else:
		statuses[status_id] = stacks

func get_status(status_id: String) -> int:
	return int(statuses.get(status_id, 0))
