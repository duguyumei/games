@tool
class_name M24Book
extends Node3D

## 武学书：线装古籍、躺平封面朝上（2026-09-22 书案 v9——订线走整书：v8 三面孤图被评
## 「书面书脊没连接/顶部没连接/背面没有」，对参考图走线分析后改为**一根连续四眼锁线
## 绕全书五面**：封面主干贯穿四站＋每站横联贴脊棱＋结头；书脊每站竖线翻绕全高接封底；
## 封底同构；首末站主干从天头/地脚翻绕接回——五面覆膜共享坐标（TRUNK_IN/四站公式），
## 棱边逐点相接）。
## v7 保留：厚 0.055/书脊包边/默认深靛蓝；v6 保留：高:宽 1.3、题签 30%/75%、印底锚定。
## v4 古籍本体保留：软纸面齐平不出边（无硬壳）、无西式书脊带、订口线脚×4 贯穿书厚、
## 书厚 0.09、页册×3 参差、陈年纸黄。
## 版式（v3 对四张参考图量化）：纯色布面＋右侧竖长白贴签＋竖排墨字（字组上置）＋签底朱印。
## 「后面书面可加封面图片」＝back_cover_texture 预留（null＝纯色）。
## 亮＝可用、暗＝不可用（整书压暗 0.45）；点击发动、发动发光后续轮。
## 原点＝底面中心（y=0 贴下书面）；全参数检查器导出＝手调；
## 子件脚本建（owner 留空不入档）、位置拖根节点。


const FONT := preload("res://assets/fonts/LXGWWenKai-Medium.ttf")  # 09-22 马善政被否→霞鹜文楷（OFL）

const COVER_T := 0.008   # 封面纸厚（古籍软面，非硬壳）
const WRAP := 0.004      # 封面纸对页块微包（共两侧，非出边）
const SPINE_WRAP_T := 0.014  # 书脊包边厚（色脊：包住订口缘）
const SLIP_W_K := 0.30   # 题签条宽/书宽（四图实测 25–35%）
const SLIP_H_K := 0.75   # 题签条高/书高（实测 50–80%，取偏满）
const SLIP_PAD := 0.035  # 签内上下边距
const SEAL_GAP := 0.04   # 末字→朱印间距
const SEAL_K := 0.50     # 朱印边长＝签宽 × 此系数
const CHAR_MAX := 0.125  # 字高上限（世界单位）
const CHAR_LEADING := 1.15  # 行距＝字高 × 此系数（v4 字距=字高太挤被评「糊成一片」）
const N_SLABS := 3       # 页册分层数（参差＝手工纸页感）
const SLAB_JITTER := 0.006  # 页册错位幅度

const DEEP_BLUE := Color(0.11, 0.17, 0.30)  # 深靛蓝（用户令默认色，2026-09-22）
const PAGE_AGE := Color(0.87, 0.81, 0.66)  # 陈年纸黄（现代白页＝精装信号，弃）
const SLIP := Color(0.93, 0.90, 0.82)      # 题签纸（新纸贴上）
const INK := Color(0.13, 0.15, 0.17)       # 书名墨
const THREAD := Color(0.88, 0.84, 0.72)    # 订绳（本色麻线，提亮一档上镜）
const COVER_DEEP := Color(0.07, 0.06, 0.05)
const SEAL_RED := Color(0.66, 0.20, 0.17)  # 朱砂
const SEAL_INK := Color(0.95, 0.92, 0.86)  # 印文（白文）
const DIM_K := 0.45  # 暗＝整书压暗系数

@export var title := "武学":
	set(v):
		title = v
		_rebuild()
@export var cover_color := DEEP_BLUE:  # 封面色（用户令先默认深蓝；轨色届时另议）
	set(v):
		cover_color = v
		_rebuild()
@export var spine_color := DEEP_BLUE:  # 书脊包边色（同封面默认深蓝）
	set(v):
		spine_color = v
		_rebuild()
@export var lit := true:
	set(v):
		lit = v
		_rebuild()
@export var seal_text := "":  # 朱印章文（空＝只有红章无字）
	set(v):
		seal_text = v
		_rebuild()
@export_range(0.0, 0.9, 0.01) var cover_shade := 0.0:  # 封面往深压的程度（0＝纯 cover_color）
	set(v):
		cover_shade = v
		_rebuild()
