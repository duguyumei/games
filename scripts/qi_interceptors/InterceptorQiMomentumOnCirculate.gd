## 运转时给该真气施加气力变化。
##
## 数值不写在脚本里，而是从注册这个拦截器的内功配置读取，键为 momentum_amount。
## 因此「运转时气力 +1」与「运转时气力 +2」共用本脚本，只是内功数据不同。
##
## 通过内功配置的 watches_opponent 还能表达「敌方运转时」—— 同一脚本亦可复用，
## 因为阵营判定发生在查找阶段，脚本本身不关心是谁在运转。
extends BaseQiInterceptor


## 内功配置里读取气力增减量的键名。
const VALUE_MOMENTUM_AMOUNT: String = "momentum_amount"


func process_qi_interception(
		resolver: QiInterceptorResolver,
		preview_mode: bool = false) -> int:
	# 施加状态会修改本局真气实例，属于副作用，预览时必须跳过。
	if preview_mode:
		return ACCEPTANCES.CONTINUE

	var source_instance: Variant = resolver.get_source_instance()
	if not source_instance is NeigongData:
		return ACCEPTANCES.CONTINUE
	var neigong_data: NeigongData = source_instance

	var momentum_amount: int = int(
		neigong_data.neigong_interceptor_values.get(VALUE_MOMENTUM_AMOUNT, 0))
	if momentum_amount == 0:
		return ACCEPTANCES.CONTINUE

	# 从动作参数取出本次运转的真气；运转动作以 UID 传递。
	var battle_state: BattleQiState = Global.battle_qi_state
	if battle_state == null:
		return ACCEPTANCES.CONTINUE
	var qi_uid: String = str(resolver.get_shadowed_value("qi_uid", ""))
	if qi_uid.is_empty():
		return ACCEPTANCES.CONTINUE
	var qi: QiData = battle_state.find_qi(qi_uid)
	if qi == null:
		return ACCEPTANCES.CONTINUE

	var source_context: Dictionary[String, Variant] = resolver.get_source_context()
	qi.add_state(QiStateEntry.momentum(
		momentum_amount, source_context.get("source_instance_id", "")))

	return ACCEPTANCES.CONTINUE
