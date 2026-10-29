@tool
class_name MJBTileStand
extends Control

## 站立·正立牌（统一模型 01，2026-09-18 用户令：每个姿势一张组件，便于后续调整复用）。
## 玩家手牌形态：mahjong_graphic 竖精灵直出（双层/圆角/透视/阴影已烘焙）。
## 宽＝透视牌宽（MJBPerspective 派生），高＝姿态规范纵横比（389/272）。
## 手牌交互态三件：selected（升起，由手牌行置 y 偏移）｜candidate（金边）｜fresh（顶缘金条）。


const ASPECT := 389.0 / 272.0
const GOLD := Color(0.98, 0.82, 0.3)
const GOLD_EDGE := Color(0.85, 0.75, 0.4)

var candidate := false:  # 武学备付候选（金边）
	set(v):
		candidate = v
		queue_redraw()
var fresh := false:      # 刚摸到（顶缘金条）
	set(v):
		fresh = v
		queue_redraw()

var _tex: Texture2D


func setup(tile: MJTile, w: int) -> void:
	_tex = MJBTileFace.stand_tex(tile)
	custom_minimum_size = Vector2(w, roundi(w * ASPECT))
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	if candidate:
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), GOLD_EDGE, false, 2.0)
	if fresh:
		draw_rect(Rect2(4, 2, size.x - 8, 3), GOLD)
