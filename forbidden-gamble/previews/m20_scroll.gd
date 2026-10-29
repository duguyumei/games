@tool
class_name M20Scroll
extends Node3D

## 谱卷：摊开的武学卷（2026-09-22 试制轮，用户令「做个卷模型给我看看」）。
## 形制＝一轨一卷（功法谱/护身谱/心法谱）：纸面平铺毯面、两端卷轴＋轴头、
## 右端轨色题签（谱名单字）、条目竖列右起＝槽序（传统书写序）。
## 状态语法：preview_mark＝朱笔圈第几条（文人批注传统，接朱印语言）。
## 免费模型搜索结论：无许可证干净的中式卷轴（2026-09-22），走程序化（同麻将牌轮）。
## 全参数检查器导出＝用户手调；位置拖根节点；子件脚本建（@tool 编辑器即渲染，
## owner 留空不入存档，避免与 _rebuild 重复挂载）。


const FONT := preload("res://assets/fonts/MaShanZheng-Regular.ttf")

const PAPER := Color(0.93, 0.90, 0.82)      # 纸面骨白（用色三调·骨白档）
const WOOD := Color(0.30, 0.21, 0.14)       # 卷轴轴木
const KNOB := Color(0.85, 0.80, 0.70)       # 轴头骨色（略深于纸）
const INK := Color(0.13, 0.11, 0.09)        # 墨字（同 HUD 签墨色）
const VERMILLION := Color(0.72, 0.25, 0.2)  # 朱笔圈（朱批传统，功法朱同源）
const BONE := Color(0.92, 0.89, 0.80)       # 题签上的谱名字（骨白档）

@export var title := "功":
	set(v):
		title = v
		_rebuild()
@export var rail_color := Color(0.72, 0.25, 0.2):
	set(v):
		rail_color = v
		_rebuild()
@export var entries: PackedStringArray = ["点穴", "连环掌", "破甲拳"]:
	set(v):
		entries = v
		_rebuild()
@export var paper_w := 3.2:
	set(v):
		paper_w = maxf(1.4, v)
		_rebuild()
@export var paper_d := 1.7:
	set(v):
		paper_d = maxf(0.9, v)
		_rebuild()
@export var entry_font_px := 40:
	set(v):
		entry_font_px = maxi(16, v)
		_rebuild()
@export var col_step := 0.46:
	set(v):
		col_step = maxf(0.25, v)
		_rebuild()
@export var preview_mark := -1:
	set(v):
		preview_mark = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var top := 0.05  # 纸面中心离根高度（毯面上微浮）
	var slip_w := 0.42
	var roller_r := 0.10
	var roller_x := paper_w / 2.0 + 0.02

	_add_box("纸面", Vector3(paper_w, 0.03, paper_d), PAPER, 1.0, Vector3(0, top, 0))

	for side in [-1.0, 1.0]:
		var roller := CylinderMesh.new()
		roller.top_radius = roller_r
		roller.bottom_radius = roller_r
		roller.height = paper_d + 0.18
		var rm := _add_mesh("卷轴" + ("右" if side > 0 else "左"), roller,
				_mat(WOOD, 0.7), Vector3(side * roller_x, top, 0))
		rm.rotation_degrees.x = 90.0  # 圆柱轴向 y→z
		for end in [-1.0, 1.0]:
			var knob := CylinderMesh.new()
			knob.top_radius = 0.075
			knob.bottom_radius = 0.075
			knob.height = 0.12
			var km := _add_mesh("轴头", knob, _mat(KNOB, 0.6),
					Vector3(side * roller_x, top, end * (paper_d / 2.0 + 0.14)))
			km.rotation_degrees.x = 90.0

	var slip_x := paper_w / 2.0 - 0.46
	_add_box("题签", Vector3(slip_w, 0.035, paper_d - 0.30), rail_color, 0.85,
			Vector3(slip_x, top + 0.017, 0))
	var tl := _add_label(title, BONE, 46)
	tl.name = "谱名"
	tl.position = Vector3(slip_x, top + 0.05, 0)

	var col0_x := paper_w / 2.0 - 1.16
	for i in entries.size():
		var e: String = entries[i]
		var l := _add_label(_vertical(e), INK, entry_font_px)
		l.name = "条目%02d" % (i + 1)
		l.position = Vector3(col0_x - i * col_step, top + 0.05, 0)

	if preview_mark >= 0 and preview_mark < entries.size():
		var ring := TorusMesh.new()
		ring.inner_radius = 0.24
		ring.outer_radius = 0.29
		var rg := _add_mesh("朱笔圈", ring, _mat(VERMILLION, 0.8, VERMILLION),
				Vector3(col0_x - preview_mark * col_step, top + 0.045, 0))
		rg.scale = Vector3(1.0, 1.0, 2.7)  # 竖列拉长成椭圆


func _vertical(s: String) -> String:
	var out := ""
	for i in s.length():
		if i > 0:
			out += "\n"
		out += s[i]
	return out


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
	l.line_spacing = -6.0
	l.modulate = color
	l.rotation_degrees.x = -90.0  # 平躺面朝上，字顶朝 −z（面向 +z 镜头可读）
	add_child(l)
	return l


func _mat(albedo: Color, rough: float, emit := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = 0.45
	return m
