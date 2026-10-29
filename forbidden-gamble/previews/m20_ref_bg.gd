@tool
extends TextureRect

## 参考底图：编辑器 2D 画布垫底摆 HUD 用，运行时不出现。
## 存档常丢 visible=false 的老毛病（AGENTS §5 复检项），2026-09-21 第三次复发且形态最迷惑：
## 用户 F6 一直看到垫底位图（位图锯齿≠实时渲染），渲染配置三轮调整全部"无变化"实为被位图遮蔽。
## 固化：运行态无条件隐藏——存档丢不丢 false 均不影响运行画面。
func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
