## 原版 HandPileView 1:1（Nosebleed.Pancake.View/HandPileView.cs，1564 行）＋
## PlayerModel.GetOrCreateCard/ReturnCardToPool 视图半边（PlayerModel.cs:7537/12161——
## 模型半边留 battle，视图半边归本件，引擎映射登记）。
## 本件＝手牌根节点：锚底中＋37px、960×182、scale 1.14（SC_Game.unity:789268-789292 实测）。
## 卡视图终身制：uid→视图绑定＝卡模型生命周期（原版 CardModel._cardView 同GO 终身）；
## 离手不销毁——弃/耗到达即隐藏（ReturnCardViewToHand 池化复用，原版 :466-471）。
extends "res://qiforge/vc/CardPileView.gd"

signal card_hover_started(card: Dictionary)     # 引擎映射：InteractionStarted 转发（屏接预览）
signal card_hover_ended(card: Dictionary)
signal card_play_clicked(card: Dictionary)      # CardSelected 转发（屏接点击施放）
signal card_to_played(card: Dictionary)         # 打出→已打出区（ComboPile 对位，视觉暂用现制登记）
signal card_destroy_fx(card: Dictionary)        # DestroyPile 溶解前的碎牌 FX 挂口

const VC := preload("res://qiforge/vc/VcConfig.gd")
const CARD_VIEW := preload("res://qiforge/vc/CardView.gd")
const HAND_HOLDER := preload("res://qiforge/vc/HandCardSlotHolder.gd")

const HAND_SHELL_EXTRA := 80.0    # 壳加高盖住「原位＋弹起位」（我方自拟：命中区盖弹起上沿）

var _card_group: Control = null             # _cardGroup（HandPileView.cs:256）→ HandCardSlotHolder
var _pooled_slot_container: Control = null  # 池槽容器（CardSlotHolder._pooledCardSlotContainer）
var _uid_views := {}                        # uid → CardView（模型终身绑定——原版 CardModel._cardView）
var _card_pool: Array = []                  # PlayerModel._cardPool 视图半边（:6026）
var _hooks: Dictionary = {}                 # 屏注入（tip_avoid 等）
var _current_damage_detail := 0             # _currentDamageDetail（:254）——伤害详情刷新位
# [VCTRAJ] 临时轨迹追踪（验收完删）：uid → Array[Vector2]，每帧记录飞行中卡的位置
var _traj := {}                              # uid → PackedVector2Array
var _traj_clear_t := 0.0                     # 轨迹清空倒计时

func _init() -> void:
	# 子件在 _init 预建：宿主装配序＝setup() 先于 add_child（QiVcRoot:432-434 实测），
	# _ready 尚未跑而 setup() 要摸 _card_group——预建后两序皆稳
	_pile_root = self
	# 锚位口径（2026-11-12 场景链全通定案，真值档 §九）：HandPile 锚底中＋37（:789287）、
	# 父链全拉伸零偏移（:793852-855）→ **带底＝屏底上方 37px**；旧「18% 卡高≈57px」截图
	# 定标作废（疑量到弧上中卡，真值≈46px）。1.14 绕底中轴心生效（底缘不动）。
	var gap := VC.HAND_ROOT_ANCHORED_POS.y
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -VC.HAND_ROOT_SIZE.x * 0.5
	offset_right = VC.HAND_ROOT_SIZE.x * 0.5
	offset_top = -(gap + VC.HAND_ROOT_SIZE.y)
	offset_bottom = -gap
	scale = Vector2.ONE * VC.HAND_ROOT_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 槽容器＝原版 UsedCardSlots（带内再嵌层，非铺满带）：906×224.3、中心＝带顶下方 67.15、
	# 水平中心 449.59（SC_Game:771888-892 直译；间距/行宽按 906 算——真值档 §九）＋池槽容器
	_card_group = HAND_HOLDER.new()
	_card_group.name = "CardGroup"
	_card_group.size = VC.USED_SLOTS_SIZE
	_card_group.position = VC.USED_SLOTS_CENTER_IN_BAND - VC.USED_SLOTS_SIZE * 0.5
	add_child(_card_group)
	_pooled_slot_container = Control.new()
	_pooled_slot_container.name = "PooledSlots"
	_pooled_slot_container.visible = false
	add_child(_pooled_slot_container)
	_card_group._pooled_card_slot_container = _pooled_slot_container

