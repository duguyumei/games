## qi-forge 内容生成器：我方全部游戏内容由这里注册（模式沿用 StR 数据生成约定）。
## 试玩切片 v0：首战双怪＋武者角色＋初始卡组，全部以 StR 原生机制表达；
## 标 TODO 的机制件（AV 行动条/真气/三命中/威力/伤害公式）随战斗管线切片接管后回填。
## 数值出处：《基础规则 v0.4》《敌方设计 v0.2》；试玩版已知偏差（能量暂用 StR 3/3、
## 卸力暂用护盾=格挡占位）在管线切片替换。
## 注：不设 class_name，避免进入全局类缓存扰动 StR 既有编译顺序（Card 循环依赖问题）。
extends RefCounted

static func generate_qiforge_data() -> void:
	_add_cards_spells()
	_add_enemies_g1()
	_add_character_starter()
	_add_accessories()
	_add_events_g1()
	_add_run_start_xinfa_options()
	print("qi-forge: content registered (xinfa spells / duo enemies / wu zhe / accessories / xinfa draft)")


#region 术法牌（卡组本体——《基础规则 v0.4》§2：卡组＝心法绑定 2 个同型术法 × 各 2 张）
## 术法定义出处：《身法线 v0.1》各包；卡名「X·术法N」为占位（正式名待口述）；
## 打出效果挂空——真气/封穴/移速系统随战斗管线切片实装后回填。
static func _add_cards_spells() -> void:
	var color: String = "red" # 占位沿用 StR 红色素材，剥离期替换
	for pack: Array in XINFA_PACKS:
		var pack_letter: String = str(pack[0]).substr(str(pack[0]).length() - 1, 1)
		var spells: Array = pack[6]
		for spell_index in spells.size():
			var spell: Array = spells[spell_index]
			var card: CardData = CardData.new("card_qif_spell_{0}{1}".format([pack_letter.to_lower(), spell_index + 1]))
			card.card_name = "{0}·术法{1}".format([pack_letter, "一二"[spell_index]])
			card.card_color_id = "color_{0}".format([color])
			card.card_description = str(spell[1])
			card.card_texture_path = "external/sprites/cards/{0}/card_basic_block_{0}.png".format([color])
			card.card_type = CardData.CARD_TYPES.SKILL
			card.card_rarity = CardData.CARD_RARITIES.BASIC
			card.card_energy_cost = int(spell[0])
			card.card_requires_target = false
			card.card_play_actions = []	# 待战斗管线切片：打出效果（真气/封穴/移速）
			Global.register_rod(card)


#region 武者（试玩角色：血 50＝通用模板）
static func _add_character_starter() -> void:
	var color: String = "red" # 占位沿用 StR 红色素材
	var character: CharacterData = CharacterData.new("character_qif")
	character.character_player_id = "player_qif"
	character.character_name = "武者"
	character.character_description = "qi-forge 试玩角色（通用模板：血50/攻25/防20/速100）"
	character.character_color_id = "color_{0}".format([color])
	character.character_icon_texture_path = "external/sprites/characters/character_{0}/character_{0}_icon.png".format([color])
	character.character_starting_health = 50
	character.character_starting_money = 0 # 历练开局为 0（StR 默认 999 是 demo 值）
	character.character_starting_attack = 25
	character.character_starting_defense = 20
	character.character_starting_speed = 100
	character.character_starting_hits = {"力道": 5, "迅疾": 5, "精妙": 5}
	# 基础卡组为空——卡组全部由开局心法遴选带来（§2：每心法 2 个同型术法 × 各 2 张）
	character.character_starting_card_object_ids = []
	# 奖励池暂借红色系（试玩期保证战后选卡可用；正式遴选待心法包切片）
	character.character_starting_card_draft_card_pack_ids = ["card_pack_red"]
	character.character_starting_artifact_pack_ids = ["artifact_pack_white"]
	character.character_starting_consumable_pack_ids = ["consumable_pack_white"]
	Global.register_rod(character)

	# 角色动画（占位贴图）
	var animation: AnimationData = AnimationData.new("animation_character_qif")
	character.character_animation_id = animation.object_id
	animation.add_combatant_animations(
		["external/sprites/characters/character_{0}/character_{0}.png".format([color])],
		["external/sprites/characters/character_{0}/character_{0}.png".format([color])],
		["external/sprites/characters/character_{0}/character_{0}.png".format([color])],
	)
	Global.register_rod(animation)

	# 玩家原型（选人列表由此出现）
	var player: PlayerData = PlayerData.new("player_qif")
	player.player_character_object_id = "character_qif"
	Global.register_rod(player)

	# 试玩期：把 StR demo 角色移出选人池，只留武者（demo 数据本体保留，剥离期一并清）
	# 选人菜单遍历的是角色表，玩家表一并清理
	for demo_character_id: String in ["character_red", "character_blue", "character_green", "character_orange"]:
		Global._id_to_character_data.erase(demo_character_id)
	for demo_player_id: String in ["player_red", "player_blue", "player_green", "player_orange"]:
		Global._id_to_player_data.erase(demo_player_id)
