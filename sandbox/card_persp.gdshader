shader_type canvas_item;

// 内外晃＝真透视（单应变换）：卡是刚性平面，只有近大远小，不会弯曲
// 之前版本的线性近似会把卡内部拉扯不匀（看着像卡形变了），已弃
// tip_x/tip_y：-1..1，脚本每帧喂；strength＝幅度总闸
uniform float tip_x : hint_range(-1.0, 1.0) = 0.0;
uniform float tip_y : hint_range(-1.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 0.5) = 0.08;

void fragment() {
	vec2 p = UV - vec2(0.5);
	// 分母＝离屏深度：鼠标按住的那边分母大＝远＝小，对边近＝大
	float denom = 1.0 + tip_x * strength * p.x * 2.0 + tip_y * strength * p.y * 2.0;
	vec2 t = p / denom + vec2(0.5);
	if (t.x < 0.0 || t.x > 1.0 || t.y < 0.0 || t.y > 1.0) {
		COLOR = vec4(0.0); // 翻过去露出的角透背景
	} else {
		COLOR = texture(TEXTURE, t);
	}
}
