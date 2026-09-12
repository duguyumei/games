extends Node2D
# 镶孔方向对比：右侧竖排 vs 顶部横排（4 槽拱形 + 5 槽顺子）

const CARD_SCENE := "res://ui/technique_card.tscn"
const GROUP_SCENE := "res://ui/qi_slot_group.tscn"

var _configs: Array = [
	{"label": "右侧 · 4槽拱形", "x": 90.0, "orient": 0, "count": 4, "layout": 1},
	{"label": "右侧 · 5槽顺子", "x": 330.0, "orient": 0, "count": 5, "layout": 2},
	{"label": "顶部 · 4槽拱形", "x": 660.0, "orient": 1, "count": 4, "layout": 1},
	{"label": "顶部 · 5槽顺子", "x": 900.0, "orient": 1, "count": 5, "layout": 2},
]

func _ready() -> void:
	get_viewport().get_window().size = Vector2i(1280, 720)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.17, 0.19)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var card_packed: PackedScene = load(CARD_SCENE)
	var group_packed: PackedScene = load(GROUP_SCENE)
	for cfg in _configs:
		var card: Control = card_packed.instantiate()
		card.position = Vector2(float(cfg["x"]), 220.0)
		add_child(card)
		var group: Control = group_packed.instantiate()
		group.set("orientation", int(cfg["orient"]))
		group.set("slot_count", int(cfg["count"]))
		group.set("slot_layout", int(cfg["layout"]))
		group.set("demo_filled", 1)
		card.add_child(group)
		var label := Label.new()
		label.text = str(cfg["label"])
		label.position = Vector2(float(cfg["x"]), 460.0)
		label.size = Vector2(200, 24)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		add_child(label)
	await get_tree().create_timer(1.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://previews/slot_orient.png")
	print("预览图已保存：res://previews/slot_orient.png")
	get_tree().quit()
