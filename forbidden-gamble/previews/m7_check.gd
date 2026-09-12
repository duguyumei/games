extends Node
# M7a 场景树校验：内功胶囊内容、EmptyHint 状态、EndOverlay 初始隐藏

func _ready() -> void:
	var main: Control = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	for side in ["PlayerPanel", "EnemyPanel"]:
		var panel: Control = main.get_node("Center/Column/Stage/" + side)
		var col: Control = panel.get_node("InternalColumn")
		var texts: Array[String] = []
		for child in col.get_children():
			if child is Label:
				texts.append(child.text)
			elif child is Panel:
				var label: Label = child.get_node_or_null("Label")
				if label == null:
					for sub in child.get_children():
						if sub is Label:
							label = sub
							break
				if label != null:
					texts.append(label.text)
		print("%s InternalColumn visible=%s chips=%s" % [side, col.visible, texts])

	var empty_hint: Label = main.get_node("Center/Column/Stage/PlayerPanel/IntentEmpty/EmptyHint")
	print("EmptyHint text='%s' visible=%s rect=%s" % [empty_hint.text, empty_hint.visible, empty_hint.get_global_rect()])
	var intent_demo: Control = main.get_node("Center/Column/Stage/EnemyPanel/IntentDemo")
	print("EnemyIntentDemo visible=%s name_label='%s'" % [intent_demo.visible, intent_demo.get_node("NameStrip/IntentName").text])
	print("EndOverlay visible=%s（结算浮层，初始应隐藏）" % main.get_node("EndOverlay").visible)
	print("TopBar context='%s' turn='%s' log='%s'" % [
		main.get_node("Center/Column/TopBar/Bar/ContextLabel").text,
		main.get_node("Center/Column/TopBar/Bar/TurnLabel").text,
		main.get_node("Center/Column/TopBar/Bar/LogLine").text])
	get_tree().quit()
