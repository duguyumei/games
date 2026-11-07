@tool
extends Control
# CardLab＝TCG 卡预览台：卡面 → SubViewport（2×）→ 纹理 → 单应倾斜＋金属光效着色器
# 鼠标跟随倾斜；悬停放大只动显示层，不改布局尺寸
const CARD := preload("res://qiforge/QiCardStyle.gd")
const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QIFONTS := preload("res://qiforge/QiFontBank.gd")
const SHADER := preload("res://sandbox/card_tilt_glint.gdshader")

const SS := 2.0                 # 超采样倍数（文字清晰度）
const HOVER_SCALE := 1.50       # 悬停放大（只动显示层，底部锚点向上长）
const TILT_MAX := 0.50          # 倾斜最大量（喂给着色器的 tip）
const MARGIN := 1.18            # 显示矩形外扩（防倾斜切断）
const SMOOTH := 12.0            # 跟手平滑

var _vp: SubViewport
var _tex: TextureRect
var _mat: ShaderMaterial
var _card_size := Vector2.ZERO
var _tip := Vector2(0.25, -0.18)
var _tip_tgt := Vector2.ZERO
var _light := Vector2(0.5, 0.35)
var _phase := 0.0
var _t := 0.0
var _hover := false
var _scale_cur := 1.0

func _ready() -> void:
	QISTYLE.apply_root_theme(self)
	for c in get_children():
		c.free()
	_card_size = CARD.size_of("detail")

	_vp = SubViewport.new()
	_vp.size = Vector2i(roundi(_card_size.x * SS), roundi(_card_size.y * SS))
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.disable_3d = true
	add_child(_vp)

	var def: Dictionary = {
		"name": "撩",
		"qi": 2,
		"gain": "撩",
		"need": ["劈", "刺"],
		"type_line": "剑式 · 攻",
		"rules": "造成 10 点伤害，目标优先为预攻击敌人。",
		"flavor": "剑走轻灵，一撩即回。",
		"tone": "blue",
	}
	var card: Control = CARD.make_tcg_card(def, "detail")
	card.theme = QIFONTS.default_theme()   # SubViewport 内不吃根窗主题，单独挂
	card.scale = Vector2(SS, SS)
	card.position = Vector2.ZERO
	_vp.add_child(card)

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("strength", 0.09)
	_mat.set_shader_parameter("uv_scale", MARGIN)
	_mat.set_shader_parameter("glint_strength", 1.0)

	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.size = _card_size * MARGIN
	_tex.pivot_offset = Vector2(_card_size.x * MARGIN * 0.5, _card_size.y * MARGIN)
	_tex.material = _mat
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_tex)
	_layout()
	if "--shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.cardlab_shot.png")
		get_tree().quit()

func _layout() -> void:
	var c := get_viewport_rect().size * 0.5 if not Engine.is_editor_hint() else size * 0.5
	_tex.position = c - _card_size * MARGIN * 0.5

func _process(delta: float) -> void:
	_t += delta
	var demo: bool = "--tilt-demo" in OS.get_cmdline_user_args()
	var center := _tex.position + _card_size * MARGIN * 0.5
	var m: Vector2 = get_global_mouse_position()
	var half := _card_size * 0.5
	var n := Vector2((m.x - center.x) / half.x, (m.y - center.y) / half.y)
	var inside: bool = absf(n.x) < 1.0 and absf(n.y) < 1.0
	if demo:
		inside = true
		n = Vector2(0.6, -0.35)
	_hover = inside
	# 负号：鼠标指着的那侧向内凹（远离观者）
	_tip_tgt = -Vector2(clampf(n.x, -1.0, 1.0), clampf(n.y, -1.0, 1.0)) * TILT_MAX if inside else Vector2(0.0, 0.0)
	_tip = _tip.lerp(_tip_tgt, clampf(delta * SMOOTH, 0.0, 1.0))
	# 待机光泽带慢扫 / 悬停改由着色器按「近侧边框」出光
	var ph: float = fmod(_t * 0.12, 1.4) - 0.2
	_phase = lerpf(_phase, ph, clampf(delta * 6.0, 0.0, 1.0))
	var target_scale: float = HOVER_SCALE if inside else 1.0
	_scale_cur = lerpf(_scale_cur, target_scale, clampf(delta * 10.0, 0.0, 1.0))
	_tex.scale = Vector2(_scale_cur, _scale_cur)

	_mat.set_shader_parameter("tip_x", _tip.x)
	_mat.set_shader_parameter("tip_y", _tip.y)
	_mat.set_shader_parameter("sheen_phase", _phase)
	_mat.set_shader_parameter("hover", 1.0 if inside else 0.0)
