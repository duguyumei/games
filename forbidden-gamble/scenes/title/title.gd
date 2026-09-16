extends Control

# 主菜单：演武场（主线入口）＋ 图鉴（只读数据浏览）＋ 退出。
# 2026-09-12 定案：暂弃搜打撤（远征/据点/备战链路已随远征层删除，历史在 git 基线）。

func _ready() -> void:
	# 开始挑战：小丑牌式组挑战（选卡组→3 战循环→结算/修习）
	($Center/VBox/ChallengeButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.DECK_SELECT))
	# 演武场：直接进战斗沙盒（新功法/词条的试玩入口）
	($Center/VBox/DojoButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.DOJO))
	($Center/VBox/CodexButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.CODEX))
	($Center/VBox/QuitButton as Button).pressed.connect(func(): get_tree().quit())
	await PreviewCapture.maybe_capture(self)
