extends Control

# 主菜单（v1 试玩期）：演武场 ＋ 退出。
# 探索入口（继续远征/新的远征）已按用户决定移除——远征/据点链路随内容阶段再上架，
# 其场景与系统仍由测试与冒烟覆盖，非死代码。

func _ready() -> void:
	# 演武场：直接进战斗沙盒（新功法/词条的试玩入口，不带远征上下文）
	($Center/VBox/DojoButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.DOJO))
	($Center/VBox/QuitButton as Button).pressed.connect(func(): get_tree().quit())
	await PreviewCapture.maybe_capture(self)
