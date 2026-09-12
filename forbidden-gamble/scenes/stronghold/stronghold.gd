extends Control

# 据点（局外 hub，布局参考用户给的手游哨站后勤图）：
# 背景为程序淡墨山水（正式"大地图"美术资产后续替换）；左侧 制作/购买/升级/仓库，
# 右侧 出发/图鉴/搭配。仓库接真实 meta 存档；其余功能占位（13 号框架，随系统落地再接）。

const Palette := preload("res://ui/board_palette.gd")

# 仓库/构筑数据出口（备战页同款注入模式：测试注裸实例隔离真档，运行时接 autoload）。
# 不写类型标注：MetaArchive 是 autoload 无 class_name，静态按 Node 查会拒掉动态调用。
var archive

func _ready() -> void:
	if archive == null:
		archive = get_node("/root/MetaArchive")
	_draw_mountains()
	_refresh_warehouse_info()
	($TopBar/HomeButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.TITLE))
	($LeftMenu/WarehouseButton as Button).pressed.connect(_open_warehouse)
	($LeftMenu/StudyButton as Button).pressed.connect(_open_study)
	($LeftMenu/CraftButton as Button).pressed.connect(_notice.bind("制作", "用仓库材料打造装备与道具。功能随制造系统落地。"))
	($LeftMenu/BuyButton as Button).pressed.connect(_notice.bind("购买", "向行商采购物资。功能随商店系统落地。"))
	($LeftMenu/UpgradeButton as Button).pressed.connect(_notice.bind("升级", "科技树式据点升级。功能随成长系统落地。"))
	($RightMenu/DepartButton as Button).pressed.connect(_on_depart)
	($RightMenu/CodexButton as Button).pressed.connect(
		func(): get_tree().change_scene_to_file(SceneRoutes.CODEX))
	($RightMenu/BuildButton as Button).pressed.connect(_open_build)
	($WarehousePanel/Margin/VBox/WClose as Button).pressed.connect(func(): $WarehousePanel.visible = false)
	($BuildPanel/Margin/VBox/BClose as Button).pressed.connect(func(): $BuildPanel.visible = false)
	($StudyPanel/Margin/VBox/SClose as Button).pressed.connect(func(): $StudyPanel.visible = false)
	($NoticePanel/Margin/VBox/NClose as Button).pressed.connect(func(): $NoticePanel.visible = false)
	await PreviewCapture.maybe_capture(self, 1.5)

# ---------- 仓库（真实，meta 存档） ----------

func _refresh_warehouse_info() -> void:
	# 顶栏三联（D-062）：银两（折银/商店后置，暂恒 0）｜历练（胜仗/撤离/研读积累）｜仓库总价值
	($TopBar/ValueLabel as Label).text = "银两 %d ｜ 历练 %d ｜ 仓库总价值 %d" % [
		archive.silver, archive.experience, archive.warehouse_value()]
	($LeftMenu/WarehouseButton as Button).text = "仓库（%d 堆）" % archive.warehouse.size()

func _open_warehouse() -> void:
	($WarehousePanel/Margin/VBox/WTitle as Label).text = "仓库 · 总价值 %d" % archive.warehouse_value()
	var grid := $WarehousePanel/Margin/VBox/WScroll/WGrid as GridContainer
	for child in grid.get_children():
		child.queue_free()
	if archive.warehouse.is_empty():
		grid.columns = 1
		grid.add_child(Palette.plain_label("（空空如也——撤离成功的物资会存入这里）", 14, Palette.COLOR_INK))
	else:
		grid.columns = 8
		for item in archive.warehouse:
			grid.add_child(_warehouse_slot(item))
	$WarehousePanel.visible = true

func _warehouse_slot(item: Dictionary) -> Panel:
	return ItemSlot.make(item, Vector2(64, 80), 11)

# ---------- 占位与出发 ----------

# ---------- 构筑面板（D-060）：心法 5 平权槽 + 功法 4 位 + 真气牌库 + 规则汇总 ----------

