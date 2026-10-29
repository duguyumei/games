@tool
extends Node
## 平面桌烘焙台·满屏版（2026-09-24 用户「桌面纯平铺满」定案）。
## 呢面满屏四边不出框（桌沿/桌帮退役）、顶视正射无透视；2.5D 感由牌精灵扛。
## 方形呢面 23×23（同 studio 贴图映射＝纹理无形变、方向保正），相机框 19.0×10.7 裁中带、锁 16:9 满幅。
## 光影＝场景内四角灯斑渐变面片直烘入图（远近暗化已撤——呢面自带亮渐变＝studio 原性格）。
## F6 运行＝自动烘存 res://assets/bake/table_fullbleed_2x.png 并留满屏 2D 预览；
## 预览层含气海嵌块（V5 中线中央·动态 2D 件·余数检查器可调）＋三杆挂签架（bake_rail.gd·tscn 真节点单杆可拖），均不进底图。
## 编辑器内只预览不写盘。带沿旧版产物 table_flat_2x.png 留档（近沿要回归时可用）。

const OUT_PATH := "res://assets/bake/table_fullbleed_2x.png"
const BAKE_W := 2560          # 2×（2D 对局 1280 宽，16:9 满幅）
const NET := 23.0             # 呢面边长（牌长数，同 studio——方形＝贴图无形变）
const FRAME_H := 10.7         # 相机框高（牌长数；框宽＝FRAME_H×16/9 自动、呢面裁中带）

@export var qisea_count := 64:  # 气海余数（检查器可调；「余 N 张」动态 2D 件预览）
	set(v):
		qisea_count = v
		if _qisea_cnt != null:
			_qisea_cnt.text = "余 %d 张" % v

var _vp: SubViewport
var _cam: Camera3D
var _qisea_cnt: Label

func _ready() -> void:
	_build_scene()
	_layout_camera()
	if not Engine.is_editor_hint():
		_bake.call_deferred()

func _build_scene() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.handle_input_locally = false
	add_child(_vp)

	var world := Node3D.new()
	world.name = "BakeWorld"
	_vp.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.6
	sun.position = Vector3(0, 5, 0)
	sun.rotation_degrees = Vector3(-50, 30, 0)   # studio 同款（−50°X＋方位角偏 30°）
	world.add_child(sun)

	var table: Mj3dTable = load("res://scenes/mahjong3d/mj3d_table.tscn").instantiate()
	table.felt_texture = load("res://assets/table/felt_user.png")
	table.net_side = NET
	world.add_child(table)
	# 贴图不翻 V：呢面图带方向性竹纹，翻转会倒（2026-09-24 用户「怎么竹子倒过来了」）。
	# 呢面自带亮渐变（顶亮底暗）＝studio 同款性格，保留不强扭；远近暗化撤除。

	_shade_quad(world, _grad_vignette())  # 四角灯斑压暗（仅此一件）

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.rotation_degrees = Vector3(-90, 0, 0)
	_cam.near = 1.0
	_cam.far = 200.0
	world.add_child(_cam)

	# 2D 预览：所见即烘焙所得（满屏）
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.19, 0.22, 0.26)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var pv := TextureRect.new()
	pv.texture = _vp.get_texture()
	pv.set_anchors_preset(Control.PRESET_FULL_RECT)
	pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.add_child(pv)
	layer.add_child(_build_qisea())   # 气海＝动态 2D 件，只进预览层不进底图
	# 三杆挂签架＝tscn 真节点「架层/功法杆·护身杆·心法杆」（单杆可拖、存盘保留）

func _layout_camera() -> void:
	_vp.size = Vector2(BAKE_W, int(round(BAKE_W * 9.0 / 16.0)))
	_cam.position = Vector3(0, 50, 0)
	_cam.size = FRAME_H   # 正射高＝框高，宽自动＝FRAME_H×16/9≈19.0（呢面 23 裁中带）

func _shade_quad(parent: Node3D, tex: GradientTexture2D) -> void:
	# 面片尺寸＝相机框（铺满可见区）——大于框会让渐变爬坡落在框外（首轮实测踩坑）。
	var frame_w := FRAME_H * 16.0 / 9.0
	var qm := QuadMesh.new()
	qm.size = Vector2(frame_w, FRAME_H)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	qm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.position = Vector3(0, 0.05, 0)
	mi.rotation_degrees = Vector3(-90, 0, 0)
	parent.add_child(mi)

func _grad_vignette() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.10)])
	var t := GradientTexture2D.new()
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.gradient = g
	return t

func _build_qisea() -> Panel:
	## 气海嵌块（V5 中线战况带中央·样式对齐效果图：圆角嵌块＋金字＋余数＋下投影）。
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(74.0 / 255.0, 69.0 / 255.0, 60.0 / 255.0)
	sb.border_color = Color(112.0 / 255.0, 100.0 / 255.0, 77.0 / 255.0)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 4)
	var p := Panel.new()
	p.name = "气海"
	p.add_theme_stylebox_override("panel", sb)
	p.anchor_left = 0.5
	p.anchor_top = 0.5
	p.anchor_right = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -61
	p.offset_top = -33
	p.offset_right = 61
	p.offset_bottom = 33
	var font := load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	var title := Label.new()
	title.name = "标题"
	title.text = "气海"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(235.0 / 255.0, 219.0 / 255.0, 179.0 / 255.0))
	var cnt := Label.new()
	cnt.name = "余数"
	cnt.text = "余 %d 张" % qisea_count
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.add_theme_font_override("font", font)
	cnt.add_theme_font_size_override("font_size", 13)
	cnt.add_theme_color_override("font_color", Color(217.0 / 255.0, 204.0 / 255.0, 174.0 / 255.0))
	_qisea_cnt = cnt
	var vb := VBoxContainer.new()
	vb.name = "内容"
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(title)
	vb.add_child(cnt)
	p.add_child(vb)
	return p

func _bake() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw  # 等 SubViewport 首帧出图
	var img := _vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://assets/bake")
	img.save_png(OUT_PATH)
	print("[bake_flat_table] saved ", OUT_PATH, " ", img.get_size())
