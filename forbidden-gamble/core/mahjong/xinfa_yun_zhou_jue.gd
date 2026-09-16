class_name MJXinfaYunZhouJue
extends MJXinfa

# 运筹诀（挑战层新心法·心法槽，占位）：每次招架（碰/杠/吃）罡气 +1
# ——与拆招诀同型异酬（拆招诀给变招充能、运筹诀给罡气——防御经济两条进料口）。


func _init() -> void:
	id = "yun_zhou_jue"
	display_name = "运筹诀"


func summary() -> String:
	return "运筹诀（每次招架 +1 罡气）"


func on_claim_done(f: MJFighter) -> void:
	f.add_gang_qi(1)
