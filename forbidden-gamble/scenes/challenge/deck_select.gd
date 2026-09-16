extends Control

## 选卡组（挑战层 M2）：卡组＝人物——数值/派生/起始武学一张大卡；有档时「继续挑战」
## 按存档 phase 直达对应屏。程序化 UI（mahjong_battle 同风格）。

const _KIND_NAMES := {"gongfa": "功法", "xinfa": "心法", "hushen": "护身"}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var title := Label.new()
	title.text = "择卡组出战"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	if RunSaver.has_save():
		var resume := Button.new()
		resume.text = "继续挑战"
		resume.custom_minimum_size = Vector2(320, 44)
		resume.pressed.connect(_on_resume)
		root.add_child(resume)

	for deck_id in DataRepo.mj_decks().keys():
		root.add_child(_deck_card(DataRepo.mj_decks()[deck_id]))

	var back := Button.new()
	back.text = "‹ 回主菜单"
	back.custom_minimum_size = Vector2(320, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.TITLE))
	root.add_child(back)
	await PreviewCapture.maybe_capture(self)


func _deck_card(deck: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var name_row := HBoxContainer.new()
	var title := Label.new()
	title.text = "%s　%s" % [deck.get("name", ""), deck.get("desc", "")]
	title.add_theme_font_size_override("font_size", 20)
	name_row.add_child(title)
	v.add_child(name_row)

	var n: Dictionary = deck.get("neili", {})
	var jin := int(n.get("jin", 1))
	var gu := int(n.get("gu", 1))
	var qi := int(n.get("qi", 1))
	var stats := Label.new()
	stats.text = "基础：攻 %d｜防 %d｜精力 %d（架势 %d）｜血 %d\n内力：劲 %d·骨 %d·气 %d → 面板 攻 %d｜防 %d｜丹田 13" % [
		int(deck.get("base_attack", 10)), int(deck.get("base_defense", 0)),
		int(deck.get("base_jing", 1)), int(deck.get("base_jing", 1)) + 2,
		int(deck.get("base_max_hp", 100)), jin, gu, qi,
		int(deck.get("base_attack", 10)) + 2 * jin, int(deck.get("base_defense", 0)) + gu]
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(stats)

	var slots: Dictionary = deck.get("slots", {})
	var loadout: Dictionary = deck.get("loadout", {})
	var arms := ""
	for kind in ["gongfa", "xinfa", "hushen"]:
		var names: Array[String] = []
		for wid in loadout.get(kind, []):
			var t := MJTechniqueLibrary.make(str(wid))
			names.append(t.display_name if t != null else str(wid))
		arms += "%s槽 %d：%s\n" % [_KIND_NAMES[kind], int(slots.get(kind, 1)), "、".join(names)]
	var arms_label := Label.new()
	arms_label.text = arms.strip_edges()
	v.add_child(arms_label)

	var start := Button.new()
	start.text = "以此卡组开始挑战"
	start.custom_minimum_size = Vector2(320, 42)
	start.pressed.connect(func() -> void:
		if RunSession.begin(str(deck.get("id", "basic"))):
			get_tree().change_scene_to_file(SceneRoutes.CHALLENGE_HUB))
	v.add_child(start)
	return panel


func _on_resume() -> void:
	if RunSession.resume():
		var target := SceneRoutes.CHALLENGE_HUB
		match RunSession.state.phase:
			"settlement":
				target = SceneRoutes.SETTLEMENT
			"xiuxi":
				target = SceneRoutes.XIUXI
		get_tree().change_scene_to_file(target)
