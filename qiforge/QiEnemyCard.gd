## 敌人卡（2026-11-05 用户令：敌人卡牌化、5 堆×3 张、上露右露；无血条/名字）
## 卡面＝暗框＋纸窗＋立绘；档位（小怪/精英/Boss）用框区分。
extends RefCounted

const QISTYLE = preload("res://qiforge/QiStyle.gd")
const SIZE := Vector2(190.0, 250.0)

static func _tex(name: String) -> Texture2D:
	var p := "res://qiforge/assets/hud/%s.png" % name
	var img := Image.load_from_file(ProjectSettings.globalize_path(p))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

## tier: small / elite / boss
static func make(enemy: Dictionary, tier: String, portrait_idx: int) -> Control:
	var card := Control.new()
	card.custom_minimum_size = SIZE
	card.size = SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _frame_style(tier))
	card.add_child(frame)
	var win := Panel.new()
	win.position = Vector2(7.0, 7.0)
	win.size = Vector2(SIZE.x - 14.0, SIZE.y - 14.0)
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = Color(0.86, 0.82, 0.72, 1.0)
	wsb.set_corner_radius_all(4)
	win.add_theme_stylebox_override("panel", wsb)
	card.add_child(win)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture = _tex("enemy_%d" % (portrait_idx % 3 + 1))
	pic.position = Vector2(10.0, 10.0)
	pic.size = Vector2(SIZE.x - 20.0, SIZE.y - 20.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pic)
	return card

## 档位框样式（make 与 refresh 共用一份）
static func _frame_style(tier: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.05, 0.045, 0.97)
	sb.set_corner_radius_all(7)
	match tier:
		"boss":
			sb.border_color = Color(0.72, 0.18, 0.15, 1.0)
			sb.set_border_width_all(4)
			sb.shadow_color = Color(0.55, 0.10, 0.08, 0.40)
			sb.shadow_size = 10
		"elite":
			sb.border_color = Color(0.86, 0.78, 0.55, 1.0)
			sb.set_border_width_all(3)
			sb.shadow_color = Color(0, 0, 0, 0.40)
			sb.shadow_size = 7
		_:
			sb.border_color = Color(0.60, 0.56, 0.46, 0.9)
			sb.set_border_width_all(2)
			sb.shadow_color = Color(0, 0, 0, 0.32)
			sb.shadow_size = 5
	return sb

## 复用节点就地刷新（2026-11-06 敌阵对账制规格§7：节点身份稳定——档位变就换框；
## 血量＝无血条不刷；将来受击闪/抖动/血条动画挂这些稳定节点上）
static func refresh(card: Control, enemy: Dictionary, tier: String) -> void:
	var frame := card.get_child(0) as Panel
	if frame != null:
		frame.add_theme_stylebox_override("panel", _frame_style(tier))
