shader_type canvas_item;

uniform float shear_x = 0.0;  // 斜切量（脚本每帧喂进来）

void vertex() {
	VERTEX.x += (VERTEX.y - 211.0) * shear_x;  // 以卡水平中线为轴：上半左移、下半右移 → 竖边倾斜
}
