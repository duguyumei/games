extends Node3D

## 3D 牌桌·布局预览（2026-09-17 用户令：就做 3D；「先做桌面 3D 没有牌 我看看行不行」）。
## 分区照当前 2D 版布局 1:1 空间化（用户令「3D 的最终效果应该像现在的一样」）：
## 远端敌手牌带｜左列气海墙｜中列敌/我气河（上下）｜右列敌/我副露（上下）｜近端我方手牌。
## 占位＝半透明色块＋Label3D（**无牌**，评估透视与布局用，接线轮撤）；
## **固定视角**（2026-09-18 用户令：取消拖动转视角——我方席位定机位）。
## 不接规则引擎；2D 版（mahjong_battle）冻结不动。


const ZONES := [
	{"name": "敌方手牌带", "rect": Rect2(-4.8, -3.25, 9.6, 0.7), "color": Color(0.75, 0.32, 0.26, 0.18)},
	{"name": "气海墙", "rect": Rect2(-6.6, -2.1, 1.15, 4.2), "color": Color(0.32, 0.42, 0.62, 0.18)},
	{"name": "敌方气河", "rect": Rect2(-4.25, -2.0, 5.85, 1.55), "color": Color(0.62, 0.56, 0.30, 0.16)},
	{"name": "我方气河", "rect": Rect2(-4.25, 0.45, 5.85, 1.55), "color": Color(0.80, 0.68, 0.30, 0.16)},
	{"name": "敌方副露", "rect": Rect2(2.25, -2.0, 4.25, 1.55), "color": Color(0.34, 0.56, 0.42, 0.16)},
	{"name": "我方副露", "rect": Rect2(2.25, 0.45, 4.25, 1.55), "color": Color(0.45, 0.66, 0.48, 0.16)},
	{"name": "我方手牌", "rect": Rect2(-5.15, 2.55, 10.3, 0.7), "color": Color(0.82, 0.72, 0.34, 0.18)},
]

const FELT_TOP := 0.845   # 呢面顶面 Y（Table/Felt：0.81＋半高 0.035）
# 倾角三档（2026-09-18 用户令「你知道我说的高是什么吗——牌立在桌子上我都看不到牌」）：
# 「高」的判据＝**立牌面可读**（视线对立牌面入射角）——俯角压到 **56°**（入射 34°），
# d=11 看桌心。探针实测：远沿 165／近沿 647（不占敌我信息带）、我方立牌顶 y514、
# 敌背顶 y172、屏宽 86%（x 88–1191）。
const CAM_POS := Vector3(0, 9.96, 6.15)
const CAM_TARGET := Vector3(0, 0.845, 0)

@onready var camera: Camera3D = $Camera3D
@onready var zones: Node3D = $Zones
var _top_bar: MJBTopBar
var _enemy_panel: MJBFighterPanel
var _player_panel: MJBFighterPanel


func _ready() -> void:
	_build_zone_markers()
	_build_wall()
	_build_standing_demo()
	_build_center_emblem()
	_build_overlay()
	camera.position = CAM_POS
	camera.look_at(CAM_TARGET)  # 倾斜档：看向桌心（垂直档才须 rotation 直设防偏心）
	# 血量/基础信息＝**2D 版同款组件原位复用**（2026-09-18 用户令「和2d版的一样 你不要改
	# ／位置不动」）：顶栏（拍·行动方居中）→敌条整行在顶→（牌桌）→我条整行在底。
	# 数据暂为占位 MJFighter——引擎接线轮喂真值。
	var foe := MJFighter.new()
	foe.side = "enemy"
	foe.display_name = "石仆"
	foe.hp_fp = 8400
	_enemy_panel.update_panel(foe, {}, false, [])
	var me := MJFighter.new()
	me.side = "player"
	me.display_name = "玩家"
	_player_panel.update_panel(me, {}, true, [])


# 分区占位：**细描边框**（无填充——2026-09-18 用户令「桌面上怎么好像还其他颜色」：
# 彩色填充块把桌面染杂，改单一暖白细框）＋Label3D（billboard 面向镜头）。
func _build_zone_markers() -> void:
	var frame := _frame_texture()
	for z in ZONES:
		if z["name"] == "气海墙" or z["name"] == "敌方手牌带" or z["name"] == "我方手牌":
			continue  # 真牌占位（码墙/立牌行）——细框让位
		var rect: Rect2 = z["rect"]
		var quad := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(rect.size.x, rect.size.y)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = frame
		mat.albedo_color = Color(1, 0.97, 0.88, 0.55)
		mesh.material = mat
		quad.mesh = mesh
		var cx := rect.position.x + rect.size.x * 0.5
		var cz := rect.position.y + rect.size.y * 0.5
		quad.position = Vector3(cx, FELT_TOP + 0.02, cz)
		quad.rotation_degrees.x = -90.0
		zones.add_child(quad)
		var label := Label3D.new()
		label.text = z["name"]
		label.font_size = 30
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1, 0.98, 0.9, 0.55)
		label.outline_size = 12
		label.position = Vector3(cx, FELT_TOP + 0.5, cz)
		zones.add_child(label)


# 描边框贴图：透明芯＋白边（材质 albedo_color 统一染色）。
func _frame_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var edge := 3
	for y in range(64):
		for x in range(64):
			var on := x < edge or x >= 64 - edge or y < edge or y >= 64 - edge
			img.set_pixel(x, y, Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0))
	return ImageTexture.create_from_image(img)


