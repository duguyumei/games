## 拖拽件（Godot 原生拖放协议）：拖起＝自动跟手预览＋原卡压暗；松手不在可放区＝自动还原。
## 内层工厂卡 mouse_filter=IGNORE，事件全由本件接管（拖拽/点击都在这挂）。
## 2026-10-26 备战舱轮扩展：同壳可兼作落点（drop_ok/on_drop 可选回调——编队换位、
## 后备收起等把本件直接当落点用，勿另造轮子）；card_data 为空时不可拖（纯落点用法）。
extends Control

var card_data: Dictionary = {}
var preview_card: Control = null
## 拖拽形态（2026-10-28 STS2 制）：preview＝整卡跟手（无目标功法/备战舱/普攻胶囊）；
## arrow＝卡不跟手——battle 屏把原卡升起＋画贝塞尔箭头（目标功法，NMouseCardPlay/NTargetingArrow 制）。
var drag_style: String = "preview"
var drop_ok: Callable = Callable()   # (data) -> bool
var on_drop: Callable = Callable()   # (data, self) -> void
var on_drag_begin: Callable = Callable()   # 起拖即回调（有效目标/归属高亮用）
var on_drag_end: Callable = Callable()   # 拖拽结束（无论成否）——战场用来清落点高亮/连线
var drag_armed: bool = false   # 本按压周期内已起过拖拽——点击语义（如详情页）须让其位

func _get_drag_data(_pos: Vector2) -> Variant:
	if card_data.is_empty():
		return null
	drag_armed = true
	if drag_style != "arrow" and is_instance_valid(preview_card):
		# 引擎在拖拽结束时自动释放跟手预览——必须上缴副本，模板本体留在壳上；
		# 直接上缴模板＝首拖后 preview_card 悬空，再拖报错且起不了拖（2026-10-27 备战舱二拖 bug）。
		var pv: Control = preview_card.duplicate()
		pv.name = "QiDragPreview"
		pv.modulate = Color(1, 1, 1, 0.75)
		# 鼠标锚卡底中（STS 制）：引擎把预览居中于光标——零尺寸锚壳＋子件上移＝卡悬于准星上方，
		# 不再盖住正要瞄准的落点（模板未入树 size 不可靠，取 custom_minimum_size）。
		var psz: Vector2 = preview_card.custom_minimum_size
		var holder := Control.new()
		holder.name = "QiDragAnchor"
		holder.add_child(pv)
		pv.position = Vector2(-psz.x * 0.5, -psz.y * 0.88)
		set_drag_preview(holder)
	if on_drag_begin.is_valid():
		on_drag_begin.call()
	if drag_style != "arrow":
		modulate = Color(1, 1, 1, 0.35)
	return {"drag_data": card_data, "from": self}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return drop_ok.is_valid() and drop_ok.call(data)

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if on_drop.is_valid():
		on_drop.call(data, self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		drag_armed = true   # 覆盖 force_drag 等不经 _get_drag_data 的起拖路径
	elif what == NOTIFICATION_DRAG_END:
		modulate = Color(1, 1, 1, 1.0)
		if on_drag_end.is_valid():
			on_drag_end.call()
