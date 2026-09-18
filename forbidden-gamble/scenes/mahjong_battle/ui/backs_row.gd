class_name MJBBacksRow
extends HBoxContainer

## 敌方手牌带（牌桌远端·上桌，2026-09-17 用户令）：居中背牌行——远端档位缩小
## （近大远小假透视：此 20×27 vs 我方手牌 30–55）。摸牌飞行落点＝右端新背牌。


const TILE_W := 20
const TILE_H := 27


func _init() -> void:
	add_theme_constant_override("separation", 2)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_backs(count: int) -> void:
	for child in get_children():
		child.queue_free()
	for _i in range(count):
		add_child(MJBTileFace.make_back(TILE_W, TILE_H))


## 背牌带右端（敌方摸牌飞行的落点——新背牌追加侧）；无背牌＝整带矩形。
func backs_dest_rect() -> Rect2:
	if get_child_count() == 0:
		return get_global_rect()
	return (get_child(get_child_count() - 1) as Control).get_global_rect()
