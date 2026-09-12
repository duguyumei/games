class_name BoardPresenters
extends RefCounted

# 只读展示层（BoardState 的展示模块）：把状态字典翻译成 UI 文案与数值。
# 纯查询、零副作用——规则动作一律不在这里。经 setup 注入 BoardState 属主，
# 读 config/items/enemies 活引用。

var b: BoardState

func setup(owner: BoardState) -> void:
	b = owner

# 禁地状态（C-023）：等级、名称、下一级阈值（-1 表示已满级）、
# 气息与追杀信息（hunt_next=-1 表示守卫关机，不再追杀）、迷踪香静音窗余量。
func alert_info() -> Dictionary:
	var levels: Array = b.config.get("alert_levels", [])
	var info := {"level": b.alert_level, "name": "平静", "next_at": -1}
	if b.alert_level > 0 and b.alert_level <= levels.size():
		info["name"] = str(levels[b.alert_level - 1].get("name", "骚动"))
	if b.alert_level < levels.size():
		info["next_at"] = int(levels[b.alert_level].get("at", 0))
	info["qixi"] = b.qixi
	if b.guardians_off:
		info["hunt_next"] = -1
	else:
		var hunt: Dictionary = b.config.get("hunt", {})
		info["hunt_next"] = int(hunt.get("first", 0)) + b.hunt_count * int(hunt.get("step", 0))
	info["hunter"] = ""
	if not b.hunter.is_empty():
		info["hunter"] = ("镇物分身·%s" if bool(b.hunter.get("avatar", true)) else "镇物真身·%s") % str(b.hunter.get("enemy_id", ""))
	info["sneak"] = b.sneak_ap
	return info

func kind_name(kind: String) -> String:
	match kind:
		"scatter":
			return "零散物品"
		"enemy":
			return "敌人"
		"chest":
			return "箱子"
		"location":
			return "地点卡"
		"pursuer":
			return "追兵"
		"zhenwu":
			return "镇物"
		"body":
			return "遗体"
		"npc":
			return "路人"
	return kind

func card_display(card: Dictionary) -> String:
	match str(card.get("kind", "")):
		"scatter":
			return item_name(str(card.get("item_id", "")))
		"enemy":
			return str(card.get("enemy_id", ""))
		"pursuer":
			return "追兵·" + str(card.get("enemy_id", ""))
		"zhenwu":
			var n := str(card.get("enemy_id", ""))
			if bool(card.get("avatar", false)):
				var life := int(b.hunter.get("life", 0)) if not b.hunter.is_empty() else 0
				return "镇物分身·%s（余%d息）" % [n, life]
			return "镇物真身·%s" % n
		"chest":
			var name := str(chest_config(str(card.get("chest", ""))).get("name", "箱子"))
			if bool(card.get("opened", false)):
				return name + "（空）" if (card.get("contents", []) as Array).is_empty() else name + "（开着）"
			return name
		"location":
			return str(location_def(card).get("name", "地点卡"))
		"body":
			var body_name := "遗体·" + str(card.get("enemy_id", ""))
			if bool(card.get("opened", false)):
				return body_name + "（已搜空）" if (card.get("contents", []) as Array).is_empty() else body_name + "（已搜）"
			return body_name
		"npc":
			return str(b.config.get("npcs", {}).get(str(card.get("npc_id", "")), {}).get("name", "路人"))
	return "未知"

# 三态警戒（C-028）：calm 平常 / alerted 惊动 / ready 准备（满表，玩家再动就挨咬）。
# 只对活敌有意义；镇物的迫近另算（check_ambush 用）。
func alert_badge(card: Dictionary) -> Dictionary:
	var value := int(card.get("alert", 0))
	var cap := b._alert_cap(card)
	var state := "calm"
	if value >= cap:
		state = "ready"
	elif value > 0:
		state = "alerted"
	return {"state": state, "value": value, "cap": cap}