## 手牌根几何：锚底中、960×182、scale 1.14（SC_Game.unity:789268-789292 直译；
## pivot (0.5,0)＝底中——1.14 绕底中轴心缩放，底缘离屏底距离不被缩放）
func _ready() -> void:
	super()
	pivot_offset = Vector2(size.x * 0.5, size.y)

## setup（引擎映射：场景序列化引用 → 注入；重绑守卫＝is_connected 防重开重复连接）
func setup(player_model, runner, hooks := {}) -> void:
	setup_basics(player_model, runner, self)
	_hooks = hooks
	_card_group.set_meta("player_model", player_model)
	_card_group.set_meta("interactable_of", Callable(self, "_interactable_of"))
	if not _card_group.CardSelectedEvent.is_connected(_on_card_selected):
		_card_group.CardSelectedEvent.connect(_on_card_selected)
	if not _card_group.InteractionStartedEvent.is_connected(_on_interaction_started):
		_card_group.InteractionStartedEvent.connect(_on_interaction_started)
	if not _card_group.InteractionEndedEvent.is_connected(_on_interaction_ended):
		_card_group.InteractionEndedEvent.connect(_on_interaction_ended)

# ── 视图池（PlayerModel.GetOrCreateCard 视图半边，:7537）────────────────

## GetOrCreateCardView（PlayerModel.GetOrCreateCard 对位：池 Pop→无则建；挂手牌根
## worldStays=false；OnSpawned 复位；SetCardConfig 绑定；uid 终身表登记）
func GetOrCreateCardView(card: Dictionary):
	var uid := int(card.get("uid", -1))
	if _uid_views.has(uid) and is_instance_valid(_uid_views[uid]):
		return _uid_views[uid]
	var view: Control = null
	if _card_pool.is_empty():
		view = CARD_VIEW.new()
		add_child(view)
	else:
		view = _card_pool.pop_back()
		if view.get_parent() != self:
			add_child(view)
		view.visible = true
	view.KillPileTween()                  # 池腾换：杀旧飞行 tween（弃/耗/出场未完即复用）
	view.set_meta("player_model", _player_model)
	view.set_meta("hand_uid", uid)
	view.set_meta("tip_avoid", _hooks.get("tip_avoid", []))
	view.OnSpawned()                       # 池复用复位（CardView.cs:3210）
	view.SetCardConfig(card, true)         # SetConfig（:7651）
	_uid_views[uid] = view
	return view

## ReturnCardViewToHand（:466）——视图回收：归父＋隐藏（不销毁）
func ReturnCardViewToHand(card_view) -> void:
	if card_view == null or not is_instance_valid(card_view):
		return
	card_view.SetTransformParent(_pile_root, true)
	card_view.visible = false
	_card_pool.push_back(card_view)

## 战斗重开复位（引擎映射：原版场景重载 → 手动池化全清；登记）
func ResetForNewBattle() -> void:
	for uid in _uid_views.keys():
		var v = _uid_views[uid]
		if is_instance_valid(v):
			v.visible = false
			_card_pool.push_back(v)
	_uid_views.clear()
	ClearPile()

# ── 加牌（抽牌命令体，HandPileView.CardAddedViewCommand :370 重载）─────

