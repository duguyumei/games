class_name PreviewCapture

# 简单预览截图助手：命令行带 --shot 时等待若干秒后截图退出（title/stronghold 共用；
# board 因有 --shot-drawer/--shot-container 等专项模式，保留自己的截图块）。

static func maybe_capture(node: Node, wait_sec := 1.5, out_path := "user://board_shot.png") -> bool:
	if not OS.get_cmdline_user_args().has("--shot"):
		return false
	await node.get_tree().create_timer(wait_sec).timeout
	var image := node.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(out_path)
	node.get_tree().quit()
	return true
