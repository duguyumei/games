@tool
class_name Mj3dTable
extends Node3D

## 3D 麻将桌（2026-09-18 用户令「你还是做个3D的桌子吧」——2D 桌布透视退役）。
## 比例＝调研实测，单位＝当前牌模型（长 26mm 档＝1）：
##   自动桌 36 桌面净呢面 81.5×81.5cm、外框 96×96cm
##   （百度经验/知乎/万师傅/房天下多源一致；专利 CN219962226U 亦载 81.5）
##   配 36# 牌（长 35.5mm）→ 桌边 815/35.5≈23 牌长／框 960/35.5≈27／沿宽≈2 牌长。
## 受光路线（2026-09-20 用户令「感觉还是要光照」）：标准材质＋场景灯（studio＝
## 低环境光＋顶前方向光）；灯斑/呢面颗粒仍烘焙贴图，体积感交给真光照。
## 腿省略：固定俯角机位下被近沿/桌帮遮挡，任何角度不可见。

const RIM_W := 1.0          # 桌沿宽（牌长数）——2026-09-20 用户令「边框改成1」（研究值 2.04，现用户定 1）
const APRON_THICK := 0.8    # 桌帮壁厚（视觉量，无调研源）

@export var net_side := 23.0:   # 桌边长（牌长数）——23＝36 桌面研究值
	set(v):
		net_side = v
		_rebuild()
@export var net_side_z := 0.0:  # 深向桌边（牌长数；0＝随 net_side 方形——2026-09-24 平面烘焙深桌用）
	set(v):
		net_side_z = v
		_rebuild()
@export var rim_height := 0.4:  # 桌沿高出呢面（视觉量，无调研源）
	set(v):
		rim_height = v
		_rebuild()
@export var apron_depth := 3.0: # 桌帮下垂深（视觉量；机位内只露出近端一截）
	set(v):
		apron_depth = v
		_rebuild()
@export var felt_color := Color(0.12, 0.33, 0.21):
	set(v):
		felt_color = v
		_rebuild_mats()
@export var felt_texture: Texture2D:  # 外贴呢面图（2026-09-20 用户令「换图片不是换颜色」）；空＝程序烘焙
	set(v):
		felt_texture = v
		_rebuild_mats()
@export var rim_color := Color(0.30, 0.20, 0.12):
	set(v):
		rim_color = v
		_rebuild_mats()
@export var apron_color := Color(0.16, 0.11, 0.075):
	set(v):
		apron_color = v
		_rebuild_mats()
@export var lamp_strength := 0.16:  # 呢面四角压暗（2D 灯斑的 3D 版：径向乘子烘焙）
	set(v):
		lamp_strength = v
		_rebuild_mats()
@export var grain_strength := 0.05: # 呢面颗粒幅度
	set(v):
		grain_strength = v
		_rebuild_mats()

var _felt_mat: StandardMaterial3D
var _rim_top_mat: StandardMaterial3D
var _rim_wall_mat: StandardMaterial3D
var _apron_mat: StandardMaterial3D


func _ready() -> void:
	_build()


# tscn 属性载入时 setter 先于入树触发——入树后统一由 _build 建，避免双建。
func _rebuild() -> void:
	if is_inside_tree():
		_build()


func _rebuild_mats() -> void:
	if not is_inside_tree():
		return
	_ensure_mats()
	_apply_mats()