#endregion


#region 开局饰品（三组各选一·借跑局修饰面板承载）
# 机制复用：RunModifierData 互斥组＝每组各选一；默认件标记＝开局自动勾选。
# 效果本体随战斗管线切片逐步实装；本阶段先立选择流程与文案。
static func _add_accessories() -> void:
	# 先清 demo 自定义词条（难度系 difficulty_0~5 保留不动；id 以数据实测为准）
	for demo_modifier_id: String in [
		"run_modifier_custom_easy_mode", "run_modifier_endless_mode",
		"run_modifier_custom_1", "run_modifier_custom_2",
		"run_modifier_draft_all_colors",
	]:
		Global._id_to_run_modifier_data.erase(demo_modifier_id)

	var groups: Dictionary = {
		"clothes": ["服饰", [
			["服饰·一", "普攻次数 +1；普攻后回复 1 点能量"],
			["服饰·二", "任意单位死亡后回复一半能量；每回合开始时回复一半能量"],
			["服饰·三", "造成治疗或间接伤害时，回复 1 点能量"],
			["服饰·四", "每回合开始时获得 3 点能量；攻击异常层数最多的敌人后，回复 1 点能量"],
			["服饰·五", "每回合开始时回满能量；使用卡牌后，随机 1 张手牌费用 −1"],
		]],
		"head": ["头饰", [
			["头饰·一", "战斗结束时生命上限永久 +1"],
			["头饰·二", "为敌人施加的异常状态层数 ×2"],
			["头饰·三", "普攻后攻击力永久 +1；打出伤害型卡牌后威力永久 +2%"],
			["头饰·四", "战斗结束时放弃三命中三选二，自动攻／防／血／速各 +1"],
		]],
		"leg": ["腿部", [
			["腿部·一", "每回合开始时抽 4 张牌"],
			["腿部·二", "任意敌人死亡后抽 2 张牌；每回合开始时手牌不足 2 张则补齐至 2"],
			["腿部·三", "奇数回合抽满手牌，偶数回合不抽牌"],
			["腿部·四", "每回合开始时随机抽 2 张牌，再从每个心法的术法牌中各抽 1 张"],
		]],
	}

	for group_key: String in groups:
		var group_name: String = groups[group_key][0]
		var entries: Array = groups[group_key][1]
		var group_ids: Array[String] = []
		for i: int in len(entries):
			group_ids.append("qif_acc_{0}_{1}".format([group_key, i + 1]))

		for i: int in len(entries):
			var accessory: RunModifierData = RunModifierData.new(group_ids[i])
			accessory.run_modifier_name = "{0}·{1}".format([group_name, ["一", "二", "三", "四", "五"][i]])
			accessory.run_modifier_description = "{0}（效果随管线逐步实装）".format([entries[i][1]])
			accessory.run_modifier_is_custom = true
			accessory.run_modifier_group_name = group_name
			accessory.run_modifier_is_default_enabled = (i == 0) # 每组默认勾选第一件
			for other_id: String in group_ids:
				if other_id != group_ids[i]:
					accessory.run_modifier_exclusive_to_modifier_ids.append(other_id)
			Global.register_rod(accessory)
