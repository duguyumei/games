class_name FighterState
extends RefCounted

# 战斗单位（真气语法 v2.2 区域语义，《真气语法_v2》§3）：
# - hand＝**丹田**（体内真气；上限＝dantian_capacity，被动获得行动权时补满）
# - melds＝**副露区**（功法打出的牌——主动打出＋吃碰杠截来打出的；公开、锁死、不可截）
# - destiny_pile＝**本命牌组**（仅开局洗抽入丹田，战中不回流；系统挂起）
# 气海（共墙）与个人牌河是战斗级共享/分属区，住 CombatState。
var fighter_id: String
var display_name: String
var max_hp: int
var hp: int
var guard: int = 0
var hand: Array = []
var destiny_pile: Array = []
# 副露区：每次功法打出的一组牌（Array of Array[QiCard]）
var melds: Array = []
# 丹田容量（个体化：玩家 8 占位；敌方＝对手卡起手张数——身体各有大小）
var dantian_capacity := 8
var techniques: Array[String] = []
# 装备心法（D-060：5 平权槽的小丑牌式被动，XinfaRuntime 注册成管线钩子；玩家侧专用）
var xinfa: Array[String] = []
# 破绽（下一次被动获得行动权时跳过该次行动；不叠加、即查即耗；主动夺取不受影响）。
# 铸币厂（v3）：杠（被杠者）＋压制动词。
var flawed := false
# 敌方对手卡定义（敌方系统 v2 + 真气语法 v2.2）：{hand, qi_sea, swap_policy, ladder}，
# 由 EncounterLoader 填充；CombatState 据此构建 EnemyBrain。玩家侧不用。
var enemy_def: Dictionary = {}
# 战斗内状态（毒等）：status_id -> 层数。战斗结束即消失。
var statuses: Dictionary = {}
# 功法级战斗状态：technique_cooldowns tech_id -> 剩余冷却次数；
# xinfa_cooldowns "心法名|词条下标" -> 剩余次数（同一口钟）
var technique_cooldowns: Dictionary = {}
var xinfa_cooldowns: Dictionary = {}
# charging：当前蓄力（蓄力 N 词条）——{technique, charge, need, cards}；满值自动发动。
var charging: Dictionary = {}

func _init(new_id: String, new_name: String, new_max_hp: int) -> void:
	fighter_id = new_id
	display_name = new_name
	max_hp = new_max_hp
	hp = new_max_hp

func is_alive() -> bool:
	return hp > 0

# 冷却计时：自己的每次拍起手调用（被动获得或截链首段）。功法与心法同一口钟。
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

# 有没有合法行动（流动制的"无气让拍"判据）：蓄力占位 → 有；手里还有牌 → 至少可架势；
# 手牌耗尽且未蓄力 → 无气可动（让过一拍，疲劳照计——气竭判负已退役）。
func has_legal_action() -> bool:
	if has_active_charge():
		return true
	return not hand.is_empty()

func take_damage(amount: int) -> Dictionary:
	var incoming := maxi(amount, 0)
	var guard_damage := mini(guard, incoming)
	guard -= guard_damage
	var hp_damage := maxi(incoming - guard_damage, 0)
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
