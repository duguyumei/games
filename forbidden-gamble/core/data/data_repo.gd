extends Node

# 数据定义层（autoload DataRepo；脚本不写 class_name——Godot 禁止与 autoload 同名遮蔽）：
# 全部游戏 JSON 的唯一加载入口——缓存 + schema 校验 + reload() 失效重载。
# 此前同一份 JSON 读取逻辑存在四份（BoardState/EncounterLoader/TechniqueResolver/
# StatusRuntime），且 TechniqueResolver/StatusRuntime 的静态缓存永不失效。
# 校验：validate_pack 是纯函数（测试可喂损坏数据）；validate_all 启动时跑一遍，
# 坏数据 push_error 带「文件/条目/字段」上下文——静默 .get() 默认值吞错的时代结束。

const CONFIG_PATH := "res://data/location_qingfeng.json"
const ITEMS_PATH := "res://data/items.json"
const ENEMIES_PATH := "res://data/enemies.json"
const TECHNIQUES_PATH := "res://data/techniques.json"
const XINFA_PATH := "res://data/xinfa.json"
const STATUSES_PATH := "res://data/statuses.json"
const SANDBOX_ENCOUNTER_PATH := "res://data/sandbox_encounter.json"
const PLAYER_PATH := "res://data/player.json"

# schema 枚举（与规则实现同步维护）
const RARITIES := ["common", "fine", "rare", "legend"]
const TIERS := ["normal", "veteran", "elite", "master"]
# 牌型（v1 属性轴）：一气＋重族 N 张同属性＋合族 N 张异属性，选牌上限 4
const PATTERNS := ["ONE_QI", "HEAVY_2", "HEAVY_3", "HEAVY_4", "MIX_2", "MIX_3", "MIX_4"]
# 功法效果类型（v1 数值语法：效果＝基值＋系数×真气量）
const EFFECT_TYPES := ["damage", "guard_cover", "apply_status", "remove_guard", "heal", "draw", "self_hp_loss"]
# 功法词条标签：压制＝行动权不转让（冷却定价重复）
const TECHNIQUE_TAGS := ["压制"]
# 功法效果条件键（_condition_met 支持）
const TECHNIQUE_WHEN_KEYS := ["attribute_gte"]
const STATUS_ACTIONS := ["hp_loss", "damage_modify"]
const STATUS_ON := ["battle_start", "breath", "technique_use", "damage"]
# 心法词表（D-060/D-061，契约见《27》§3）
const XINFA_SCHOOLS := ["风", "林", "火", "山", "通用"]
const XINFA_ON := ["battle_start", "breath", "lift_qi", "technique_prepare", "technique_use", "damage", "initiative_gain", "initiative_transfer", "initiative_seize"]
const XINFA_PHASES := ["pre", "post"]
const XINFA_CONDITION_KEYS := ["attribute_gte", "grade_lte", "first_lift", "xinfa_school_gte", "pattern", "transfer_gte", "breath_gte", "as_attacker", "as_target", "target_is_enemy", "source_is_enemy", "once_per_breath", "once_per_battle"]
const XINFA_DO_TYPES := ["transfer_bonus", "damage_bonus", "damage_resist", "reflect", "guard_bonus", "heal", "draw", "wash_back", "breath_transform", "lift_bonus", "qi_amount_bonus", "apply_status", "self_hp_loss", "seize_initiative", "cancel", "amount_bonus"]
# 物品大类与消耗品小类（25 号暂定稿）；container＝行囊（M4 穿戴容量件）；
# use 效果词表 = 已实现执行器的清单
const ITEM_TYPES := ["consumable", "material", "valuable", "manual", "weapon", "armor", "container", "readable"]
const CONSUMABLE_SUBTYPES := ["medicine", "hidden_weapon", "tool", "provision", "credential"]
const USE_SCOPES := ["battle", "explore"]
const USE_TARGETS := ["self", "enemy"]
const USE_EFFECT_KINDS := ["heal", "restore_ap", "damage", "apply_status", "open_all_chests", "sneak_window"]

var _cache := {}

func _ready() -> void:
	for err in validate_all():
		push_error("[DataRepo] " + err)

# ---------- 加载与缓存 ----------

func load_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法加载配置: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("配置格式错误: " + path)
		return {}
	_cache[path] = parsed
	return parsed

# 失效重载（测试换数据用）
func reload() -> void:
	_cache.clear()

func config() -> Dictionary:
	return load_json(CONFIG_PATH)

func items() -> Dictionary:
	return load_json(ITEMS_PATH)

func enemies() -> Dictionary:
	return load_json(ENEMIES_PATH)

func techniques() -> Dictionary:
	return load_json(TECHNIQUES_PATH)

func xinfa() -> Dictionary:
	return load_json(XINFA_PATH)

func statuses() -> Dictionary:
	return load_json(STATUSES_PATH)

