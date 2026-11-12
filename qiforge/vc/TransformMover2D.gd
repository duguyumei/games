## 原版 TransformMover2D 1:1（Nosebleed.Util/TransformMover2D.cs，595 行）。
## 用途：卡牌「速度＋减速带」寻的移动（CardView.MoveTo / hover 移动驱动；DrawPile→Hand 微滑同源）。
## 方法集对齐原版 10 法（Awake/Update/OnReachedDestination/ResetOnComplete/ForceStopMove/
## SetTargetTransform/SetTargetPosition/SetSpeed/SetDecelerateDistance/TeleportToTargetPosition）。
## 引擎映射：MonoBehaviour.enabled ⇔ set_process（闲置停更新）；挂在卡根下的子节点写父 CanvasItem
## 变换（Unity 多组件同物体 → Godot 子节点组件制）；Vector3 ⇔ Vector2。
## Update 体在原版为大坏点（:206-448），骨架（距离²<0.001 到达／速度×deltaTime／减速带渐减步进）
## 按 ISIL 可读段与我方 _seek_2d 实装等价式落码——出处注记见各步。
extends Node

signal ReachedTargetPosition          # m_ReachedTargetPosition（TransformMover2D.cs:22）
signal TargetChanged                  # m_TargetChanged（:24）

var _useLocalPosition := false        # :10
var _targetPosition := Vector2.ZERO   # :12
var _targetTransform: CanvasItem = null   # :14
var _currentSpeed := 0.007812502      # :16（初速实测）
var _currentDecelerateDistance := 0.0     # :18
var _hasReachedTarget := false        # :20
var _host: CanvasItem = null          # 引擎映射：本组件写宿主（父节点）变换

func _init() -> void:
	set_process(false)

func _ready() -> void:                # 引擎映射：Awake（:201）enabled=false → 闲置停更新
	_host = get_parent() as CanvasItem
	set_process(false)

## TargetPosition（:26）——优先取目标 Transform 位置
func _target_pos() -> Vector2:
	if _targetTransform != null and is_instance_valid(_targetTransform):
		return _targetTransform.position
	return _targetPosition

## CurrentPosition（:56）——按 useLocalPosition 切换 local/global
func _current_pos() -> Vector2:
	if _host == null:
		return Vector2.ZERO
	if _useLocalPosition:
		return _host.position
	return _host.global_position

func _set_current_pos(pos: Vector2) -> void:
	if _host == null:
		return
	if _useLocalPosition:
		_host.position = pos
	else:
		_host.global_position = pos

func _process(delta: float) -> void:  # Update（:206）
	if _host == null:
		return
	var target := _target_pos()
	var cur := _current_pos()
	var to := target - cur
	var dist_sq := to.length_squared()
	if dist_sq < 0.001:                # 到达阈值（距离²，:309）
		OnReachedDestination()
		return
	var dist := sqrt(dist_sq)
	var step := _currentSpeed * delta  # 速度×Time.deltaTime（:332）
	if _currentDecelerateDistance > 0.0 and dist <= _currentDecelerateDistance:
		step *= dist / _currentDecelerateDistance   # 减速带内按距离比例刹车（:325/:363-375 语义）
	if step >= dist:
		OnReachedDestination()
		return
	_set_current_pos(cur + to / dist * step)   # 归一化方向×步进（:389-394）

## OnReachedDestination（:450）——到位：置位＋广播＋对齐目标＋停更新＋清目标引用
func OnReachedDestination() -> void:
	_hasReachedTarget = true
	ReachedTargetPosition.emit()
	_set_current_pos(_target_pos())
	set_process(false)
	_targetTransform = null

## ResetOnComplete（:494）——原版体：仅当 ReachedTargetPosition 有订阅时触发 TargetChanged
## （Cpp2IL 可读段；语义待 ISIL 复核——行为无害，照搬）
func ResetOnComplete() -> void:
	if ReachedTargetPosition.get_connections().size() > 0:
		TargetChanged.emit()

## ForceStopMove（:512）
func ForceStopMove() -> void:
	_hasReachedTarget = true
	set_process(false)
	_targetTransform = null
	TargetChanged.emit()

## SetTargetTransform（:537）——链式
func SetTargetTransform(target_transform: CanvasItem) -> Node:
	_hasReachedTarget = false
	set_process(true)
	_targetTransform = target_transform
	return self

## SetTargetPosition（:549）
func SetTargetPosition(target_position: Vector2) -> Node:
	_hasReachedTarget = false
	set_process(true)
	_targetPosition = target_position
	return self

## SetSpeed（:557）
func SetSpeed(speed: float) -> Node:
	_currentSpeed = speed
	return self

## SetDecelerateDistance（:563）
func SetDecelerateDistance(decelerate_distance: float) -> Node:
	_currentDecelerateDistance = decelerate_distance
	return self

## TeleportToTargetPosition（:569）——瞬移到目标并立即到达
func TeleportToTargetPosition() -> void:
	_set_current_pos(_target_pos())
	OnReachedDestination()
