## qi-forge 统一弹窗系统 v2（2026-10-27 按 STS2 NModalContainer 制重造）：
## Control 弹窗盒（QiDialogBox）＋ColorRect 背板补间到 85% 黑（0.3s）＋MouseFilter 输入门＋单弹窗互斥
## （已有弹窗再开＝拒绝）——不再使用 Godot AcceptDialog/Window。
## API 兼容旧制：create(parent, title, size, ok, cancel, esc, outside_close) -> [scrim, box]；
## 内容挂 box.content()；确认走 confirmed 信号；warning 快捷件同旧。
extends RefCounted

const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")
const QISTYLE := preload("res://qiforge/QiStyle.gd")
const BOX := preload("res://qiforge/QiDialogBox.gd")

static var _open_box: Control = null     # 单弹窗互斥（STS2 制：已有弹窗再开＝拒）

static func create(parent: Control, title_text: String, size: Vector2, ok_text: String,
		cancel_text: String = "", esc_closeable: bool = true, outside_close: bool = false,
		dim: bool = true) -> Array:
	if _open_box != null and is_instance_valid(_open_box) and _open_box.visible:
		push_warning("QiDialog：已有弹窗开着，拒绝再开（STS2 单弹窗制）")
		return [null, null]
	var scrim := ColorRect.new()
	scrim.name = "QiScrim"
	scrim.color = Color(0, 0, 0, 0)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.z_index = 90   # 模态置顶（2026-10-29 修「攻次珠浮上奖励弹窗」：屏内常驻件局部 z 8~60
	                     # 压过默认 z=0 的弹窗；scrim 90/box 91 统一盖全屏件族；浮窗独立 CanvasLayer 不受影响）
	parent.add_child(scrim)
	var box: Control = BOX.new()
	box.setup(title_text, ok_text, cancel_text, size, esc_closeable)
	box.z_index = 91
	parent.add_child(box)
	_open_box = box
	if outside_close:
		scrim.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_close_pair(scrim, box))
	# 关联收尾：盒离树 → 互斥位清空＋背板淡出释放
	box.tree_exiting.connect(func() -> void:
		if _open_box == box:
			_open_box = null
		_fade_out(scrim))
	# 确认/取消统一关窗释放（调用方另接 confirmed 做自己的事，两个连接都会触发）
	box.canceled.connect(func() -> void: _close_pair(scrim, box))
	box.confirmed.connect(func() -> void: _close_pair(scrim, box))
	# 背板淡入（STS2：alpha → 0.85，0.3s）；dim=false＝无遮罩档（输入门保留、纯视觉关——
	# 2026-10-28 用户裁定：装备窗不要背板）
	if dim:
		var tw := scrim.create_tween()
		tw.tween_property(scrim, "color:a", 0.85, 0.3)
	return [scrim, box]

## 公开关窗入口（装备窗等即点即关流用；box.hide() 不走关窗管线会孤儿化背板——禁用）
static func close(scrim: ColorRect, box: Control) -> void:
	_close_pair(scrim, box)

static func _close_pair(scrim: ColorRect, box: Control) -> void:
	# 输入门即放行（同帧，STS2 制）；淡出由 tree_exiting/_fade_out 接力，纯视觉
	if is_instance_valid(scrim):
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if box != null and is_instance_valid(box):
		box.queue_free()
	elif is_instance_valid(scrim):
		scrim.queue_free()

static func _fade_out(scrim: ColorRect) -> void:
	if not is_instance_valid(scrim):
		return
	# STS2 制（NMerchantInventory.CloseInventory 实证）：输入门与视觉解耦——
	# 关窗决定一下即 mouse_filter 瞬切 IGNORE，淡出纯装饰；旧制「淡完才 free」多出
	# 0.3s 全屏输入死区（关弹窗后 hover/点击哑掉，modal_tip B 复原挂之根因）。
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := scrim.create_tween()
	tw.tween_property(scrim, "color:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		if is_instance_valid(scrim):
			scrim.queue_free())

## 二次确认快捷件（双键，ESC 拒关）：确认即回调并关窗。
static func warning(parent: Control, title_text: String, body_text: String, on_confirm: Callable) -> Array:
	var arr := create(parent, title_text, Vector2(520, 300), "确认", "取消", false)
	if arr[1] == null:
		return arr
	var dialog: Control = arr[1]
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.text = body_text
	body.add_theme_font_size_override("normal_font_size", 20)
	body.custom_minimum_size = Vector2(456, 120)
	dialog.content().add_child(body)
	dialog.confirmed.connect(func() -> void:
		dialog.visible = false
		if on_confirm.is_valid():
			on_confirm.call())
	dialog.canceled.connect(func() -> void:
		dialog.visible = false)
	dialog.popup_centered(Vector2i(520, 300))
	return arr

## 旧 API 兼容（确认键样式已在盒内定制）
static func restyle_ok(_dialog: Control) -> void:
	pass
