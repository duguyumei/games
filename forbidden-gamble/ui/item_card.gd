class_name ItemCard
extends Panel

# 装备卡（图鉴用）：名称＋稀有度色条＋主属性行＋描述。setup 可在入树前调用。

const RARITY_COLORS := {
	"common": Color(0.45, 0.42, 0.38),
	"fine": Color(0.2, 0.45, 0.3),
	"rare": Color(0.2, 0.35, 0.6),
	"legend": Color(0.7, 0.5, 0.15),
}


func setup(item_name: String, rarity: String, stat_line: String, desc: String) -> void:
	($Margin/VBox/NameLabel as Label).text = item_name
	($Margin/VBox/StatLabel as Label).text = stat_line
	($Margin/VBox/DescLabel as Label).text = desc
	var style := (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	style.border_color = RARITY_COLORS.get(rarity, style.border_color)
	add_theme_stylebox_override("panel", style)