func _build() -> void:
	for c in get_children():
		if c.name == "TableTop":
			remove_child(c)
			c.free()
	var root := Node3D.new()
	root.name = "TableTop"
	add_child(root)
	_ensure_mats()
	var half := net_side * 0.5
	var depth := net_side_z if net_side_z > 0.0 else net_side
	var half_z := depth * 0.5
	var edge_x := half + RIM_W * 0.5
	var edge_z := half_z + RIM_W * 0.5
	# 呢面（XZ 平面 y=0；灯斑+颗粒+外缘接缝暗线全烘焙在灰度乘子里）
	var felt := MeshInstance3D.new()
	felt.name = "Felt"
	var pm := PlaneMesh.new()
	pm.size = Vector2(net_side, depth)
	felt.mesh = pm
	felt.material_override = _felt_mat
	root.add_child(felt)
	# 桌沿 ×4：北南整长（27＝23+2×2），东西嵌在北南之间。
	# 上下两层盒：顶盖板亮色＋沿壁暗一档（「上亮下暗」用几何分层实现——
	# BoxMesh 侧壁 V 轴朝向随面而变，贴图渐变实测不可靠，2026-09-18 本轮实锤）
	var cap_h := minf(0.12, rim_height * 0.5)
	var top_ns := BoxMesh.new()
	top_ns.size = Vector3(net_side + 2.0 * RIM_W, cap_h, RIM_W)
	var top_ew := BoxMesh.new()
	top_ew.size = Vector3(RIM_W, cap_h, depth)
	var wall_h := rim_height - cap_h
	var wall_ns := BoxMesh.new()
	wall_ns.size = Vector3(net_side + 2.0 * RIM_W, wall_h, RIM_W)
	var wall_ew := BoxMesh.new()
	wall_ew.size = Vector3(RIM_W, wall_h, depth)
	for i in 2:
		var s := 1.0 if i == 1 else -1.0
		var rz := MeshInstance3D.new()
		rz.name = "RimWallNS%d" % i
		rz.mesh = wall_ns
		rz.material_override = _rim_wall_mat
		rz.position = Vector3(0, wall_h * 0.5, edge_z * s)
		root.add_child(rz)
		var rz_top := MeshInstance3D.new()
		rz_top.name = "RimTopNS%d" % i
		rz_top.mesh = top_ns
		rz_top.material_override = _rim_top_mat
		rz_top.position = Vector3(0, rim_height - cap_h * 0.5, edge_z * s)
		root.add_child(rz_top)
		var rx := MeshInstance3D.new()
		rx.name = "RimWallEW%d" % i
		rx.mesh = wall_ew
		rx.material_override = _rim_wall_mat
		rx.position = Vector3(edge_x * s, wall_h * 0.5, 0)
		root.add_child(rx)
		var rx_top := MeshInstance3D.new()
		rx_top.name = "RimTopEW%d" % i
		rx_top.mesh = top_ew
		rx_top.material_override = _rim_top_mat
		rx_top.position = Vector3(edge_x * s, rim_height - cap_h * 0.5, 0)
		root.add_child(rx_top)
	# 桌帮 ×4：外沿壁 y∈[−apron_depth, −0.02]（顶缝下移 0.02 防与沿底共面）
	var ap_ns := BoxMesh.new()
	ap_ns.size = Vector3(net_side + 2.0 * RIM_W, apron_depth, APRON_THICK)
	var ap_ew := BoxMesh.new()
	ap_ew.size = Vector3(APRON_THICK, apron_depth, depth + 2.0 * RIM_W)
	var ap_in := half + RIM_W - APRON_THICK * 0.5
	var ap_in_z := half_z + RIM_W - APRON_THICK * 0.5
	for i in 2:
		var s := 1.0 if i == 1 else -1.0
		var az := MeshInstance3D.new()
		az.name = "ApronNS%d" % i
		az.mesh = ap_ns
		az.material_override = _apron_mat
		az.position = Vector3(0, -apron_depth * 0.5 - 0.02, ap_in_z * s)
		root.add_child(az)
		var ax := MeshInstance3D.new()
		ax.name = "ApronEW%d" % i
		ax.mesh = ap_ew
		ax.material_override = _apron_mat
		ax.position = Vector3(ap_in * s, -apron_depth * 0.5 - 0.02, 0)
		root.add_child(ax)


func _ensure_mats() -> void:
	_felt_mat = StandardMaterial3D.new()
	_felt_mat.albedo_color = felt_color
	_felt_mat.albedo_texture = felt_texture if felt_texture != null else _bake_felt()
	_rim_top_mat = _flat_mat(rim_color)
	_rim_wall_mat = _flat_mat(rim_color.darkened(0.28))
	_apron_mat = _flat_mat(apron_color)


func _apply_mats() -> void:
	if not has_node("TableTop"):
		return
	for part in $TableTop.get_children():
		if part.name == "Felt":
			part.material_override = _felt_mat
		elif part.name.begins_with("RimTop"):
			part.material_override = _rim_top_mat
		elif part.name.begins_with("RimWall"):
			part.material_override = _rim_wall_mat
		else:
			part.material_override = _apron_mat


func _flat_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


# 呢面贴图：灰度乘子（×albedo_color 出真色）。灯斑＝径向压暗，颗粒＝噪声，
# 外缘 7px 暗线＝呢面沉入桌沿的接缝（2D 桌布内缘暗线等价）。
func _bake_felt() -> ImageTexture:
	const S := 512
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.22
	noise.seed = 7
	for y in S:
		for x in S:
			var u := (float(x) + 0.5) / S - 0.5
			var v := (float(y) + 0.5) / S - 0.5
			var d := Vector2(u, v).length() / 0.7071
			var lamp := 1.0 - lamp_strength * clampf(d * 1.45, 0.0, 1.0)
			var grain := 1.0 + noise.get_noise_2d(x, y) * grain_strength
			var t := clampf(lamp * grain, 0.0, 1.0)
			var edge := minf(minf(x, y), S - 1 - maxf(x, y))
			if edge < 7.0:
				t *= lerpf(0.78, 1.0, edge / 7.0)
			img.set_pixel(x, y, Color(t, t, t))
	return ImageTexture.create_from_image(img)