#endregion


#region G1 首战双怪
static func _add_enemies_g1() -> void:
	# 战士型（内力判定：单属性·刚）。占位贴图沿用 StR 素材，剥离期替换。
	var warrior: EnemyData = EnemyData.new("enemy_qif_warrior")
	warrior.enemy_name = "重甲武卒"
	warrior.enemy_texture_path = "external/sprites/enemies/enemy_purple_medium.png"
	warrior.add_health_bounds(60, 60) # 设计值固定 60，无随机
	# TODO(管线切片)：被动·护阵＝相邻槽位敌人受伤 -20%（需 7 槽位相邻判定）
	# TODO(管线切片)：三命中 力6/迅2/精1；出厂真气 催破1+护体1（敌我同源字段）
	warrior.add_intent_state([
		EnemyIntentData.new(EnemyIntentData.INTENT_INITIAL, 0, 0, 0, "", 0, "",
			{"qif_intent_slash": 3, "qif_intent_smash": 1}),
	])
	# 挥击（普攻定位·力道型）：100%×攻20×防御区 ≈ 10
	warrior.add_intent_state([
		EnemyIntentData.new("qif_intent_slash", 0, 10, 1, "", 0, "",
			{"qif_intent_slash": 2, "qif_intent_smash": 1}),
	])
	# 猛击（力道型·冷却2）：150% 伤害＋推玩家条 20%。推条待 AV 行动条系统落地。
	warrior.add_intent_state([
		EnemyIntentData.new("qif_intent_smash", 0, 15, 1, "", 0, "",
			{"qif_intent_slash": 3}),
	])
	warrior.add_standard_animations(
		["external/sprites/enemies/enemy_purple_medium.png"]
	)
	for intent_id: String in ["qif_intent_slash", "qif_intent_smash"]:
		warrior.enemy_intents[intent_id].enemy_intent_name = {"qif_intent_slash": "挥击", "qif_intent_smash": "猛击"}[intent_id]
	Global.register_rod(warrior)

	# 射手型（内力判定：单属性·轻）
	var archer: EnemyData = EnemyData.new("enemy_qif_archer")
	archer.enemy_name = "劲弩手"
	archer.enemy_texture_path = "external/sprites/enemies/enemy_blue_small.png"
	archer.add_health_bounds(35, 35)
	# TODO(管线切片)：被动·乘衅＝攻击带破绽目标伤害 +10%
	# TODO(管线切片)：三命中 力1/迅6/精2；出厂真气 身法1
	archer.add_intent_state([
		EnemyIntentData.new(EnemyIntentData.INTENT_INITIAL, 0, 0, 0, "", 0, "",
			{"qif_intent_shoot": 3, "qif_intent_focus": 1}),
	])
	# 射击（普攻定位·迅疾型）：110%×攻22×防御区 ≈ 13；TODO 每次造成伤害后挂玩家 1 层破绽
	archer.add_intent_state([
		EnemyIntentData.new("qif_intent_shoot", 0, 13, 1, "", 0, "",
			{"qif_intent_shoot": 2, "qif_intent_focus": 1}),
	])
	# 凝神（增益·冷却3·不可连用）：TODO 获得身法真气 20 点（轻系≈速+28%，档位衰减）
	# ＋期间 3 次自身行动受伤 -50%（招式性质走计时）
	archer.add_intent_state([
		EnemyIntentData.new("qif_intent_focus", 0, 0, 0, "", 0, "",
			{"qif_intent_shoot": 3}),
	])
	archer.add_standard_animations(
		["external/sprites/enemies/enemy_blue_small.png"]
	)
	for intent_id: String in ["qif_intent_shoot", "qif_intent_focus"]:
		archer.enemy_intents[intent_id].enemy_intent_name = {"qif_intent_shoot": "射击", "qif_intent_focus": "凝神"}[intent_id]
	Global.register_rod(archer)
#endregion