## CardAddedViewCommand（:370，d__12 ISIL 全文直读 2026-11-13）——抽牌可见动画＝
## **带底中心出生三件套＋短飞入槽**：alpha 0→DOFade **0.05s 平值**（0x502BC04 二进制
## 直读，不÷mult）＋rotateFrom 旋入（0.2÷mult）＋scale 0→1（0.2÷mult，ease 10）同步起，
## TransformMover2D 500×mult＋减速带 10÷mult 飞向槽位。出生点＝手牌根枢轴（GetOrCreateCard
## :10913-10923 仅 SetZ 不改 x/y＋d__12 worldStays:TRUE 保位）——单张瞬现居中、
## 大批＝不可见流光整批落左侧（2026-11-13 用户实测三证词定案）。
## 命令长度＝本批节拍（draw_stagger＝Log(N,1000)/N——原版精确代数坏点，v0.2 实装值）。
func CardAddedViewCommand(player_model, card: Dictionary, view_speed_multiplier := 1.0) -> void:
	var view = GetOrCreateCardView(card)
	if view == null:
		return
	# 槽位链接＋布局（锁定门内）
	_card_group.AddCardToBottom(card)
	var it = _interactable_of(card)
	var slot = it._current_card_slot if it != null else null
	var tgt := Vector2.ZERO
	if slot != null:
		tgt = (slot as Control).position + (slot as Control).size * 0.5 - VC.CARD_CENTER_IN_SHELL
	# 出生点＝直接落槽位（用户实测原版 2026-11-13：「手牌瞬间出现在左侧，没有看到
	# 抽牌的过程」——无可见飞行，卡原地冒出来＋手牌重排。此前「从手牌根飞过去」系
	# 我对 SetSpeed/mover 的过度解读——mover 管 UpdatePosition 槽位跟随，不管出场）
	var born := tgt
	# 再入场复位（弃/打出后抽回：交互恢复＋根姿态归零——出场态由 TweenContainer 承载）
	if it != null:
		it.EnableInteraction()
	view.rotation = 0.0
	view.scale = Vector2.ONE
	view.z_index = 10
	view.position = born
	view._tween_container.scale = Vector2.ZERO
	view._tween_container.rotation = deg_to_rad(-90.0)
	view.modulate.a = 0.0
	view.set_meta("fly_speed", true)   # 飞行标记（锁豁免/悬停门/落地检测）——不覆盖速度
	                                    # 2026-11-13 ISIL 铁案：UpdatePosition 直接写位置用
	                                    # min(1000, dist/dt)，不走 mover；mover 仅悬停层
	view.visible = true
	TryInsertCard(view, 0)
	view.OnCardAddedToHand(player_model)
	# [VCANIM] 临时埋点（验收完删）：抽牌时间线——出生位/目标位/层级序（scene＝树序，
	# Godot 命中走树序不走 z_index——重叠区谁吃事件由它决定）＋三件套完成时刻
	var t0 := Time.get_ticks_msec()
	view.set_meta("anim_t0", t0)
	print("[VCANIM] draw-in uid=%d t=%d start=(%.0f,%.0f) tgt=(%.0f,%.0f) z=%d scene=%d/%d lock=%s" % [
		int(card.get("uid", -1)), t0, born.x, born.y, tgt.x, tgt.y,
		view.z_index, view.get_index(), view.get_parent().get_child_count(),
		"1" if _card_group.AreCardPositionsLocked() else "0"])
	_stack_line("draw")
	# 出场三件套（fire-and-forget；淡入＋缩放 0→1＋旋入，时长÷mutl＝d__12 :167/:198-204；
	# ease 10 InOutCubic 实测）
	var dm := maxf(1.0, view_speed_multiplier)
	var tw: Tween = view.create_tween()
	view.set_meta("pile_tween", tw)
	tw.tween_property(view, "modulate:a", 1.0, 0.05)   # DOFade 0.05s 平值（0x502BC04 二进制直读，÷mult 无指令——不除）
	tw.parallel().tween_property(view._tween_container, "scale", Vector2.ONE,
		VC.DRAW_CARD["scaleDuration"] / dm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(view._tween_container, "rotation", 0.0,
		VC.DRAW_CARD["rotateDuration"] / dm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func() -> void:
		if is_instance_valid(view):
			print("[VCANIM] draw-3done uid=%d +%dms" % [int(card.get("uid", -1)),
				Time.get_ticks_msec() - t0]))   # [VCANIM] 临时（验收完删）
	# 命令长度＝本批节拍（连续流水：上一张刚起飞下一张接上）
	var stagger := float(card.get("draw_stagger", 0.0))
	if stagger > 0.0:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.create_timer(stagger, false).timeout

## TeleportCardToPileView（:332）——传送进手牌（遭遇载入路径）：挂根＋底加槽＋传送＋归一
func TeleportCardToPileView(player_model, card: Dictionary) -> void:
	var view = GetOrCreateCardView(card)
	if view == null:
		return
	_card_group.AddCardToBottom(card)
	view.visible = true
	TryInsertCard(view, 0)
	view.OnCardAddedToHand(player_model)
	var it = _interactable_of(card)
	var slot = it._current_card_slot if it != null else null
	if slot != null:
		view.position = (slot as Control).position + (slot as Control).size * 0.5 - VC.CARD_CENTER_IN_SHELL
	if it != null:
		it.EnableInteraction()
	view.rotation = 0.0
	view.scale = Vector2.ONE
	view.z_index = 10
	view._tween_container.scale = Vector2.ONE
	view._tween_container.rotation = 0.0
	view.modulate.a = 1.0

## OnCardAddedToHand(CardView)（:387）——激活＋插表
func OnCardAddedToHand(card_view) -> void:
	UnfreezeComboValueAll()
	card_view.visible = true
	TryInsertCard(card_view, 0)

func UnfreezeComboValueAll() -> void:
	pass   # UnfreezeComboValue（:349）——连击费制未搬（气费制登记），占位

# ── 移除（:379 CardRemovedViewUpdate）─────────────────────────────────

## CardRemovedViewUpdate（:379）——离手视图更新：广播离手＋槽移除＋视图出表
func CardRemovedViewUpdate(card: Dictionary) -> void:
	var view = _view_of(card)
	if view != null:
		view.OnRemovedFromHand()
	_card_group.TryRemoveCard(card)
	if view != null:
		TryRemoveCard(view)
		# 解槽＋关交互（引擎映射：弃/耗接管后 InteractableCard 停止跟随——原版
		# DisableInteractionAndUnlink 链）；打出时鼠标还指着＝先收悬停
		#（2026-11-12 日志实锤：打出后无 hover-out → sel 悬挂 7、预览不撤——EndInteraction 补链）
	var it = _interactable_of(card)
	if it != null:
		if it.IsHovering():
			it.EndInteraction()
		it.DisableInteractionAndUnlink()

## OnCardPlayed（:1110 三参重载——GDScript 无重载，基类单参虚法保留、本件三参版改名
## OnCardPlayedFull，引擎映射登记）：打出（去向＝已打出区）：离手＋刷新全手费用
func OnCardPlayedFull(player_model, card: Dictionary, _card_returns_to_hand: bool) -> void:
	CardRemovedViewUpdate(card)
	RefreshCardsUI(player_model)
	card_to_played.emit(card)

# ── 整手清空（回合末，:395-465）───────────────────────────────────────

## OnRemoveAll（:395）——入队 RemoveAllUpdate
func OnRemoveAll() -> void:
	if _runner != null:
		_runner.EnqueueCommand(RemoveAllUpdate.bind())

## RemoveAllUpdate（:448 协程）——ClearPile＋一帧
func RemoveAllUpdate() -> void:
	ClearPile()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame

## OnRemoveAllFinished（:415）——入队 RemoveAllFinished
func OnRemoveAllFinished() -> void:
	if _runner != null:
		_runner.EnqueueCommand(RemoveAllFinished.bind())

## RemoveAllFinished（:457 协程）——（原版 GameView 更新视图退订段，未搬＝空）
func RemoveAllFinished() -> void:
	pass

# ── 刷新（:1121-1378）────────────────────────────────────────────────

## RefreshCardsUI()（:1121）——无参重载
func RefreshCardsUIAll() -> void:
	RefreshCardsUI(_player_model)

## RefreshCardsUI(PlayerModel)（:1139）——逐卡刷费用＋刷面
func RefreshCardsUI(player_model) -> void:
	for card in _pile_cards():
		var view = _view_of(card)
		if view == null:
			continue
		view.UpdateCostText(player_model)
		view.RefreshView(player_model)

## UpdateDamageDetail（:314）——伤害详情变化→刷全手（占位：伤害预览走屏侧悬卡预览）
func UpdateDamageDetail(_val) -> void:
	RefreshCardsUIAll()

# ── SyncView（:473）——模型→视图对账（旧视图隐藏、模型卡补视图）──────────

func SyncView() -> void:
	var model_uids := {}
	for card in _pile_cards():
		model_uids[int(card.get("uid", -1))] = true
	# 模型里没有的旧视图 → 隐藏回池（不销毁）
	for uid in _uid_views.keys().duplicate():
		if not model_uids.has(uid):
			var v = _uid_views[uid]
			if is_instance_valid(v):
				v.visible = false
				v.OnRemovedFromHand()
			_uid_views.erase(uid)
	# 视图表全量重建
	ClearPile()
	for card in _pile_cards():
		var view = GetOrCreateCardView(card)
		if view != null:
			TryAddCard(view)

func _pile_cards() -> Array:
	if _player_model == null:
		return []
	return _player_model.hand

func _view_of(card: Dictionary):
	var v = _uid_views.get(int(card.get("uid", -1)), null)
	if v != null and is_instance_valid(v):
		return v
	return null

func _interactable_of(card: Dictionary):
	var view = _view_of(card)
	if view == null:
		return null
	for ch in view.get_children():
		if ch.name == "InteractableCard":
			return ch
	return null

# ── 悬停/点击接线（引擎映射：InteractableCard 事件 → 屏信号）──────────

func _on_card_selected(interactable) -> void:
	var uid := int(interactable._card_view.get_meta("hand_uid", -1))
	for card in _pile_cards():
		if int(card.get("uid", -1)) == uid:
			card_play_clicked.emit(card)
			return

func _on_interaction_started(interactable) -> void:
	var view = interactable._card_view
	var uid := int(view.get_meta("hand_uid", -1))
	# 选中序号→布局劈开（原版 OnCardInteractionStarted ISIL :7045-7730：置顶＋
	# FindAndSetCurrentSelected→set_SelectedIndex——**不碰计时器**；OnCardInteracted＝
	# 仅已锁时续锁，空手悬停劈开即时生效）
	_card_group.FindAndSetCurrentSelected(interactable)
	_card_group.TrySetLayoutGroupIndex(_card_group.CurrentSelectedCardIndex())
	_card_group.OnCardInteracted(null)
	_card_group.ForceLayoutRefresh()
	view.z_index = 60
	if view.get_parent() != null:
		view.get_parent().move_child(view, -1)   # SetAsLastSibling（ISIL CardSlotHolder:7667）——
		# Godot 命中序走树序不走 z_index（引擎事实）：置尾＝渲染+命中同时置顶，重叠区全归悬停卡
	print("[VCANIM] hover-in uid=%d scene=%d/%d z=%d t=%d" % [uid, view.get_index(),
		view.get_parent().get_child_count(), view.z_index, Time.get_ticks_msec()])   # [VCANIM] 临时（层级序验证）
	_stack_line("hover-in")
	view.GetCardTooltips(_player_model)
	view.ToggleTooltips(true)
	for card in _pile_cards():
		if int(card.get("uid", -1)) == uid:
			card_hover_started.emit(card)
			break

func _on_interaction_ended(interactable) -> void:
	var view = interactable._card_view
	var uid := int(view.get_meta("hand_uid", -1))
	_card_group.TrySetLayoutGroupIndex(-1)
	_card_group.ForceLayoutRefresh()
	view.z_index = 10
	_restore_view_order_to_slots()   # 悬停收尾层级复位（OnCardInteractionEnded :3723-3725 对位）
	print("[VCANIM] hover-out uid=%d scene=%d z=%d t=%d" % [uid, view.get_index(),
		view.z_index, Time.get_ticks_msec()])   # [VCANIM] 临时（验收完删）
	view.ToggleTooltips(false)
	for card in _pile_cards():
		if int(card.get("uid", -1)) == uid:
			card_hover_ended.emit(card)
			break

# ── 每帧（引擎映射：原版各组件自带 Update → 本件统一驱动悬停抬升寻的）────

func _process(delta: float) -> void:
	for view in _card_views:
		if not is_instance_valid(view):
			continue
		for ch in (view as Control).get_children():
			if ch.name == "InteractableCard":
				ch.HoverOffsetSeek(delta)
	# [VCTRAJ] 临时（验收完删）：飞行中卡每帧记录位置＋落地日志
	var any_flying := false
	for view in _card_views:
		if not is_instance_valid(view) or not (view as Control).visible:
			continue
		var v := view as Control
		if v.has_meta("fly_speed"):
			any_flying = true
			var uid := int(v.get_meta("hand_uid", -1))
			if uid >= 0:
				if not _traj.has(uid):
					_traj[uid] = PackedVector2Array()
				(_traj[uid] as PackedVector2Array).append(v.position)
	if any_flying:
		_traj_clear_t = 3.0
		queue_redraw()
	elif _traj_clear_t > 0.0:
		_traj_clear_t -= delta
		if _traj_clear_t <= 0.0:
			# 落定快照：全部轨迹＋最终位置打一行
			for uid in _traj:
				var pts: PackedVector2Array = _traj[uid]
				if pts.size() > 1:
					var dist := (pts[pts.size()-1] - pts[0]).length()
					var path_len := 0.0
					for i in range(1, pts.size()):
						path_len += (pts[i] - pts[i-1]).length()
					print("[VCTRAJ] uid=%d pts=%d start=(%.0f,%.0f) end=(%.0f,%.0f) straight=%.0f path=%.0f detour=%.0f" % [
						uid, pts.size(), pts[0].x, pts[0].y,
						pts[pts.size()-1].x, pts[pts.size()-1].y,
						dist, path_len, path_len - dist])
			_traj.clear()
			queue_redraw()

## [VCTRAJ] 临时（验收完删）：轨迹叠加层——飞行路径画彩色线
func _draw() -> void:
	var colors := [Color.RED, Color.CYAN, Color.YELLOW, Color.MAGENTA,
		Color.LIME, Color.ORANGE, Color.DEEP_PINK, Color.AQUA]
	var i := 0
	for uid in _traj:
		var pts: PackedVector2Array = _traj[uid]
		if pts.size() > 1:
			var col: Color = colors[i % colors.size()]
			col.a = 0.7
			draw_polyline(pts, col, 3.0)
			# 起点标记
			draw_circle(pts[0], 5.0, col)
			# 终点标记
			draw_circle(pts[pts.size()-1], 3.0, Color(col.r, col.g, col.b, 1.0))
		i += 1

## 悬停收尾视图层级复位（原版 OnCardInteractionEnded 尾段，CardSlotHolder.cs:3723-3738：
## view.SetSiblingIndex(槽序)＋SelectedIndex=-1）——悬停置顶只在悬停期间有效，松手回槽序；
## 我方视图与槽不同父，按槽序依次压顶等价实现（左在下右在上＝与抽牌后静置序一致，
## 2026-11-13 F6 图层漂移案补搬——此前只搬置顶没搬复位，扫牌一次洗一次叠压序）
func _restore_view_order_to_slots() -> void:
	for slot in _card_group.get_children():
		var it = slot.SlottedInteractableCard()
		if it == null or it._card_view == null or not is_instance_valid(it._card_view):
			continue
		var v: Control = it._card_view
		if v.visible and v.get_parent() == self:
			move_child(v, get_child_count() - 1)

## [VCANIM] 临时（动画/层级验收完删）：手牌叠压快照——按场景树序列卡 uid@树位（z≠10 才标）。
## Godot 命中序＝树序（z_index 只管渲染）——谁在重叠区吃事件由本行直接可读。
func _stack_line(ev: String) -> void:
	var parts: Array = []
	for ch in get_children():
		if ch is Control and ch.has_meta("hand_uid") and (ch as Control).visible:
			var zz: int = (ch as Control).z_index
			parts.append("%d@%d%s" % [int((ch as Control).get_meta("hand_uid", -1)),
				(ch as Control).get_index(), "" if zz == 10 else "(z%d)" % zz])
	print("[VCANIM] stack[%s] %s" % [ev, " ".join(parts)])
