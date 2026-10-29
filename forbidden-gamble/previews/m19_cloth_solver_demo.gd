extends Control

## 桌布↔相机联调求解器（2026-09-18 用户令「开始吧」——先定桌布基准再铺牌）。
## 反转主从关系：**物理相机是真源**——给定（俯角·收敛比·近沿占屏宽），数值解出
## 物理桌（宽/深）与相机距离，投影四边形原样回写给桌布（矩形＋top_width_ratio
## 精确复现对称透视四边形），MJBPerspective 从解出的桌布 sync——2D/3D/桌布三
## 方共用一套自洽数字，从此无"画得不物理"问题。
## 调研基准：主流收敛比 0.35–0.45（欢乐麻将实测 0.44/雀魂带 0.35–0.40），默认 0.40。
## 牌＝同物理尺寸放近/远两行（不再逐行强制 2D 宽度）——远近差全由真透视产生。

const TILE := preload("res://scenes/mahjong3d/mj3d_blank_tile.tscn")
const FONT := "res://assets/fonts/MaShanZheng-Regular.ttf"

@onready var cloth: MJBTableCloth = $桌布
@onready var cam: Camera3D = $牌层/SubViewport/Camera3D

var pitch := 40.0        # 相机俯角°（滑杆；原桌布 0.65 ⇔ 52.5°，调研带 0.35–0.45 ⇔ 36–44°）
var ratio_target := 0.44 # 收敛比（滑杆；欢乐麻将实测 0.44/雀魂带 0.35–0.40）
var near_y_target := 780.0 # 近沿屏行（滑杆；>720＝近沿出屏被切——「坐在桌边」的关键）
var near_span := 0.92    # 近沿占屏宽（滑杆）
var base_w := 50         # 近端牌宽 px（滑杆）

# v2 教训：远沿行＋收敛比＋俯角三者同时钉死＝超定无解（四何参三约束才有一自由度）。
# v3 定稿：俯角/收敛比是旋钮，**远沿行＝物理输出**——桌超出屏幕时红字警告，
# 用户降俯角或收敛比即可拉回（三量锁死的约束从坑变成看得见的调参反馈）。
# v4（用户令「一般桌面近的是超过显示的」）：近沿行开放出屏（>720），
# 整桌入屏＝隔远看模型（长方形感）；近沿出屏＝坐桌边。

const Z_NEAR := 120.0    # 近沿世界位（几何锚）
const FOV := 48.0

var solved := {}
var _hand: Mj3dTileBlank
var _far: Mj3dTileBlank
var _readout: Label
var _value_labels := {}


func _ready() -> void:
	cam.fov = FOV
	_hand = TILE.instantiate() as Mj3dTileBlank
	_far = TILE.instantiate() as Mj3dTileBlank
	var world := $牌层/SubViewport/TileWorld
	world.add_child(_hand)
	world.add_child(_far)
	await get_tree().process_frame
	_build_ui()
	_resolve()


# —— 求解：D 二分钉近沿行 → W 缩放钉近沿宽 → S 二分钉收敛比；远沿行＝输出 ——
func _resolve() -> void:
	cam.fov = FOV
	cam.look_at(Vector3.ZERO)
	var d_lo := 150.0
	var d_hi := 6000.0
	for _i in 30:
		var mid := (d_lo + d_hi) * 0.5
		_set_cam(pitch, mid)
		if _edge_y(Z_NEAR) > near_y_target:
			d_lo = mid
		else:
			d_hi = mid
	var dist := (d_lo + d_hi) * 0.5
	_set_cam(pitch, dist)
	var want_near_px := 1280.0 * near_span
	var w_t := 400.0
	for _i in 3:
		var wn := _edge_width(w_t, Z_NEAR)
		if wn < 1.0:
			break
		w_t *= want_near_px / wn
	# S 二分：ratio(S) 随深度单调降
	var s_lo := 5.0
	var s_hi := 8000.0
	for _i in 30:
		var mid := (s_lo + s_hi) * 0.5
		var r := _edge_width(w_t, Z_NEAR - mid) / _edge_width(w_t, Z_NEAR)
		if r > ratio_target:
			s_lo = mid
		else:
			s_hi = mid
	var z_far := Z_NEAR - (s_lo + s_hi) * 0.5
	# 投影四边形 → 桌布（矩形＋收敛比；桌帮归零＝四边形即呢面）
	var nl: Vector2 = cam.unproject_position(Vector3(-w_t / 2.0, 0, Z_NEAR))
	var nr: Vector2 = cam.unproject_position(Vector3(w_t / 2.0, 0, Z_NEAR))
	var fl: Vector2 = cam.unproject_position(Vector3(-w_t / 2.0, 0, z_far))
	var fr: Vector2 = cam.unproject_position(Vector3(w_t / 2.0, 0, z_far))
	cloth.apron_height = 0.0
	cloth.offset_left = nl.x
	cloth.offset_right = nr.x
	cloth.offset_top = minf(fl.y, fr.y)
	cloth.offset_bottom = nl.y
	cloth.top_width_ratio = (fl.distance_to(fr)) / maxf(1.0, nl.distance_to(nr))
	MJBPerspective.sync(cloth, cloth.top_width_ratio)
	# 牌：同一物理尺寸，近手牌行（近沿上 130px，近沿出屏时落在屏内）＋远背牌行（远沿下 50px）
	var tile_world_w := base_w / _px_per_world(Vector3(0, 0, Z_NEAR))
	var k := tile_world_w / (19.0 / 26.0)
	var solved_far_y := minf(fl.y, fr.y)
	var hand_row: float = clampf(near_y_target - 130.0, 500.0, 700.0)
	var far_row: float = solved_far_y + 50.0
	_place(_hand, hand_row, k, false)
	_place(_far, far_row, k, true)
	solved = {"pitch": pitch, "D": dist, "W": w_t, "S": Z_NEAR - z_far,
		"ratio": cloth.top_width_ratio,
		"far_y": minf(fl.y, fr.y), "near_y": nl.y}
	_update_readout()


