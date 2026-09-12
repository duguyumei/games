class_name BattleSequencer
extends Node

# 敌方连动演出编排（M7c 节奏版收编）：一个动作结算一拍，令牌防重入——
# 玩家在演出间隙再出手/弃战/重开会开启新链，旧链自动退场。
# 单步内容（结算+drain+重画+飘字）由场景根注入 on_step；收链与终局经信号上抛。
# 链内最后一次刷新发生在 busy=true 时（按钮隐藏）——收链后必须重画一次，
# 否则按钮行一直消失到玩家下一次交互（试玩踩中，回归见 m7c 预览）。

signal chain_finished  # 敌方链收尾且未终局——场景根重画（按钮恢复）
signal battle_ended    # 终局停拍完成——场景根弹结算浮层

const ENEMY_STEP_SEC := 0.6  # 每个敌方动作间停一拍
const END_BEAT_SEC := 0.8    # 终局后再停一拍让最后一击看得清

var busy := false

var pace_getter: Callable  # () -> float，演出速度档
var on_step: Callable      # () -> void，单个敌方动作的结算与呈现

var _token := 0

# 杀掉进行中的链（弃战/重开时调用），busy 立即复位。
func interrupt() -> void:
	_token += 1
	busy = false

func play(tm: TurnManager, combat: CombatState) -> void:
	_token += 1
	var token := _token
	busy = true
	var safety := 20
	while not tm.is_over() and combat.active_side == "enemy" and safety > 0:
		safety -= 1
		on_step.call()
		await get_tree().create_timer(ENEMY_STEP_SEC * pace_getter.call()).timeout
		if token != _token:
			return
	busy = false
	if tm.is_over():
		# 终局停一拍：让最后一击的血条/飘字先被看清，再上结算浮层。
		await get_tree().create_timer(END_BEAT_SEC * pace_getter.call()).timeout
		if token == _token:
			battle_ended.emit()
	else:
		chain_finished.emit()
