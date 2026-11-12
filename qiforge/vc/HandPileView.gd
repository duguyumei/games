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
# [HAND] 多卡排列诊断（2026-11-12 用户令；诊断完删）：布局版本变化后等 0.25s 打一次落定快照
var _debug_seen_rev := -1
var _debug_settle := 0.0

func _init() -> void:
	# 子件在 _init 预建：宿主装配序＝setup() 先于 add_child（QiVcRoot:432-434 实测），
	# _ready 尚未跑而 setup() 要摸 _card_group——预建后两序皆稳
	_pile_root = self
	# 锚位口径（2026-11-12 实机截图定标）：原版 HandPile 锚底中+37 系局部布局真值，但其上屏
	# 链经 Player(世界)→Canvas(ScreenSpaceCamera)——纵向落点静态读不全，按用户 2026-11-07 原版
	# 截图像素实测：**卡底距画面底 ≈ 18% 卡高**（比例与分辨率/窗口无关）。
	# 几何语义：rect 偏移定义「未缩放矩形」＝画布单位（960×182），1.14 缩放绕底中轴心生效
	# （底缘不动）；底缘离屏底＝57 屏幕px（轴心线偏移不被缩放）。
	var gap := roundi(0.18 * VC.CARD_SIZE.y * VC.HAND_ROOT_SCALE)   # ≈57px：卡底离屏底
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -VC.HAND_ROOT_SIZE.x * 0.5
	offset_right = VC.HAND_ROOT_SIZE.x * 0.5
	offset_top = -(float(gap) + VC.HAND_ROOT_SIZE.y)
	offset_bottom = -float(gap)
	scale = Vector2.ONE * VC.HAND_ROOT_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 槽容器（CardSlotHolder 挂件＝HorizontalCardLayoutGroup，960×182 居中＝原版 18559 同构）
	# ＋池槽容器
	_card_group = HAND_HOLDER.new()
	_card_group.name = "CardGroup"
	_card_group.set_anchors_preset(Control.PRESET_FULL_RECT)
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

## CardAddedViewCommand（:370）——抽牌可见动画＝原地出场三件套＋微滑入格（真值档 v0.2 终案：
## 卡出生即挂手牌根，无长飞）。fire-and-forget：三件套启动即走，命令长度＝本批节拍
##（draw_stagger＝Log(N,1000)/N，批量 N 由屏侧算好塞卡字典——原版精确代数坏点，v0.2 实装值）。
func CardAddedViewCommand(player_model, card: Dictionary, _view_speed_multiplier := 1.0) -> void:
	var view = GetOrCreateCardView(card)
	if view == null:
		return
	# 槽位链接＋布局（锁定门内）
	_card_group.AddCardToBottom(card)
	# 出生姿态（原版：localScale=0＋rotateFrom(−55°,180°,−90°) 背面翻正＋alpha 0；
	# 2D 无背面——y=180 翻面不搬，−90° 旋入近似〔登记〕）
	var it = _interactable_of(card)
	var slot = it._current_card_slot if it != null else null
	var born := Vector2.ZERO
	if slot != null:
		born = (slot as Control).position + (slot as Control).size * 0.5 - VC.CARD_CENTER_IN_SHELL
	# 再入场复位（弃/打出后抽回：交互恢复＋根姿态归零——出场态由 TweenContainer 承载）
	if it != null:
		it.EnableInteraction()
	view.rotation = 0.0
	view.scale = Vector2.ONE
	view.z_index = 10
	view.position = born - Vector2(0.0, 48.0)   # 微滑起点（槽位上方 48px）
	view._tween_container.scale = Vector2.ZERO
	view._tween_container.rotation = deg_to_rad(-90.0)
	view.modulate.a = 0.0
	view.set_meta("fly_speed", VC.CARD_MOVEMENT["moveSpeed"])         # 微滑 500px/s
	view.set_meta("fly_decel", VC.CARD_MOVEMENT["decelerateDistance"])   # 减速带 10
	view.visible = true
	TryInsertCard(view, 0)
	view.OnCardAddedToHand(player_model)
	# 出场三件套（fire-and-forget；淡入 0.05＋缩放 0→1 0.2＋旋入 0.2 InOutCubic＝Ease 10 实测）
	var tw: Tween = view.create_tween()
	view.set_meta("pile_tween", tw)
	tw.tween_property(view, "modulate:a", 1.0, VC.DRAW_CARD["scaleDuration"] * 0.25)
	tw.parallel().tween_property(view._tween_container, "scale", Vector2.ONE,
		VC.DRAW_CARD["scaleDuration"]).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(view._tween_container, "rotation", 0.0,
		VC.DRAW_CARD["rotateDuration"]).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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
	# 选中序号→布局劈开（原版 FindAndSetCurrentSelected→layout SelectedIndex 链）；
	# 交互即清计时→解锁（悬停劈开即时生效）
	_card_group.FindAndSetCurrentSelected(interactable)
	_card_group.TrySetLayoutGroupIndex(_card_group.CurrentSelectedCardIndex())
	_card_group.OnCardInteracted(null)
	_card_group.set_meta("hand_ev", "hover_in")
	_card_group.ForceLayoutRefresh()
	view.z_index = 60
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
	_card_group.set_meta("hand_ev", "hover_out")
	_card_group.ForceLayoutRefresh()
	view.z_index = 10
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
	# [HAND] 多卡排列诊断（2026-11-12 用户令；诊断完删）：布局一变，等 0.25s 卡跟槽落定，
	# 打一次「槽序 vs 视图场景序 + 卡面中心 vs 槽心 + 悬停缩放」。只查多卡，不刷屏。
	if _card_group != null and int(_card_group.get("_debug_rev")) != _debug_seen_rev:
		_debug_seen_rev = int(_card_group.get("_debug_rev"))
		_debug_settle = 0.25
	elif _debug_settle > 0.0:
		_debug_settle -= delta
		if _debug_settle <= 0.0:
			_debug_dump_views()

