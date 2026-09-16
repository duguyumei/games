extends Control

## 图鉴（发现制收藏，挑战层 v1.4 §4.9——参考我地麻 Illustration 重构）：
## 四页全量收录现行 v3 内容——真气（万/筒/条×1–9 牌面总览，全量展示）／武学（功法·护体·心法三组）／
## 牌灵／对手卡；武学/牌灵/对手＝发现制（获得/交战才亮，未发现显示「？？？——未发现」剪影）；
## 头部收藏完成度百分比。收藏档 CodexState（user://mj_meta.json，跨局存活）。
## v2.2 旧四页（风火山真气/装备/旧功法/旧内功）退役出图鉴（数据与代码不动）。
## 修为解锁/成就解锁/搜索/稀有度分组＝后置（见《组挑战_代码设计_v1》§4.9 对照表）。

@onready var tabs: TabContainer = $Margin/VBox/Tabs
@onready var ratio_label: Label = $Margin/VBox/RatioLabel


func _ready() -> void:
	_fill_qi()
	_fill_wuxue()
	_fill_pailing()
	_fill_opponents()
	ratio_label.text = "收藏 %d/%d（%d%%）" % [CodexState.discovered_count(), CodexState.all_ids().size(),
		int(CodexState.discovered_ratio() * 100)]
	($Margin/VBox/BottomRow/BackButton as Button).pressed.connect(
		func(): get_tree().change_scene_to_file(SceneRoutes.TITLE))
	await PreviewCapture.maybe_capture(self)


func _page(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	tabs.add_child(scroll)
	return v


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


# —— 真气：三门×九值牌面总览（结构性内容，全量展示不参与发现） ——
func _fill_qi() -> void:
	var v := _page("真气")
	v.add_child(_heading("三门×九值——共 108 张均匀气海"))
	for suit in MJTile.SUITS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_heading(suit))
		for value in range(MJTile.VALUE_MIN, MJTile.VALUE_MAX + 1):
			var tile := Label.new()
			tile.text = "%s%d" % [suit, value]
			tile.custom_minimum_size = Vector2(44, 34)
			tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tile.add_theme_font_size_override("font_size", 18)
			row.add_child(tile)
		v.add_child(row)


# —— 武学：功法/护体/心法三组，发现制 ——
func _fill_wuxue() -> void:
	var v := _page("武学")
	var groups := {
		"功法（攻·耗式重击）": MJTechniqueLibrary.attack_roster(),
		"护体（守·罡气即时）": MJTechniqueLibrary.defense_roster(),
		"心法（被动）": MJTechniqueLibrary.xinfa_roster(),
	}
	for group_name in groups:
		v.add_child(_heading(group_name))
		for id_str in groups[group_name]:
			v.add_child(_entry(str(id_str), _describe_wuxue.bind(str(id_str))))
	v.add_child(_heading("获取：战后三选一免费拿一；修习货架历练购买"))


func _describe_wuxue(id_str: String) -> String:
	var t := MJTechniqueLibrary.make(id_str)
	if t == null:
		return id_str
	if t.kind == "defense":
		return "%s（护体·罡气%d）——%s" % [t.display_name, t.gang_qi_cost, t.brief]
	var parts: Array[String] = []
	for symbol in t.recipe:
		parts.append("%s×%d" % [symbol, int(t.recipe[symbol])])
	return "%s（%s·%d%%）——%s" % [t.display_name, "＋".join(parts), t.power, t.brief]


# —— 牌灵：发现制（获得即亮） ——
func _fill_pailing() -> void:
	var v := _page("牌灵")
	v.add_child(_heading("缚于具体牌种（购入时自择；每牌种限一枚）"))
	for id_str in MJPaiLing.roster():
		v.add_child(_entry(str(id_str), _describe_pailing.bind(str(id_str))))
	v.add_child(_heading("获取：修习货架购买；三选一在武学槽满时以牌灵补位"))


func _describe_pailing(id_str: String) -> String:
	var ling := MJPaiLing.make(id_str, "万", 0)
	if ling == null:
		return id_str
	return ling.summary().replace("·万0", "")


# —— 对手卡：发现制（交战即亮） ——
func _fill_opponents() -> void:
	var v := _page("对手")
	v.add_child(_heading("一组三战（小/小/首领）——同构：强度住内力，血量贴玩家"))
	for key in DataRepo.mj_opponents().keys():
		v.add_child(_entry(str(key), _describe_opponent.bind(str(key))))


func _describe_opponent(key: String) -> String:
	var opp: Dictionary = DataRepo.mj_opponents()[key]
	var n: Dictionary = opp.get("neili", {})
	var techs: Array[String] = []
	for wid in opp.get("techniques", []):
		var t := MJTechniqueLibrary.make(str(wid))
		techs.append(t.display_name if t != null else str(wid))
	return "%s【%s】气血 %d｜内力 劲%d·骨%d·气%d｜功法 %s" % [
		opp.get("name", ""), "首领" if str(opp.get("tier")) == "boss" else "喽啰",
		int(opp.get("base_max_hp", 100)),
		int(n.get("jin", 1)), int(n.get("gu", 1)), int(n.get("qi", 1)),
		"、".join(techs)]


# 发现制条目：已发现→全文明码；未发现→剪影。
func _entry(id_str: String, describe: Callable) -> Control:
	var line := Label.new()
	if CodexState.is_discovered(id_str):
		line.text = "◆ " + str(describe.call())
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		line.text = "◇ ？？？——未发现"
		line.modulate = Color(0.55, 0.52, 0.48)
	return line
