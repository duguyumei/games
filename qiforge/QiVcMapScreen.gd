## VC 制楼层地图屏（2026-11-01 地图轮→简笔墨线轮→同壳轮）。
## 机柜/左右舷/顶带（等级＋经验条＋层数徽）＝QiVcCabinet 公共件，与战斗屏同壳；
## 本屏只管中央视口＝简笔墨线地图：透明地坪＋墨点、区域轮廓一笔勾边、实体墨字、
## 当前位玉底「侠」章；地格按图幅自适应放大。
## 交互＝点地格 BFS 寻路走过去（沿路逐格滑、可任意回头）＋WASD 逐格走；
## 明雷/宝箱/铲子/出口是图上实体——明雷截停开战、宝箱拾取、铲子弹问、出口直接下层。
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QIDIALOG := preload("res://qiforge/QiDialog.gd")
const QI_CAB := preload("res://qiforge/QiVcCabinet.gd")
const CAB_SCENE := preload("res://qiforge/QiVcCabinet.tscn")   # 2026-11-04 场景化：顶带/舷位与战斗屏同一实例源
const BATTLE_SCENE := preload("res://qiforge/QiVcBattle.tscn")  # 2026-11-05 同壳：直接复用战斗屏静态 HUD

## 中央地图视口＝新四分区里的战斗框（与战斗屏同框）
const MAP_VIEW := Rect2(373.0, 16.0, 1174.0, 840.0)
const VC := preload("res://qiforge/QiVcData.gd")
const MAPGEN := preload("res://qiforge/QiVcMapGen.gd")

const CELL_MAX := 48           # 地格边长上限（小图放大——教程窄路 40px 档）

# —— 简笔墨线配色（地图画法专用）——
const INK_LINE := Color(0.24, 0.20, 0.15, 0.85)    # 墨线（纸底用深墨）
const INK_DOT := Color(0.33, 0.28, 0.21, 0.9)     # 墨点（地坪）
const ENEMY_INK := Color(0.62, 0.17, 0.12)        # 朱墨（敌）
const CHEST_INK := Color(0.55, 0.39, 0.10)        # 金墨（箱）
const SHOVEL_INK := Color(0.20, 0.42, 0.31)       # 玉墨（铲）

signal encounter_requested(entity: Dictionary)
signal dig_requested()
signal boss_requested(entity: Dictionary)
signal upgrade_requested()   # 2026-11-07 属性轮：打开局外养成面板（宿主持 meta 档）

var run: Dictionary = {}
var floor_idx := 0
var map_data: Dictionary = {}
var player_cell := Vector2i.ZERO

var _cell := 24                 # 地格边长（按图幅自适应）
var _player_token: Panel = null
var _moving := false
var _relic_modal_open := false    # 内功获得弹窗开着＝地图输入全停（QiDialog 模态的键盘侧门）
var _tokens := {}               # Vector2i -> Control（实体墨字）
var _top_refs := {}             # 机柜顶带（等级/经验/层数）
var _wing_refs := {}            # 机柜舷位（血/抽/弃）

func setup(run_ref: Dictionary, fidx: int, mdata: Dictionary) -> void:
	run = run_ref
	floor_idx = fidx
	map_data = mdata

func _ready() -> void:
	_fill(self)
	_build()

func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0

func grid_offset() -> Vector2:
	var w := float(int(map_data["w"]) * _cell)
	var h := float(int(map_data["h"]) * _cell)
	var view := MAP_VIEW
	var ax := view.position.x
	var ay := view.position.y
	return Vector2(ax + (view.size.x - w) * 0.5, ay + (view.size.y - h) * 0.5)

func cell_pos(c: Vector2i) -> Vector2:
	var off := grid_offset()
	return Vector2(off.x + c.x * _cell, off.y + c.y * _cell)

