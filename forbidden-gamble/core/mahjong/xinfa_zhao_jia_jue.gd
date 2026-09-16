class_name MJXinfaZhaoJiaJue
extends MJXinfa

# 拆招诀（v3.5 基础心法·心法槽，占位）：每次招架（碰/杠/吃）额外 +1 变招充能。
# 变招充能的进料口：基础按拍（每自身拍＋(1＋气力)，v3.6，招架拍同）、心法从招架加（每次 +1）。


func _init() -> void:
	id = "zhao_jia_jue"
	display_name = "拆招诀"


func summary() -> String:
	return "拆招诀（每次招架 +1 变招充能）"


func on_claim_done(f: MJFighter) -> void:
	f.add_bian_charge(1)
