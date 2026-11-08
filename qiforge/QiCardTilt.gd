## 卡面斜切视图公共件（2026-11-08 从 QiVcScreen._make_tilt_view 抽出）
## 卡渲进 SubViewport → 贴图挂单应透视 shader，鼠标位置喂 tip_x/tip_y 即"卡随指针倾斜"。
## 返回的 TextureRect 只负责显示（mouse_filter＝IGNORE），事件交给外层壳。
extends RefCounted

const CARD := preload("res://qiforge/QiCardStyle.gd")
const QIFONTS := preload("res://qiforge/QiFontBank.gd")
const TILT_SHADER := preload("res://qiforge/assets/card_tilt_glint.gdshader")
const SS := 2.0          # 超采样倍数

static func make(def: Dictionary, ctx: String, w: float, h: float) -> TextureRect:
	var vp := SubViewport.new()
	vp.size = Vector2i(roundi(w * SS), roundi(h * SS))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X
	var card: Control = CARD.make_tcg_card(def, ctx)
	card.theme = QIFONTS.default_theme()
	card.scale = Vector2(SS, SS)
	vp.add_child(card)
	var mat := ShaderMaterial.new()
	mat.shader = TILT_SHADER
	mat.set_shader_parameter("strength", 0.09)
	mat.set_shader_parameter("uv_scale", 1.18)
	var tex := TextureRect.new()
	tex.name = "TiltView"
	tex.add_child(vp)
	tex.texture = vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.size = Vector2(w, h) * 1.18
	tex.material = mat
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex.set_meta("vc_card", card)
	tex.set_meta("tip", Vector2.ZERO)
	return tex

## 按鼠标位置推进倾斜（与手牌同一套：归一化 ×-0.5，带平滑）
static func drive(tex: TextureRect, mouse: Vector2, delta: float) -> void:
	if not is_instance_valid(tex):
		return
	var mat := tex.material as ShaderMaterial
	if mat == null:
		return
	var r: Rect2 = tex.get_global_rect()
	var ctr: Vector2 = r.position + r.size * 0.5
	var half: Vector2 = r.size / (2.0 * 1.18)
	var nv := Vector2((mouse.x - ctr.x) / maxf(1.0, half.x), (mouse.y - ctr.y) / maxf(1.0, half.y))
	var inside: bool = absf(nv.x) < 1.0 and absf(nv.y) < 1.0
	var tgt := Vector2.ZERO
	if inside:
		tgt = -nv * 0.5
	var k: float = clampf(delta * 9.0, 0.0, 1.0)
	var tip: Vector2 = (tex.get_meta("tip", Vector2.ZERO) as Vector2).lerp(tgt, k)
	tex.set_meta("tip", tip)
	mat.set_shader_parameter("tip_x", tip.x)
	mat.set_shader_parameter("tip_y", tip.y)

## 卡面四角（屏幕坐标，含斜切位移）——浮窗按它贴边/跟随，和手牌同一套算法
static func corners(tex: TextureRect, w: float, h: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not is_instance_valid(tex):
		return out
	var face := Rect2((tex.size.x - w) * 0.5, (tex.size.y - h) * 0.5, w, h)
	var xf := tex.get_global_transform_with_canvas()
	var q := [
		xf * face.position,
		xf * Vector2(face.end.x, face.position.y),
		xf * face.end,
		xf * Vector2(face.position.x, face.end.y)]
	var tip: Vector2 = tex.get_meta("tip", Vector2.ZERO)
	var sc3: float = xf.get_scale().x
	var dux := (0.5 / (1.0 - 0.09 * tip.x) - 0.5) / 1.18
	var duy := (0.5 / (1.0 - 0.09 * tip.y) - 0.5) / 1.18
	var dx := dux * w * sc3
	var dy := duy * h * sc3
	q[1] += Vector2(dx, dy)
	q[2] += Vector2(dx, -dy)
	q[3] += Vector2(-dx, -dy)
	q[0] += Vector2(-dx, dy)
	for v in q:
		out.push_back(v)
	return out
