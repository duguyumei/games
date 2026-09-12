extends Panel

# 卡面组件：类别色描边 + 居中牌名（毛笔字）。纯展示（tscn 里 mouse_filter=IGNORE）。
# 用法：instantiate → add_child → setup(牌面文本, 类别)。

const Palette := preload("res://ui/board_palette.gd")

func setup(text: String, kind: String) -> void:
	add_theme_stylebox_override("panel", Palette.card_style(kind))
	($NameLabel as Label).text = text
