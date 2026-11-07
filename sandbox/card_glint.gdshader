shader_type canvas_item;

// 壳层光效：鼠标热点高光 + 45° 光泽带（待机慢扫，悬停跟手）
// base_tint 承接原 self_modulate 的褪色古铜（0.85, 0.845, 0.83）
uniform vec4 base_tint : source_color = vec4(0.85, 0.845, 0.83, 1.0);
uniform vec2 light_pos = vec2(0.5, 0.35);   // 光源（卡面 UV，脚本每帧喂）
uniform float sheen_phase = 0.4;            // 光泽带对角相位（脚本喂：待机慢扫/悬停跟手）
uniform float glint_strength : hint_range(0.0, 2.0) = 1.0; // 光效总强度

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float metal = max(tex.r, max(tex.g, tex.b));  // 金框亮度＝金属遮罩：暗缝不上光
	// 鼠标热点（x 轴按卡宽高比校正，光斑才是圆的）
	vec2 d = UV - light_pos;
	d.x *= 0.71;
	float spot = exp(-dot(d, d) * 24.0);
	// 45° 光泽带（phase 扫过整条对角线）
	float axis = (UV.x * 0.71 + UV.y) * 0.7071;
	float band = smoothstep(0.14, 0.0, abs(axis - sheen_phase));
	float amt = (spot * 0.9 + band * 0.3) * glint_strength;
	vec3 col = tex.rgb * base_tint.rgb + vec3(1.0, 0.965, 0.87) * amt * metal;
	COLOR = vec4(col, tex.a * base_tint.a);
}
