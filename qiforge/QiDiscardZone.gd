## 弃牌带（Godot 原生拖放接收方）：任意手牌拖起即显（NOTIFICATION_DRAG_BEGIN 广播）；
## 拖入＝高亮（_can_drop_data）；松手＝弃置回调（_drop_data，蓝本语义：弃置不扣能量）。
extends Control

var on_discard: Callable = Callable()
var _hot := false

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("drag_data")
	if OS.get_environment("QI_DRAG_DEBUG") != "":
		print("DBG can_drop pos=", _pos, " data=", data, " -> ", ok)
	_set_hot(ok)
	return ok

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if OS.get_environment("QI_DRAG_DEBUG") != "":
		print("DBG drop_data pos=", _pos, " data=", data)
	_set_hot(false)
	if on_discard.is_valid() and data is Dictionary and data.has("drag_data"):
		on_discard.call(data["drag_data"], data.get("from"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		visible = true
	elif what == NOTIFICATION_DRAG_END:
		visible = false
		_set_hot(false)

func _set_hot(hot: bool) -> void:
	if hot == _hot:
		return
	_hot = hot
	var tw := create_tween()
	tw.tween_property(self, "modulate",
		Color(1.7, 1.4, 1.25, 1.0) if hot else Color(1, 1, 1, 1.0), 0.12)
