class_name XinfaCard
extends Panel

# 内功卡（图鉴/演武场用）：名称＋阶别条＋描述。setup 可在入树前调用。

func setup(xinfa_name: String, tier: int, school: String, desc: String) -> void:
	($Margin/VBox/NameLabel as Label).text = xinfa_name
	($Margin/VBox/TierLabel as Label).text = "%s · %d 阶" % [school, tier]
	($Margin/VBox/DescLabel as Label).text = desc
