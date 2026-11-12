## 原版 DiscardPileView 1:1（Nosebleed.Pancake.View/DiscardPileView.cs）——弃牌飞行。
## 数值＝discardCardConfig 真值（GlobalConfig.asset:202-211）：postDiscardWait 0.15／
## rotate 0.2s delay 0.02 → 55°／scale 0.1s delay 0.05 → 0.2／move 250 decel 0.5。
## 【对账项登记】原版命令等飞行 mover 到达（MoveToCardPile→OnCardReachedPile→SetActive(false)）
## ＋多卡 speedMultiplier（cardDiscardLogBase 1000 对数钟，代数坏点）；我方先行＝飞行
## fire-and-forget（视觉与现行 F6 已批手感一致：错峰起步、并行飞行），命令长度＝postWait
## 节拍，到达回调隐藏。ISIL 复核后切「await 到达」制。
## 弃堆无独立容器视觉（登记）：飞行目标＝屏弃堆锚（hooks.get_discard_center 注入）。
extends "res://qiforge/vc/CardPileView.gd"

const VC := preload("res://qiforge/vc/VcConfig.gd")

var _hand_pile_view = null                 # 注入：手牌视图（视图表/_pile_root 复用）
var _get_discard_center: Callable = Callable()

func setup(player_model, runner, hand_pile_view, get_discard_center: Callable) -> void:
	setup_basics(player_model, runner, hand_pile_view.PileRoot())
	_hand_pile_view = hand_pile_view
	_get_discard_center = get_discard_center

func _pile_cards() -> Array:
	if _player_model == null:
		return []
	return _player_model.discard_pile

func _view_of(card: Dictionary):
	return _hand_pile_view._view_of(card)

## CardAddedViewCommand（DiscardPileView.cs:272）——弃牌命令体：
## 离手视图更新（槽释放）→ 飞行（rotate/scale tween＋mover 寻的）→ postWait 节拍 → 入表
func CardAddedViewCommand(player_model, card: Dictionary, view_speed_multiplier := 1.0) -> void:
	var view = _view_of(card)
	if view == null or not is_instance_valid(view):
		return
	_hand_pile_view.CardRemovedViewUpdate(card)   # 槽释放＋离手广播（原版由 HandPile 侧先走）
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	# 等 !HasAnimationInterrupts（:40-51 同构）：飞行等动画打断清空（一帧粒度）
	while view.HasAnimationInterrupts():
		await tree.process_frame
	# 飞行三件（discardCardConfig）：rotateTo 55°（0.2s delay 0.02）＋scaleTo 0.2（0.1s delay
	# 0.05）＋mover 寻的（250/0.5）——fire-and-forget，到达回调隐藏（对账项见类头）
	var root: Control = _hand_pile_view.PileRoot()
	var target_global: Vector2 = _get_discard_center.call()
	var inv := root.get_global_transform_with_canvas().affine_inverse()
	var half_shell: Vector2 = Vector2(VC.CARD_SIZE.x, VC.CARD_SIZE.y + VC.HAND_TOP_PAD) * 0.5
	var target_local: Vector2 = inv * target_global - half_shell
	view.z_index = 5
	view.KillPileTween()   # 池腾换防打架
	var tw: Tween = view.create_tween()
	view.set_meta("pile_tween", tw)
	tw.tween_interval(VC.DISCARD_CARD["rotateDelay"])
	tw.tween_property(view._tween_container, "rotation",
		deg_to_rad(VC.DISCARD_CARD["rotateTo"].x), VC.DISCARD_CARD["rotateDuration"])
	tw.parallel().tween_interval(VC.DISCARD_CARD["scaleDelay"] - VC.DISCARD_CARD["rotateDelay"])
	tw.parallel().tween_property(view._tween_container, "scale",
		VC.DISCARD_CARD["scaleTo"], VC.DISCARD_CARD["scaleDuration"])
	var dist: float = (target_local - view.position).length()
	var speed: float = VC.DISCARD_CARD["moveSpeed"] * maxf(1.0, view_speed_multiplier)
	var fly_time: float = dist / maxf(1.0, speed)
	tw.parallel().tween_property(view, "position", target_local, fly_time)\
		.set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(view, "modulate:a", 0.0,
		maxf(0.05, fly_time - 0.06)).set_delay(0.06)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(view):
			view.visible = false          # OnCardReachedPile：SetActive(false)（:320-332）
			view.modulate.a = 1.0
			view._tween_container.scale = Vector2.ONE
			view._tween_container.rotation = 0.0)
	# postWait 节拍（:126-144）：>MIN_CARD_WAIT 才等；speedMultiplier 加速
	var post: float = VC.DISCARD_CARD["postDiscardWait"] / maxf(1.0, view_speed_multiplier)
	if post > MIN_CARD_WAIT:
		await tree.create_timer(post, false).timeout
	TryAddCard(view)

## OnCardRemoved（回抽：弃堆卡洗回抽堆）——视图已隐藏，仅出表
func CardRemovedViewUpdate(card: Dictionary) -> void:
	var view = _view_of(card)
	if view != null:
		TryRemoveCard(view)
