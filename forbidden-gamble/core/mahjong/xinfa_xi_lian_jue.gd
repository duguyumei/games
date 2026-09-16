class_name MJXinfaXiLianJue
extends MJXinfa

# 洗练诀（挑战层新心法·心法槽，占位）：打出为普攻（kind=normal）时，
# 下次摸牌 +1（draw_bonus_next 瞬态——正常/破绽拍摸牌消费即清，缺牌补充不吃）。


func _init() -> void:
	id = "xi_lian_jue"
	display_name = "洗练诀"


func summary() -> String:
	return "洗练诀（普攻打出后，下次摸牌 +1）"


func on_posture_played(f: MJFighter, kind: String) -> void:
	if kind == "normal":
		f.draw_bonus_next = 1
