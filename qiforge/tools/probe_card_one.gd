## 单卡预览：把指定卡用工厂建成 detail 档，居中截图（看卡面现状用）
extends SceneTree
const CARD := preload("res://qiforge/QiCardStyle.gd")
const VC := preload("res://qiforge/QiVcData.gd")
const QIFONTS := preload("res://qiforge/QiFontBank.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var id := "feixing_shu"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("card="):
			id = a.substr(5)
	var rootc := Control.new()
	rootc.size = Vector2(1920, 1080)
	root.add_child(rootc)
	var bg := ColorRect.new(); bg.color = Color(0.92,0.90,0.86); bg.size = Vector2(1920,1080)
	rootc.add_child(bg)
	var def: Dictionary = CARD.tcg_def_of(VC.CARDS[id])
	var card: Control = CARD.make_tcg_card(def, "detail")
	card.theme = QIFONTS.default_theme()
	card.position = Vector2(960 - 135, 540 - 190)
	rootc.add_child(card)
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/sandbox/card_one.png")
	print("SAVED ", id)
	quit()
