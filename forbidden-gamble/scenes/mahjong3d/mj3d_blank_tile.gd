@tool
class_name Mj3dTileBlank
extends Node3D

## 空白双层麻将牌（2026-09-18 用户令「先做一个第一 1 的」——调研第一组取值）。
## @tool（2026-09-20 补）：编辑器只执行 @tool——不挂则牌体在编辑器画布不渲染
## （HandRow 摆了 20 张牌编辑器里全看不见的事故实锤）；本脚本无游戏逻辑，挂 tool 安全。
## 中国牌实测比例：长 26 : 宽 19 : 厚 12（民国竹骨牌实测原值）；
## 厚度分层＝骨面 55% / 竹背 45%（骨厚 6.5/12，"6 分骨"档）。
## 实现单网格单材质：侧/端面 UV.v＝厚度归一坐标，1px 宽渐变贴图在 45% 处硬切两色
## ——接缝为像素级直线（比双盒堆叠的圆角接口干净，无 z-fighting）。
## 空白牌体：无牌面贴图；圆角半径沿用 4% 牌高（mahjong.wtf 实测 1mm/26mm）。
## 2026-09-24 丝路九天 3MF 实测复核：角部圆角 3.4–4.6% 牌长带内，参数不变。
## 几何算法同 mj3d_tile v2（法线零向量＋绕序双坑已修，勿回退）。

const SIZE := Vector3(19.0 / 26.0, 1.0, 12.0 / 26.0)  # 宽(X)×长(Y)×厚(Z)，长=1 归一
const RADIUS := 0.04          # 圆角（≈4% 牌高＝1mm/26mm）
const SEGMENTS := 4
const BACK_SHARE := 0.30      # 背层占厚度比例（2026-09-20 用户令「有点厚」→45% 调 30%＝「9 分骨」档，宽黄带砍三分之一；骨面 70%）
const BONE_COLOR := Color(0.965, 0.945, 0.90)              # 骨面（象牙白）
const BACK_COLOR := Color(231.0 / 255.0, 157.0 / 255.0, 69.0 / 255.0)  # 背层黄 #E79D45（2026-09-20 用户指定，原 2D 绿背退役）
const ROUGHNESS := 0.85  # 哑光骨面（2026-09-20 用户令「中间偏淡」＝正对镜头的镜面高光洗白——0.3 半光泽放大了它；真骨牌本就是哑光）
const SIDE_DIM := 0.68   # 侧面压暗系数（2026-09-20 用户令「牌间白缝」——侧骨面受光发亮，行内牌缝读成白线；×0.68＝接触阴影化）

# 牌面贴图（2026-09-20 用户令「加上实际的图片 就是条筒万」）：
# face_id 填「数字＋万/筒/条」（如 3万/7筒/2条）→ 子面片贴 assets/mj3d_faces 对应图；
# 空串＝素面。面片＝QuadMesh 微浮 +Z 面（0.003 防共面），不动物体网格。
const FACE_DIR := "res://assets/mj3d_faces/"
const SUIT_PREFIX := {"万": "m", "筒": "p", "条": "s"}

@export var face_id := "":
	set(v):
		face_id = v
		_apply_face()

# 六面 [u, v, n]（绕序须朝外——gl_compatibility 按面朝向翻法线，见 mj3d_tile v2 注）
const _FACES := [
	[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)],
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
]

static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D


func _ready() -> void:
	$Body.mesh = _get_mesh()
	if $Body.material_override == null:
		$Body.material_override = _get_material()
	_apply_face()