# 气海墙＝真实码牌（2026-09-18 用户令）：扣牌两层＝墩，墩列沿桌纵深排（左列两排×六墩）。
# 背纹朝上（lie_flat＋set_back）——素白背读不出是麻将（用户令「白色的一片」），Back 贴图顶面朝镜头。
const WALL_TILE := preload("res://scenes/mahjong3d/mj3d_tile.tscn")
const WALL_SCALE := 0.7
const TILE_GAP := 0.02   # 牌间自然缝隙（码墙/立牌同用）


func _build_wall() -> void:
	# 牌厚读牌体真值（2026-09-18 建模重做：0.62 真比例——旧 0.38 薄饼退役）。
	var t := Mj3dTile.SIZE.z * WALL_SCALE
	var row_pitch := Mj3dTile.SIZE.y * WALL_SCALE + TILE_GAP
	var cols := [-6.28, -5.72]
	for ci in cols.size():
		for ri in range(6):
			for layer in range(2):
				var tile: Mj3dTile = WALL_TILE.instantiate()
				tile.lie_flat()
				tile.set_back()
				tile.scale = Vector3.ONE * WALL_SCALE
				tile.position = Vector3(cols[ci], FELT_TOP + t * (0.5 + layer), -1.8 + ri * row_pitch)
				zones.add_child(tile)


# 立牌实证排（2026-09-18 用户令「牌立在桌子上我都看不到牌吧」——视角的判据＝立牌面可读）：
# 我方手牌行＝立牌面朝镜头＋**后倾 12°**（建模调研定案：可读性靠真比例厚牌体＋后倾迎镜头，
# 不压低机位）；紧排 pitch＝牌宽＋缝隙（同码墙，立牌彼此挨着）。敌方手牌带＝立牌背纹朝镜头。
const LEAN_DEG := 12.0


func _build_standing_demo() -> void:
	var hand := [["万", 1], ["万", 2], ["万", 3], ["万", 4], ["万", 5], ["万", 6], ["万", 7],
		["万", 8], ["万", 9], ["筒", 2], ["筒", 5], ["条", 3], ["条", 7]]
	var pitch := Mj3dTile.SIZE.x * WALL_SCALE + TILE_GAP
	var x0 := -(hand.size() - 1) * 0.5 * pitch
	var y := FELT_TOP + 0.5 * WALL_SCALE * cos(deg_to_rad(LEAN_DEG))  # 后倾＝支点在底棱
	for i in range(hand.size()):
		var tile: Mj3dTile = WALL_TILE.instantiate()
		tile.stand(false, LEAN_DEG)
		tile.set_tile(hand[i][0], hand[i][1])
		tile.scale = Vector3.ONE * WALL_SCALE
		tile.position = Vector3(x0 + i * pitch, y, 2.55)
		zones.add_child(tile)
	for i in range(13):
		var back: Mj3dTile = WALL_TILE.instantiate()
		back.stand()
		back.set_back()
		back.scale = Vector3.ONE * WALL_SCALE
		back.position = Vector3(x0 + i * pitch, FELT_TOP + 0.5 * WALL_SCALE, -2.9)
		zones.add_child(back)


# 中心暗纹（雀魂参照：呢面中心淡圆纹/徽标）——程序径向渐变贴图，平贴呢面正中。
func _build_center_emblem() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var d := Vector2(x - 127.5, y - 127.5).length() / 128.0
			var a := clampf(1.0 - absf(d - 0.62) * 3.2, 0.0, 1.0) * 0.5
			if d < 0.55:
				a = maxf(a, clampf(0.16 - d * 0.12, 0.0, 0.16))
			img.set_pixel(x, y, Color(0.02, 0.11, 0.06, a))
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(5.2, 5.2)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mesh.material = mat
	var quad := MeshInstance3D.new()
	quad.mesh = mesh
	quad.position = Vector3(0, FELT_TOP + 0.015, 0)
	quad.rotation_degrees.x = -90.0
	zones.add_child(quad)


# 2D 覆盖层（CanvasLayer）＝2D 版根布局原位（2026-09-18 用户令「位置不动」）：
# 顶栏（返回/拍·行动方居中/词条/设置）→ 敌状态条整行在顶 → 牌桌 → 我状态条整行在底。
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_top_bar = MJBTopBar.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	layer.add_child(_top_bar)
	_top_bar.back_pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.DOJO))
	var glossary := MJBGlossaryPopup.new()
	layer.add_child(glossary)
	_top_bar.help_pressed.connect(func(): glossary.open())
	var settings := MJBSettingsPopup.new()
	layer.add_child(settings)
	_top_bar.settings_pressed.connect(func(): settings.open(true))
	_top_bar.set_turn("拍 0 · 你的回合", Color(0.92, 0.86, 0.7))
	_enemy_panel = MJBFighterPanel.new("石仆")
	_enemy_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_enemy_panel.offset_left = 16
	_enemy_panel.offset_right = -16
	_enemy_panel.offset_top = 44
	layer.add_child(_enemy_panel)
	_player_panel = MJBFighterPanel.new("玩家")
	_player_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_player_panel.offset_left = 16
	_player_panel.offset_right = -16
	_player_panel.offset_top = -58  # 底锚只给零高矩形——VBox 从锚点向下长会整条掉出屏：
	_player_panel.offset_bottom = -6  # 须上下偏移都给，把矩形抬进屏内（血条不可见事故的根因）
	layer.add_child(_player_panel)
	var title := Label.new()
	title.text = "3D 牌桌 · 布局预览（无牌）"
	title.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	title.offset_left = -420
	title.offset_top = -64
	title.offset_right = -14
	title.offset_bottom = -44
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.6, 0.56, 0.46, 0.8))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)
