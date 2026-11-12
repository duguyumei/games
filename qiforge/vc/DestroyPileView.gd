## 原版 DestroyPileView 1:1（Nosebleed.Pancake.View/DestroyPileView.cs）——碎牌/消耗堆。
## 数值＝destroyableCardConfig（GlobalConfig.asset:212-222）：postDestroyWait 0.015／
## scale 0.05s delay 0.05 → 1.3（溶解前胀闪）／dissolveTime 0.5。
## 碎裂视觉暂用我方碎块制（16 碎块＋白闪，F6 已批——登记；溶解 shader 后续轮接）。
## 战后消耗/shattered 卡永久移除＝视图池化等战斗重开统一回收。
extends "res://qiforge/vc/CardPileView.gd"

const VC := preload("res://qiforge/vc/VcConfig.gd")

var _hand_pile_view = null

func setup(player_model, runner, hand_pile_view) -> void:
	setup_basics(player_model, runner, hand_pile_view.PileRoot())
	_hand_pile_view = hand_pile_view

func _pile_cards() -> Array:
	if _player_model == null:
		return []
	return _player_model.exhaust_pile

func _view_of(card: Dictionary):
	return _hand_pile_view._view_of(card)

## CardAddedViewCommand（DestroyPileView.cs:162）——消耗命令体：postWait → 溶解（胀闪
## scaleTo 1.3→碎牌 FX→隐藏）；view.DestroyCard 广播＝原版 BurnCard 入口（:269）
func CardAddedViewCommand(player_model, card: Dictionary, view_speed_multiplier := 1.0) -> void:
	var view = _view_of(card)
	if view == null or not is_instance_valid(view):
		return
	_hand_pile_view.CardRemovedViewUpdate(card)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var post: float = VC.DESTROYABLE_CARD["postDestroyWait"] / maxf(1.0, view_speed_multiplier)
	if post > 0.0:
		await tree.create_timer(post, false).timeout
	if not is_instance_valid(view):
		return
	view.z_index = 5
	view.KillPileTween()   # 池腾换防打架
	# 溶解前胀闪（scaleDuration 0.05 delay 0.05 → 1.3）
	var tw: Tween = view.create_tween()
	view.set_meta("pile_tween", tw)
	tw.tween_interval(VC.DESTROYABLE_CARD["scaleDelay"])
	tw.tween_property(view._tween_container, "scale",
		VC.DESTROYABLE_CARD["scaleTo"], VC.DESTROYABLE_CARD["scaleDuration"])
	# 碎牌 FX（我方碎块制挂口——屏侧 signal 接管视觉）＋溶解时长后隐藏回池
	view.DestroyCard(view_speed_multiplier)          # CardDestroyed 广播（:269 BurnCard 链头）
	_hand_pile_view.card_destroy_fx.emit(card)
	await tree.create_timer(VC.DESTROYABLE_CARD["dissolveTime"], false).timeout
	if is_instance_valid(view):
		view.visible = false
		view.modulate.a = 1.0
		view._tween_container.scale = Vector2.ONE
		view._tween_container.rotation = 0.0
	TryAddCard(view)