#region G1 遭遇
static func _add_events_g1() -> void:
	# 首战：双怪各占一槽（相邻位，触发护阵被动教学）
	var event_g1_fight1: EventData = EventData.new("event_qif_g1_fight1")
	event_g1_fight1.event_death_message_bbcode = "殁于首战"
	event_g1_fight1.event_weighted_enemy_object_ids = [
		{"enemy_qif_warrior": 1},
		{"enemy_qif_archer": 1},
	]
	Global.register_rod(event_g1_fight1)

	# 临时接线（试玩确定性）：act_1 简单战斗池整池替换为我们的首战，
	# 保证起局第一场必是双怪。局结构切片（6 组×3 场）落地后换独立 Act/池。
	var act1_easy_pool: EventPoolData = Global.get_event_pool_data("event_pool_act_1_easy")
	if act1_easy_pool != null:
		act1_easy_pool.event_pool_event_object_ids = ["event_qif_g1_fight1"]
		act1_easy_pool.event_pool_fallback_event_object_id = "event_qif_g1_fight1"
#endregion


#region 开局心法遴选（5 选 2·借 RunStartOptions 承载）
# 流程：一进备战层弹出 5 门心法（B/C/E/F/G 五包，对应身法线档），选 2 门后各带 4 张术法入组。
# 试玩注记：术法本体随战斗管线切片实装，现阶段每门心法以现有 4 种基础卡暂代成组，
# 选择文案如实标注「暂代」；心法被动（喂费/充能/抗性）同样待管线切片。

## 心法包总表（单一事实源）：
## [选项id, 展示名, 心法效果句, 暂代卡组, 升级一, 升级二, 术法[费用,效果,升1,升2]×2]
## 术法名暂以「术法一／术法二」占位，正式命名待用户口述。
const XINFA_PACKS: Array = [
	["run_start_option_qif_B", "B 包·普攻喂费", "心法：普攻后 50% 随机身法牌费用 −1",
		["card_qif_spell_b1", "card_qif_spell_b1", "card_qif_spell_b2", "card_qif_spell_b2"],
		"每次普攻 50% 概率抽一张卡，一次行动最多触发 6 次",
		"普攻伤害 +50%，并造成 50% 溅射伤害",
		[[3, "移速 +50%，持续 2 回合；期间攻击类功法每耗 1 点能量，本次伤害 +20%", "", ""],
		 [2, "移速 +20%，持续 3 回合；期间每打出一张身法牌，对随机敌人普攻一次", "", ""]]],
	["run_start_option_qif_C", "C 包·真气引擎", "心法：身法每累计消耗 2 点能量，获得随机真气",
		["card_qif_spell_c1", "card_qif_spell_c1", "card_qif_spell_c2", "card_qif_spell_c2"],
		"改为获得一层伤害增幅（伤害 +3%）",
		"改为获得 10% 轻灵真气量的催破真气",
		[[3, "获得 5 点随机类型真气", "最低类型真气额外 +5", ""],
		 [2, "获得 3 点轻灵真气", "提升至 5 点", ""]]],
	["run_start_option_qif_E", "E 包·身法喂费", "心法：每次使用身法牌，随机非身法卡费用 −1",
		["card_qif_spell_e1", "card_qif_spell_e1", "card_qif_spell_e2", "card_qif_spell_e2"],
		"改为随机身法牌 −1 能量，且 30% 概率抽一张牌",
		"身法心法充能时额外 +1 充能",
		[[1, "获得 3 层封穴，能量 +3", "改为 +5", "本次行动内下一次能量回复量翻倍"],
		 [3, "速度 +50% 持续一回合；下次行动开始时所有手牌能量 −1", "", ""]]],
	["run_start_option_qif_F", "F 包·提前兑现", "心法：我方行动提前时获得一层攻击增幅",
		["card_qif_spell_f1", "card_qif_spell_f1", "card_qif_spell_f2", "card_qif_spell_f2"],
		"每使用两次身法牌，下次行动提前 25%，并获得两次攻击机会",
		"角色无法被行动推迟；排序在玩家后的敌人速度 −30%",
		[[1, "抽 3 弃 3；下次行动提前 20%", "直到下回合前，每次受到攻击行动提前 10%", ""],
		 [3, "行动结束时，下次行动提前 25%，持续 3 回合", "持续期间受到的非直接伤害减半", ""]]],
	["run_start_option_qif_G", "G 包·移速抗性", "心法：移速受到的敌人效果影响降低 50%",
		["card_qif_spell_g1", "card_qif_spell_g1", "card_qif_spell_g2", "card_qif_spell_g2"],
		"影响降低提升至 90%；封穴与破绽影响减少 50%；行动无法被推迟",
		"所有敌人减速 10%，且敌人受到的其他减速效果提升 50%",
		[[1, "每有一名速度低于我方 80% 速度的敌人，获得 1 点能量", "改为「速度低于我方」", ""],
		 [4, "对所有敌人造成 3 级破绽和 3 级封穴", "", ""]]],
]

