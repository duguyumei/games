## 真气拦截器的固定配置。
##
## 与 ActionInterceptorData 的区别在于定位方式：那套用「发起者 / 承受者」两个位置
## 表达效果归属，适合攻击这类一定打在某人身上的动作。真气运转、抽气、回血这类
## 动作作用于自己，没有承受者，「敌方运转时反震」无处可挂。
##
## 因此这套改为按动作类型注册，并在注册记录上带 owner。判断一个拦截器是否生效
## 只需比较 owner 与动作发起者，见 QiInterceptorResolver。
extends SerializableData
class_name QiInterceptorData

## 拦截时机。
enum PHASES {
	BEFORE,  ## 动作执行前；可以改参数，也可以拒绝动作
	AFTER,   ## 动作执行后；只能读结果与追加效果，拒绝无意义
}

## 拦截器脚本路径；必须是 BaseQiInterceptor 的子类。
@export var qi_interceptor_script_path: String = ""

## 被本拦截器拦截的动作脚本路径白名单。
## 与 action.get_script().resource_path 精确比对，因此要用 Scripts 里的路径常量。
@export var qi_intercepted_action_paths: Array[String] = []

## 本拦截器关心谁发起的动作。
## false（默认）—— 关心自己发起，例如「我运转时气力 +2」。
## true —— 关心对方发起，例如「敌方运转时反震 3 点」。
@export var qi_interceptor_watches_opponent: bool = false

## 本拦截器在动作执行前还是执行后生效。
## BEFORE（默认）—— 例如「运转时气力 +2」，可以改目标牌区或拒绝运转。
## AFTER —— 例如「运转后气力 -1」，此时运转已发生，能读到真气的实际落点。
@export var qi_interceptor_phase: int = PHASES.BEFORE

## 处理顺序，数值高者先执行；敌我拦截器在同一个列表里排序，因此优先级跨阵营有效。
## 前后两个阶段各自成链、各自排序，互不影响。
## 用 1000 这类宽间距数值，便于以后在中间插入新的。
@export var qi_interceptor_priority: int = 0