# 牌面子面片：tscn 载入期 setter 先于入树——_ready 统一应用；改 face_id 即时换面。
func _apply_face() -> void:
	if not is_inside_tree():
		return
	var quad: MeshInstance3D = get_node_or_null("Face")
	if face_id.length() < 2:
		if quad != null:
			quad.visible = false
		return
	var value := face_id[0].to_int()
	var key := face_id[1]
	var prefix: String = SUIT_PREFIX.get(key, key if key in ["m", "p", "s"] else "")
	if value < 1 or prefix.is_empty():
		push_warning("face_id 无法解析: " + face_id)
		return
	var tex := load(FACE_DIR + str(value) + prefix + ".png") as Texture2D
	if tex == null:
		push_warning("牌面贴图缺失: " + face_id)
		return
	if quad == null:
		quad = MeshInstance3D.new()
		quad.name = "Face"
		add_child(quad)
	if quad.mesh == null:
		var qm := QuadMesh.new()
		qm.size = Vector2(SIZE.x - 0.06, SIZE.y - 0.06)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = ROUGHNESS
		qm.material = mat
		quad.mesh = qm
		quad.position = Vector3(0, 0, SIZE.z * 0.5 + 0.003)
	(quad.mesh as QuadMesh).material.albedo_texture = tex
	quad.visible = true


# 圆角盒：九宫铺网格（角区 SEG×SEG／边条／中心 1×1），clamp 内缩后沿半径推出。
# UV：厚度坐标 p.z 归一化为 v（0=背面 −Z／1=牌面 +Z）；±Z 面取贴图上下半区常数点。
static func _get_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
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
						# 中心平坦区 p==c → 法线取面法线（零向量陷阱已修）
						var dn := p - c
						var push := dn.normalized() if dn.length_squared() > 1e-9 else n
						var world := c + push * RADIUS
						gv.append(world)
						gn.append(push)
						var uvv: Vector2
						if n.z > 0.5:
							uvv = Vector2(0.98, 0.98)   # 牌面＝骨色区（亮列 1）
						elif n.z < -0.5:
							uvv = Vector2(0.98, 0.02)   # 背面＝背层区（亮列 1）
						else:
							# 侧/端面：v＝厚度归一（0=背 1=面）。u 选列（2026-09-20 牌间白缝）：
							# ±X 接触面→暗列 0（×SIDE_DIM 接触阴影）；±Y 顶底条带→亮列 1（受光棱线保留）
							var col := 0.02 if absf(n.x) > 0.5 else 0.98
							uvv = Vector2(col, clampf((world.z + he.z) / (2.0 * he.z), 0.0, 1.0))
						gt.append(uvv)
				var w := res_u + 1
				for ty in range(res_v):
					for tx in range(res_u):
						var a := ty * w + tx
						var b := ty * w + tx + 1
						var cc := (ty + 1) * w + tx + 1
						var dd := (ty + 1) * w + tx
						for idx in [a, cc, b, a, dd, cc]:  # 绕序朝外（v2 修正保留）
							verts.append(gv[idx])
							norms.append(gn[idx])
							uvs.append(gt[idx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _mesh


# 双层渐变贴图：1×64，v<30%＝背层色，v>30%＝骨面色。
# 接缝软切（2026-09-20 用户令「两侧割裂」）：切点两侧各 ~7% 过渡带 lerp——
# 硬直线双跳色（象牙白×高饱和黄零过渡）读成「两块粘起来的」，软缝＋窄黄带同治。
# uv.v=0 采样行 0（背面）→ 深背区；±Z 面取常数点 (0.5,0.02)/(0.5,0.98) 落纯色区。
# 2026-09-20 用户令「感觉还是要光照」：材质已转标准受光（法线 v2 修好），场景需配灯。
static func _get_material() -> StandardMaterial3D:
	if _mat != null:
		return _mat
	const H := 64
	var img := Image.create(2, H, false, Image.FORMAT_RGBA8)
	var cut := int(round(BACK_SHARE * (H - 1)))
	for x in 2:
		for y in H:
			var t := clampf((float(y) - cut + 2.0) / 4.0, 0.0, 1.0)
			var c := BACK_COLOR.lerp(BONE_COLOR, t)
			if x == 0:
				c *= SIDE_DIM  # 列 0＝侧/端面（暗），列 1＝正背面（亮）
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = ROUGHNESS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat = m
	return m


# —— 摆放姿态（同 mj3d_tile 语义）——

func stand(face_away := false, lean_deg := 0.0) -> void:
	rotation = Vector3(-deg_to_rad(lean_deg), PI if face_away else 0.0, 0.0)

func lie_flat() -> void:
	rotation = Vector3(-PI / 2.0, 0, 0)

func lie_face_down() -> void:
	rotation = Vector3(PI / 2.0, 0, 0)