func _open_build() -> void:
	var content := $BuildPanel/Margin/VBox/BScroll/BContent as VBoxContainer
	for child in content.get_children():
		child.queue_free()
	content.add_child(_section_title("心法（%d 槽平权，点击已装备的卸下）" % archive.XINFA_SLOTS))
	content.add_child(_slot_row(archive.loadout.get("xinfa", []), archive.XINFA_SLOTS, "xinfa"))
	content.add_child(_section_title("已学心法（点击装备）"))
	content.add_child(_learned_grid("xinfa"))
	content.add_child(_section_title("功法（%d 位，点击已装备的卸下）" % archive.TECHNIQUE_SLOTS))
	content.add_child(_slot_row(archive.loadout.get("techniques", []), archive.TECHNIQUE_SLOTS, "techniques"))
	content.add_child(_section_title("已学功法（点击装备）"))
	content.add_child(_learned_grid("techniques"))
	content.add_child(_section_title("真气牌库"))
	content.add_child(_deck_summary())
	content.add_child(_section_title("当前生效规则（构筑即披露）"))
	content.add_child(_rules_summary())
	$BuildPanel.visible = true

func _section_title(text: String) -> Label:
	return Palette.plain_label(text, 15, Palette.COLOR_INK)

# 装备槽行：空槽显示"空"；点击已装备项卸下（同名唯一，卸下即从 loadout 移除）
func _slot_row(equipped: Array, slots: int, slot_type: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for index in slots:
		var id := str(equipped[index]) if index < equipped.size() else ""
		var button := Button.new()
		button.custom_minimum_size = Vector2(128, 46)
		button.focus_mode = Control.FOCUS_NONE
		button.text = id if not id.is_empty() else "空"
		var captured := id
		button.pressed.connect(func() -> void:
			if captured.is_empty():
				return
			var next: Array = []
			for entry in archive.loadout.get(slot_type, []):
				if str(entry) != captured:
					next.append(str(entry))
			archive.set_loadout(slot_type, next)
			archive.save_meta()
			_open_build())
		row.add_child(button)
	return row

# 已学清单网格：装备中的高亮并禁点（防重复），未装备的点击上阵
func _learned_grid(slot_type: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var learned: Array = archive.learned_xinfa if slot_type == "xinfa" else archive.learned_techniques
	var equipped: Array = archive.loadout.get(slot_type, [])
	for id in learned:
		var button := Button.new()
		button.custom_minimum_size = Vector2(128, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.text = str(id)
		if slot_type == "xinfa":
			var school := str(XinfaRuntime.xinfa_data(str(id)).get("school", ""))
			var tier := int(XinfaRuntime.xinfa_data(str(id)).get("tier", 1))
			button.text = "[%s·%d] %s" % [school, tier, str(id)]
		if equipped.has(id):
			button.disabled = true
		var captured := str(id)
		button.pressed.connect(func() -> void:
			var next: Array = []
			for entry in archive.loadout.get(slot_type, []):
				next.append(str(entry))
			next.append(captured)
			archive.set_loadout(slot_type, next)
			archive.save_meta()
			_open_build())
		grid.add_child(button)
	if learned.is_empty():
		grid.columns = 1
		grid.add_child(Palette.plain_label("（尚未参悟任何心法）" if slot_type == "xinfa" else "（尚未参悟额外功法）", 13, Palette.COLOR_INK))
	return grid

# 真气牌库摘要：属性分布 + 品级分布（牌库构筑调整随炼气系统开放，v1 只读）
func _deck_summary() -> Label:
	var deck: Array = DataRepo.player_def().get("deck", [])
	var attr_counts := {}
	var grade_counts := {"下品": 0, "中品": 0, "上品": 0}
	for card in deck:
		var attr := str((card as Dictionary).get("attribute", ""))
		attr_counts[attr] = int(attr_counts.get(attr, 0)) + 1
		var grade := str((card as Dictionary).get("grade", "下品"))
		grade_counts[grade] = int(grade_counts.get(grade, 0)) + 1
	var parts: Array[String] = []
	for attr in ["风", "林", "火", "山"]:
		if attr_counts.has(attr):
			parts.append("%s×%d" % [attr, int(attr_counts[attr])])
	var grade_parts: Array[String] = []
	for grade in ["下品", "中品", "上品"]:
		grade_parts.append("%s×%d" % [grade, int(grade_counts[grade])])
	return Palette.plain_label(
		"%d 口真气：%s ｜ 品级 %s（调整随炼气开放）" % [deck.size(), "，".join(parts), "／".join(grade_parts)],
		13, Palette.COLOR_INK)

# 规则汇总：装备心法逐门披露效果文本 + 系别分布（01 号"规则透明"的局外落点）
func _rules_summary() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var equipped: Array = archive.loadout.get("xinfa", [])
	if equipped.is_empty():
		box.add_child(Palette.plain_label("（未装备心法）", 13, Palette.COLOR_INK))
	for id in equipped:
		var data := XinfaRuntime.xinfa_data(str(id))
		var line := "《%s》[%s·%d] %s" % [str(id), str(data.get("school", "")), int(data.get("tier", 1)), XinfaRuntime.effect_text(str(id))]
		box.add_child(Palette.plain_label(line, 13, Palette.COLOR_INK))
	var spread := ""
	for school in ["风", "林", "火", "山"]:
		var count := XinfaRuntime.equipped_school_count(equipped, school)
		if count > 0:
			spread += "%s系%d门 " % [school, count]
	if not spread.is_empty():
		box.add_child(Palette.plain_label("系别分布：" + spread, 13, Palette.COLOR_GOLD))
	return box

# ---------- 参悟面板（研读秘籍，D-047 参悟即蚀） ----------

func _open_study() -> void:
	var content := $StudyPanel/Margin/VBox/SScroll/SContent as VBoxContainer
	for child in content.get_children():
		child.queue_free()
	# 按 DataRepo 权威定义识别仓库里的 manual 类物品（条目是定义副本，字段流转不可依赖）
	var seen := {}
	for item in archive.warehouse:
		var item_id := str(item.get("id", ""))
		if seen.has(item_id):
			continue
		var def: Dictionary = DataRepo.items().get(item_id, {})
		if def.is_empty() or str(def.get("type", "")) != "manual":
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text_label := Palette.plain_label(_manual_row_text(item_id, int(item.get("qty", 1))), 14, Palette.COLOR_INK)
		text_label.custom_minimum_size = Vector2(360, 0)
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text_label)
		seen[item_id] = true
		var study_button := Button.new()
		study_button.focus_mode = Control.FOCUS_NONE
		study_button.text = "研读"
		var captured := item_id
		study_button.pressed.connect(func() -> void: _on_study(captured))
		row.add_child(study_button)
		content.add_child(row)
	if seen.is_empty():
		content.add_child(Palette.plain_label("（仓库里没有秘籍——撤离时带出功法卷与心法篇，在此研读）", 13, Palette.COLOR_INK))
	$StudyPanel.visible = true

func _manual_row_text(item_id: String, qty: int) -> String:
	var def: Dictionary = DataRepo.items().get(item_id, {})
	var teach: Dictionary = def.get("teach", {})
	var kind_name := "心法" if str(teach.get("kind", "")) == "xinfa" else "功法"
	return "%s ×%d ｜ 传授%s《%s》" % [str(def.get("name", item_id)), maxi(qty, 1), kind_name, str(teach.get("id", "?"))]

func _on_study(item_id: String) -> void:
	var result: Dictionary = archive.study_manual(item_id)
	if bool(result.get("ok", false)):
		var kind_name := "心法" if str(result.get("kind", "")) == "xinfa" else "功法"
		_notice("参悟有成", "习得%s《%s》。卷上文字散去，秘籍已销毁。" % [kind_name, str(result.get("id", ""))])
	else:
		_notice("参悟未成", str(result.get("reason", "")))
	_refresh_warehouse_info()
	_open_study()

# ---------- 出发与占位 ----------

func _notice(title: String, text: String) -> void:
	($NoticePanel/Margin/VBox/NTitle as Label).text = title
	($NoticePanel/Margin/VBox/NText as Label).text = text
	$NoticePanel.visible = true

# 出发先去备战页整备（C-027）：选禁地、换装、挑携行物资，那边点「出发」才开远征。
func _on_depart() -> void:
	get_tree().change_scene_to_file(SceneRoutes.PREP)

# ---------- 背景：程序淡墨山水（正式大地图美术后换） ----------

func _draw_mountains() -> void:
	_add_ridge(0.66, 46.0, Color(0.17, 0.14, 0.11, 0.08), 0.011)
	_add_ridge(0.78, 64.0, Color(0.16, 0.30, 0.24, 0.10), 0.017)

func _add_ridge(y_ratio: float, height: float, color: Color, freq: float) -> void:
	var w := size.x
	var h := size.y
	var base_y := h * y_ratio
	var points := PackedVector2Array()
	points.append(Vector2(0, h))
	var x := 0.0
	while x <= w:
		var y := base_y - (sin(x * freq) * 0.6 + sin(x * freq * 2.7 + 1.3) * 0.4) * height
		points.append(Vector2(x, y))
		x += 40.0
	points.append(Vector2(w, h))
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	$Mountains.add_child(poly)
