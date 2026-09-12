extends Panel

# 日志滚动窗组件：喂文本行自动滚底；可选逐行颜色（bbcode 着色）。
# 版图左下角常驻日志与战斗战报罩层共用本组件（join+滚底只此一份）。

func set_lines(lines: Array[String], colors: Array = []) -> void:
	var parts: Array[String] = []
	for i in range(lines.size()):
		var line := _escape(lines[i])
		if i < colors.size() and colors[i] is Color:
			line = "[color=#%s]%s[/color]" % [(colors[i] as Color).to_html(false), line]
		parts.append(line)
	($Scroll/Lines as RichTextLabel).text = "\n".join(parts)
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	var scroll := $Scroll as ScrollContainer
	if scroll.get_v_scroll_bar() != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

# bbcode 转义：正文里的 "[" 不能当标签解析
static func _escape(s: String) -> String:
	return s.replace("[", "[lb]")