func _build() -> void:
	player_cell = map_data.get("player_cell", map_data["start"])   # 战后回图位置持久（run 内引用）
	map_data["player_cell"] = player_cell
	_cell = maxi(12, int(minf(minf(MAP_VIEW.size.x / float(int(map_data["w"])),
		MAP_VIEW.size.y / float(int(map_data["h"]))), float(CELL_MAX))))
	# 2026-11-05 用户令：地图屏与战斗屏同壳——直接实例战斗屏静态 HUD，隐藏战斗专属件
	var shell := BATTLE_SCENE.instantiate() as Control
	shell.set_script(null)
	add_child(shell)
	# 2026-11-05 用户令「先兼容一波」：复用战斗屏静态件后，血/气/牌堆数字的
	# 字体/色/影仍靠 wire_scene 运行时挂（Noto 运行时加载入不了 tscn）——
	# 地图屏不挂＝数字裸奔。此处只挂样式，位置全在 tscn 不碰。
	QI_CAB.wire_scene(shell)
	for pn in ["EnemyRow", "EndBtn", "PlayAllBtn", "StanceBox", "CenterBox"]:
		var n := shell.get_node_or_null("%" + pn)
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	_top_refs = {
		"lvl": shell.get_node_or_null("%LvlLbl"),
		"xp_fill": shell.get_node_or_null("%XpFill"),
		"xp_text": shell.get_node_or_null("%XpText"),
		"floor": shell.get_node_or_null("%FloorLbl"),
		"track_w": 1056.0,
	}
	_wing_refs = {
		"hp_text": shell.get_node_or_null("%HpText"),
		"qi": shell.get_node_or_null("%QiText"),
		"draw_lbl": shell.get_node_or_null("%DrawCount"),
		"discard_lbl": shell.get_node_or_null("%DiscardCount"),
	}
	gui_input.connect(_on_screen_input)
	_rebuild_grid()
	_rebuild_tokens()
	_player_token = _make_player_badge()
	_player_token.position = cell_pos(player_cell)
	add_child(_player_token)
	_build_upgrade_btn()
	_refresh_stats()

## 局外养成入口（2026-11-07 属性轮）：地图右下「修行」钮——金币升级基础属性
func _build_upgrade_btn() -> void:
	var btn := Button.new()
	btn.text = "修行"
	QISTYLE.apply_primary(btn)
	btn.position = Vector2(60.0, size.y - 96.0)
	btn.size = Vector2(140.0, 48.0)
	btn.pressed.connect(func() -> void: upgrade_requested.emit())
	add_child(btn)

#region 简笔墨线地图（透明地坪＋墨点＋区域勾边；Button 族铺装——E28 实证可靠）
func _is_floor(grid: Array, w: int, h: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	return grid[y][x] == 1

func _rebuild_grid() -> void:
	for c in get_children():
		if c.name == "FloorCell":
			c.queue_free()
	var grid: Array = map_data["grid"]
	var w := int(map_data["w"])
	var h := int(map_data["h"])
	var off := grid_offset()
	for y in h:
		for x in w:
			if grid[y][x] != 1:
				continue
			var cell := Button.new()
			cell.name = "FloorCell"
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)   # 透明地坪——简笔墨线制
			sb.border_color = INK_LINE
			if not _is_floor(grid, w, h, x, y - 1):
				sb.border_width_top = 2
			if not _is_floor(grid, w, h, x, y + 1):
				sb.border_width_bottom = 2
			if not _is_floor(grid, w, h, x - 1, y):
				sb.border_width_left = 2
			if not _is_floor(grid, w, h, x + 1, y):
				sb.border_width_right = 2
			cell.add_theme_stylebox_override("normal", sb)
			cell.add_theme_stylebox_override("hover", sb)
			cell.add_theme_stylebox_override("pressed", sb)
			cell.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			cell.text = "·"
			cell.add_theme_color_override("font_color", INK_DOT)
			cell.add_theme_font_size_override("font_size", 12)
			cell.position = Vector2(off.x + x * _cell, off.y + y * _cell)
			cell.size = Vector2(_cell, _cell)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if (x * 13 + y * 7) % 5 == 0:
				cell.rotation = 0.02   # 手绘微歪（确定性，不走种子）
			add_child(cell)

