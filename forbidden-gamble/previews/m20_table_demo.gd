extends Node3D

## m20：3D 桌＋物理比例牌阵首验（2026-09-18 用户令「做桌子模型…根据比例做」）。
## 桌:牌比＝23（36 桌面 81.5cm 配 36# 牌 35.5mm，多源调研值），沿宽 2——桌模型内置。
## 牌阵＝物理推算，非任意摆：墙 136 张→每边 17 墩×2 层；此处 16 墩×4 边（128 张），
##   角部留半牌位缺口防两墙角墩同位 z-fight（演示近似）。
## 手牌行＝14 张立牌（25° 后仰面向玩家），近沿内 1 牌长、间距 1.06×宽（真实密排量级）。
## 相机（承 m19 语言）：桌宽被比例钉死 → 旋钮只剩 俯角＋近沿占屏宽＋桌牌比；
##   D 二分钉占屏宽，近沿行/收敛比/手牌宽全部退化为输出读数（不再可调）。

const TILE := preload("res://scenes/mahjong3d/mj3d_blank_tile.tscn")
const TABLE := preload("res://scenes/mahjong3d/mj3d_table.tscn")
const FONT := "res://assets/fonts/MaShanZheng-Regular.ttf"
const FOV := 48.0
const TILE_W := 19.0 / 26.0
const TILE_T := 12.0 / 26.0
const STACKS := 16    # 每边墩数（角部缺口版；满墙＝17）
const HAND_N := 14
const SHOW_TILES := false  # 2026-09-18 用户令「先不放麻将 就看牌桌」——纯桌首验

var pitch := 40.0        # 相机俯角°
var near_span := 0.92    # 近沿（框外沿顶）占屏宽
var net_side := 23.0     # 桌牌比（研究值 23＝36 桌面配 36# 牌）

var cam: Camera3D
var table: Mj3dTable
var _tiles: Array[Mj3dTileBlank] = []
var _readout: Label


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.075, 0.06)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	cam = Camera3D.new()
	cam.fov = FOV
	cam.current = true
	add_child(cam)
	table = TABLE.instantiate() as Mj3dTable
	add_child(table)
	if SHOW_TILES:
		for i in STACKS * 4 * 2 + HAND_N:
			var t := TILE.instantiate() as Mj3dTileBlank
			add_child(t)
			_tiles.append(t)
	await get_tree().process_frame
	_build_ui()
	_resolve()


# —— 求解：D 二分钉「近沿占屏宽」（桌宽已定）；其余全部＝读数输出 ——
func _resolve() -> void:
	table.net_side = net_side
	if SHOW_TILES:
		_place_tiles()
	cam.fov = FOV
	var z_ne := net_side * 0.5 + Mj3dTable.RIM_W
	var want := 1280.0 * near_span
	var d_lo := 8.0
	var d_hi := 400.0
	for _i in 40:
		var mid := (d_lo + d_hi) * 0.5
		_set_cam(pitch, mid)
		if _rim_w(z_ne) > want:
			d_lo = mid   # 太宽 → 拉远
		else:
			d_hi = mid
	_set_cam(pitch, (d_lo + d_hi) * 0.5)
	_update_readout()


func _set_cam(p_deg: float, dist: float) -> void:
	var r := deg_to_rad(p_deg)
	cam.position = Vector3(0, dist * sin(r), dist * cos(r))
	cam.look_at(Vector3.ZERO)


func _rim_w(z: float) -> float:
	var x := net_side * 0.5 + Mj3dTable.RIM_W
	var a := cam.unproject_position(Vector3(-x, table.rim_height, z))
	var b := cam.unproject_position(Vector3(x, table.rim_height, z))
	return a.distance_to(b)


func _felt_w(z: float) -> float:
	var x := net_side * 0.5
	var a := cam.unproject_position(Vector3(-x, 0, z))
	var b := cam.unproject_position(Vector3(x, 0, z))
	return a.distance_to(b)