# 地块预览（小地块悬停 tooltip／明牌侦察）：当前网格里所有牌的牌面名。
func site_peek(pos: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for entry in b.site_at(pos).get("grid", []):
		var card: Dictionary = entry
		if not card.is_empty():
			out.append(card_display(card))
	return out

# 容器弹窗视图（D-028 弹窗翻牌）：名字＋内容物条目（暗/亮、物品名、稀有度）。
# 暗牌不报物品名（弹窗 UI 只用 flipped 条目的名字——赌博就在这一下）。
func container_view(card: Dictionary) -> Dictionary:
	var kind := str(card.get("kind", ""))
	var title := ""
	if kind == "chest":
		title = str(chest_config(str(card.get("chest", ""))).get("name", "箱子"))
	elif kind == "body":
		title = "搜刮·" + str(card.get("enemy_id", ""))
	var entries := []
	for entry in card.get("contents", []):
		var e: Dictionary = entry
		var item_id := str(e.get("item_id", ""))
		entries.append({
			"flipped": bool(e.get("flipped", false)),
			"item_id": item_id,
			"name": item_name(item_id),
			"rarity": str(b.items.get(item_id, {}).get("rarity", "common")),
			"tooltip": item_entry_tooltip(b.items.get(item_id, {})) if bool(e.get("flipped", false)) else "盖着——翻开才知道（1 行动力）",
		})
	return {"kind": kind, "name": title, "entries": entries}

# 压顶镇物的迫近进度（0~cap；未压顶返回 -1）。
func hunter_proximity() -> int:
	if b.hunter.is_empty() or b.hunter.get("site", Vector2i(9, 9)) != b.hero_site:
		return -1
	return int(b.hunter.get("prox", 0))

func rarity_name(rarity: String) -> String:
	match rarity:
		"common":
			return "普通"
		"fine":
			return "精良"
		"rare":
			return "稀有"
		"legend":
			return "传说"
	return rarity

# ---------- 悬停详情（tooltip 文案） ----------

const TYPE_LABELS := {
	"consumable": "消耗品", "material": "材料", "valuable": "财物", "manual": "秘籍",
	"weapon": "兵器", "armor": "护具", "container": "行囊", "readable": "读物",
}

# 物品详情（静态：物品定义字典自带全部信息，prep/背包/容器弹窗/牌面共用）。
# 行序：类别·稀有度 → 装备参数/使用效果 → 价值 → 描述。
static func item_entry_tooltip(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var lines: Array[String] = []
	var type_id := str(item.get("type", ""))
	var head := "%s·%s" % [TYPE_LABELS.get(type_id, type_id), rarity_name_static(str(item.get("rarity", "common")))]
	lines.append("【%s】%s" % [head, str(item.get("name", ""))])
	var weapon: Dictionary = item.get("weapon", {})
	if not weapon.is_empty():
		lines.append("%s系 +%d（基础耐久 %d）" % [str(weapon.get("school", "")), int(weapon.get("level", 0)), int(weapon.get("base_dur", 0))])
	var armor: Dictionary = item.get("armor", {})
	if not armor.is_empty():
		lines.append("护体减伤 %d（基础耐久 %d）" % [int(armor.get("level", 0)), int(armor.get("base_dur", 0))])
	var container: Dictionary = item.get("container", {})
	if not container.is_empty():
		lines.append("行囊 %d 格" % int(container.get("slots", 0)))
	var use: Dictionary = item.get("use", {})
	if not use.is_empty():
		var scopes: Array = use.get("scopes", [])
		var scope_tip := "探索中可用" if scopes.has("explore") else "战斗中可用"
		var effects: Array[String] = []
		for effect in use.get("effects", []):
			var e: Dictionary = effect
			var amount := int(e.get("amount", 0))
			match str(e.get("kind", "")):
				"heal":
					effects.append("回复气血 %d" % amount)
				"restore_ap":
					effects.append("行动力 +%d" % amount)
				"sneak_window":
					effects.append("静音 %d 点行动力（动牌不产噪）" % amount)
				"open_all_chests":
					effects.append("震开此地未开的箱")
				"damage":
					effects.append("对敌伤害 %d" % amount)
		if not effects.is_empty():
			lines.append("%s：%s" % [scope_tip, "；".join(effects)])
	var value := int(item.get("value", 0))
	if value > 0:
		lines.append("价值 %d" % value)
	var desc := str(item.get("desc", ""))
	if not desc.is_empty():
		lines.append(desc)
	return "\n".join(lines)

static func rarity_name_static(rarity: String) -> String:
	match rarity:
		"fine":
			return "精良"
		"rare":
			return "稀有"
		"legend":
			return "传说"
	return "普通"

# 牌面悬停提示（版图当前地块网格）：按类别给规则要点；物品/敌人带参数。
func card_tooltip(card: Dictionary) -> String:
	match str(card.get("kind", "")):
		"scatter":
			var tip := item_entry_tooltip(b.items.get(str(card.get("item_id", "")), {}))
			if tip.is_empty():
				return "零散物品"
			return tip + "\n点击拾取（免费）"
		"enemy", "pursuer":
			var e: Dictionary = b.enemies.get(str(card.get("enemy_id", "")), {})
			var lines: Array[String] = ["%s（%s·%s）" % [str(e.get("name", card.get("enemy_id", ""))),
				tier_name(str(e.get("tier", "normal"))), str(e.get("school", ""))]]
			if int(e.get("max_hp", 0)) > 0:
				lines.append("气血 %d · 功法 %d 门" % [int(e.get("max_hp", 0)), (e.get("techniques", []) as Array).size()])
			lines.append("点击迎战（战斗不耗行动力；相邻敌牌会连坐入战）")
			return "\n".join(lines)
		"zhenwu":
			if bool(card.get("avatar", false)):
				return "镇物分身：追杀你的投影\n击散即消，无掉落；真身仍会再遣"
			return "镇物真身：杀它清场（现存分身齐散）\n准备好再动手"
		"chest":
			var cfg := chest_config(str(card.get("chest", "")))
			var contents: Array = card.get("contents", [])
			if contents.is_empty():
				return "拿空的壳——东西都被取走了"
			if bool(card.get("opened", false)):
				return "已开盖：%d 件盖着（翻 1 行动力/张，拿取免费）" % contents.size()
			return "%s：开启费 %d 行动力，内盖 %d 件\n点击开盖进弹窗翻牌" % [str(cfg.get("name", "箱子")), int(cfg.get("ap_cost", 1)), contents.size()]
		"body":
			var b_contents: Array = card.get("contents", [])
			if b_contents.is_empty():
				return "搜空的遗体"
			if bool(card.get("opened", false)):
				return "已搜开：%d 件盖着（翻 1 行动力/张，拿取免费）" % b_contents.size()
			return "搜刮遗体：开启费 1 行动力，内盖 %d 件\n点击开盖进弹窗翻牌" % b_contents.size()
		"npc":
			return "路人：点击交谈（免费，可反复）"
		"location":
			var def := location_def(card)
			var tip := str(def.get("name", "地点卡"))
			var req := str(def.get("require_item", ""))
			if not req.is_empty():
				tip += "\n需要%s" % item_name(req)
			tip += "\n点击打开（0 行动力）"
			return tip
	return ""

# 敌人四档：普通/好手/精英/首领。
func tier_name(tier: String) -> String:
	match tier:
		"normal":
			return "普通"
		"veteran":
			return "好手"
		"elite":
			return "精英"
		"master":
			return "首领"
	return tier

func item_rarity(item_id: String) -> String:
	return str(b.items.get(item_id, {}).get("rarity", "common"))

func chest_open_cost(chest_id: String) -> int:
	return int(chest_config(chest_id).get("ap_cost", 1))

# ---------- 规则层共用的查询助手 ----------

func chest_config(chest_id: String) -> Dictionary:
	return b.config.get("chests", {}).get(chest_id, {})

func item_name(item_id: String) -> String:
	return str(b.items.get(item_id, {}).get("name", item_id))

func location_def(card: Dictionary) -> Dictionary:
	return b.config.get("location_cards", {}).get(str(card.get("location", "")), {})

func site_name(pos: Vector2i) -> String:
	return str(b.site_at(pos).get("name", "未知之地"))
