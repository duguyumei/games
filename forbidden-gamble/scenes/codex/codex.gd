extends Control

## 图鉴（卡牌网格版）：真气（丹珠）/装备（装备卡）/功法（功法卡复用战斗卡面）/内功（内功卡）。
## 只读展示，全部数据来自 DataRepo；卡片组件在编辑器可调。

const TECH_CARD_SCENE := preload("res://ui/technique_card.tscn")
const XINFA_CARD_SCENE := preload("res://ui/xinfa_card.tscn")
const ITEM_CARD_SCENE := preload("res://ui/item_card.tscn")
const QI_ORB_SCENE := preload("res://ui/qi_orb.tscn")

const ATTRS := ["风", "林", "火", "山"]
# 品级三档（v1 三品化）：下/中/上
const GRADES := ["下", "中", "上"]

@onready var qi_content: VBoxContainer = $Margin/VBox/Tabs/真气/Scroll/QiContent
@onready var equip_grid: GridContainer = $Margin/VBox/Tabs/装备/Scroll/EquipGrid
@onready var tech_grid: GridContainer = $Margin/VBox/Tabs/功法/Scroll/TechGrid
@onready var xinfa_grid: GridContainer = $Margin/VBox/Tabs/内功/Scroll/XinfaGrid


func _ready() -> void:
	_fill_qi()
	_fill_equipment()
	_fill_techniques()
	_fill_xinfa()
	($Margin/VBox/BottomRow/BackButton as Button).pressed.connect(
		func(): get_tree().change_scene_to_file(SceneRoutes.TITLE))


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.109804, 0.090196, 0.070588, 1))
	return label


func _fill_qi() -> void:
	# 每属性一行：属性名＋下/中/上三颗丹珠（复用战斗丹珠组件）
	for attr in ATTRS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var head := _heading(attr)
		head.custom_minimum_size = Vector2(28, 0)
		row.add_child(head)
		for grade_index in range(GRADES.size()):
			var orb := QI_ORB_SCENE.instantiate() as QiOrb
			orb.force_text = GRADES[grade_index]
			orb.orb_color = QiOrb.color_for_attribute(attr)
			row.add_child(orb)
		qi_content.add_child(row)
	qi_content.add_child(_heading("牌型一览"))
	var techniques: Dictionary = DataRepo.load_json(DataRepo.TECHNIQUES_PATH)
	var used: Array = []
	for tid in techniques.keys():
		for p in techniques[tid].get("patterns", []):
			if not used.has(p):
				used.append(p)
	var names: Array = []
	for p in used:
		names.append(PatternEvaluator.pattern_name(str(p)))
	var label := Label.new()
	label.text = "、".join(names)
	label.add_theme_font_size_override("font_size", 15)
	qi_content.add_child(label)


func _fill_equipment() -> void:
	var items: Dictionary = DataRepo.load_json(DataRepo.ITEMS_PATH)
	for id in items.keys():
		var e: Dictionary = items[id]
		var stat_line := ""
		match str(e.get("type", "")):
			"weapon":
				var w: Dictionary = e.get("weapon", {})
				stat_line = "%s·+%d" % [str(w.get("school", "—")), int(w.get("level", 0))]
			"armor":
				var a: Dictionary = e.get("armor", {})
				stat_line = "护体·减伤 %d" % int(a.get("level", 0))
			"container":
				stat_line = "行囊"
			_:
				continue
		var card := ITEM_CARD_SCENE.instantiate()
		card.setup(str(e.get("name", id)), str(e.get("rarity", "")), stat_line, str(e.get("desc", "")))
		equip_grid.add_child(card)


func _fill_techniques() -> void:
	var techniques: Dictionary = DataRepo.load_json(DataRepo.TECHNIQUES_PATH)
	var ids := techniques.keys().duplicate()
	ids.sort_custom(func(a, b):
		return int(techniques[a].get("level", 0)) < int(techniques[b].get("level", 0)))
	for tid in ids:
		var t: Dictionary = techniques[tid]
		var card := TECH_CARD_SCENE.instantiate()
		var patterns: Array = []
		for p in t.get("patterns", []):
			patterns.append(PatternEvaluator.pattern_name(str(p)))
		card.set_card(str(tid), "需：%s\n%s" % ["、".join(patterns), TechniqueResolver.effect_summary(str(tid))],
			int(t.get("level", 1)))
		tech_grid.add_child(card)


func _fill_xinfa() -> void:
	var xinfa: Dictionary = DataRepo.load_json(DataRepo.XINFA_PATH)
	var ids := xinfa.keys().duplicate()
	ids.sort_custom(func(a, b):
		return int(xinfa[a].get("tier", 0)) < int(xinfa[b].get("tier", 0)))
	for xid in ids:
		var x: Dictionary = xinfa[xid]
		var card := XINFA_CARD_SCENE.instantiate()
		card.setup(str(xid), int(x.get("tier", 1)), str(x.get("school", "—")), str(x.get("desc", "")))
		xinfa_grid.add_child(card)