func _make_glyph(g: String, color: Color, px: int) -> Label:
	var l := Label.new()
	l.text = g
	QISTYLE.font(l, px)
	QISTYLE.text_color(l, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 当前位＝玉底「侠」章（玉绿透底＋描边，简笔制里唯一的实底件）
func _make_player_badge() -> Panel:
	var p := Panel.new()
	p.size = Vector2(_cell, _cell)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(QISTYLE.JADE.r, QISTYLE.JADE.g, QISTYLE.JADE.b, 0.28)
	sb.border_color = QISTYLE.JADE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	var l := _make_glyph("侠", QISTYLE.JADE, maxi(12, int(_cell * 0.6)))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _rebuild_tokens() -> void:
	for c in _tokens:
		if is_instance_valid(_tokens[c]):
			(_tokens[c] as Control).queue_free()
	_tokens = {}
	for e in map_data["entities"]:
		var cell: Vector2i = e["cell"]
		var tok: Label
		match String(e["type"]):
			"enemy":
				tok = _make_glyph(_enemy_glyph(String(e["id"])), ENEMY_INK, maxi(12, int(_cell * 0.6)))
			"boss":
				tok = _make_glyph("王", ENEMY_INK, maxi(12, int(_cell * 0.7)))
			"chest":
				tok = _make_glyph("箱", CHEST_INK, maxi(12, int(_cell * 0.55)))
			"shovel":
				tok = _make_glyph("铲", SHOVEL_INK, maxi(12, int(_cell * 0.6)))
			"exit":
				tok = _make_glyph("出", Color(0.26, 0.22, 0.17), maxi(12, int(_cell * 0.6)))
			_:
				continue
		tok.size = Vector2(_cell, _cell)
		tok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tok.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tok.position = cell_pos(cell)
		add_child(tok)
		_tokens[cell] = tok
#endregion

func _enemy_glyph(eid: String) -> String:
	var def: Dictionary = VC.ENEMIES.get(eid, {})
	var nm := String(def.get("name", "敌"))
	return nm.substr(0, 1)

func _refresh_stats() -> void:
	var lvl := int(run.get("level", 1))
	QI_CAB.refresh_top(_top_refs, lvl, int(run.get("xp", 0)), floor_idx, VC.FLOORS.size(),
		VC.xp_to_next(lvl))
	var mhp := int(run.get("mhp", VC.PLAYER_BASE["hp"]))
	QI_CAB.refresh_wings(_wing_refs, int(run.get("hp", mhp)), mhp,
		(run.get("deck", []) as Array).size(), 0)

func _on_screen_input(event: InputEvent) -> void:
	if _relic_modal_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _moving:
			return
		var off := grid_offset()
		var cell := Vector2i(int((event.position.x - off.x) / _cell), int((event.position.y - off.y) / _cell))
		if cell.x < 0 or cell.y < 0 or cell.x >= int(map_data["w"]) or cell.y >= int(map_data["h"]):
			return
		if (map_data["grid"] as Array)[cell.y][cell.x] != 1:
			return
		_walk_to(cell)

func _walk_to(cell: Vector2i) -> void:
	if _relic_modal_open:
		return
	var p: Variant = MAPGEN.path(map_data, player_cell, cell)
	if p == null:
		return
	var steps: Array = p
	if steps.size() < 2:
		return
	_moving = true
	for i in range(1, steps.size()):
		var nxt: Vector2i = steps[i]
		player_cell = nxt
		map_data["player_cell"] = player_cell
		_player_token.position = cell_pos(nxt)
		if _entity_at(nxt) != null:
			break   # 截停：实体格触发
		await get_tree().create_timer(0.06).timeout
	_moving = false
	_trigger_cell(player_cell)

## WASD 走格（2026-11-01 用户裁定：分格地图＋键盘逐格走，障碍物不走；方向键同服；
## 长按连走＝Godot 原生 Input 轮询（is_key_pressed）＋步进冷却——零自造状态机）
const STEP_INTERVAL := 0.13
var _step_cd := 0.0

func _process(delta: float) -> void:
	if _relic_modal_open:
		return
	var d := Vector2i.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d = Vector2i(0, -1)
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d = Vector2i(0, 1)
	elif Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d = Vector2i(-1, 0)
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d = Vector2i(1, 0)
	if d == Vector2i.ZERO:
		return
	_step_cd -= delta
	if _step_cd <= 0.0:
		_step_cd = STEP_INTERVAL
		_step_move(d)

func _step_move(d: Vector2i) -> void:
	if _moving or _relic_modal_open:
		return
	var nxt := player_cell + d
	if nxt.x < 0 or nxt.y < 0 or nxt.x >= int(map_data["w"]) or nxt.y >= int(map_data["h"]):
		return
	if (map_data["grid"] as Array)[nxt.y][nxt.x] != 1:
		return   # 障碍物（墙）不走
	player_cell = nxt
	map_data["player_cell"] = player_cell
	_player_token.position = cell_pos(nxt)
	_trigger_cell(player_cell)

func _entity_at(cell: Vector2i) -> Variant:
	for e in map_data["entities"]:
		if (e["cell"] as Vector2i) == cell:
			return e
	return null

func _trigger_cell(cell: Vector2i) -> void:
	if _relic_modal_open:
		return
	var e: Variant = _entity_at(cell)
	if e == null:
		return
	var ent: Dictionary = e
	match String(ent["type"]):
		"enemy":
			encounter_requested.emit(ent)
		"boss":
			boss_requested.emit(ent)
		"chest":
			var loot := String(ent.get("id", ""))
			if loot != "" and VC.NEIGONG.has(loot):
				# 2026-11-19 用户令：内功宝箱→获得弹窗（原版 ReceiveRelicModal 制）；
				# 点「获取」才入账/移除宝箱（对齐原版 Button_GetRelic→EquipRelic→Close）
				_open_neigong_modal(loot, cell)
			else:
				run["copper"] = int(run.get("copper", 0)) + 20
				_grant_toast("获得 20 铜币", cell)
				_remove_entity(cell)
		"shovel":
			_ask_dig()
		"exit":
			_remove_entity(cell)
			dig_requested.emit()   # 教程出口：走上去直接下层（不弹问话）

## 拾取提示（短提示、1.6s 淡出）：铜币等非内功宝箱用；内功已改走获得弹窗
func _grant_toast(text: String, cell: Vector2i) -> void:
	var lbl := _make_glyph(text, QISTYLE.AMBER_BRIGHT, 16)
	lbl.size = Vector2(_cell * 4.0, _cell)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = cell_pos(cell) + Vector2(-_cell * 1.5, -_cell * 0.9)
	lbl.z_index = 90
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)

