## 原版 CardPileView 1:1（Nosebleed.Pancake.View/CardPileView.cs，1829 行）——抽象牌堆视图基类。
## 方法集对齐（Awake/OnEnable/OnDisable 生命周期段并入 Godot 映射；GameModel 事件订阅段
## 由子类 setup 注入替代——引擎映射登记）。调试字符串族（FormatCardView 等）略（登记）。
extends "res://qiforge/vc/View.gd"

signal PileChanged                          # PileChanged（CardPileView.cs:255）
signal CardAdded(card_view)                 # CardAdded（:305）
signal CardRemoved(card_view)               # CardRemoved（:373）

const MIN_CARD_WAIT := 1.0 / 30.0           # MIN_CARD_WAIT（:222）

var _pile_root: Control = null              # _pileRoot（:224）
var _card_views: Array = []                 # _cardViews（:226）
var _card_pile_model = null                 # _cardPileModel（:228）→ battle（牌堆数组代理）
var _runner = null                          # 引擎映射：CommandRunner 单例 → 注入共享实例
var _player_model = null                    # 注入：battle

## PileCount（:236）
func PileCount() -> int:
	return _card_views.size()

## Cards（:251）
func Cards() -> Array:
	return _card_views

## PileRoot（:253）
func PileRoot() -> Control:
	if _pile_root != null:
		return _pile_root
	return self

## OnCardAdded（:512）——加牌入口：teleport→TeleportCardToPileView；队列→EnqueueCommand；否则直跑
func OnCardAdded(player_model, card: Dictionary, use_command_queue: bool,
		teleport_to_position := false, view_speed_multiplier := 1.0) -> void:
	if teleport_to_position:
		TeleportCardToPileView(player_model, card)
		return
	var cmd := CardAddedViewCommand.bind(player_model, card, view_speed_multiplier)
	if use_command_queue and _runner != null:
		_runner.EnqueueCommand(cmd)
	else:
		cmd.call()

## OnCardRemoved（:559）
func OnCardRemoved(player_model, card: Dictionary, use_command_queue: bool) -> void:
	var cmd := CardRemovedViewCommand.bind(player_model, card)
	if use_command_queue and _runner != null:
		_runner.EnqueueCommand(cmd)
	else:
		cmd.call()

## OnCardPlayed（:587，虚空）
func OnCardPlayed(_card: Dictionary) -> void:
	pass

## TryAddCard（:591）——查重＋入列表＋广播
func TryAddCard(card_view) -> bool:
	if ContainsCard(card_view):
		return false
	_card_views.push_back(card_view)
	PileChanged.emit()
	CardAdded.emit(card_view)
	return true

## TryInsertCard（:733）——按位插入
func TryInsertCard(card_view, index: int) -> bool:
	if ContainsCard(card_view):
		return false
	_card_views.insert(clampi(index, 0, _card_views.size()), card_view)
	PileChanged.emit()
	CardAdded.emit(card_view)
	return true

## TryRemoveCard（:1091）
func TryRemoveCard(card_view) -> bool:
	if not _card_views.has(card_view):
		return false
	_card_views.erase(card_view)
	PileChanged.emit()
	CardRemoved.emit(card_view)
	return true

## ClearPile（:1121）
func ClearPile() -> void:
	_card_views.clear()
	PileChanged.emit()

## ContainsCard（:1138）
func ContainsCard(card_view) -> bool:
	return _card_views.has(card_view)

## TeleportCardToPileView（:1219，虚）——基类仅 TryAddCard
func TeleportCardToPileView(_player_model, card: Dictionary) -> void:
	var view = _view_of(card)
	if view != null:
		TryAddCard(view)

## CardAddedViewCommand（:1224，虚协程）——等 !HasAnimationInterrupts 后 TryAddCard
func CardAddedViewCommand(player_model, card: Dictionary, _view_speed_multiplier := 1.0) -> void:
	var view = _view_of(card)
	if view == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	while view.HasAnimationInterrupts() and tree != null:
		await tree.process_frame
	TryAddCard(view)

## CardRemovedViewCommand（:1233）——一帧后 CardRemovedViewUpdate
func CardRemovedViewCommand(_player_model, card: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
	CardRemovedViewUpdate(card)

## CardRemovedViewUpdate（:1242，虚）
func CardRemovedViewUpdate(card: Dictionary) -> void:
	var view = _view_of(card)
	if view != null:
		TryRemoveCard(view)

## SyncView（:1247）——模型→视图全量重建（对账）
func SyncView() -> void:
	super()
	ClearPile()
	for card in _pile_cards():
		var view = _view_of(card)
		if view != null:
			TryAddCard(view)

# ── 注入桥（引擎映射：原版场景序列化引用/事件订阅 → setup 注入）─────────

func setup_basics(player_model, runner, pile_root: Control) -> void:
	_player_model = player_model
	_runner = runner
	_pile_root = pile_root

## 牌堆模型数组（子类给：battle.hand / battle.discard_pile / …）
func _pile_cards() -> Array:
	return []

## 卡字典→视图（子类经 uid 视图表查）
func _view_of(_card: Dictionary):
	return null
