extends Control

## 无光空白牌×2D 桌布合成·**可调样机**（2026-09-18 用户令「先调吧 我怎么调 怎么看效果」）。
## 运行后左上浮层四滑杆：后倾角／相机俯角／手牌行位／近端牌宽——拖动实时重落牌，
## 读数条实时显示参数与实测（底棱宽/落行 y）。调满意记下四值回报，回填定稿用。
## 架构不变：2D 桌布＝校准基准；3D 牌层零光源 UNSHADED；逆投影＋定点迭代落位。

const TILE := preload("res://scenes/mahjong3d/mj3d_blank_tile.tscn")
const FONT := "res://assets/fonts/MaShanZheng-Regular.ttf"

@onready var cloth: Control = $桌布
@onready var cam: Camera3D = $牌层/SubViewport/Camera3D

const CAM_LOOK := Vector3(0, 0, -30)
const CAM_DIST := sqrt(620.0 * 620.0 + 460.0 * 460.0)   # 766（弧上移机位不改距离）

var lean := 25.0        # 后倾角°
var pitch := 53.4       # 相机俯角°
var hand_t := 0.90      # 手牌行位（0=呢面远缘 1=近缘）
var base_w := 50        # 近端基准牌宽 px（写回 MJBPerspective.base_w，走真系统旋钮）

var _tile: Mj3dTileBlank
var _readout: Label
var _value_labels := {}


func _ready() -> void:
	_apply_camera()
	await get_tree().process_frame   # 桌布布局落定后再取矩形
	MJBPerspective.sync(cloth, cloth.top_width_ratio)
	_tile = TILE.instantiate() as Mj3dTileBlank
	$牌层/SubViewport/TileWorld.add_child(_tile)
	_build_ui()
	_place_tile()


func _apply_camera() -> void:
	var r := deg_to_rad(pitch)
	cam.position = CAM_LOOK + Vector3(0, sin(r), cos(r)) * CAM_DIST
	cam.look_at(CAM_LOOK)


## 落牌：逆投影定世界位＋定点迭代收敛（实测投影宽反哺尺度，三轮亚像素）；
## 落点按倾角补偿（底棱精确压目标行）。
func _place_tile() -> void:
	var y_hand: float = lerpf(MJBPerspective.far_y, MJBPerspective.near_y, hand_t)
	MJBPerspective.base_w = base_w
	var want_w: float = float(MJBPerspective.tile_size_at(y_hand).x)
	var ground := _ground_at(Vector2(640, y_hand))
	var k := _px_per_world_at(ground)
	var scale_k := want_w / (k * (19.0 / 26.0))
	_tile.stand(false, lean)
	var rad := deg_to_rad(lean)
	for _i in 3:
		_tile.scale = Vector3.ONE * scale_k
		_tile.position = ground + Vector3(0, 0.5 * cos(rad), -0.5 * sin(rad)) * scale_k
		var half := 19.0 / 26.0 * 0.5
		var l: Vector2 = cam.unproject_position(_tile.global_transform * Vector3(-half, -0.49, 0))
		var r: Vector2 = cam.unproject_position(_tile.global_transform * Vector3(half, -0.49, 0))
		var got := l.distance_to(r)
		if got < 0.5:
			break
		scale_k *= want_w / got
	_update_readout()


func _ground_at(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var n := cam.project_ray_normal(screen)
	return o + n * (-o.y / n.y)


func _px_per_world_at(p: Vector3) -> float:
	var a := cam.unproject_position(p)
	var b := cam.unproject_position(p + Vector3(1, 0, 0))
	return a.distance_to(b)


## —— 左上调参浮层 ——

func _build_ui() -> void:
	var font := load(FONT) as Font
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.86)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_add_slider(box, font, "后倾角", 0.0, 45.0, 1.0, lean,
		func(v: float): lean = v; _place_tile())
	_add_slider(box, font, "相机俯角", 40.0, 70.0, 0.5, pitch,
		func(v: float): pitch = v; _apply_camera(); _place_tile())
	_add_slider(box, font, "手牌行位 t", 0.5, 1.0, 0.01, hand_t,
		func(v: float): hand_t = v; _place_tile())
	_add_slider(box, font, "近端牌宽", 36, 64, 1, float(base_w),
		func(v: float): base_w = int(round(v)); _place_tile())
	_readout = Label.new()
	if font != null:
		_readout.add_theme_font_override("font", font)
		_readout.add_theme_font_size_override("font_size", 18)
	_readout.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	box.add_child(_readout)


func _add_slider(box: VBoxContainer, font: Font, title: String, lo: float, hi: float, step: float, cur: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(96, 0)
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
	slider.custom_minimum_size = Vector2(240, 24)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(64, 0)
	if font != null:
		value_label.add_theme_font_override("font", font)
		value_label.add_theme_font_size_override("font_size", 19)
		value_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	row.add_child(value_label)
	_value_labels[title] = value_label
	value_label.text = _fmt_value(cur)
	slider.value_changed.connect(func(v: float):
		value_label.text = _fmt_value(v)
		on_change.call(v))


func _fmt_value(v: float) -> String:
	return str(snappedf(v, 0.01))


func _update_readout() -> void:
	var y_hand: float = lerpf(MJBPerspective.far_y, MJBPerspective.near_y, hand_t)
	var want_w: float = float(MJBPerspective.tile_size_at(y_hand).x)
	var half := 19.0 / 26.0 * 0.5
	var l: Vector2 = cam.unproject_position(_tile.global_transform * Vector3(-half, -0.5, 0))
	var r: Vector2 = cam.unproject_position(_tile.global_transform * Vector3(half, -0.5, 0))
	_readout.text = "底棱宽 %.1f／目标 %.0f　底棱行 y%.0f／目标 %.0f\n倾角 %.1f°　俯角 %.1f°　行位 %.2f　牌宽 %d" % [
		l.distance_to(r), want_w, l.y, y_hand, lean, pitch, hand_t, base_w]
