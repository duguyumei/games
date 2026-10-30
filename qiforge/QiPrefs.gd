## 偏好设置（user://qi_prefs.cfg，ConfigFile 原生件；即时生效自动保存）。
## 音频项＝battle_sfx 战斗音效总开关（2026-10-29）；显示项＝fullscreen/resolution/resizable
## （2026-10-29 仿 STS2 显示设置制：canvas_items＋Aspect=Keep 等比缩放、全屏走 WindowSetMode、
## 分辨率＝窗口尺寸 16:9 档、窗口可调 flag；宽高比四档不采纳——我方像素预算仅按 1920×1080 调校）。
## 设置弹窗（弹窗固定尺寸制：设置 520×430；内容超长走 ScrollContainer）＝备战舱/战斗屏顶栏共用。
extends RefCounted

const QIDIALOG := preload("res://qiforge/QiDialog.gd")
const QISTYLE := preload("res://qiforge/QiStyle.gd")

const PATH := "user://qi_prefs.cfg"
const INK := Color("5a452c")   # 浅色弹窗皮上的深墨字（默认主题浅白字压浅皮不可读）
## 分辨率档＝窗口尺寸 16:9 白名单（STS2 制按屏滤除放不下的档）
const RESOLUTIONS: Array = [Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440)]

static var _cache: Dictionary = {}

static func battle_sfx() -> bool:
	if not _cache.has("battle_sfx"):
		var cf := ConfigFile.new()
		_cache["battle_sfx"] = cf.load(PATH) == OK \
			and bool(cf.get_value("audio", "battle_sfx", false))
	return bool(_cache["battle_sfx"])

static func set_battle_sfx(on: bool) -> void:
	_cache["battle_sfx"] = on
	_save("audio", "battle_sfx", on)

static func fullscreen() -> bool:
	return _bool("display", "fullscreen", false)

static func set_fullscreen(on: bool) -> void:
	_cache["display.fullscreen"] = on
	_save("display", "fullscreen", on)

static func resolution() -> Vector2i:
	if not _cache.has("display.resolution"):
		var cf := ConfigFile.new()
		var txt := "1920,1080"
		if cf.load(PATH) == OK:
			txt = String(cf.get_value("display", "resolution", "1920,1080"))
		var parts := txt.split(",")
		if parts.size() == 2 and int(parts[0]) > 0 and int(parts[1]) > 0:
			_cache["display.resolution"] = Vector2i(int(parts[0]), int(parts[1]))
		else:
			_cache["display.resolution"] = Vector2i(1920, 1080)
	return _cache["display.resolution"]

static func set_resolution(v: Vector2i) -> void:
	_cache["display.resolution"] = v
	_save("display", "resolution", "%d,%d" % [v.x, v.y])

static func resizable() -> bool:
	return _bool("display", "resizable", true)

static func set_resizable(on: bool) -> void:
	_cache["display.resizable"] = on
	_save("display", "resizable", on)

static func _bool(section: String, key: String, default: bool) -> bool:
	var ck := "%s.%s" % [section, key]
	if not _cache.has(ck):
		var cf := ConfigFile.new()
		_cache[ck] = cf.load(PATH) == OK and bool(cf.get_value(section, key, default))
	return bool(_cache[ck])

static func _save(section: String, key: String, value: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)   # 无档容错＝新建
	cf.set_value(section, key, value)
	cf.save(PATH)

## 显示设置落地（STS2 NGame.ApplyDisplaySettings 同制，单屏开发档）：
## 全屏＝WindowSetMode(Fullscreen)；窗口＝按 resolution 档 WindowSetSize（超屏裁剪）＋
## 可调 flag（unresizable 反相）；无头探针环境不动窗口。
static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win: Window = (Engine.get_main_loop() as SceneTree).root
	if fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	win.unresizable = not resizable()
	var scr := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var sz := resolution()
	sz = Vector2i(mini(sz.x, scr.x), mini(sz.y, scr.y))
	DisplayServer.window_set_size(sz)
	DisplayServer.window_set_position(
		DisplayServer.screen_get_position(DisplayServer.window_get_current_screen()) + (scr - sz) / 2)

