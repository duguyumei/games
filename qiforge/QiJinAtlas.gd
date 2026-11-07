## 金丹零件图集（2026-11-06 用户出图）：3×3 绿幕已抠 → jindan_sheet.png
## 1 丹体 / 2 墨圈 / 3 火星 / 4 符纹 / 5 朱砂 / 6 流光 / 7 气晕 / 8 裂纹 / 9 气柱
extends RefCounted

const SHEET := "res://qiforge/assets/hud/jindan_sheet.png"
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
	at.region = Rect2(float(k % 3) * cw, float(k / 3) * ch, cw, ch)
	_cache[i] = at
	return at
