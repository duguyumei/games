extends SceneTree
func _init() -> void:
	var I = preload("res://qiforge/QiVcIcons.gd")
	var t: Texture2D = I.silhouette(Color("a87f7f"))
	var img: Image = t.get_image()
	img.save_png("/tmp/sil_check.png")
	print("size=", img.get_size(), " used=", img.get_used_rect())
	var t2: Texture2D = I.icon("might")
	var i2: Image = t2.get_image()
	i2.save_png("/tmp/might_check.png")
	print("might size=", i2.get_size(), " used=", i2.get_used_rect())
	quit()
