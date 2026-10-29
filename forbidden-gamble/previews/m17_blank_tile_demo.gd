extends Node3D

## 空白双层牌体·四姿势特写样机（2026-09-18 用户令「那先做一个第一 1 的」）。
## 比例＝26:19:12、骨面 55%/竹背 45%（中国牌调研第一组）。
## 特写机位偏高（≈59° 俯角）——立牌顶面两色带与躺牌侧带是本模型的关键可视特征。
## 不接规则引擎，纯视觉评估；m16 样机保留作姿势全集参照。

const TILE := preload("res://scenes/mahjong3d/mj3d_blank_tile.tscn")
const FONT := "res://assets/fonts/MaShanZheng-Regular.ttf"
const CAM_POS := Vector3(0, 2.6, 1.5)
const CAM_TARGET := Vector3(0, 0.05, 0)
const FELT_TOP := 0.05

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.position = CAM_POS
	camera.look_at(CAM_TARGET)
	$Sun.rotation_degrees = Vector3(-50, 0, 0)
	_build()
	await get_tree().process_frame
	_place_labels()


func _build() -> void:
	# v1 布局教训：立/躺同 x 列时，立牌牌体在屏上正好遮住后方躺牌的近端分层带
	# （探针射线穿立牌牌体＝白面假象）——立牌外列、躺牌内列错开。
	var face_tile := TILE.instantiate() as Mj3dTileBlank
	add_child(face_tile)
	face_tile.position = Vector3(-0.95, FELT_TOP + SIZE_Y_HALF, 0.5)
	face_tile.stand(false, 12.0)
	var back_tile := TILE.instantiate() as Mj3dTileBlank
	add_child(back_tile)
	back_tile.position = Vector3(0.95, FELT_TOP + SIZE_Y_HALF, 0.5)
	back_tile.stand(true)
	# 后排：躺·骨面朝上（左内）／躺·竹背朝上（右内）
	var lie_up := TILE.instantiate() as Mj3dTileBlank
	add_child(lie_up)
	lie_up.position = Vector3(-0.42, FELT_TOP + SIZE_Z_HALF, -0.65)
	lie_up.lie_flat()
	var lie_down := TILE.instantiate() as Mj3dTileBlank
	add_child(lie_down)
	lie_down.position = Vector3(0.42, FELT_TOP + SIZE_Z_HALF, -0.65)
	lie_down.lie_face_down()


const SIZE_Y_HALF := 0.5   # 立牌半高（牌长 1.0 归一）
const SIZE_Z_HALF := 12.0 / 26.0 / 2.0  # 躺牌半厚（0.2308）


func _place_labels() -> void:
	var font := load(FONT) as Font
	var layer := CanvasLayer.new()
	add_child(layer)
	var specs := [
		{"text": "立·骨面朝前（后倾 12°）", "world": Vector3(-0.95, FELT_TOP + 1.05, 0.5)},
		{"text": "立·竹背朝前", "world": Vector3(0.95, FELT_TOP + 1.05, 0.5)},
		{"text": "躺·骨面朝上", "world": Vector3(-0.42, FELT_TOP + 0.32, -0.65)},
		{"text": "躺·竹背朝上", "world": Vector3(0.42, FELT_TOP + 0.32, -0.65)},
	]
	for spec in specs:
		var label := Label.new()
		label.text = spec["text"]
		if font != null:
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.78))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		layer.add_child(label)
		label.position = camera.unproject_position(spec["world"]) + Vector2(-70, -12)
