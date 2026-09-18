class_name Mj3dTile
extends Node3D

## 3D 麻将牌（2026-09-18 建模重做）：程序化**圆角方盒**牌体（ArrayMesh）。
## 比例＝真牌卡尺实测 19.37×26×16.11mm → 0.74:1:0.62；圆角≈4% 牌高、4 段
## （依据 mahjong.wtf 实测：bevel 1mm/26mm；算法移植自 wwwtyro 圆角盒）。
## 象牙白 roughness≈0.3 带光泽；牌面贴图经图集**平贴圆角面的平坦区**
## （圆角带恒象牙白——贴图不弯过棱边，消贴纸感）。
## 朝向约定：默认站立、正面朝 +Z（玩家近端镜头方向）；
## stand(true)＝背对镜头（敌方手牌）；lean_deg＝立牌后倾（牌面迎镜头）；
## lie_flat()＝躺平正面向上（弃牌河/副露/码墙背纹朝上）；lie_face_down()＝扣牌。

const TILE_DIR := "res://assets/tiles/"
const SUIT_PREFIX := {"万": "Man", "筒": "Pin", "条": "Sou"}

const SIZE := Vector3(0.74, 1.0, 0.62)   # 宽×高×厚（真牌等比）
const RADIUS := 0.04                     # 圆角半径（≈4% 牌高）
const SEGMENTS := 4                      # 圆角段数
const IVORY := Color(0.965, 0.945, 0.90)
const ROUGHNESS := 0.3
const FACE_COVER := 0.88                 # 牌面贴图在图集内的覆盖（内缩留象牙边）
const IVORY_UV := Vector2(0.004, 0.004)  # 圆角带/侧面的图集采样点（恒象牙白）

# 六面 [u, v, n]（u×v=n；CULL_DISABLED 下绕序不敏感，法线解析计算）。
const _FACES := [
	[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)],
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
]

static var _tex_cache := {}      # 文件名 -> Texture2D（缺文件记 null，不反复探测）
static var _atlas_cache := {}    # Texture2D -> 图集 ImageTexture
static var _mat_cache := {}      # 材质键 -> StandardMaterial3D
static var _body_mesh: ArrayMesh


static func _texture(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var path := TILE_DIR + name + ".png"
		_tex_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[name]


# 圆角盒：每面按「角区 SEGMENTS×SEGMENTS／边区长条／中心 1×1」九宫铺网格，
# 顶点向内缩盒（半边长−半径）clamp 后沿半径推出——面心平、棱圆柱、角球面，
# 法线＝推出方向（解析精确）。+Z 面中心区映射图集 [0,1]²（贴图平贴平坦区）。
static func _get_body_mesh() -> ArrayMesh:
	if _body_mesh != null:
		return _body_mesh
	var he := SIZE * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	for f in _FACES:
		var u: Vector3 = f[0]
		var v: Vector3 = f[1]
		var n: Vector3 = f[2]
		var hu := absf(u.dot(he))
		var hv := absf(v.dot(he))
		var hn := absf(n.dot(he))
		var bu := [-hu, -(hu - RADIUS), hu - RADIUS, hu]
		var bv := [-hv, -(hv - RADIUS), hv - RADIUS, hv]
		for bi in range(3):
			for bj in range(3):
				var res_u := 1 if bi == 1 else SEGMENTS
				var res_v := 1 if bj == 1 else SEGMENTS
				var gv := PackedVector3Array()
				var gn := PackedVector3Array()
				var gt := PackedVector2Array()
				for iy in range(res_v + 1):
					for ix in range(res_u + 1):
						var uu := lerpf(bu[bi], bu[bi + 1], float(ix) / res_u)
						var vv := lerpf(bv[bj], bv[bj + 1], float(iy) / res_v)
						var p := n * hn + u * uu + v * vv
						var c := Vector3(
							clampf(p.x, -(he.x - RADIUS), he.x - RADIUS),
							clampf(p.y, -(he.y - RADIUS), he.y - RADIUS),
							clampf(p.z, -(he.z - RADIUS), he.z - RADIUS))
						var dn := (p - c).normalized()
						gv.append(c + dn * RADIUS)
						gn.append(dn)
						var uvv := IVORY_UV
						if n.z > 0.5 and bi == 1 and bj == 1:
							uvv = Vector2(
								(uu + (hu - RADIUS)) / (2.0 * (hu - RADIUS)),
								1.0 - (vv + (hv - RADIUS)) / (2.0 * (hv - RADIUS)))
						gt.append(uvv)
				var w := res_u + 1
				for iy in range(res_v):
					for ix in range(res_u):
						var a := iy * w + ix
						var b := iy * w + ix + 1
						var cc := (iy + 1) * w + ix + 1
						var dd := (iy + 1) * w + ix
						for idx in [a, b, cc, a, cc, dd]:
							verts.append(gv[idx])
							norms.append(gn[idx])
							uvs.append(gt[idx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	_body_mesh = ArrayMesh.new()
	_body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _body_mesh


# 图集：象牙底＋牌面贴图等比缩放居中 blend（透明区留象牙，无黑边）。
static func _atlas_for(tex: Texture2D) -> ImageTexture:
	if _atlas_cache.has(tex):
		return _atlas_cache[tex]
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(IVORY)
	var art := tex.get_image()
	if art.get_format() != Image.FORMAT_RGBA8:
		art.convert(Image.FORMAT_RGBA8)
	var box := int(s * FACE_COVER)
	var k := minf(float(box) / art.get_width(), float(box) / art.get_height())
	var dw := maxi(1, int(art.get_width() * k))
	var dh := maxi(1, int(art.get_height() * k))
	art.resize(dw, dh, Image.INTERPOLATE_LANCZOS)
	img.blend_rect(art, Rect2i(0, 0, dw, dh), Vector2i((s - dw) / 2, (s - dh) / 2))
	var t := ImageTexture.create_from_image(img)
	_atlas_cache[tex] = t
	return t


static func _material_for(tex: Texture2D) -> StandardMaterial3D:
	var key := "ivory"
	if tex != null:
		key = tex.resource_path if tex.resource_path != "" else "ptr%d" % tex.get_instance_id()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = IVORY
	m.roughness = ROUGHNESS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex != null:
		m.albedo_texture = _atlas_for(tex)
	_mat_cache[key] = m
	return m


func _ready() -> void:
	$Body.mesh = _get_body_mesh()
	if $Body.material_override == null:  # 挂树前 set_back/set_tile 已给材质则不覆盖
		$Body.material_override = _material_for(null)


func set_tile(suit: String, value: int) -> void:
	var prefix: String = SUIT_PREFIX.get(suit, "")
	if prefix != "":
		set_face_texture(_texture(prefix + str(value)))


func set_back() -> void:
	set_face_texture(_texture("Back"))


func set_face_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	$Body.material_override = _material_for(tex)


# —— 摆放姿态（改的是自身 rotation，位置由布局方给）——

## 站立（face_away＝背对镜头；lean_deg＝后倾——顶边远离镜头、牌面上仰迎镜头）。
func stand(face_away := false, lean_deg := 0.0) -> void:
	rotation = Vector3(-deg_to_rad(lean_deg), PI if face_away else 0.0, 0.0)


func lie_flat() -> void:
	rotation = Vector3(-PI / 2.0, 0, 0)


func lie_face_down() -> void:
	rotation = Vector3(PI / 2.0, 0, 0)


## 躺平且牌头朝向对面（敌方弃牌河——从对手视角正读）。
func lie_flat_facing_foe() -> void:
	rotation = Vector3(-PI / 2.0, PI, 0)
