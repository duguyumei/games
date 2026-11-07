## VC 制属性图标（2026-11-04 用户裁定「图标自绘/CC0」）：18 枚 32×32 程序像素图标，
## 无外部素材——按原版图标语义自绘近似形（叶/烛台/沙漏/磁/弹/十字/卡/箱/冠/骷/四叶/币/骰/禁/快进/心/警/魅）。
## 用法：QiVcIcons.icon("might") -> Texture2D（静态缓存，按 id 只画一次）。
extends RefCounted

static var _cache: Dictionary = {}

static func icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match id:
		"might": _sword(img)
		"area": _candelabra(img)
		"duration": _hourglass(img)
		"amount": _arrows(img)
		"magnet": _magnet(img)
		"recovery": _cross(img, Color("7fae62"))
		"deal_count": _card(img)
		"scavenge": _chest(img)
		"growth": _up_arrow(img)
		"curse": _skull(img)
		"luck": _clover(img)
		"greed": _coin(img)
		"reroll": _die(img)
		"banish": _banish(img)
		"skip": _skip(img)
		"revival": _heart(img)
		"risk": _warning(img)
		"charm": _charm(img)
		_:
			_cross(img, Color("c9a227"))
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex

#region 画笔
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_px(img, x, y, c)

static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				_px(img, x, y, c)

