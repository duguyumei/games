class_name MJBTipFloat
extends PanelContainer

## 浮窗详情（明码层）：悬停展示，锚定触发控件、视口内翻转，不拦鼠标、不挡点击。
## 参照《我地麻》BaseNodeFloatPanel 家族（DescriptionWindow/DetailPanelCtr）——零资产、纯结构参照。
## 根装配时创建唯一实例（active）；各区块用 bind()/bind_tech() 一行挂悬停。
## headless（m13/GUT）下鼠标永不进入＝零副作用。


const WIDTH := 280.0
const HOVER_DELAY := 0.35  # 防误触：悬停停留超过此时长才出窗（划过不出）

static var active: MJBTipFloat

var _title := Label.new()
var _body := VBoxContainer.new()
var _hover_widget: Control = null


func _init() -> void:
	active = self
	visible = false
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.105, 0.97)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.55, 0.48, 0.32)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6))
	box.add_child(_title)
	_body.add_theme_constant_override("separation", 2)
	box.add_child(_body)


static func bind(widget: Control, title: String, lines: Array) -> void:
	if active == null:
		return
	# 内容存 meta：重复 bind 只刷新内容不重连（高频重绘的牌面/读数安全）
	widget.set_meta("tip_title", title)
	widget.set_meta("tip_lines", lines)
	if widget.has_meta("tip_on"):
		return
	widget.set_meta("tip_on", true)
	widget.mouse_filter = Control.MOUSE_FILTER_STOP
	widget.mouse_entered.connect(func():
		active._hover_widget = widget
		var timer := active.get_tree().create_timer(HOVER_DELAY)
		timer.timeout.connect(func():
			if active._hover_widget == widget and is_instance_valid(widget):
				active._try_show(widget)))
	widget.mouse_exited.connect(func():
		active._hover_widget = null
		active.visible = false)


## 自绘内容挂点（2026-09-17 用户令：记牌＝小牌矩阵，非文字行）：
## custom 由调用方持有并刷新；悬停时浮窗临时收编、移开时脱挂（不释放——调用方还要复用）。
static func bind_custom(widget: Control, title: String, custom: Control) -> void:
	if active == null:
		return
	custom.set_meta("tip_custom_owner", true)
	widget.set_meta("tip_title", title)
	widget.set_meta("tip_custom", custom)
	if widget.has_meta("tip_on"):
		return
	widget.set_meta("tip_on", true)
	widget.mouse_filter = Control.MOUSE_FILTER_STOP
	widget.mouse_entered.connect(func():
		active._hover_widget = widget
		var timer := active.get_tree().create_timer(HOVER_DELAY)
		timer.timeout.connect(func():
			if active._hover_widget == widget and is_instance_valid(widget):
				active._try_show(widget)))
	widget.mouse_exited.connect(func():
		active._hover_widget = null
		active.visible = false
		active._detach_custom())


func _try_show(widget: Control) -> void:
	if widget.has_meta("tip_custom"):
		show_custom(widget)
	else:
		show_for(widget, widget.get_meta("tip_title"), widget.get_meta("tip_lines"))


# 自绘内容：脱挂旧件 → 清文字行 → 收编 custom → 落位。
func show_custom(widget: Control) -> void:
	_detach_custom()
	_free_label_rows()
	_title.text = String(widget.get_meta("tip_title"))
	_body.add_child(widget.get_meta("tip_custom"))
	size = get_combined_minimum_size()
	_place(widget)
	visible = true


func _detach_custom() -> void:
	for c in _body.get_children():
		if c.has_meta("tip_custom_owner"):
			_body.remove_child(c)


# 只释放文字行；自绘件（tip_custom_owner）只脱挂不释放——归调用方持有。
func _free_label_rows() -> void:
	for c in _body.get_children():
		if not c.has_meta("tip_custom_owner"):
			_body.remove_child(c)
			c.free()


# 功法浮窗文案（2026-09-17 用户令：只留本武学自己的账——配方/威力/前摇值/罡气价/效果全文；
# 推进规则、入河明牌、护体窗口等底层机制在顶栏问号词条，不进武学浮窗）。
static func bind_tech(widget: Control, tech: MJTechnique) -> void:
	if tech == null:
		return
	var lines: Array = []
	if tech.kind == "defense":
		lines.append("罡气价：%d" % tech.gang_qi_cost)
	else:
		var parts: Array[String] = []
		var symbols := 0
		for symbol in tech.recipe:
			parts.append("%s×%d" % [symbol, int(tech.recipe[symbol])])
			symbols += int(tech.recipe[symbol])
		lines.append("配方：%s" % "＋".join(parts))
		lines.append("威力：%d%% × 攻击面板" % tech.power)
		lines.append("前摇：%d 拍" % (tech.windup if tech.windup > 0 else symbols))
	if not tech.brief.is_empty():
		lines.append(tech.brief)
	bind(widget, tech.display_name, lines)


func show_for(anchor: Control, title: String, lines: Array) -> void:
	_detach_custom()
	_title.text = title
	# 立即移除并释放旧行（queue_free 会与新行同帧并存，最小尺寸偶发一帧偏高）
	_free_label_rows()
	for line in lines:
		var l := Label.new()
		l.text = str(line)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.86, 0.83, 0.76))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(l)
	size = get_combined_minimum_size()
	_place(anchor)
	visible = true


# 落位：锚控件右侧优先、视口翻转钳制。
func _place(anchor: Control) -> void:
	var vp := get_viewport_rect().size
	var rect := anchor.get_global_rect()
	var pos := rect.end + Vector2(10, -size.y / 2.0)
	if pos.x + size.x > vp.x - 8.0:
		pos = rect.position - Vector2(size.x + 10.0, size.y / 2.0)
	pos.x = clampf(pos.x, 8.0, vp.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - size.y - 8.0)
	position = pos
