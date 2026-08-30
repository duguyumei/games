## 真气拦截器基类。
##
## 在真气动作执行前或执行后被调用，由配置的 qi_interceptor_phase 决定。
## BEFORE 阶段可以修改动作参数、生成额外效果动作，或直接拒绝动作。
## AFTER 阶段动作已经执行完，只能读取结果与追加效果 —— 此时返回 REJECTED 无意义，
## 会被当作 STOPPED 处理。
##
## 改后的参数存在 QiInterceptorResolver 上，不写回动作本身。
##
## 纯函数式：每次拦截都会 load().new() 新建实例，因此**不要给拦截器挂任何属性**，
## 属性存不住。所有状态从 resolver 或来源实例读取。
##
## preview_mode 为 true 时禁止产生副作用（不改实例、不发信号、不衰减层数），
## 也永远不该返回 REJECTED —— 否则界面预览的数值会与实际打出的不一致。
## 有副作用的实现应在方法开头直接 return CONTINUE。
##
## 与旧 BaseActionInterceptor 的已知差异：本体系不支持 forced_interceptor_ids
## （未注册也强制生效）。真气效果一律通过注册表生效，没有强制注入的场景。
extends Resource
class_name BaseQiInterceptor

## 放行状态码。决定拦截链是否继续，以及动作本身是否执行。
enum ACCEPTANCES {
	CONTINUE,  ## 继续处理这个动作上后续的拦截器
	STOPPED,   ## 执行动作，但不再处理后续拦截器
	REJECTED,  ## 拒绝动作，本次动作不执行
}


### 待重写
## 处理一次拦截，返回上面的放行状态码。
func process_qi_interception(
		_resolver: QiInterceptorResolver,
		_preview_mode: bool = false) -> int:
	return ACCEPTANCES.CONTINUE
