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
	# 逐卡流水节拍（d__146 timePerCard＝Log(N,1000)/N，屏按批注入同值——串行队列逐卡睡出
	# i×timePerCard 错峰；2026-11-13 补搬：旧版同帧齐发＝一坨漂移，原版机关枪节奏读感利索）
	var stg := float(card.get("disc_stagger", 0.0))
	if stg > 0.0:
		await tree.create_timer(stg, false).timeout
	# 等 !HasAnimationInterrupts（:40-51 同构）：飞行等动画打断清空（一帧粒度）
	while view.HasAnimationInterrupts():
		await tree.process_frame
	# 飞行三件（discardCardConfig 双层制）：rotateTo 55°＋scaleTo 0.2（视觉层＝tween）
	# ＋位置传输（mover 层＝TransformMover2D 寻的＋到达事件隐藏）
	var root: Control = _hand_pile_view.PileRoot()
	var target_global: Vector2 = _get_discard_center.call()
	var inv := root.get_global_transform_with_canvas().affine_inverse()
	var half_shell: Vector2 = Vector2(VC.CARD_SIZE.x, VC.CARD_SIZE.y + VC.HAND_TOP_PAD) * 0.5
	var target_local: Vector2 = inv * target_global - half_shell
	view.z_index = 5
	view.KillPileTween()   # 池腾换防打架
	view.RegisterAnimationInterrupt(self)   # 原版 MoveToCardPile 起飞登记——下一条加牌命令等本卡飞完
	var dm := maxf(1.0, view_speed_multiplier)   # 三件套时长÷mult（ISIL MoveToCardPile divss）
	# ── 视觉层（DOTween 等效）：rotate＋scale ──
	var tw: Tween = view.create_tween()
	view.set_meta("pile_tween", tw)
	tw.tween_interval(VC.DISCARD_CARD["rotateDelay"])
	tw.tween_property(view._tween_container, "rotation",
		deg_to_rad(VC.DISCARD_CARD["rotateTo"].x),
		VC.DISCARD_CARD["rotateDuration"] / dm)
	tw.parallel().tween_interval(VC.DISCARD_CARD["scaleDelay"] - VC.DISCARD_CARD["rotateDelay"])
	tw.parallel().tween_property(view._tween_container, "scale",
		VC.DISCARD_CARD["scaleTo"], VC.DISCARD_CARD["scaleDuration"] / dm)
	# ── 位置层（mover 寻的＋到达事件）──
	var dist: float = (target_local - view.position).length()
	view._transform_mover._useLocalPosition = true
	# 飞行时长默认 0.08s（原版实测 65-110ms）；已打出区冲弃由屏按卡注入 2×（0.16s，
	# 2026-11-19 用户令「速度慢点，变成2倍」——右上→弃堆那段单独慢，手牌弃牌不动）
	var fly_dur: float = float(card.get("disc_flight_dur", VC.DISCARD_FLIGHT_DUR))
	view._transform_mover.SetSpeed(maxf(dist / maxf(0.001, fly_dur), 50.0))
	view._transform_mover.SetDecelerateDistance(
		VC.DISCARD_CARD["decelerateDistance"] / dm)
	view.MoveTo(target_local, func() -> void:
		# 观测：飞行区间收口（已打出区冲弃时由屏注入 flight_end；其他路径无此键＝no-op）
		var end_cb: Callable = card.get("flight_end", Callable())
		if end_cb.is_valid():
			end_cb.call()
		if is_instance_valid(view):
			view.DeregisterAnimationInterrupt(self)
			view.visible = false          # OnCardReachedPile：SetActive(false)（:320-332）
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

## TeleportCardToPileView（CardPileView.OnCardAdded 的 teleport 分支）——离手＋瞬隐＋入表。
## 〔2026-11-19 勘误：原版 teleport:true 仅读档落牌（LoadSaveData csall:544）消费；终局手牌
## 与已打出区都走弃牌飞行（d__280:251 isGameOver=false；DiscardComboPile→OnRemovedFromComboPile
## csall:1843 teleport:false）。11-13「终局瞬隐」系新手前几关无连击堆出牌即收的误判。〕
func TeleportCardToPileView(player_model, card: Dictionary) -> void:
	_hand_pile_view.CardRemovedViewUpdate(card)
	var view = _view_of(card)
	if view != null:
		# 传送落点＝弃堆中心（原版 :265 AddCardToPile 挂堆根＋position＝堆位再隐藏——
		# 2026-11-14 胜利收尾洗回案：瞬隐牌停在堆位，随后洗牌飞行从堆位起飞）
		var root: Control = _hand_pile_view.PileRoot()
		var inv := root.get_global_transform_with_canvas().affine_inverse()
		var half_shell: Vector2 = Vector2(VC.CARD_SIZE.x, VC.CARD_SIZE.y + VC.HAND_TOP_PAD) * 0.5
		view.position = inv * _get_discard_center.call() - half_shell
		view.visible = false
		view.DeregisterAnimationInterrupt(self)
		TryAddCard(view)