## 多卡视图快照：槽序（布局权威）vs 视图场景序（z 叠压权威），以及每张卡面中心与槽心误差。
## 误差在 0.25s 后仍 >2px → 卡没跟上槽（锁位/飞行/目标算错）；场景序≠槽序 → 叠压错位。
func _debug_dump_views() -> void:
	if _card_group == null:
		return
	var n: int = _card_group.get_child_count()
	if n == 0:
		return
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var slot_uids: Array = []
	var slot_index := {}
	var slot_centers := {}
	var i := 0
	for slot in _card_group.get_children():
		var uid := _debug_uid_of_slot(slot)
		slot_uids.append(uid)
		slot_index[uid] = i
		var sc := slot as Control
		# 槽心取未旋转矩形中心（与 UpdatePosition 目标同式 slot.position+size*0.5）——
		# 槽自带扇形 rotation，走全局变换会把参考点转歪 ~18px，验收误报 FACE_OFF
		slot_centers[uid] = inv * (_card_group.get_global_transform_with_canvas()
				* (sc.position + sc.size * 0.5))
		i += 1
	var active: Array = []
	for v in _card_views:
		if is_instance_valid(v) and (v as Control).visible:
			active.append(v)
	active.sort_custom(func(a, b): return (a as Control).get_index() < (b as Control).get_index())
	var view_uids: Array = []
	for v in active:
		view_uids.append(int((v as Control).get_meta("hand_uid", -1)))
	var model_uids: Array = []
	for card in _pile_cards():
		model_uids.append(int(card.get("uid", -1)))
	var active_uids: Array = []
	var active_slots = _card_group.get("_active_card_slots")
	if active_slots is Array:
		for slot in active_slots:
			active_uids.append(_debug_uid_of_slot(slot))
	var order_ok := view_uids == slot_uids
	var model_ok := model_uids == slot_uids
	var active_ok := active_uids == slot_uids
	var max_err := 0.0
	var max_err_uid := -1
	var rows: Array = []
	for v in active:
		var uid := int((v as Control).get_meta("hand_uid", -1))
		var sidx := int(slot_index.get(uid, -1))
		var face := Vector2.ZERO
		var tilt = v._tilt_view
		if tilt != null and is_instance_valid(tilt):
			face = inv * (tilt.get_global_transform_with_canvas() * ((tilt as Control).size * 0.5))
		var slotc: Vector2 = slot_centers.get(uid, Vector2.ZERO)
		var err := (face - slotc).length() if sidx >= 0 else -1.0
		var it = (v as Control).get_node_or_null("InteractableCard")
		var hover: bool = it != null and it.IsHovering()
		var fly: bool = (v as Control).has_meta("fly_speed")
		if not fly and not hover and err > max_err:
			max_err = err
			max_err_uid = uid
		var vr = v._visual_root
		var rot: float = rad_to_deg(vr.rotation) if vr != null else 0.0
		var tc = v._tween_container
		var tween: float = tc.scale.x if tc != null else 0.0
		rows.append("i=%d uid=%d slot=%d scene=%d z=%d face=(%.0f,%.0f) slotc=(%.0f,%.0f) err=%.1f rot=%.1f tween=%.2f hover=%s fly=%s" % [
			sidx, uid, sidx, (v as Control).get_index(), (v as Control).z_index,
			face.x, face.y, slotc.x, slotc.y, err, rot, tween,
			"1" if hover else "0", "1" if fly else "0"])
	if n < 6 and order_ok and model_ok and active_ok and max_err <= 2.0:
		return
	print("[HAND] views n=%d sel=%d order.model=%s order.slot=%s order.view=%s order.active=%s model_ok=%s order_ok=%s active_ok=%s max_err=%.1f@%d%s%s%s%s" % [
		n, _card_group.GetSelectedIndex(), str(model_uids), str(slot_uids), str(view_uids),
		str(active_uids), "1" if model_ok else "0", "1" if order_ok else "0",
		"1" if active_ok else "0", max_err, max_err_uid,
		"" if model_ok else " MODEL_MISMATCH", "" if order_ok else " ORDER_MISMATCH",
		"" if active_ok else " ACTIVE_MISMATCH", "" if max_err <= 2.0 else " FACE_OFF"])
	for r in rows:
		print("[HAND] view %s" % r)

func _debug_uid_of_slot(slot) -> int:
	if slot == null:
		return -1
	var it = slot.SlottedInteractableCard()
	if it == null:
		return -1
	var v = it._card_view
	if v == null or not is_instance_valid(v):
		return -1
	return int(v.get_meta("hand_uid", -1))