func _set_cam(p_deg: float, dist: float) -> void:
	var r := deg_to_rad(p_deg)
	cam.position = Vector3(0, dist * sin(r), dist * cos(r))
	cam.look_at(Vector3.ZERO)


func _edge_y(z: float) -> float:
	return cam.unproject_position(Vector3(0, 0, z)).y


func _edge_width(w_t: float, z: float) -> float:
	var a := cam.unproject_position(Vector3(-w_t / 2.0, 0, z))
	var b := cam.unproject_position(Vector3(w_t / 2.0, 0, z))
	return a.distance_to(b)


func _row_y(t: float) -> float:
	return lerpf(MJBPerspective.far_y, MJBPerspective.near_y, t)


func _place(tile: Mj3dTileBlank, y_screen: float, scale_k: float, back: bool) -> void:
	var o := cam.project_ray_origin(Vector2(640, y_screen))
	var n := cam.project_ray_normal(Vector2(640, y_screen))
	var ground := o + n * (-o.y / n.y)
	tile.scale = Vector3.ONE * scale_k
	tile.stand(back, 25.0 if not back else 0.0)
	var rad := deg_to_rad(25.0)
	var lift := 0.5 * cos(rad) if not back else 0.5
	var push := -0.5 * sin(rad) if not back else 0.0
	tile.position = ground + Vector3(0, lift, push) * scale_k


func _px_per_world(p: Vector3) -> float:
	var a := cam.unproject_position(p)
	var b := cam.unproject_position(p + Vector3(1, 0, 0))
	return a.distance_to(b)


# —— 左上浮层（同 m18 交互语言）——

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
	_add_slider(box, font, "收敛比", 0.30, 0.60, 0.01, ratio_target, func(v): ratio_target = v; _resolve())
	_add_slider(box, font, "近沿行", 500.0, 900.0, 5.0, near_y_target, func(v): near_y_target = v; _resolve())
	_add_slider(box, font, "近沿占屏宽", 0.70, 1.10, 0.01, near_span, func(v): near_span = v; _resolve())
	_add_slider(box, font, "近端牌宽", 36, 64, 1, float(base_w), func(v): base_w = int(round(v)); _resolve())
	_readout = Label.new()
	if font != null:
		_readout.add_theme_font_override("font", font)
		_readout.add_theme_font_size_override("font_size", 17)
	_readout.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
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
	_value_labels[title] = value_label
	value_label.text = str(snappedf(cur, 0.01))
	slider.value_changed.connect(func(v: float):
		value_label.text = str(snappedf(v, 0.01))
		on_change.call(v))


func _update_readout() -> void:
	var hand_w := _tile_screen_w(_hand)
	var far_w := _tile_screen_w(_far)
	var felt_h: float = solved.get("near_y", 0.0) - solved.get("far_y", 0.0)
	var far_y: float = solved.get("far_y", 0.0)
	_readout.text = "收敛比 目标%.2f 实测%.3f｜近牌 %d→%.0fpx 远牌 %.0fpx\n呢面高 %.0fpx（远沿 y%.0f）｜桌 深%.0f 宽%.0f 距%.0f\n滑杆值：俯角 %.1f° 收敛 %.2f 占屏 %.2f 牌宽 %d" % [
		ratio_target, solved.get("ratio", 0.0), base_w, hand_w, far_w,
		felt_h, far_y,
		solved.get("S", 0.0), solved.get("W", 0.0), solved.get("D", 0.0),
		pitch, ratio_target, near_span, base_w]
	# 物理约束可视化：远沿出屏（<40）＝这组旋钮无解，红字指路
	if far_y < 40.0:
		_readout.text += "\n⚠ 远沿超出屏幕顶——降「俯角」或「收敛比」"
		_readout.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	else:
		_readout.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))


func _tile_screen_w(tile: Mj3dTileBlank) -> float:
	var half := 19.0 / 26.0 * 0.5
	var l: Vector2 = cam.unproject_position(tile.global_transform * Vector3(-half, -0.2, 0))
	var r: Vector2 = cam.unproject_position(tile.global_transform * Vector3(half, -0.2, 0))
	return l.distance_to(r)
