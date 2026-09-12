class_name CardPicker
extends Control

# 通用选卡弹层：open(title, entries) 展开卡网格，点卡回传 value 并关闭。
# entries: [{card: Control, value: Variant}]；关闭按钮/点暗处收起不选。

signal picked(value)


func _ready() -> void:
	($Dim as ColorRect).gui_input.connect(_on_dim_input)
	($Center/Panel/Margin/VBox/CloseButton as Button).pressed.connect(close)
	visible = false


func open(title: String, entries: Array) -> void:
	($Center/Panel/Margin/VBox/TitleLabel as Label).text = title
	var grid: GridContainer = $Center/Panel/Margin/VBox/Scroll/Grid
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for entry in entries:
		var card: Control = entry["card"]
		card.set_meta("pick_value", entry["value"])
		card.gui_input.connect(_on_card_input.bind(card))
		grid.add_child(card)
	visible = true


func close() -> void:
	visible = false


func _on_card_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var value = card.get_meta("pick_value", null)
		close()
		picked.emit(value)


func _on_dim_input(_event: InputEvent) -> void:
	close()