#region 内功获得弹窗（2026-11-19 用户令；原版 ReceiveRelicModal 制）
## 原版证据：Nosebleed.Pancake.Modal/ReceiveRelicModal.cs:27＋游戏预制体
## GameObject/ReceiveRelicModal.prefab（1000×500 面板／图标＋名＋描述＋New!＋GET；
## 描述 0.02s/字打字机；Button_GetRelic→EquipRelic→Close；点窗外不关、无取消）。
## 我方落点：走项目唯一弹窗件 QiDialog（固定 1000×560）——标题/图标/名/描述在 content，
## 底部 OK 钮复用作「获取」；描述打完直接浮出（2026-11-19 用户口述，去掉原版 2s 等待）。
## 原版 HelperImage 列表在 prefab 为空，故无 helper 图分支；本地化以中文内联。
func _open_neigong_modal(loot: String, cell: Vector2i) -> void:
	var relic: Dictionary = VC.NEIGONG[loot]
	var sz := Vector2(1000.0, 560.0)
	_relic_modal_open = true
	var arr: Array = QIDIALOG.create(self, "", sz, "获取", "", false)
	var box = arr[1]   # 动态取（QiDialogBox 无 class_name）：title_l/ok_btn/content 均运行期成员
	if box == null:
		# 单弹窗互斥兜底：不吞奖励——直接入账＋原飘字（正常宝箱路径碰不到）
		_relic_modal_open = false
		_grant_neigong(loot)
		_remove_entity(cell)
		_grant_toast("获得内功：%s" % String(relic.get("name", loot)), cell)
		return
	box.tree_exiting.connect(func() -> void: _relic_modal_open = false)
	box.z_index = 95                       # 盖过地图飘字层（90）
	box.title_l.visible = false            # 原版无独立标题条——大标题并入内容区
	box.popup_centered(Vector2i(int(sz.x), int(sz.y)))
	# popup_centered 的 _recenter 是 deferred；先钉一次，避免首帧从左上角闪出
	box.size = sz
	box.position = (get_viewport_rect().size - sz) * 0.5

	var content: VBoxContainer = box.content()
	content.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "获得内功！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(title, 40, true)
	QISTYLE.text_color(title, QISTYLE.AMBER_BRIGHT)
	content.add_child(title)

	# 信息区（原版 RelicInfoContainer 950×290 的等价）：左侧图标底 100×100＋名字/新!／描述
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", QISTYLE.panel(0.30))
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(info)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	info.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	col.add_child(row)
	var icon_frame := Panel.new()
	icon_frame.custom_minimum_size = Vector2(100.0, 100.0)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.16, 0.12, 0.07, 0.92)
	isb.border_color = QISTYLE.AMBER
	isb.set_border_width_all(2)
	isb.set_corner_radius_all(10)
	icon_frame.add_theme_stylebox_override("panel", isb)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_frame)
	var glyph := Label.new()
	glyph.text = "功"
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	QISTYLE.font(glyph, 52, true)
	QISTYLE.text_color(glyph, QISTYLE.AMBER_BRIGHT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(glyph)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 4)
	row.add_child(name_col)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	name_col.add_child(name_row)
	var name_l := Label.new()
	name_l.text = String(relic.get("name", loot))
	QISTYLE.font(name_l, 32, true)
	QISTYLE.text_color(name_l, QISTYLE.CREAM)
	name_row.add_child(name_l)
	var new_l := Label.new()
	new_l.text = "新！"
	QISTYLE.font(new_l, 20, true)
	QISTYLE.text_color(new_l, Color("ffe15a"))
	new_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(new_l)
	var sub_l := Label.new()
	sub_l.text = "内功 · 宝箱所得"
	QISTYLE.font(sub_l, 16)
	QISTYLE.text_color(sub_l, QISTYLE.TEXT_SUB)
	name_col.add_child(sub_l)

	var desc := Label.new()
	desc.text = String(relic.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.clip_text = true
	desc.custom_minimum_size = Vector2(0.0, 150.0)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	QISTYLE.font(desc, 24)
	QISTYLE.text_color(desc, Color(0.92, 0.88, 0.78))
	desc.visible_characters = 0
	col.add_child(desc)

	# 原版 GET：打字完才出；2026-11-19 用户令「打完字直接出」——去掉原版 2s 等待
	var ok: Button = box.ok_btn
	ok.text = "获取"
	ok.custom_minimum_size = Vector2(240.0, 60.0)
	QISTYLE.font(ok, 24, true)
	ok.modulate = Color(1.0, 1.0, 1.0, 0.0)
	ok.disabled = true
	var n: int = desc.get_total_character_count()
	var tw := desc.create_tween()
	tw.tween_interval(0.25)   # 让背板淡入先走一拍
	tw.tween_property(desc, "visible_characters", n, maxf(0.2, float(n) * 0.02))
	tw.tween_callback(func() -> void:
		ok.disabled = false
		ok.pivot_offset = ok.size * 0.5
		ok.scale = Vector2(0.9, 0.9)
		var rt := ok.create_tween()
		rt.tween_property(ok, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
		rt.parallel().tween_property(ok, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ok.grab_focus())

	box.confirmed.connect(func() -> void:
		_grant_neigong(loot)
		_remove_entity(cell))

func _grant_neigong(loot: String) -> void:
	var ng: Array = run.get("neigong", [])
	if not ng.has(loot):
		ng.push_back(loot)
	run["neigong"] = ng
	_refresh_stats()
	var def: Dictionary = VC.NEIGONG.get(loot, {})
	print("[内功] 宝箱获得：%s（id=%s）→ 当前内功=%s" % [
		String(def.get("name", loot)), loot, str(ng)])
#endregion

func _remove_entity(cell: Vector2i) -> void:
	for i in range(map_data["entities"].size() - 1, -1, -1):
		if (map_data["entities"][i]["cell"] as Vector2i) == cell:
			map_data["entities"].remove_at(i)
	if _tokens.has(cell):
		if is_instance_valid(_tokens[cell]):
			(_tokens[cell] as Control).queue_free()
		_tokens.erase(cell)

## 战后回图：胜＝移除该明雷；负＝明雷保留（满血重打由宿主处理）
func after_battle(cell: Vector2i, won: bool) -> void:
	if won:
		_remove_entity(cell)
		_refresh_stats()

func _ask_dig() -> void:
	var arr: Array = QIDIALOG.create(self, "挖去下一层？", Vector2(460, 240), "挖！", "再逛逛")
	var box = arr[1]
	if box == null:
		dig_requested.emit()   # 单弹窗互斥下的兜底：直接挖
		return
	var body := Label.new()
	body.text = "拿到铲子了。\n可以先把这层逛完再挖——回头路随时能走。"
	QISTYLE.font(body, QISTYLE.FS_BODY)
	body.add_theme_color_override("font_color", Color(0.16, 0.14, 0.11))
	box.content().add_child(body)
	box.confirmed.connect(func() -> void:
		_remove_entity(player_cell)
		dig_requested.emit())
