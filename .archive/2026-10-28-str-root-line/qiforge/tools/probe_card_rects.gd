## 一次性矩形探针：无头构建工厂卡，量各分区实际尺寸＋悬停浮层开关
extends SceneTree

var _frames: int = 0
var _card: Button = null

func _initialize() -> void:
	change_scene_to_file("res://scenes/Root.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		var style: GDScript = load("res://qiforge/QiCardStyle.gd")
		_card = style.make_xinfa_card(
			{"id": "run_start_option_qif_C", "name": "C 包·真气引擎", "desc": "身法每累计消耗 2 点能量，获得随机真气"},
			1, "改为获得一层伤害增幅（伤害 +3%）", "改为获得 10% 轻灵真气量的催破真气")
		root.add_child(_card)
		return false
	if _frames == 45:
		print("rect: card size=", _card.size)
		for child in _card.get_children():
			var overlay_note: String = ""
			if child is Panel and not child.visible:
				overlay_note = " (overlay hidden)"
			print("rect: ", child.name, " pos=", child.position, " size=", child.size, overlay_note)
		_card.mouse_entered.emit()
		var overlay: Control = null
		for child in _card.get_children():
			if child is Panel and child.position.y >= 30.0 and abs(child.size.y - 163.0) < 8.0:
				overlay = child
		print("rect: overlay_visible_after_hover=", overlay.visible if overlay != null else "not_found",
			" size=", overlay.size if overlay != null else Vector2.ZERO)
		var spell: Button = (load("res://qiforge/QiCardStyle.gd") as GDScript).make_spell_card(
			"术法一", 3, "获得 5 点随机类型真气", "最低类型真气额外 +5")
		root.add_child(spell)
		spell.global_position = Vector2(400, 100)
		return false
	if _frames == 60:
		for child in root.get_children():
			if child is Button and child.position.x > 300.0:
				print("rect: spell card size=", child.size)
				for sub in child.get_children():
					print("rect:  ", sub.name, " pos=", sub.position, " size=", sub.size)
		quit()
		return true
	return false
