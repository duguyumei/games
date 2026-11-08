shader_type canvas_item;

// 单应透视倾斜 + 边缘反光
// 悬停时不再在鼠标处打光斑，而是照亮「靠近观者的那一侧」边框（rim light）
uniform float tip_x : hint_range(-1.0, 1.0) = 0.0;
uniform float tip_y : hint_range(-1.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 0.5) = 0.09;
uniform float uv_scale = 1.18;
uniform float sheen_phase = 0.4;
uniform float glint_strength : hint_range(0.0, 2.0) = 1.0;
uniform float hover : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 base = (UV - vec2(0.5)) * uv_scale + vec2(0.5);
	vec2 p = base - vec2(0.5);
	float denom = 1.0 + tip_x * strength * p.x * 2.0 + tip_y * strength * p.y * 2.0;
	vec2 t = p / denom + vec2(0.5);
	if (t.x < 0.0 || t.x > 1.0 || t.y < 0.0 || t.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 tex = texture(TEXTURE, t);
		float metal = clamp(max(tex.r, max(tex.g, tex.b)) * 1.15 - 0.35, 0.0, 1.0) * step(0.35, tex.a);
		float edge = min(min(t.x, 1.0 - t.x), min(t.y, 1.0 - t.y));
		// 待机：内部一条缓慢扫过的光泽带（外框不上光，避免描边感）
		float axis = (t.x * 0.71 + t.y) * 0.7071;
		float band = smoothstep(0.07, 0.0, abs(axis - sheen_phase));   // 收窄：原 0.16 太宽，整条边一直亮
		// 整卡扫光（2026-11-08）：与金件光带同相位，光从整张卡上掠过，不再只是边上一圈
		float sweep = 0.0;   // 卡面扫光撤除（2026-11-08 用户：动画太突兀，卡面保持干净）
		vec3 col_sweep = tex.rgb + vec3(1.0, 0.96, 0.86) * sweep * tex.a;
		float amt_idle = 0.0;
		// 悬停：靠近观者那一侧的边框反光（tip 指向鼠标侧＝远侧，故取反方向）
		// tip＝鼠标反方向＝靠近观者那一侧；用它定反光方向（之前取反了，亮在了远侧）
		vec2 near_dir = normalize(vec2(tip_x, tip_y) + vec2(0.0001, 0.0001));
		float along = dot(t - vec2(0.5), near_dir) + 0.5;
		float rim = smoothstep(0.72, 0.98, along) * smoothstep(0.16, 0.02, edge);
		float amt_hover = rim * 0.42 * metal;
		float amt = amt_hover * hover * glint_strength;   // 只保留悬停时的近侧反光
		amt = clamp(amt, 0.0, 0.35);   // 限幅：防过曝发白
		// 金属受光＝金色更亮（暖金），不是盖一层白
		vec3 warm = vec3(1.0, 0.80, 0.36);
		vec3 col = col_sweep + warm * amt + tex.rgb * amt * 0.35;
		COLOR = vec4(col, tex.a);
	}
}
