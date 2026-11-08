shader_type canvas_item;

// 金件光泽带：挂在金框/分割线面板上，只给不透明笔画加一道斜向扫光
// band_pos＝对角相位（TcgCard._process 驱动：待机慢扫 / 悬停跟手）
// 底色＝TEXTURE×COLOR：StyleBoxFlat 平涂时 TEXTURE 为白→取 COLOR；
// StyleBoxTexture（分割线）时 TEXTURE 为贴图——两态都正。
uniform float band_pos = 0.2;
uniform float strength : hint_range(0.0, 2.0) = 0.7;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float axis = (UV.x * 0.71 + UV.y) * 0.7071;
	float d = (axis - band_pos) * 5.5;
	float band = exp(-d * d);
	float amt = clamp(band * strength, 0.0, 0.45);   // 限幅：防 R/G 顶到 255 变“发白”
	vec3 col = base.rgb + vec3(1.0, 0.93, 0.75) * amt * step(0.35, base.a);
	COLOR = vec4(col, base.a);
}