## 备战层「已获心法」列用：全部包概要（id/名/效果）
static func get_xinfa_pack_summaries() -> Array:
	var summaries: Array = []
	for pack: Array in XINFA_PACKS:
		summaries.append({"id": pack[0], "name": pack[1], "desc": str(pack[2]).trim_prefix("心法：")})
	return summaries

## 详情用：单包全量（效果/升级路线/术法[费用,效果,升1,升2]）
static func get_xinfa_pack_full(pack_id: String) -> Dictionary:
	for pack: Array in XINFA_PACKS:
		if pack[0] == pack_id:
			return {
				"id": pack[0], "name": pack[1], "desc": str(pack[2]).trim_prefix("心法："),
				"bundle": pack[3], "up1": pack[4], "up2": pack[5], "spells": pack[6],
			}
	return {}

static func _add_run_start_xinfa_options() -> void:
	# 清 demo 开局选项（英文奖惩事件整批移出；只留本生成器的 qif_ 前缀）
	for existing_option_id: String in Global._id_to_run_start_option_data.keys():
		if not existing_option_id.begins_with("run_start_option_qif_"):
			Global._id_to_run_start_option_data.erase(existing_option_id)

	# 术法牌名取自已注册卡（_add_cards_spells 先于本函数跑）
	var card_name_by_id: Dictionary = {}
	for card_id: String in ["card_qif_spell_b1", "card_qif_spell_b2", "card_qif_spell_c1", "card_qif_spell_c2",
			"card_qif_spell_e1", "card_qif_spell_e2", "card_qif_spell_f1", "card_qif_spell_f2",
			"card_qif_spell_g1", "card_qif_spell_g2"]:
		var card_data: CardData = Global.get_card_data_from_prototype(card_id)
		if card_data != null:
			card_name_by_id[card_id] = card_data.card_name
	for pack: Array in XINFA_PACKS:
		var option: RunStartOptionData = RunStartOptionData.new(pack[0])
		option.run_start_option_type = RunStartOptionData.RUN_START_OPTION_TYPES.COMPLETE

		# 卡组文案：如「破势×3＋劲破×1」
		var bundle_counts: Dictionary = {}
		for card_id: String in pack[3]:
			bundle_counts[card_id] = bundle_counts.get(card_id, 0) + 1
		var bundle_parts: Array[String] = []
		for card_id: String in bundle_counts.keys():
			bundle_parts.append("{0}×{1}".format([card_name_by_id[card_id], bundle_counts[card_id]]))
		var bundle_text: String = "＋".join(bundle_parts)

		option.run_start_option_bb_code = "[b]{0}[/b]\n{1}\n[color=yellow]入组（暂代）：{2}[/color]".format([pack[1], pack[2], bundle_text])

		# 直塞 CardData 对象：绕开 ACTION_CREATE_CARDS 单 id 限制（generated_cards 键会被后一个覆盖）
		var bundle_cards: Array = []
		for card_id: String in pack[3]:
			bundle_cards.append(Global.get_card_data_from_prototype(card_id))
		option.run_start_option_actions = [{
			Scripts.ACTION_ADD_CARDS_TO_DECK: {"picked_cards": bundle_cards},
		}]
		Global.register_rod(option)
#endregion
