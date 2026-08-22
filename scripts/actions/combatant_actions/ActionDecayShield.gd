## 在明确的回合结束行为中衰减双方来源护盾；真气连击不会调用此动作。
extends BaseAction

func perform_action() -> void:
	if Global.battle_qi_state != null:
		Global.battle_qi_state.decay_shields_at_round_end()

func is_instant_action() -> bool:
	return true
