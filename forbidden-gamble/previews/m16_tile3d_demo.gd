extends Node3D

## 3D 牌体·姿势样机（2026-09-18 用户令：2.5D 贴图质感不足，转 3D 固定视角；
## 「现在有 2.5D 图片 你能不能做个 3D 模型出来」——mahjong_graphic 平面稿上
## 程序化圆角盒白体）。六姿势一行一式：手牌立（微后倾）／站立背／我方河躺正／
## 躺背／副露组（直躺＋横躺标记）／敌方河 180°。不接规则引擎，纯视觉评估。

const TILE := preload("res://scenes/mahjong3d/mj3d_tile.tscn")
const FONT := "res://assets/fonts/MaShanZheng-Regular.ttf"
const SPACING := 0.82          # 牌间距（牌宽 0.74＋缝）
const LEAN_HAND := 15.0        # 手牌后倾：立牌面迎镜头（56° 俯角下入射 ~41°）
# 行距拉开＋机位抬高（v1 教训：6 行塞 2.65 单位＋4.0 低机位 → 立牌行遮挡身后河牌行，
# 视觉整片发黑被判「没贴图」；真实布局行距 2+ 单位、相机高 9.96）
const CAM_POS := Vector3(0, 5.2, 3.2)
const CAM_TARGET := Vector3(0, 0.0, -0.2)

@onready var camera: Camera3D = $Camera3D

const ROWS := [
	{"label": "手牌·站立正面（后倾 15°）", "z": 1.55, "pose": "hand",
		"tiles": [["万", 1], ["万", 5], ["筒", 3], ["筒", 9], ["条", 1], ["条", 7]]},
	{"label": "敌方手牌·站立背面", "z": 0.55, "pose": "stand_back",
		"tiles": [["万", 1], ["万", 1], ["万", 1], ["万", 1], ["万", 1], ["万", 1]]},
	{"label": "我方河·躺正面", "z": -0.35, "pose": "lie",
		"tiles": [["万", 2], ["万", 8], ["筒", 5], ["条", 3], ["条", 9], ["万", 1]]},
	{"label": "我方河·躺背面", "z": -1.25, "pose": "lie_back", "x0": -1.6,
		"tiles": [["万", 1], ["万", 1], ["万", 1]]},
	{"label": "副露·直躺＋横躺标记", "z": -1.25, "pose": "meld", "xs": [1.15, 1.97, 2.98],
		"tiles": [["筒", 7], ["筒", 7], ["筒", 7]]},
	{"label": "敌方河·躺正面 180°（对家视角正读）", "z": -2.15, "pose": "lie_foe",
		"tiles": [["万", 3], ["筒", 6], ["条", 5], ["万", 9], ["条", 2]]},
]


func _ready() -> void:
	camera.position = CAM_POS
	camera.look_at(CAM_TARGET)
	# 正前上方平行光（rotation 显式设向——tscn 手写 basis 列序两翻车，弃）：
	# X 轴 -50° ＝ 光从镜头侧上方打，躺面(+Y)与立牌面(+Z)同时受光
	$Sun.rotation_degrees = Vector3(-50, 0, 0)
	for row in ROWS:
		_build_row(row)
	await get_tree().process_frame
	_place_labels()


func _build_row(row: Dictionary) -> void:
	var x0: float = row.get("x0", 0.0)
	var xs: Array = row.get("xs", [])
	var tiles: Array = row["tiles"]
	var n := tiles.size()
	const FELT_TOP := 0.05            # 呢面顶面 Y（Felt 盒半高）
	for i in n:
		var tile := TILE.instantiate() as Mj3dTile
		add_child(tile)
		# xs 显式给位（横躺标记牌旋转后占位 1.0 ＞ 间距 0.82，须留大缝）；否则按 x0 居中排
		var cx: float = float(xs[i]) if xs.size() == n else x0 + (i - float(n - 1) / 2.0) * SPACING
		# 牌体原点＝几何中心：立牌半高 0.5，躺牌半厚 0.31
		var standing: bool = row["pose"] == "hand" or row["pose"] == "stand_back"
		tile.position = Vector3(cx, FELT_TOP + (0.5 if standing else 0.31), row["z"])
		match row["pose"]:
			"hand":
				tile.stand(false, LEAN_HAND)
				tile.set_tile(tiles[i][0], tiles[i][1])
			"stand_back":
				tile.stand(true)
				tile.set_back()
			"lie":
				tile.lie_flat()
				tile.set_tile(tiles[i][0], tiles[i][1])
			"lie_back":
				tile.lie_face_down()
				tile.set_back()
			"meld":
				# 直躺两张＋第三张横转 90°（吃碰杠标记牌式）
				tile.lie_flat()
				tile.rotation.y = PI / 2.0 if i == n - 1 else 0.0
				tile.set_tile(tiles[i][0], tiles[i][1])
			"lie_foe":
				tile.lie_flat_facing_foe()
				tile.set_tile(tiles[i][0], tiles[i][1])


# 标签：3D 锚点投影到屏幕（渲染次帧后挂 CanvasLayer 标签，避首帧投影零值）
func _place_labels() -> void:
	var font := load(FONT) as Font
	var layer := CanvasLayer.new()
	add_child(layer)
	for row in ROWS:
		var anchor := Vector3(-3.4, 0.0, float(row["z"]))
		var label := Label.new()
		label.text = row["label"]
		if font != null:
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.78))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		layer.add_child(label)
		label.position = camera.unproject_position(anchor) + Vector2(4, -14)