@export_range(0.0, 0.3, 0.005) var slip_margin_x := 0.05:  # 题签距封面右缘（实测右留边小）
	set(v):
		slip_margin_x = v
		_rebuild()
@export var back_cover_texture: Texture2D:  # 封底贴图（「后面书面加封面图片」预留；null＝纯色）
	set(v):
		back_cover_texture = v
		_rebuild()
@export_range(0.35, 1.2, 0.01) var book_w := 0.55:  # 09-22 v6 高:宽 1.3（四图像素/视觉实测共识 1.25–1.40）
	set(v):
		book_w = v
		_rebuild()
@export_range(0.4, 1.6, 0.01) var book_l := 0.72:
	set(v):
		book_l = v
		_rebuild()
@export_range(0.03, 0.4, 0.005) var book_t := 0.055:  # 09-22 v7 再压薄（用户「书籍也比较厚」）
	set(v):
		book_t = v
		_rebuild()
@export_range(64, 512, 1) var title_px := 256:  # 字形栅格（v4 64px 被 2× 窗口放大＝糊，v5 提档）
	set(v):
		title_px = v
		_rebuild()
@export var show_stitch := true:
	set(v):
		show_stitch = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var cov := _tone(cover_color.lerp(COVER_DEEP, cover_shade))
	var half_w := book_w / 2.0

	# 封底纸／封面纸（软面：薄、与页齐平仅微包——古籍线装无硬壳出边）
	var back := _add_box("封底纸", Vector3(book_w + WRAP, COVER_T, book_l + WRAP), cov, 0.95,
			Vector3(0, COVER_T / 2.0, 0))
	if back_cover_texture != null:
		(back.material_override as StandardMaterial3D).albedo_texture = back_cover_texture
	_add_box("封面纸", Vector3(book_w + WRAP, COVER_T, book_l + WRAP), cov, 0.95,
			Vector3(0, book_t - COVER_T / 2.0, 0))
	# 书脊包边（色脊：包住 −x 订口缘、全高；顶唇压低到订线覆膜之下——v9c 前版顶唇
	# 高于覆膜 0.5mm，遮断横联头＝封面-书脊断点实因）
	_add_box("书脊包边", Vector3(SPINE_WRAP_T, book_t + 0.001, book_l + WRAP),
			_tone(spine_color), 0.85, Vector3(-half_w + 0.005, book_t / 2.0, 0))
	# 页册×3（参差错位＝手工纸页毛边；书口（+x 右）与天地头露出纸黄）
	var pt := (book_t - COVER_T * 2.0) / N_SLABS
	for i in N_SLABS:
		var j := (i - float(N_SLABS - 1) / 2.0) * SLAB_JITTER
		_add_box("页册%d" % (i + 1), Vector3(book_w - 0.006, pt, book_l - 0.006),
				_tone(PAGE_AGE), 1.0,
				Vector3(j * 0.6, COVER_T + pt * (i + 0.5), j))
	# 订线（v9：对参考图走线分析——一根连续四眼锁线绕整本书：
	# 封面主干贯穿四站＋每站横联到脊缘＋结头；脊侧每站竖线翻绕接封底；
	# 封底同构；首末站从天头/地脚翻绕接回。五面覆膜共享坐标，棱边逐点相接）
	if show_stitch:
		var fw := book_w + WRAP
		var fl := book_l + WRAP
		var tex_cover := _tex_thread_cover()
		_add_mesh("封面订线", _quad_up(fw, fl),
				_thread_mat(tex_cover), Vector3(0, book_t + 0.0015, 0))
		_add_mesh("封底订线", _quad_down(fw, fl),
				_thread_mat(tex_cover), Vector3(0, -0.0015, 0))
		# 脊膜顶/底端收到覆膜平面同高（角点闭死：x 差 0.5mm、y 零差）
		_add_mesh("书脊订线", _quad_neg_x(fl, book_t + 0.002),
				_thread_mat(_tex_thread_spine()), Vector3(-fw / 2.0 - 0.0005, -0.0005, 0))
		_add_mesh("天头订线", _quad_neg_z(fw, book_t + 0.003),
				_thread_mat(_tex_thread_edge()), Vector3(0, -0.0015, -fl / 2.0 - 0.0005))
		_add_mesh("地脚订线", _quad_pos_z(fw, book_t + 0.003),
				_thread_mat(_tex_thread_edge()), Vector3(0, -0.0015, fl / 2.0 + 0.0005))
	# 题签＋竖排书名＋朱印（比例取实测：签 30% 宽/75% 高；字组上置、印底锚定）
	if title.length() > 0:
		var n := title.length()
		var slip_w := book_w * SLIP_W_K
		var seal_w := slip_w * SEAL_K
		var char_h := minf(CHAR_MAX,
				(book_l * SLIP_H_K - 2.0 * SLIP_PAD - SEAL_GAP - seal_w) / (1.0 + (n - 1) * CHAR_LEADING))
		var pitch := char_h * CHAR_LEADING
		var need := 2.0 * SLIP_PAD + char_h + (n - 1) * pitch + SEAL_GAP + seal_w
		var slip_d := maxf(book_l * SLIP_H_K, need)
		var slip_x := half_w - slip_w / 2.0 - slip_margin_x
		var slip_top := -slip_d / 2.0  # 远端（首字侧）
		_add_box("题签", Vector3(slip_w, 0.005, slip_d), _tone(SLIP), 0.9,
				Vector3(slip_x, book_t + 0.0025, 0.0))
		for i in n:
			var ch := _add_label(title[i], INK if lit else INK * 0.75)
			ch.name = "书名%d" % (i + 1)
			ch.font_size = title_px
			ch.pixel_size = char_h / float(title_px)
			ch.position = Vector3(slip_x, book_t + 0.009,
					slip_top + SLIP_PAD + char_h / 2.0 + i * pitch)
			ch.rotation_degrees.x = -90.0
		var seal_z := slip_d / 2.0 - SLIP_PAD - seal_w / 2.0  # 签底锚定
		_add_box("朱印", Vector3(seal_w, 0.007, seal_w), _tone(SEAL_RED), 0.8,
				Vector3(slip_x, book_t + 0.008, seal_z))
		if seal_text.length() > 0:
			var st := _add_label(seal_text[0], SEAL_INK if lit else SEAL_INK * 0.75)
			st.name = "印文"
			st.font_size = title_px
			st.pixel_size = (seal_w * 0.72) / float(title_px)
			st.position = Vector3(slip_x, book_t + 0.014, seal_z)
			st.rotation_degrees.x = -90.0


