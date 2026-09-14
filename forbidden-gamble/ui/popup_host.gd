class_name PopupHost
extends Control

# 通用弹窗框架（C-017 经验产品化）：把内容面板锚定在任意控件下缘右对齐弹出。
# - 点弹窗以外任意处关闭（全屏背板拦截——含"再点顶栏按钮即收起"的场景）
# - ESC 关闭（_unhandled_input 消费事件，先于场景根自己的 ESC 逻辑）
# - 互斥：open 自动收起上一个
# 内容面板由调用方构建（战斗暗墨/版图纸墨各自风格），本组件只管定位与关闭交互。
# 用法：作为场景根的直接子节点（全屏锚定）；本类自带全屏锚定，add_child 即可。

signal closed

var _catcher: Control
var _content: Control
var _anchor: Control
var _centered := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 无弹窗时不挡场景输入
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func is_open() -> bool:
	return _content != null and is_instance_valid(_content)

# 当前弹出的内容面板（预览/测试用；无弹窗返回 null）
func current_content() -> Control:
	return _content if is_open() else null

func open(anchor: Control, content: Control) -> void:
	close(false)
	_centered = false
	_anchor = anchor
	_catcher = Control.new()
	_catcher.name = "PopupCatcher"
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)
	_content = content
	add_child(_content)
	_reposition()

# 居中开窗（详情页类）：屏幕中央弹出，不锚定控件——点外关闭/ESC/互斥照旧。
func open_centered(content: Control) -> void:
	close(false)
	_centered = true
	_catcher = Control.new()
	_catcher.name = "PopupCatcher"
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)
	_content = content
	add_child(_content)
	_reposition()

# notify=false 供 open() 内部换面板使用：对调用方而言弹窗没有"关闭"过。
func close(notify := true) -> void:
	var was_open := is_open()
	if _catcher != null and is_instance_valid(_catcher):
		_catcher.queue_free()
	_catcher = null
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	_content = null
	_anchor = null
	_centered = false
	if was_open and notify:
		closed.emit()

# 窗口尺寸变化时贴住锚点（expand 缩放下窗口比例≠16:9，列会居中偏移，
# 屏幕角定位会脱离顶栏——必须按锚控件实时 global_rect 换算）
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_reposition()

func _reposition() -> void:
	if not is_open():
		return
	_content.reset_size()
	if _centered or _anchor == null or not is_instance_valid(_anchor):
		var vp := get_viewport_rect().size
		_content.position = (vp - _content.size) * 0.5
		return
	var rect := _anchor.get_global_rect()
	_content.position = Vector2(rect.end.x - _content.size.x - 2.0, rect.end.y + 6.0)

func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and is_open():
		close()
		get_viewport().set_input_as_handled()