static func _ring(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := x - cx
			var dy := y - cy
			var d := dx * dx + dy * dy
			if d <= r * r and d >= (r - 2) * (r - 2):
				_px(img, x, y, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, w := 2) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in steps + 1:
		var t := float(i) / float(maxi(1, steps))
		var x := int(round(float(x0) + (float(x1 - x0) * t)))
		var y := int(round(float(y0) + (float(y1 - y0) * t)))
		for oy in w:
			for ox in w:
				_px(img, x + ox, y + oy, c)
#endregion

#region 图标
static func _sword(img: Image) -> void:
	var blade := Color("cfd6e0")
	var hilt := Color("c9a227")
	_line(img, 9, 23, 24, 8, blade, 2)
	_line(img, 20, 6, 26, 12, blade, 2)
	_line(img, 7, 20, 14, 27, hilt, 2)
	_line(img, 6, 26, 10, 26, hilt, 1)
	_px(img, 25, 7, Color("eef3fa"))

static func _candelabra(img: Image) -> void:
	var wax := Color("cdb98a")
	var flame := Color("e08a3e")
	_line(img, 8, 24, 24, 24, wax, 1)   # 底座
	for i in 3:
		var x := 9 + i * 7
		_line(img, x, 24, x, 12, wax, 1)
		_circle(img, x + 1, 8 + i % 2, 2, flame)
		_px(img, x + 1, 11, Color("f6d27a"))

static func _hourglass(img: Image) -> void:
	var c := Color("6f9fd8")
	_line(img, 8, 6, 24, 6, c, 1)
	_line(img, 8, 26, 24, 26, c, 1)
	_line(img, 9, 7, 23, 25, c, 1)
	_line(img, 23, 7, 9, 25, c, 1)
	_rect(img, 14, 14, 4, 4, Color("a8c8f0"))

static func _arrows(img: Image) -> void:
	var c := Color("e0b84a")
	for i in 3:
		var x := 7 + i * 8
		_line(img, x, 24, x, 12, c, 1)
		_line(img, x - 3, 15, x, 10, c, 1)
		_line(img, x + 3, 15, x, 10, c, 1)

static func _magnet(img: Image) -> void:
	var c := Color("b8c4d4")
	var red := Color("c05a5a")
	_rect(img, 8, 8, 5, 14, red)
	_rect(img, 19, 8, 5, 14, red)
	_rect(img, 8, 20, 16, 5, c)
	_rect(img, 8, 8, 5, 4, c)
	_rect(img, 19, 8, 5, 4, c)

static func _cross(img: Image, c: Color) -> void:
	_rect(img, 13, 6, 6, 20, c)
	_rect(img, 6, 13, 20, 6, c)

static func _card(img: Image) -> void:
	var c := Color("e8e2d2")
	_rect(img, 9, 5, 14, 22, c)
	_rect(img, 11, 8, 10, 9, Color("8a3a3a"))
	_rect(img, 11, 19, 10, 2, Color("5a5a6a"))

static func _chest(img: Image) -> void:
	var gold := Color("c9a227")
	var dark := Color("7a5a18")
	_rect(img, 6, 14, 20, 12, gold)
	_rect(img, 6, 9, 20, 6, dark)
	_line(img, 6, 14, 26, 14, dark, 1)
	_rect(img, 14, 13, 4, 6, Color("f0e6c8"))
	_px(img, 15, 16, dark)

static func _up_arrow(img: Image) -> void:
	var c := Color("7fae62")
	_line(img, 16, 26, 16, 10, c, 3)
	_line(img, 8, 17, 16, 7, c, 3)
	_line(img, 24, 17, 16, 7, c, 3)

static func _skull(img: Image) -> void:
	var bone := Color("ddd6c6")
	_circle(img, 16, 14, 8, bone)
	_rect(img, 12, 20, 8, 5, bone)
	_rect(img, 11, 14, 4, 4, Color("2a2230"))
	_rect(img, 17, 14, 4, 4, Color("2a2230"))
	_px(img, 15, 19, Color("2a2230"))
	_px(img, 16, 19, Color("2a2230"))

static func _clover(img: Image) -> void:
	var c := Color("7fae62")
	_circle(img, 12, 12, 5, c)
	_circle(img, 20, 12, 5, c)
	_circle(img, 12, 20, 5, c)
	_circle(img, 20, 20, 5, c)
	_line(img, 16, 22, 16, 28, Color("4f7a3a"), 1)

static func _coin(img: Image) -> void:
	_circle(img, 16, 16, 10, Color("e0b84a"))
	_circle(img, 16, 16, 7, Color("c9a227"))
	_rect(img, 14, 11, 4, 10, Color("f6e2a0"))
	_px(img, 13, 13, Color("8a6a18"))

static func _die(img: Image) -> void:
	_rect(img, 7, 7, 18, 18, Color("e8e8e8"))
	_rect(img, 9, 9, 14, 14, Color("cfcfcf"))
	_rect(img, 11, 11, 3, 3, Color("2a2a2a"))
	_rect(img, 18, 11, 3, 3, Color("2a2a2a"))
	_rect(img, 14, 14, 3, 3, Color("2a2a2a"))
	_rect(img, 11, 18, 3, 3, Color("2a2a2a"))
	_rect(img, 18, 18, 3, 3, Color("2a2a2a"))

static func _banish(img: Image) -> void:
	_rect(img, 8, 5, 16, 22, Color("d8d0c0"))
	_line(img, 8, 6, 24, 26, Color("c05a5a"), 2)
	_line(img, 24, 6, 8, 26, Color("c05a5a"), 2)

static func _skip(img: Image) -> void:
	var c := Color("e0a05a")
	_line(img, 8, 8, 8, 24, c, 2)
	for i in 2:
		var x := 10 + i * 8
		_line(img, x, 8, x + 7, 16, c, 2)
		_line(img, x + 7, 16, x, 24, c, 2)

static func _heart(img: Image) -> void:
	var c := Color("c05a5a")
	_circle(img, 12, 12, 6, c)
	_circle(img, 20, 12, 6, c)
	_line(img, 7, 14, 16, 26, c, 3)
	_line(img, 25, 14, 16, 26, c, 3)
	_rect(img, 14, 15, 4, 4, Color("f0e6c8"))

static func _warning(img: Image) -> void:
	var c := Color("e0a05a")
	_line(img, 16, 5, 27, 26, c, 2)
	_line(img, 5, 26, 27, 26, c, 2)
	_line(img, 5, 26, 16, 5, c, 2)
	_rect(img, 15, 12, 3, 8, Color("2a2230"))
	_rect(img, 15, 22, 3, 3, Color("2a2230"))

static func _charm(img: Image) -> void:
	var c := Color("d07aa8")
	_circle(img, 12, 12, 6, c)
	_circle(img, 20, 12, 6, c)
	_line(img, 7, 14, 16, 26, c, 3)
	_line(img, 25, 14, 16, 26, c, 3)
	_px(img, 11, 10, Color("f6d0e2"))
	_px(img, 12, 9, Color("f6d0e2"))
#endregion

## 敌人剪影占位（2026-11-04 用户令「都做完」）：64×88 暗色人形，替原版敌人形象；
## 贴图按 tint 缓存，敌种不同色不同形（圆形头/躯干/四肢程序拼）。
static func silhouette(tint: Color) -> Texture2D:
	var key := "sil_" + tint.to_html()
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(64, 88, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_circle(img, 32, 18, 11, tint)
	_rect(img, 21, 30, 22, 32, tint)
	_line(img, 24, 60, 16, 84, tint, 4)
	_line(img, 40, 60, 48, 84, tint, 4)
	_line(img, 23, 38, 9, 58, tint, 4)
	_line(img, 41, 38, 55, 58, tint, 4)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
