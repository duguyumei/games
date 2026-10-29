@tool
class_name Mj3dQiSea
extends Node3D

## 气海台·桌面嵌入式实物（2026-09-21 用户令「把中央的气海嵌入到牌桌模型中…略微凸起，
## 气海和数字都应该是模型的一部分…有 3D 的远近效果」——HUD 屏幕层气海方块退役）。
## 台＝呢面微凸深色嵌块（板族气海档 0.6 的 3D 不透明版，底部微沉防与呢面共面闪烁）；
## 「气海」金字＝TextMesh 微挤出受光（马善政体，OFL）；「余 N 张」动态数字同款小号。
## 全部平躺头朝 −Z（我方机位读正，敌方视角倒——与牌河牌同约定）。
## @tool＝编辑器所见即运行；参数全导出、拖根节点＝整体挪（手调约定同 HandRow/River）。

const GOLD := Color(0.92, 0.86, 0.7)            # 金＝资源库存（三调色，同 HUD 气海金字）
# 台面色（2026-09-21 用户报「背景一团黑」修正，同日再提亮）：HUD 方块的 (0.09,0.085,0.08) 是
# 60% 半透明叠画面色——不透明直用＝死黑；首版等观感档 (0.19,0.175,0.15) 用户仍觉黑，
# 再提到暖灰亮档（比呢面深一档、不发黑）；侧壁暗一档立凸起轮廓（同 Mj3dTable 桌沿几何分层法）。
const SLAB_TOP := Color(0.28, 0.26, 0.225)
const SLAB_SIDE_DIM := 0.72
const FONT_PATH := "res://assets/fonts/MaShanZheng-Regular.ttf"
const SINK := 0.02                               # 台底沉入呢面量（防底面共面闪烁）

@export var slab_w := 2.4:   # 台宽（X，牌长数；2026-09-21 用户令「边调短点」3.0→2.4）
	set(v):
		slab_w = maxf(0.5, v)
		_rebuild()
@export var slab_d := 2.4:   # 台深（Z，牌长数）——中央留空 z∈[−1.9,1.9] 内
	set(v):
		slab_d = maxf(0.5, v)
		_rebuild()
@export var slab_h := 0.12:  # 凸出呢面高（「略微凸起」）
	set(v):
		slab_h = maxf(0.02, v)
		_rebuild()
@export var title_text := "气海":
	set(v):
		title_text = v
		_rebuild()
@export var tiles_left := 30:  # 余牌数（运行时接线后动态更新）
	set(v):
		tiles_left = maxi(0, v)
		_rebuild()
@export var font_px_title := 100:  # 「气海」字号（px；实际字高＝×pixel_size）
	set(v):
		font_px_title = maxi(10, v)
		_rebuild()
@export var font_px_num := 55:     # 数字行字号
	set(v):
		font_px_num = maxi(10, v)
		_rebuild()
@export var pixel_size := 0.008:   # px→世界单位换算
	set(v):
		pixel_size = maxf(0.001, v)
		_rebuild()
@export var extrude := 0.02:       # 字挤出厚度（受光微浮雕）
	set(v):
		extrude = maxf(0.0, v)
		_rebuild()
@export var curve_step := 0.25:   # 字轮廓曲线细分步长（px）——毛笔体笔画全曲线，默认步长折线化
	                               # ＝笔画边缘锯齿（2026-09-21 用户报「中间有锯齿感」）；越小越平滑
	set(v):
		curve_step = maxf(0.05, v)
		_rebuild()

var _font: Font


func _ready() -> void:
	_build()


# tscn 属性载入时 setter 先于入树触发——入树后统一由 _build 建，避免双建。
func _rebuild() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children():
		if c.name == "QiSeaRoot":
			remove_child(c)
			c.free()
	var root := Node3D.new()
	root.name = "QiSeaRoot"
	add_child(root)
	if _font == null:
		_font = load(FONT_PATH) as Font
	# 台体＝两层盒（几何分层）：亮色薄顶盖＋暗色主体（侧壁），底部微沉入呢面
	var cap_h := minf(0.05, slab_h * 0.5)
	var cap := MeshInstance3D.new()
	cap.name = "SlabCap"
	var capm := BoxMesh.new()
	capm.size = Vector3(slab_w, cap_h, slab_d)
	cap.mesh = capm
	cap.material_override = _mat(SLAB_TOP)
	cap.position = Vector3(0.0, slab_h - cap_h * 0.5, 0.0)
	root.add_child(cap)
	var body := MeshInstance3D.new()
	body.name = "SlabBody"
	var bm := BoxMesh.new()
	bm.size = Vector3(slab_w, slab_h - cap_h + SINK, slab_d)
	body.mesh = bm
	body.material_override = _mat(SLAB_TOP.darkened(SLAB_SIDE_DIM))
	body.position = Vector3(0.0, (slab_h - cap_h - SINK) * 0.5, 0.0)
	root.add_child(body)
	# 「气海」行：台面远半（屏幕上方，双行布局同退役 HUD 方块）
	root.add_child(_text_mesh("Title", title_text, font_px_title, Vector3(0.0, slab_h + 0.002, -0.35)))
	# 「余 N 张」行：台面近半
	root.add_child(_text_mesh("Count", "余 %d 张" % tiles_left, font_px_num, Vector3(0.0, slab_h + 0.002, 0.5)))


func _text_mesh(n: String, txt: String, px: int, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var tm := TextMesh.new()
	tm.text = txt
	if _font != null:
		tm.font = _font
	tm.font_size = px
	tm.pixel_size = pixel_size
	tm.depth = extrude
	tm.curve_step = curve_step
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # 属性名是 horizontal_alignment（alignment 不存在，运行时核实）
	mi.mesh = tm
	mi.material_override = _mat(GOLD)
	mi.position = pos
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # 平躺仰面头朝 −Z（同牌河牌）
	return mi


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85  # 哑光（同骨面/桌沿档）
	return m