# —— 牌阵（物理推算布局）——
func _place_tiles() -> void:
	var half := net_side * 0.5
	var ring := STACKS * TILE_W * 0.5   # 墙中心线（±ring；墙总长 16×0.73≈11.7 牌长）
	var rad := deg_to_rad(25.0)
	var lift := 0.5 * cos(rad)
	var push := -0.5 * sin(rad)
	var hand_z := half - 1.0
	for s in 4:
		for i in STACKS:
			for lv in 2:
				var t := _tiles[s * STACKS * 2 + i * 2 + lv]
				var off := (i - (STACKS - 1) * 0.5) * TILE_W
				var y := TILE_T * (0.5 + float(lv))
				match s:
					0: t.position = Vector3(off, y, -ring)
					1: t.position = Vector3(off, y, ring)
					2:
						t.position = Vector3(-ring, y, off)
						t.rotation = Vector3(PI / 2.0, PI / 2.0, 0)
						continue
					3:
						t.position = Vector3(ring, y, off)
						t.rotation = Vector3(PI / 2.0, PI / 2.0, 0)
						continue
				t.rotation = Vector3(PI / 2.0, 0, 0)
	for i in HAND_N:
		var t := _tiles[STACKS * 4 * 2 + i]
		t.position = Vector3((i - (HAND_N - 1) * 0.5) * TILE_W * 1.06 + push, lift, hand_z + push)
		t.stand(false, 25.0)


func _update_readout() -> void:
	var half := net_side * 0.5
	var z_ne := half + Mj3dTable.RIM_W
	var felt_near_y := cam.unproject_position(Vector3(0, 0, half)).y
	var felt_far_y := cam.unproject_position(Vector3(0, 0, -half)).y
	var rim_near_y := cam.unproject_position(Vector3(0, table.rim_height, z_ne)).y
	var rim_far_y := cam.unproject_position(Vector3(0, table.rim_height, -z_ne)).y
	var ratio := _felt_w(-half) / maxf(1.0, _felt_w(half))
	var zh := half - 1.0
	var a := cam.unproject_position(Vector3(-TILE_W * 0.5, 0.3, zh))
	var b := cam.unproject_position(Vector3(TILE_W * 0.5, 0.3, zh))
	var hand_px := a.distance_to(b)
	var felt_h := felt_near_y - felt_far_y
	_readout.text = "收敛比 实测 %.3f｜近沿 y%.0f%s｜呢面高 %.0fpx＝%.0f%%屏\n手牌宽 %.0fpx｜墙长 %.1f 牌长＝桌边 %.0f%%｜D %.1f\n俯角 %.1f° 占屏宽 %.2f 桌牌比 %.1f（研究值 23）" % [
		ratio, rim_near_y, "（出屏裁切）" if rim_near_y > 720.0 else "（整桌入屏）",
		felt_h, felt_h / 7.2,
		hand_px, STACKS * TILE_W, STACKS * TILE_W / net_side * 100.0, cam.position.length(),
		pitch, near_span, net_side]
	if rim_far_y < 40.0:
		_readout.text += "\n⚠ 远沿出屏顶——降「俯角」或「占屏宽」"
		_readout.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	else:
		_readout.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))


# —— 左上浮层（同 m18/m19 交互语言）——
func _build_ui() -> void:
	var font := load(FONT) as Font
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.88)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_add_slider(box, font, "俯角", 30.0, 75.0, 0.5, pitch, func(v): pitch = v; _resolve())
	_add_slider(box, font, "近沿占屏宽", 0.70, 1.15, 0.01, near_span, func(v): near_span = v; _resolve())
	_add_slider(box, font, "桌牌比", 15.0, 30.0, 0.5, net_side, func(v): net_side = v; _resolve())
	_readout = Label.new()
	if font != null:
		_readout.add_theme_font_override("font", font)
		_readout.add_theme_font_size_override("font_size", 17)
	box.add_child(_readout)


func _add_slider(box: VBoxContainer, font: Font, title: String, lo: float, hi: float, step: float, cur: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(104, 0)
	if font != null:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = cur
	slider.custom_minimum_size = Vector2(230, 24)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(56, 0)
	if font != null:
		value_label.add_theme_font_override("font", font)
		value_label.add_theme_font_size_override("font_size", 19)
		value_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	row.add_child(value_label)
	value_label.text = str(snappedf(cur, 0.01))
	slider.value_changed.connect(func(v: float):
		value_label.text = str(snappedf(v, 0.01))
		on_change.call(v))