func sandbox_encounter() -> Dictionary:
	return load_json(SANDBOX_ENCOUNTER_PATH)

# 玩家定义（data/player.json 根即玩家 FighterDef）
func player_def() -> Dictionary:
	return load_json(PLAYER_PATH)

# ---------- schema 校验 ----------

func validate_all() -> Array[String]:
	return validate_pack({
		"location_qingfeng.json": config(),
		"items.json": items(),
		"enemies.json": enemies(),
		"techniques.json": techniques(),
		"xinfa.json": xinfa(),
		"statuses.json": statuses(),
		"player.json": player_def(),
	})

# pack: {文件名: 数据}。纯函数，返回错误清单（空 = 全部通过）。
static func validate_pack(pack: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var config: Dictionary = pack.get("location_qingfeng.json", {})
	var items: Dictionary = pack.get("items.json", {})
	var enemies: Dictionary = pack.get("enemies.json", {})
	var techniques: Dictionary = pack.get("techniques.json", {})
	var xinfa: Dictionary = pack.get("xinfa.json", {})
	var statuses: Dictionary = pack.get("statuses.json", {})
	var player_def: Dictionary = pack.get("player.json", {})

	# 物品：id 与键一致、稀有度四档、价值非负、大类/小类/use 结构合法
	for key in items:
		var item: Dictionary = items[key]
		if str(item.get("id", "")) != str(key):
			errs.append("items.json[%s]：id（%s）与键不一致" % [key, item.get("id")])
		if not RARITIES.has(str(item.get("rarity", ""))):
			errs.append("items.json[%s]：未知稀有度 %s" % [key, item.get("rarity")])
		if int(item.get("value", -1)) < 0:
			errs.append("items.json[%s]：value 应为非负整数" % key)
		var item_type := str(item.get("type", ""))
		if not ITEM_TYPES.has(item_type):
			errs.append("items.json[%s]：未知大类 %s" % [key, item.get("type")])
		elif item_type == "consumable":
			var subtype := str(item.get("subtype", ""))
			if not CONSUMABLE_SUBTYPES.has(subtype):
				errs.append("items.json[%s]：消耗品未知小类 %s" % [key, item.get("subtype")])
			errs.append_array(_validate_item_use(key, item, statuses))
		if item.has("icon") and not str(item.get("icon", "")).begins_with("res://"):
			errs.append("items.json[%s]：icon 应为 res:// 开头的资源路径" % key)
		if item.has("max_stack") and int(item.get("max_stack", 0)) <= 0:
			errs.append("items.json[%s]：max_stack 应为正整数" % key)
		if item.has("charges") and int(item.get("charges", 0)) <= 0:
			errs.append("items.json[%s]：charges 应为正整数" % key)

	# 功法：等级 1~5、牌型/效果类型已知、apply_status 引用存在；
	# 词条字段：tags 白名单、冷却/蓄力非负；数值字段 base/scale/per_supreme 非负
	for key in techniques:
		var tech: Dictionary = techniques[key]
		var level := int(tech.get("level", 0))
		if level < 1 or level > 5:
			errs.append("techniques.json[%s]：level=%d 越界（1~5）" % [key, level])
		for pattern in tech.get("patterns", []):
			if not PATTERNS.has(str(pattern)):
				errs.append("techniques.json[%s]：未知牌型 %s" % [key, pattern])
		for tag in tech.get("tags", []):
			if not TECHNIQUE_TAGS.has(str(tag)):
				errs.append("techniques.json[%s]：未知标签 %s" % [key, tag])
		for num_field in ["cooldown", "charge", "charge_feed"]:
			if tech.has(num_field) and int(tech.get(num_field, 0)) < 0:
				errs.append("techniques.json[%s]：%s 应为非负整数" % [key, num_field])
		if int(tech.get("charge", 0)) > 0 and not tech.has("patterns"):
			errs.append("techniques.json[%s]：蓄力功法必须声明牌型" % key)
		for effect in tech.get("effects", []):
			var etype := str(effect.get("type", ""))
			if not EFFECT_TYPES.has(etype):
				errs.append("techniques.json[%s]：未知效果类型 %s" % [key, etype])
			if etype == "apply_status" and not statuses.has(str(effect.get("status", ""))):
				errs.append("techniques.json[%s]：apply_status 引用了不存在的状态 %s" % [key, effect.get("status")])
			if etype in ["damage", "guard_cover", "draw"] and not effect.has("base"):
				errs.append("techniques.json[%s]：%s 效果缺少 base（基值）" % [key, etype])
			for num_field in ["base", "scale", "per_supreme"]:
				if (effect as Dictionary).has(num_field) and int((effect as Dictionary).get(num_field, 0)) < 0:
					errs.append("techniques.json[%s]：%s 应为非负整数" % [key, num_field])
			for ckey in (effect as Dictionary).get("when", {}).keys():
				if not TECHNIQUE_WHEN_KEYS.has(str(ckey)):
					errs.append("techniques.json[%s]：未知条件键 %s" % [key, ckey])

	# 心法：品阶 1~5、系别/时机/相位/条件键/动作类型全在白名单、apply_status 引用存在
	for key in xinfa:
		var xf: Dictionary = xinfa[key]
		var tier := int(xf.get("tier", 0))
		if tier < 1 or tier > 5:
			errs.append("xinfa.json[%s]：tier=%d 越界（1~5）" % [key, tier])
		if not XINFA_SCHOOLS.has(str(xf.get("school", ""))):
			errs.append("xinfa.json[%s]：未知系别 %s" % [key, xf.get("school")])
		if str(xf.get("desc", "")).is_empty():
			errs.append("xinfa.json[%s]：desc 不能为空" % key)
		var xf_effects: Array = xf.get("effects", [])
		if xf_effects.is_empty():
			errs.append("xinfa.json[%s]：至少要有一条 effect" % key)
		for effect in xf_effects:
			var on := str((effect as Dictionary).get("on", ""))
			if not XINFA_ON.has(on):
				errs.append("xinfa.json[%s]：未知时机 %s" % [key, on])
			var phase := str((effect as Dictionary).get("phase", "pre" if on == "technique_prepare" else "post"))
			if not XINFA_PHASES.has(phase):
				errs.append("xinfa.json[%s]：未知相位 %s" % [key, phase])
			for ckey in (effect as Dictionary).get("when", {}).keys():
				if not XINFA_CONDITION_KEYS.has(str(ckey)):
					errs.append("xinfa.json[%s]：未知条件键 %s" % [key, ckey])
			# 触发冷却（化浊诀）：触发后本词条冷却 N 次自己的原子行动
			if (effect as Dictionary).has("cooldown") and int((effect as Dictionary).get("cooldown", 0)) < 0:
				errs.append("xinfa.json[%s]：cooldown 应为非负整数" % key)
			var do_dict: Dictionary = (effect as Dictionary).get("do", {})
			if not XINFA_DO_TYPES.has(str(do_dict.get("type", ""))):
				errs.append("xinfa.json[%s]：未知动作类型 %s" % [key, do_dict.get("type")])
			elif str(do_dict.get("type", "")) in ["cancel", "amount_bonus"] and phase != "pre":
				errs.append("xinfa.json[%s]：%s 只在 pre 相位合法（动作结算后取消/改数已无意义）" % [key, do_dict.get("type")])
			elif str(do_dict.get("type", "")) == "apply_status" and not statuses.has(str(do_dict.get("status", ""))):
				errs.append("xinfa.json[%s]：apply_status 引用了不存在的状态 %s" % [key, do_dict.get("status")])

	# 状态：触发时机与动作已知
	for key in statuses:
		var status: Dictionary = statuses[key]
		if not STATUS_ON.has(str(status.get("on", ""))):
			errs.append("statuses.json[%s]：未知触发时机 %s" % [key, status.get("on")])
		if not STATUS_ACTIONS.has(str(status.get("action", ""))):
			errs.append("statuses.json[%s]：未知动作 %s" % [key, status.get("action")])

	# 敌人：id 与键一致、档次四档、气血为正、功法引用存在、行囊档次在箱子表里
	var chests: Dictionary = config.get("chests", {})
	for key in enemies:
		var enemy: Dictionary = enemies[key]
		if str(enemy.get("id", "")) != str(key):
			errs.append("enemies.json[%s]：id（%s）与键不一致" % [key, enemy.get("id")])
		if not TIERS.has(str(enemy.get("tier", ""))):
			errs.append("enemies.json[%s]：未知档次 %s" % [key, enemy.get("tier")])
		if int(enemy.get("max_hp", 0)) <= 0:
			errs.append("enemies.json[%s]：max_hp 应为正整数" % key)
		for technique in enemy.get("techniques", []) + (enemy.get("ai_priority", []) as Array):
			if not techniques.has(str(technique)):
				errs.append("enemies.json[%s]：引用了不存在的功法 %s" % [key, technique])
		for xf_id in enemy.get("xinfa", []):
			if not xinfa.has(str(xf_id)):
				errs.append("enemies.json[%s]：引用了不存在的心法 %s" % [key, xf_id])
		if (enemy.get("deck", []) as Array).is_empty():
			errs.append("enemies.json[%s]：牌组为空" % key)
		for card in enemy.get("deck", []):
			if str((card as Dictionary).get("attribute", "")).is_empty() or not QiCard.GRADE_NAMES.has(str((card as Dictionary).get("grade", ""))):
				errs.append("enemies.json[%s]：牌组里有属性/品级不完整的牌 %s" % [key, card])
		if not chests.has(str(enemy.get("loot_chest", ""))):
			errs.append("enemies.json[%s]：掉落行囊 %s 不在地点包箱子表里" % [key, enemy.get("loot_chest")])
		if enemy.has("item_damage_reduction") and not (0.0 <= float(enemy.get("item_damage_reduction", 0.0)) and float(enemy.get("item_damage_reduction", 0.0)) <= 1.0):
			errs.append("enemies.json[%s]：item_damage_reduction 应在 0~1 之间" % key)

	# 玩家定义：功法/心法引用存在（player.json 进 pack 后生效；纯函数喂包不带则跳过）
	if not player_def.is_empty():
		for technique in player_def.get("techniques", []):
			if not techniques.has(str(technique)):
				errs.append("player.json：引用了不存在的功法 %s" % technique)
		for xf_id in player_def.get("xinfa", []):
			if not xinfa.has(str(xf_id)):
				errs.append("player.json：引用了不存在的心法 %s" % xf_id)

	# 地点包：行动力起点为正、警戒/追兵/散落/箱子表的跨文件引用有效
	if int(config.get("ap", {}).get("start", 0)) <= 0:
		errs.append("location_qingfeng.json：ap.start 应为正整数")
	var enemy_keys := enemies.keys()
	for level in config.get("alert_levels", []):
		for enemy in (level as Dictionary).get("enemies", []):
			if not enemy_keys.has(str(enemy)):
				errs.append("location_qingfeng.json：警戒 %s 引用了不存在的敌人 %s" % [level.get("name"), enemy])
	for enemy in config.get("pursuer_table", []):
		if not enemy_keys.has(str(enemy)):
			errs.append("location_qingfeng.json：追兵表引用了不存在的敌人 %s" % enemy)
	for item in config.get("scatter_table", []):
		if not items.has(str(item)):
			errs.append("location_qingfeng.json：散落表引用了不存在的物品 %s" % item)
	for chest_id in chests:
		for item in (chests[chest_id] as Dictionary).get("table", []):
			if not items.has(str(item)):
				errs.append("location_qingfeng.json：箱子 %s 掉落表引用了不存在的物品 %s" % [chest_id, item])
	var npcs: Dictionary = config.get("npcs", {})
	for site_type in config.get("site_types", {}):
		for spec in (config.get("site_types", {})[site_type] as Dictionary).get("cards", []):
			var kind := str((spec as Dictionary).get("kind", ""))
			if kind == "enemy" and not _all_in((spec as Dictionary).get("table", []), enemy_keys):
				errs.append("location_qingfeng.json：地块 %s 的敌人表引用了不存在的敌人" % site_type)
			if kind == "npc" and not _all_in((spec as Dictionary).get("table", []), npcs.keys()):
				errs.append("location_qingfeng.json：地块 %s 的 NPC 表引用了不存在的 NPC" % site_type)
	return errs

# 消耗品 use 结构：scopes/target 已知、效果词表受控、数值为正、apply_status 引用存在。
# 无 use 是合法形态（凭证/粮草类被动作或地点引用，不直接点用）。
static func _validate_item_use(key: String, item: Dictionary, statuses: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if not item.has("use"):
		return errs
	var use: Dictionary = item.get("use", {})
	var scopes: Array = use.get("scopes", [])
	if scopes.is_empty():
		errs.append("items.json[%s]：use.scopes 不能为空" % key)
	for scope in scopes:
		if not USE_SCOPES.has(str(scope)):
			errs.append("items.json[%s]：未知可用场景 %s" % [key, scope])
	if not USE_TARGETS.has(str(use.get("target", ""))):
		errs.append("items.json[%s]：未知作用对象 %s" % [key, use.get("target")])
	var effects: Array = use.get("effects", [])
	if effects.is_empty():
		errs.append("items.json[%s]：use.effects 不能为空" % key)
	for effect in effects:
		var kind := str((effect as Dictionary).get("kind", ""))
		if not USE_EFFECT_KINDS.has(kind):
			errs.append("items.json[%s]：未知效果类型 %s" % [key, kind])
			continue
		if kind in ["heal", "restore_ap", "damage"] and int((effect as Dictionary).get("amount", 0)) <= 0:
			errs.append("items.json[%s]：%s 的 amount 应为正整数" % [key, kind])
		if kind == "apply_status":
			if not statuses.has(str((effect as Dictionary).get("status", ""))):
				errs.append("items.json[%s]：apply_status 引用了不存在的状态 %s" % [key, (effect as Dictionary).get("status")])
			if int((effect as Dictionary).get("stacks", 0)) <= 0:
				errs.append("items.json[%s]：apply_status 的 stacks 应为正整数" % key)
	return errs

static func _all_in(table: Array, keys: Array) -> bool:
	for entry in table:
		if not keys.has(str(entry)):
			return false
	return true