func _tone(c: Color) -> Color:
	return c if lit else c * DIM_K


# ---- 订线贴图（v9 五面走线；共享坐标：trunk_px 与四站 px 由同一公式派生）----

const TRUNK_IN := 0.058  # 主干线距脊缘（世界单位；参考图 ≈5% 书宽＋横联 2–3%）


func _station_px(n_px: int, span: float) -> Array:
	# 站位像素＝按各膜实际世界跨度换算（v9c：膜长统一 fl，站世界 z 逐膜一致＝角点对齐）
	var ys: Array = []
	for i in 4:
		var sz := (i - 1.5) * (book_l / 4.6)
		ys.append(int(round((sz + span / 2.0) / span * n_px)))
	return ys


func _thread_line() -> Color:
	return Color(THREAD.r, THREAD.g, THREAD.b, 1.0)


func _tex_thread_cover() -> ImageTexture:
	# 封面/封底共用：主干**贯穿天地书缘**（首末站不停——到缘接天头/地脚翻绕线，
	# v9b 前版只画到首末站＝两端线头被用户点出「不许有线头」）＋每站横联贴脊棱＋结头。
	var w_px := 256
	var h_px := maxi(64, int(round(256.0 * (book_l + WRAP) / (book_w + WRAP))))
	var img := Image.create(w_px, h_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := _thread_line()
	var trunk := int(round(TRUNK_IN / (book_w + WRAP) * w_px))
	var ys := _station_px(h_px - 1, book_l + WRAP)
	img.fill_rect(Rect2i(trunk - 2, 2, 5, h_px - 4), c)
	for y in ys:
		img.fill_rect(Rect2i(0, y - 2, trunk + 2, 5), c)
		img.fill_rect(Rect2i(trunk - 5, y - 5, 11, 11), c)
	return ImageTexture.create_from_image(img)


func _tex_thread_spine() -> ImageTexture:
	# 脊侧：每站一条竖线翻绕全高（上下端接封面/封底横联的贴棱点）。
	var w_px := 336
	var h_px := 48
	var img := Image.create(w_px, h_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := _thread_line()
	var xs := _station_px(w_px - 1, book_l + WRAP)
	for x in xs:
		img.fill_rect(Rect2i(x - 2, 0, 5, h_px), c)
	return ImageTexture.create_from_image(img)


func _tex_thread_edge() -> ImageTexture:
	# 天头/地脚共用：首末站主干线翻绕（沿厚度贯通，接封面/封底主干两端）。
	var w_px := 256
	var h_px := 32
	var img := Image.create(w_px, h_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := _thread_line()
	var trunk := int(round(TRUNK_IN / (book_w + WRAP) * w_px))
	img.fill_rect(Rect2i(trunk - 2, 0, 5, h_px), c)
	return ImageTexture.create_from_image(img)


func _thread_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.albedo_color = Color.WHITE if lit else Color(0.45, 0.45, 0.45)
	return m


func _quad_up(w: float, l: float) -> ArrayMesh:
	# XZ 面、法线 +y；u=0 锚定 −x（书脊侧）。
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var vs := [Vector3(-w / 2.0, 0, l / 2.0), Vector3(w / 2.0, 0, l / 2.0),
			Vector3(w / 2.0, 0, -l / 2.0), Vector3(-w / 2.0, 0, -l / 2.0)]
	for tri in [[0, 2, 1], [0, 3, 2]]:
		for k in tri:
			st.set_normal(Vector3(0, 1, 0))
			st.set_uv(uvs[k])
			st.add_vertex(vs[k])
	return st.commit()


func _quad_down(w: float, l: float) -> ArrayMesh:
	# XZ 面、法线 −y（封底外视面）；u=0 仍锚 −x 书脊侧。
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var vs := [Vector3(-w / 2.0, 0, -l / 2.0), Vector3(w / 2.0, 0, -l / 2.0),
			Vector3(w / 2.0, 0, l / 2.0), Vector3(-w / 2.0, 0, l / 2.0)]
	for tri in [[0, 2, 1], [0, 3, 2]]:
		for k in tri:
			st.set_normal(Vector3(0, -1, 0))
			st.set_uv(uvs[k])
			st.add_vertex(vs[k])
	return st.commit()


func _quad_neg_x(l: float, h: float) -> ArrayMesh:
	# YZ 面、法线 −x（书脊外视面）；u 沿 z（v=0 底 v=1 顶＝接封底/封面横联贴棱点）。
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var vs := [Vector3(0, 0, -l / 2.0), Vector3(0, 0, l / 2.0),
			Vector3(0, h, l / 2.0), Vector3(0, h, -l / 2.0)]
	for tri in [[0, 2, 1], [0, 3, 2]]:
		for k in tri:
			st.set_normal(Vector3(-1, 0, 0))
			st.set_uv(uvs[k])
			st.add_vertex(vs[k])
	return st.commit()


func _quad_neg_z(w: float, h: float) -> ArrayMesh:
	# XY 面、法线 −z（天头外视面）；u=0 锚 −x 书脊侧、v 沿厚度。
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uvs := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
	var vs := [Vector3(-w / 2.0, 0, 0), Vector3(-w / 2.0, h, 0),
			Vector3(w / 2.0, h, 0), Vector3(w / 2.0, 0, 0)]
	for tri in [[0, 2, 1], [0, 3, 2]]:
		for k in tri:
			st.set_normal(Vector3(0, 0, -1))
			st.set_uv(uvs[k])
			st.add_vertex(vs[k])
	return st.commit()


func _quad_pos_z(w: float, h: float) -> ArrayMesh:
	# XY 面、法线 +z（地脚外视面）；同锚定。
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var vs := [Vector3(-w / 2.0, 0, 0), Vector3(w / 2.0, 0, 0),
			Vector3(w / 2.0, h, 0), Vector3(-w / 2.0, h, 0)]
	for tri in [[0, 2, 1], [0, 3, 2]]:
		for k in tri:
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(uvs[k])
			st.add_vertex(vs[k])
	return st.commit()


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


func _add_label(text: String, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = title_px
	l.pixel_size = 0.002
	l.modulate = color
	add_child(l)
	return l


func _mat(albedo: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	return m
