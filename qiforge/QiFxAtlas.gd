## 特效图集（2026-11-06 用户出图）：一张 3×3 绿幕图切成九件。
## 已离线抠绿 → fx_sheet.png（透明底）；这里只做 region 切片，不重复读盘。
## 格序（1..9）：1 竖斩 / 2 横斩 / 3 突刺 / 4 斜撩 / 5 命中爆点 / 6 墨溅 / 7 火舌A / 8 火舌B / 9 护环
extends RefCounted

const SHEET := "res://qiforge/assets/hud/fx_sheet.png"

static var _tex: Texture2D = null
static var _cache: Dictionary = {}

static func sheet() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if img != null and not img.is_empty():
		_tex = ImageTexture.create_from_image(img)
	return _tex

## 取一格（idx 从 1 开始，越界夹到 1..9）
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

## 加法混合材质（火/光用：真的在发光，而不是糊在纸上）
static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
