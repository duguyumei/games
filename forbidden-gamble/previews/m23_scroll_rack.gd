@tool
class_name M23ScrollRack
extends Node3D

## 卷轴架：斜立式五槽木架（2026-09-22 试制，用户令「做个架子吧」）。
## 形制＝底座＋前挡条＋槽间隔挡＋斜靠背（比卷陡 12°：卷底在前槽、上背靠板）＋
## 轨色名牌（功/护/心）＋素占位棒（可开关；卷轴本体本轮不做）。
## 斜立要义＝卷名面朝玩家（−60° 机位读名偏轴约 40°）；
## 槽位01..05＝将来挂卷/碰撞体的锚点（本轮不装交互）。
## 全参数检查器导出＝手调；子件脚本建（owner 留空不入档）；位置拖根节点。


const FONT := preload("res://assets/fonts/MaShanZheng-Regular.ttf")

const WOOD := Color(0.30, 0.21, 0.14)        # 架体木色（同谱卷轴木）
const WOOD_LIGHT := Color(0.42, 0.31, 0.20)  # 隔挡/挡条浅一档
const BONE_ROD := Color(0.88, 0.85, 0.76)    # 占位棒纸色
const BONE_TEXT := Color(0.92, 0.89, 0.80)   # 名牌字（骨白档）

@export var title := "功":
	set(v):
		title = v
		_rebuild()
@export var rail_color := Color(0.72, 0.25, 0.2):
	set(v):
		rail_color = v
		_rebuild()
@export var n_slots := 5:
	set(v):
		n_slots = clampi(v, 1, 8)
		_rebuild()
@export var filled := 3:
	set(v):
		filled = clampi(v, 0, n_slots)
		_rebuild()
@export var show_placeholders := true:
	set(v):
		show_placeholders = v
		_rebuild()
@export var scroll_diam := 0.35:
	set(v):
		scroll_diam = maxf(0.15, v)
		_rebuild()
@export var scroll_len := 1.5:
	set(v):
		scroll_len = maxf(0.4, v)
		_rebuild()
@export var slot_gap := 0.12:
	set(v):
		slot_gap = maxf(0.02, v)
		_rebuild()
@export var lean_deg := 70.0:
	set(v):
		lean_deg = clampf(v, 45.0, 85.0)
		_rebuild()


func _ready() -> void:
	_rebuild()


func _slot_x(i: int) -> float:
	return (i - (n_slots - 1) / 2.0) * (scroll_diam + slot_gap)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var r := scroll_diam / 2.0
	var pitch := scroll_diam + slot_gap
	var lean := deg_to_rad(lean_deg)
	var rack_w := n_slots * pitch + 0.6
	var depth := scroll_len * cos(lean) + scroll_diam + 0.5
	var base_h := 0.09
	var back_h := scroll_len * sin(lean) * 0.78
	var beta := lean_deg + 12.0  # 靠背比卷陡——卷底前槽、上背靠板
	var z_e := -depth / 2.0 + 0.10  # 靠背底缘（底座后沿）

	# 底座
	_add_box("底座", Vector3(rack_w, base_h, depth), WOOD, 0.8,
			Vector3(0, base_h / 2.0, 0))
	# 前挡条（卷底防滚出）
	_add_box("前挡条", Vector3(rack_w, 0.15, 0.08), WOOD_LIGHT, 0.8,
			Vector3(0, base_h + 0.075, depth / 2.0 - 0.09))
	# 斜靠背＋轨色顶饰条
	var d_b := Vector3(0, sin(deg_to_rad(beta)), -cos(deg_to_rad(beta)))
	var back := _add_box("斜靠背", Vector3(rack_w, back_h, 0.07), WOOD, 0.8,
			Vector3(0, base_h + back_h / 2.0 * d_b.y, z_e + back_h / 2.0 * d_b.z))
	back.rotation_degrees.x = beta - 90.0
	var top_pt := Vector3(0, base_h + back_h * d_b.y, z_e + back_h * d_b.z)
	var trim := _add_box("轨色饰条", Vector3(rack_w, 0.06, 0.075), rail_color, 0.7, top_pt)
	trim.rotation_degrees.x = beta - 90.0
	# 槽间隔挡（含两端共 n+1 块）＋槽位锚点
	var z_div := depth / 2.0 - 0.30
	for i in n_slots + 1:
		var bx := (i - n_slots / 2.0) * pitch
		_add_box("隔挡%02d" % i, Vector3(0.06, 0.24, 0.30), WOOD_LIGHT, 0.8,
				Vector3(bx, base_h + 0.12, z_div))
	for i in n_slots:
		var m := Node3D.new()
		m.name = "槽位%02d" % (i + 1)
		m.position = Vector3(_slot_x(i), base_h + r, z_div)
		add_child(m)
	# 素占位棒（斜靠，轴向 (0, sinθ, −cosθ)）
	if show_placeholders:
		for i in filled:
			var rod := CylinderMesh.new()
			rod.top_radius = r
			rod.bottom_radius = r
			rod.height = scroll_len
			var rm := _add_mesh("占位棒%02d" % (i + 1), rod, _mat(BONE_ROD, 0.9),
					Vector3(_slot_x(i), base_h + r, z_div))
			rm.rotation_degrees.x = lean_deg - 90.0
	# 轨色名牌（前中、面仰向玩家）
	var plate := _add_box("名牌", Vector3(0.55, 0.06, 0.30), rail_color, 0.75,
			Vector3(0, base_h + 0.28, depth / 2.0 - 0.13))
	plate.rotation_degrees.x = 25.0
	var tl := _add_label(title, BONE_TEXT, 34)
	tl.name = "谱名"
	tl.position = plate.position + Vector3(0, 0.046, 0.021)
	tl.rotation_degrees.x = -65.0


func _add_box(n: String, size: Vector3, albedo: Color, rough: float, pos: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _add_mesh(n, box, _mat(albedo, rough), pos)


func _add_mesh(n: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _add_label(text: String, color: Color, px: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = px
	l.pixel_size = 0.01
	l.modulate = color
	add_child(l)
	return l


func _mat(albedo: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	return m
