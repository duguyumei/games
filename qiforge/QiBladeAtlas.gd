## 兵刃光效图集（2026-11-06 用户出图）：3×3 绿幕已抠 → blade_sheet.png
## 1 横刺 / 2 横斩 / 3 竖劈 / 4 上撩 / 5 交击 / 6 回旋 / 7 螺旋 / 8 斜闪 / 9 收锋
extends RefCounted

const SHEET := "res://qiforge/assets/hud/blade_sheet.png"
static var _tex: Texture2D = null
static var _cache: Dictionary = {}

static func sheet() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if img != null and not img.is_empty():
		_tex = ImageTexture.create_from_image(img)
	return _tex

static func cell(idx: int) -> AtlasTexture:
	var t := sheet()
	if t == null:
		return null
	var i := clampi(idx, 1, 9)
	if _cache.has(i):
		return _cache[i]
	var cw := float(t.get_width()) / 3.0
	var ch := float(t.get_height()) / 3.0
	var k := i - 1
	var at := AtlasTexture.new()
	at.atlas = t
	# 各格按「实际笔画包围盒」裁紧（不裁的话大片透明会把笔画摊薄）
	var boxes := [
		Rect2(92, 169, 202, 6), Rect2(405, 165, 231, 39), Rect2(820, 82, 61, 202),
		Rect2(81, 466, 213, 80), Rect2(410, 424, 191, 125), Rect2(777, 447, 187, 117),
		Rect2(88, 760, 194, 126), Rect2(440, 761, 129, 124), Rect2(738, 792, 190, 39),
	]
	at.region = boxes[k]
	_cache[i] = at
	return at