## 设置弹窗：点选即存（无需确认键）；「关闭」/ESC/点背板皆收。
## 开关一律深面钮（apply_primary）非原生 CheckBox——弹窗皮为浅色九宫格，
## 默认主题浅白字压上去不可读（2026-10-29 像素实测对比≈1.1:1）。
static func open_settings(parent: Control) -> void:
	var arr := QIDIALOG.create(parent, "设置", Vector2(520, 430), "关闭", "", true, true)
	if arr[1] == null:
		return
	var box: Control = arr[1]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.content().add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	var sfx := _toggle_btn("战斗音效")
	sfx.button_pressed = battle_sfx()
	_refresh_toggle(sfx)
	sfx.toggled.connect(func(_on: bool) -> void:
		set_battle_sfx(_on)
		_refresh_toggle(sfx))
	col.add_child(sfx)
	var hint := Label.new()
	hint.text = "打击 / 选牌 / 吸附提示音总开关。\n现用音效为占位素材（音色偏硬），后续更换素材后可再开。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(400, 0)
	QISTYLE.font(hint, QISTYLE.FS_SMALL)
	hint.add_theme_color_override("font_color", INK)
	col.add_child(hint)

	col.add_child(_section_sep("显示"))
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 12)
	var res_lbl := Label.new()
	res_lbl.text = "分辨率"
	res_lbl.custom_minimum_size = Vector2(96, 0)
	QISTYLE.font(res_lbl, QISTYLE.FS_BODY)
	res_lbl.add_theme_color_override("font_color", INK)
	res_row.add_child(res_lbl)
	var res_opt := OptionButton.new()
	res_opt.custom_minimum_size = Vector2(224, 44)
	QISTYLE.apply_primary(res_opt)
	QISTYLE.font(res_opt, 19)
	res_opt.add_theme_color_override("font_color", Color("ffe9b0"))
	var cur_res := resolution()
	var pick := 0
	for i in RESOLUTIONS.size():
		var r: Vector2i = RESOLUTIONS[i]
		res_opt.add_item("%d × %d" % [r.x, r.y], i)
		if r == cur_res:
			pick = i
	res_opt.select(pick)
	res_opt.disabled = fullscreen()   # 全屏下窗口档位不适用（STS2 制）
	res_opt.item_selected.connect(func(i: int) -> void:
		set_resolution(RESOLUTIONS[i])
		apply_display())
	res_row.add_child(res_opt)
	col.add_child(res_row)

	var fs := _toggle_btn("全屏")
	fs.button_pressed = fullscreen()
	_refresh_toggle(fs)
	fs.toggled.connect(func(on: bool) -> void:
		set_fullscreen(on)
		apply_display()
		res_opt.disabled = on
		_refresh_toggle(fs))
	col.add_child(fs)
	var rz := _toggle_btn("窗口可调")
	rz.button_pressed = resizable()
	_refresh_toggle(rz)
	rz.toggled.connect(func(_on: bool) -> void:
		set_resizable(_on)
		apply_display()
		_refresh_toggle(rz))
	col.add_child(rz)
	var dhint := Label.new()
	dhint.text = "全屏＝独占整屏；分辨率＝窗口尺寸档（窗口模式下生效）。\n窗口任意拉大时画面等比缩放（16:9 保比、余边留黑）。"
	dhint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dhint.custom_minimum_size = Vector2(400, 0)
	QISTYLE.font(dhint, QISTYLE.FS_SMALL)
	dhint.add_theme_color_override("font_color", INK)
	col.add_child(dhint)
	box.popup_centered(Vector2i(520, 430))

## 深面开关钮（toggle 制；label 前缀＋「开/关」后缀随态刷）
static func _toggle_btn(label: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(340, 52)
	b.set_meta("label", label)
	QISTYLE.apply_primary(b)
	QISTYLE.font(b, 21, true)
	b.add_theme_color_override("font_color", Color("ffe9b0"))
	return b

static func _refresh_toggle(b: Button) -> void:
	b.text = "%s：%s" % [String(b.get_meta("label")), "开" if b.button_pressed else "关"]

## 分区分隔（浅皮上小节标题＋横线）
static func _section_sep(title: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var t := Label.new()
	t.text = title
	QISTYLE.font(t, QISTYLE.FS_BODY, true)
	t.add_theme_color_override("font_color", INK)
	v.add_child(t)
	var line := ColorRect.new()
	line.color = Color(0.35, 0.28, 0.18, 0.45)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	return v
