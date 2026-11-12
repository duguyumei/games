## 原版 CardView 1:1（Nosebleed.Pancake.View/CardView.cs，10614 行）——手牌核心法集。
## 结构 1:1 制（2026-11-12 宪法）：方法名/参数/功能对齐原版；缓后子系统法（宝石/戳记/
## wild 轮换/3D 视图/本地化/连击费显示族）保留占位并登记《原版差异登记》。
## 引擎映射：MonoBehaviour 多组件同物体 → 子节点组件制（TransformMover2D/InteractableCard
## 为本卡子节点，写本卡变换）；卡面＝程序化 TCG 卡渲 SubViewport 贴图（原版 sprite 图集——
## 视觉层差异登记）；_baseTweenOffset 与 _tweenContainer 合并为单 TweenContainer 节点
## （2D 单轴下 rotation 与 scale 不同属性、无写冲突——登记）。
## 节点树：CardView 根（180×277 画布单位，Card_Hand.prefab:1534）→ VisualRoot →
## TweenContainer（缩放/旋钮/悬停抬升层）→ TiltView（贴图+单应透视 shader＝HoverTilt 的 2D 替身）。
extends "res://qiforge/vc/View.gd"

signal CardDestroyed(speed_multiplier: float)     # m_CardDestroyed（CardView.cs:2765 区）
signal CardPlayed(arg: bool)                      # m_CardPlayed（:2780 区）
signal CardAddedToHand                            # m_CardAddedToHand（:2890 区）
signal RemovedFromHand                            # m_RemovedFromHand（:2960 区）
signal ViewRefreshed                              # m_ViewRefreshed（:3030 区）

const VC := preload("res://qiforge/vc/VcConfig.gd")
const NBU := preload("res://qiforge/vc/NBUtil.gd")
const CARD := preload("res://qiforge/QiCardStyle.gd")
const QIFONTS := preload("res://qiforge/QiFontBank.gd")
const KW_TIP := preload("res://qiforge/QiKeywordTooltip.gd")
const TILT_SHADER := preload("res://qiforge/assets/card_tilt_glint.gdshader")

# —— 我方自研件参数（非原版；倾斜贴图超采样/外扩/上限/平滑）——
const TILT_SS := 3.0          # SubViewport 超采样倍率
const TILT_MARGIN := 1.18     # 贴图外扩（斜切留边）
const TILT_MAX := 0.50        # 倾斜归一上限
const TILT_SMOOTH := 12.0     # 倾斜跟手平滑
const SHAKE_AMP := 5.0        # 不可付费摇头幅度（画布单位×根缩放上屏）
const SHAKE_TIME := 0.3       # 摇头时长（PlayInvalidCardShake vibrato 15Hz，真值档 v0.2）

# —— 原版字段（CardView.cs:2552-2692 摘手牌相关；缓后字段见占位法注释）——
var _card_model: Dictionary = {}        # _cardModel（:2608）→ 我方卡字典（CardModel）
var _visual_root: Control = null        # _visualRoot（:2614）
var _tween_container: Control = null    # _tweenContainer（:2616）
var _transform_mover = null             # _transformMover（:2622）→ vc/TransformMover2D 子节点
var _default_scale := Vector2.ONE       # _defaultScale（:2620）
var _initial_scale := Vector2.ONE       # _initialScale（:2634）
var _rotation_tweener: Tween = null     # _rotationTweener（:2626）
var _scale_tweener: Tween = null        # _scaleTweener（:2628）
var _animation_interrupts: Array = []   # _animationInterrupts（:2676）
var _is_initialised := false            # _isInitialised（:2670）
var _pivot_position := Vector2.ZERO     # _pivotPosition（:2640）
var _freeze_card_combo := false         # _freezeCardCombo（:2652，连击费＝VC 特有，登记）
var _frozen_card_combo_value := 0       # _frozenCardComboValue（:2654）
var _current_card_type_visuals = null   # _currentCardTypeVisuals（:2646；型视觉＝我方剑型徽章）
# —— 我方卡面子件引用（SetCardConfig/UpdateCostText 消费）——
var _tilt_view: TextureRect = null
var _face_card: Control = null          # SubViewport 内 TcgCard
var _cost_pip: Control = null           # 费用徽（名 "CostPip"）
var _qi_icon: Control = null            # 费用徽内子件（名 "QiIcon"）
var _kw_tip = null                      # 词条浮窗组件（挂卡下与卡同生共死，2026-11-10 原版制）
var shake_t := 0.0                      # 摇头剩余时长（PlayInvalidCardShake 状态）

func _init() -> void:                   # Awake（:3071）
	super()
	# 卡根＝命中壳（我方自拟加高，登记）：宽 180（原版卡宽）＋高 277+壳顶留白 118（命中稳定）
	size = Vector2(VC.CARD_SIZE.x, VC.CARD_SIZE.y + VC.HAND_TOP_PAD)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	super()                               # View.Start 同构
	TryInit()
	# VisualRoot → TweenContainer → TiltView（Card_Hand prefab 层级同构）
	_visual_root = Control.new()
	_visual_root.name = "VisualRoot"
	_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 旋转轴心＝壳内卡面中心：原版 _visualRoot 绑 FollowParent（Card_Hand.prefab:1557），
	# 拉伸铺满 180×277＋pivot (0.5,0.5)（:1909-1913）——Unity 绕枢轴旋转天然绕卡心；
	# Godot Control.new() 默认 pivot (0,0)＝左上角，不补则扇角绕左上角把卡面甩向中心
	# 最多 66px（2026-11-12 轴心案：误差∝|扇角| 实测签名，(I−R(θ))·(90,256.5) 对到 0.5px）
	_visual_root.pivot_offset = VC.CARD_CENTER_IN_SHELL
	add_child(_visual_root)
	_tween_container = Control.new()
	_tween_container.name = "TweenContainer"
	_tween_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.add_child(_tween_container)
	# 组件子节点（Unity 多组件同物体 → Godot 子节点制，登记）
	var mover_script := preload("res://qiforge/vc/TransformMover2D.gd")
	var mover := Node.new()
	mover.set_script(mover_script)
	mover.name = "TransformMover2D"
	add_child(mover)
	_transform_mover = mover
	var ic_script := preload("res://qiforge/vc/InteractableCard.gd")
	var ic := Node.new()
	ic.set_script(ic_script)
	ic.name = "InteractableCard"
	add_child(ic)
	# 词条浮窗组件（原版 KeywordTooltip 子组件制：挂卡节点下、与卡同生共死）
	var tip := KW_TIP.new()
	tip.name = "KwTip"
	add_child(tip)
	_kw_tip = tip
	# 布局交给宿主（CardSlotHolder 创建后 LinkCard/挂事件）
	card_view_ready.emit()

signal card_view_ready                   # 引擎映射：宿主接线口（原版由场景序列化引用完成）

func _process(delta: float) -> void:     # Update（:3101）——原版＝wild 卡型轮换（缓后④）；
	# 我方占位驱动：倾斜/光泽 shader 跟手（HoverTilt 的 2D 替身，登记）＋摇头衰减
	_drive_tilt(delta)

func _exit_tree() -> void:               # OnDestroy（:3117）
	super()
	UnsubscribeFromCardEvents()
	if _rotation_tweener != null and _rotation_tweener.is_valid():
		_rotation_tweener.kill()
	if _scale_tweener != null and _scale_tweener.is_valid():
		_scale_tweener.kill()

# ── 初始化/池化生命周期 ────────────────────────────────────────────────

## TryInit（:3106）——_isInitialised 置位＋记录初始缩放
func TryInit() -> void:
	_is_initialised = true
	_initial_scale = scale               # _initialScale = transform.localScale（:3112-3113）

## KillPileTween（我方扩展，登记）——杀堆飞行 tween（弃/耗/出场三件套）；池腾换时先杀防属性打架
func KillPileTween() -> void:
	if has_meta("pile_tween"):
		var t = get_meta("pile_tween")
		if t is Tween and t.is_valid():
			t.kill()
		remove_meta("pile_tween")

## OnSpawned（:3210）——对象池复用入口：杀双 tween＋tween 容器归零＋根缩放重置
func OnSpawned() -> void:
	TryInit()
	if _rotation_tweener != null and _rotation_tweener.is_valid():
		_rotation_tweener.kill()
	if _scale_tweener != null and _scale_tweener.is_valid():
		_scale_tweener.kill()
	_tween_container.scale = Vector2.ZERO          # _tweenContainer.localScale = zero（:3231）
	_tween_container.rotation = 0.0                # rotation = identity（:3233）
	scale = _initial_scale                         # transform.localScale 重置（:3235）
	shake_t = 0.0

## SubscribeToCardEvents（:3238）/ UnsubscribeFromCardEvents（:3247）——
## 原版订阅 CardModel 数据事件；我方 changed 驱动 RefreshCardsUI 对位，占位保留
func SubscribeToCardEvents() -> void:
	pass

func UnsubscribeFromCardEvents() -> void:
	pass

func SyncView() -> void:                # SyncView（:3256，原版空实现）
	super()

## SetTransformParent（:3260）
func SetTransformParent(parent: Node, world_pos_stays: bool) -> void:
	var gp := global_position if world_pos_stays else Vector2.ZERO
	var gr := rotation if world_pos_stays else 0.0
	reparent(parent, false)
	if world_pos_stays:
		global_position = gp
		rotation = gr

# ── 配置/外观 ─────────────────────────────────────────────────────────

## SetCardConfig（:3266）——绑定卡定义：重置连击冻结字段＋隐藏戳记（缓后）＋重画面＋刷费用
func SetCardConfig(card_config: Dictionary, override_obj_name := true) -> void:
	_freeze_card_combo = false                    # :3298
	_frozen_card_combo_value = 0                  # :3299
	_card_model = card_config
	if override_obj_name:
		name = "HandCard%d" % int(card_config.get("uid", 0))
	_rebuild_face()
	InitializeCardTypeVisuals()
	var player_model = _player_model()
	UpdateCostText(player_model)
	RefreshView(player_model)

## SetCardSprite（:3433）——原版换 sprite 图集；我方＝程序化卡面（视觉层差异登记，占位）
func SetCardSprite(_sprite) -> void:
	pass

func ResolveCardSprite() -> void:       # ResolveCardSprite（:3439）——同上占位
	pass

func SetCardType(_card_type) -> void:   # SetCardType（:3930）——剑型视觉归 InitializeCardTypeVisuals
	pass

func SetDescription(_description: String) -> void:   # SetDescription（:3949）——卡面 desc 重画归 _rebuild_face
	pass

## RefreshView（:3964）——按玩家态刷卡面（费用可付性/式徽）；
## 运行态签名（uses/等级/碎裂/当前型）变化＝卡面重绘（旧制每次 changed 全重建的增量替代）
func RefreshView(player_model) -> void:
	UpdateCostText(player_model)
	var pm = _player_model()
	if pm != null and not _card_model.is_empty():
		var sig := "%d|%d|%s|%s" % [int(_card_model.get("uses", 0)),
			pm.card_lv(_card_model), str(pm.is_cracked(_card_model)), String(pm.current_form)]
		if str(get_meta("face_sig", "")) != sig:
			set_meta("face_sig", sig)
			_rebuild_face()
	ViewRefreshed.emit()

## SetShadowDistance（:4029）——影子不搬（2026-11-11 用户裁定：基本注意不到），占位
func SetShadowDistance(_new_distance: Vector2, _animation_time: float, _instant := false,
		_ease := 1) -> void:
	pass

func RefreshCardDescription(_player_model: Dictionary) -> void:   # RefreshCardDescription（:4045）
	pass

func RefreshCardName() -> void:        # RefreshCardName（:4061）
	pass

func RefreshBlockedVisuals() -> void:  # RefreshBlockedVisuals（:4307）——敌盾阻挡视觉，缓后
	pass

# —— 戳记族（:4685-4775，宝石/免费/翅膀/领袖/迈达斯/手牌上限/冻结/来世）——缓后④，占位
func EnableDisableFreeToPlayStamp(_on: bool) -> void:
	pass

func EnableDisableWingsStamp(_on: bool) -> void:
	pass

func EnableDisableLeaderStamp(_on: bool) -> void:
	pass

func EnableDisableMidasStamp(_on: bool) -> void:
	pass

func RefreshHandCapStampVisual() -> void:
	pass

func EnableDisableFrozen(_on: bool) -> void:
	pass

func EnableDisableAfterLife(_on: bool) -> void:
	pass

func PlayCardChangedAnim() -> void:    # PlayCardChangedAnim（:4780）——换卡动画，缓后
	pass

## UpdateCostText（:4803）——费用文本＋可付性描红（我方＝气费制：底价+cost_delta，free=0）
func UpdateCostText(player_model) -> void:
	if _cost_pip == null:
		return
	var cost := _cost_value()
	var afford := _can_afford(player_model)
	_cost_pip.visible = true
	for ch in _cost_pip.get_children():
		if ch is Label:
			(ch as Label).text = str(cost)
	# 不可付＝费用徽描红（原版 ShowCantAffordCostText 同构）
	if _qi_icon != null:
		_qi_icon.modulate = Color(1.0, 0.32, 0.28) if not afford else Color.WHITE
	_cost_pip.modulate = Color(1.0, 0.55, 0.5) if not afford else Color.WHITE

func GetCardDescription(_player_model, _use_player_stats := false) -> String:   # :4936
	return String(_card_model.get("def", {}).get("desc", ""))

# —— 词条浮窗（原版 GetCardTooltips/ToggleTooltips/CheckTooltipScreenPos，:7257/8431/8483）——
## 我方＝QiKeywordTooltip 组件（2026-11-10 原版制：挂卡下、无「兜底全文」）
func GetCardTooltips(_player_model) -> void:
	var def: Dictionary = _card_model.get("def", {})
	if _kw_tip != null and not def.is_empty():
		_kw_tip.refresh(def)

func ToggleTooltips(on: bool) -> void:
	if _kw_tip != null:
		_kw_tip.set_active(on)

func CheckTooltipScreenPos() -> void:  # :8483——每帧贴边选边翻面（悬停中由 InteractableCard 调）
	if _kw_tip != null:
		_kw_tip.check_screen_pos()

# —— 费用显示族（:8936-9175）——连击费＝VC 特有（气费制登记），保留两态＋重置
func ShowCantAffordCostText() -> void:   # :8936
	if _cost_pip != null:
		_cost_pip.modulate = Color(1.0, 0.55, 0.5)
		if _qi_icon != null:
			_qi_icon.modulate = Color(1.0, 0.32, 0.28)

func ShowComboCostText() -> void:       # :8946——连击费制未搬，占位
	pass

func ShowDefaultCostText() -> void:    # :8961
	if _cost_pip != null:
		_cost_pip.modulate = Color.WHITE
		if _qi_icon != null:
			_qi_icon.modulate = Color.WHITE

func AnimateManaDebuff() -> void:      # :8974（UniTask）——气系统无对应减费动画，占位
	pass

func FreezeComboValue() -> void:       # :9007——连击冻结，登记
	_freeze_card_combo = true

func UnfreezeComboValue() -> void:     # :9012
	_freeze_card_combo = false

func GetCostText() -> String:          # :9017
	return str(_cost_value())

func AddToConfuseManaModifier(_amount: int) -> void:   # :9095——confuse 减费未搬，占位
	pass

func ShowDefaultDescription() -> void:   # :9115
	pass

func ResetView() -> void:              # :9146
	ShowDefaultCostText()
	ShowDefaultDescription()

func ResetConfuseManaCost() -> void:   # :9155——占位
	pass

func SetAsSwitchDiscardCandidate(_on := true) -> void:   # :9175——切招弃卡候选视觉，缓后
	pass

# ── 手牌生命周期/移动 ─────────────────────────────────────────────────

## OnRemovedFromHand（:9190）——离手：广播＋收词条
func OnRemovedFromHand() -> void:
	RemovedFromHand.emit()
	ToggleTooltips(false)

## InvokeAddedToHand（:9200）
func InvokeAddedToHand() -> void:
	CardAddedToHand.emit()

## OnPlayCardViewUpdate（:9209，IEnumerator）——出牌视图协程：
## 我方＝出招演出（上冲→飞已打出区；已打出区＝ComboPile 对位、视觉暂用现制——登记）
func OnPlayCardViewUpdate(is_auto_play: bool) -> void:
	set_meta("play_out_pending", true)   # 屏侧 _anim_card_play_out 对位挂点（屏手术接线）
	await get_tree().create_timer(0.01, false).timeout

func EnableManaCostFlames() -> void:   # :9218——费用火苗视觉，缓后
	pass

func DisableManaCostFlames() -> void:   # :9223
	pass

func ComboElements(_is_on: bool) -> void:   # :9228——连击视觉元素，缓后
	pass

## OnCardAddedToHand（:9239）——加牌入场：激活＋置首＋刷面＋广播（缩放/旋转重置归 OnSpawned）
func OnCardAddedToHand(player_model) -> void:
	visible = true                       # SetActive(true)（:9247）
	UpdateCostText(player_model)
	RefreshView(player_model)
	InvokeAddedToHand()

## OnReturnToHandTriggered（:9267，UniTask）——抛物线回手（ReturnToHandJumpHeight 500/
## Up 0.25/TopWait 0.05/Down 0.4，GlobalConfig.asset:33-49）；回手卡功能接入时启用
func OnReturnToHandTriggered(_player_model) -> void:
	await get_tree().create_timer(0.01, false).timeout

## SpawnFromTop（:9310）——顶部出生（SpawnFromTopHeight 0/Duration 0＝空动）
func SpawnFromTop() -> void:
	pass

## MoveTo（:9343）——TransformMover2D 寻的链（速度/减速带由调用方按 config 传）
func MoveTo(target_position: Vector2, on_complete: Callable = Callable()):
	_transform_mover.SetTargetPosition(target_position)
	_transform_mover.ResetOnComplete()
	if on_complete.is_valid():
		if not _transform_mover.ReachedTargetPosition.is_connected(on_complete):
			_transform_mover.ReachedTargetPosition.connect(on_complete)

func StopTransformMover() -> void:     # :9408
	_transform_mover.ForceStopMove()

func SetPivot(position: Vector2) -> void:   # :9413
	_pivot_position = position

func MoveToPivot(on_complete: Callable = Callable()) -> void:   # :9418
	MoveTo(_pivot_position, on_complete)

## RotateTo（:9427）——Kill 旧旋转 tween；delay=0 直接落值，否则 DORotate（TweenContainer 层）
func RotateTo(rotation_deg: float, duration: float, delay := 0.0):
	if _rotation_tweener != null and _rotation_tweener.is_valid():
		_rotation_tweener.kill()
	if delay <= 0.0:
		_tween_container.rotation = deg_to_rad(rotation_deg)
		return null
	_rotation_tweener = create_tween()
	_rotation_tweener.tween_interval(delay)
	_rotation_tweener.tween_property(_tween_container, "rotation",
		deg_to_rad(rotation_deg), duration)
	return _rotation_tweener

## ScaleTo（:9496＋:9562 曲线重载合并——曲线档→枚举档单法，登记）——TweenContainer 层
func ScaleTo(scl: Vector2, duration: float, ease := VC.EASE_IN_OUT_CUBIC, delay := 0.0):
	if _scale_tweener != null and _scale_tweener.is_valid():
		_scale_tweener.kill()
	if delay <= 0.0 and duration <= 0.0:
		_tween_container.scale = scl
		return null
	_scale_tweener = create_tween()
	if delay > 0.0:
		_scale_tweener.tween_interval(delay)
	_scale_tweener.tween_property(_tween_container, "scale", scl, duration)\
		.set_trans(VC.ease_trans(ease)).set_ease(VC.ease_mode(ease))
	return _scale_tweener

## ResetScale（:9628）——回 _defaultScale
func ResetScale(duration: float, delay := 0.0, ease := VC.EASE_IN_OUT_CUBIC) -> void:
	ScaleTo(_default_scale, duration, ease, delay)

## SetFacingDirection（:9639）——2D 无背面（引擎差异#2），翻面态记录占位
func SetFacingDirection(_direction) -> void:
	pass

func EnableParticles() -> void:        # :9651——粒子，缓后
	pass

func DisableParticles() -> void:       # :9657
	pass

## DestroyCard（:9663）——只广播 CardDestroyed(speedMultiplier)；销毁动画归订阅方（DestroyPileView）
func DestroyCard(speed_multiplier := 1.0) -> void:
	CardDestroyed.emit(speed_multiplier)

## AttachVisualRoot（:9672）——visualRoot 归位＋缩放重置
func AttachVisualRoot() -> void:
	if _visual_root.get_parent() != self:
		_visual_root.reparent(self, false)
	_visual_root.scale = Vector2.ONE

## RegisterAnimationInterrupt（:9680）/ Deregister（:9686）——动画打断登记（加牌命令等待判据）
func RegisterAnimationInterrupt(owner) -> void:
	if not _animation_interrupts.has(owner):
		_animation_interrupts.push_back(owner)

func DeregisterAnimationInterrupt(owner) -> void:
	_animation_interrupts.erase(owner)

## HasAnimationInterrupts 属性（:2694）
func HasAnimationInterrupts() -> bool:
	return not _animation_interrupts.is_empty()

## OnOtherCardPlayed（:9692）——他卡打出时按需刷面（我方＝动态升级刷费用/式徽）
func OnOtherCardPlayed(player_model) -> void:
	# 原版：_cardConfig.RequiresViewRefreshOnCardPlay() 才刷；我方动态升级改费→恒刷费用
	UpdateCostText(player_model)

func UpdateCardTypeView() -> void:     # :9709——wild 轮换视觉，缓后④
	pass

func InitTextTags() -> void:           # :9855——TMP 富文本标签，占位
	pass

## InitializeCardTypeVisuals（:9864）——型视觉初始化：我方＝剑型徽章按 def.stance 亮金
func InitializeCardTypeVisuals() -> void:
	if _face_card == null:
		return
	_face_card.set_meta("stance", String(_card_model.get("def", {}).get("stance", "")))
	if _face_card.has_method("refresh_stance_badge"):
		_face_card.refresh_stance_badge()

func DisableCardTypeVisuals(_visuals) -> void:   # :10053
	pass

func OnValidate() -> void:             # :10079——编辑器校验，运行时占位
	pass

func OnLocaleChange(_locale) -> void:  # :10106——本地化未搬，占位
	pass

func OnLimitBreakUpdated() -> void:    # :10136——限界突破视觉，缓后
	pass

func Init3DViewDefaultValues() -> void:   # :10166——3D 视图（引擎差异#2），占位
	pass

func On3DCardViewChanged() -> void:    # :10236——同上
	pass

## ResetStaticState（:3051）——编辑器静态复位，运行时占位
static func ResetStaticState() -> void:
	pass

# ── 我方扩展（登记：非原版方法；倾斜贴图/摇头/费用取值桥）──────────────

## PlayInvalidCardShake（原版 PlayableCard.TryPlayCard else 分支；15Hz vibrato，真值档 v0.2）
func PlayInvalidCardShake() -> void:
	shake_t = SHAKE_TIME

## 费用取值桥：CardModel 费用（底价+cost_delta，free=0——我方气费制）
func _cost_value() -> int:
	if bool(_card_model.get("free", false)):
		return 0
	return int(_card_model.get("def", {}).get("cost", 0)) + int(_card_model.get("cost_delta", 0))

## player_model 桥（宿主以 meta 注入 battle——原版场景序列化引用的 Godot 对位）
func _player_model():
	return get_meta("player_model", null)

func _can_afford(player_model) -> bool:
	if player_model == null:
		return true
	return int(player_model.player["qi"]) >= _cost_value()

## 重画面（池化复用：SubViewport 内 TcgCard 重建＝原版 ResolveCardSprite 换图的程序化对位）。
## vdef 合成＝tcg_def_of(卡定义)＋运行态（费用活查询/裂纹档/升金/碎裂/当前型）——
## 原版等价物＝CardView 从 CardModel/CardConfig 字段现读（UpdateCostText/RefreshCardDescription 族）
func _rebuild_face() -> void:
	for ch in _tween_container.get_children():
		ch.queue_free()
	var pm = _player_model()
	var vdef: Dictionary = CARD.tcg_def_of(_card_model.get("def", {}))
	if pm != null:
		vdef["qi"] = pm.card_cost(_card_model)
		vdef["crack_level"] = clampi(int(_card_model.get("uses", 0)) - 2, 1, 3)
		vdef["combo_gold"] = pm.card_lv(_card_model) > 0
		vdef["cracked"] = pm.is_cracked(_card_model)
		vdef["cur_form"] = String(pm.current_form)
	var vp := SubViewport.new()
	vp.name = "FaceVP"
	vp.size = Vector2i(roundi(VC.FACE_SIZE.x * TILT_SS), roundi(VC.FACE_SIZE.y * TILT_SS))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X   # 卡面框线抗锯齿（2026-11-08 用户指正外框锯齿）
	var card: Control = CARD.make_tcg_card(vdef, "vc_hand")   # 宽 180＝原版 1:1（工厂 vc_hand 档）
	card.theme = QIFONTS.default_theme()   # SubViewport 不吃根窗主题
	card.scale = Vector2(TILT_SS, TILT_SS)
	vp.add_child(card)
	_face_card = card
	# 费用徽引用（UpdateCostText 消费；工厂件名 "CostPip"/"QiIcon"）
	_cost_pip = _find_by_name(card, "CostPip")
	_qi_icon = _find_by_name(_cost_pip, "QiIcon") if _cost_pip != null else null
	# 词条浮窗几何桥（corners_fn＝看得见的歪卡四角；avoid＝HUD 禁区，宿主屏以 meta 注入）
	if _kw_tip != null:
		_kw_tip.setup(self, {
			"corners_fn": Callable(self, "_face_corners"),
			"anchor_fn": Callable(self, "_visual_rect"),
			"avoid": get_meta("tip_avoid", [])})
	var mat := ShaderMaterial.new()
	mat.shader = TILT_SHADER
	mat.set_shader_parameter("strength", 0.09)
	mat.set_shader_parameter("uv_scale", TILT_MARGIN)
	mat.set_shader_parameter("glint_strength", 1.0)
	var tex := TextureRect.new()
	tex.name = "TiltView"
	tex.add_child(vp)   # 视口随贴图层同生共死
	tex.texture = vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.size = VC.FACE_SIZE * TILT_MARGIN
	tex.material = mat
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 内层纯贴图——事件全归卡根
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex.set_meta("tip", Vector2.ZERO)
	tex.set_meta("sheen", 0.2)
	tex.set_meta("hov", 0.0)
	tex.set_meta("vc_card", card)
	_tilt_view = tex
	_tween_container.add_child(tex)
	# TiltView 静止位：卡面中心对齐槽位卡心（CARD_SIZE 中心）；缩放/旋转轴心＝卡面中心
	#（原版卡 RectTransform pivot (0.5,0.5)——2026-11-12 实测）
	tex.position = Vector2(VC.CARD_SIZE.x * 0.5,
		VC.HAND_TOP_PAD + VC.CARD_SIZE.y * 0.5) - tex.size * 0.5
	_tween_container.pivot_offset = tex.position + tex.size * 0.5

func _find_by_name(root: Node, node_name: String) -> Control:
	if root == null:
		return null
	for ch in root.get_children():
		if ch is Control and (ch as Control).name == node_name:
			return ch
		var deep := _find_by_name(ch, node_name)
		if deep != null:
			return deep
	return null

## 卡面四角（屏幕坐标）——浮窗/命中用「看得见的歪卡」（含 shader 斜切像素补偿）
func _face_corners() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _tilt_view == null:
		return out
	var face := Rect2((_tilt_view.size.x - VC.FACE_SIZE.x) * 0.5,
		(_tilt_view.size.y - VC.FACE_SIZE.y) * 0.5, VC.FACE_SIZE.x, VC.FACE_SIZE.y)
	var xf := _tilt_view.get_global_transform_with_canvas()
	var q := [
		xf * face.position,
		xf * Vector2(face.end.x, face.position.y),
		xf * face.end,
		xf * Vector2(face.position.x, face.end.y)]
	var tv3: Vector2 = _tilt_view.get_meta("tip", Vector2.ZERO)
	var sc3: float = _tilt_view.scale.x
	var dux := (0.5 / (1.0 - 0.09 * tv3.x) - 0.5) / TILT_MARGIN
	var duy := (0.5 / (1.0 - 0.09 * tv3.y) - 0.5) / TILT_MARGIN
	var dx := dux * VC.FACE_SIZE.x * sc3
	var dy := duy * VC.FACE_SIZE.y * sc3
	q[1] += Vector2(dx, dy)     # TR
	q[2] += Vector2(dx, -dy)    # BR
	q[3] += Vector2(-dx, -dy)   # BL
	q[0] += Vector2(-dx, dy)    # TL
	for v in q:
		out.push_back(v)
	return out

func _visual_rect() -> Rect2:
	if _tilt_view == null:
		return Rect2()
	var r := _tilt_view.get_global_rect()
	var m: float = (TILT_MARGIN - 1.0) * VC.FACE_SIZE.x * 0.5
	return r.grow(-m)

## 倾斜/光泽驱动（HoverTilt 的 2D 替身，登记）：鼠标指哪边哪边朝里倒＋近侧反光＋往复扫光；
## 隐藏卡停渲 SubViewport（池化闲置不烧 GPU——持久制的省电门）
func _drive_tilt(delta: float) -> void:
	if _tilt_view == null:
		return
	var vp := _tilt_view.get_child(0) as SubViewport
	if vp != null:
		var want: int = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
		if vp.render_target_update_mode != want:
			vp.render_target_update_mode = want
	if not visible:
		return
	var mat: ShaderMaterial = _tilt_view.material as ShaderMaterial
	if mat == null:
		return
	var mouse: Vector2 = get_global_mouse_position()
	var r: Rect2 = _tilt_view.get_global_rect()
	var ctr: Vector2 = r.position + r.size * 0.5
	var half: Vector2 = r.size / (2.0 * TILT_MARGIN)
	var nv: Vector2 = Vector2((mouse.x - ctr.x) / maxf(1.0, half.x),
		(mouse.y - ctr.y) / maxf(1.0, half.y))
	var inside: bool = absf(nv.x) < 1.0 and absf(nv.y) < 1.0
	var tip_tgt := Vector2.ZERO
	if inside:
		tip_tgt = -Vector2(clampf(nv.x, -1.0, 1.0), clampf(nv.y, -1.0, 1.0)) * TILT_MAX
	var cyc: float = fmod(Time.get_ticks_msec() * 0.0002, 2.0)
	var sheen_tgt: float = (cyc if cyc <= 1.0 else 2.0 - cyc) * 0.72
	if OS.has_environment("QI_FREEZE_SHEEN"):
		sheen_tgt = 0.40
	var kk: float = clampf(delta * TILT_SMOOTH, 0.0, 1.0)
	var tip: Vector2 = (_tilt_view.get_meta("tip", Vector2.ZERO) as Vector2).lerp(tip_tgt, kk)
	var sheen: float = lerpf(float(_tilt_view.get_meta("sheen", 0.2)), sheen_tgt, kk)
	var hov: float = lerpf(float(_tilt_view.get_meta("hov", 0.0)), 1.0 if inside else 0.0, kk)
	if OS.has_environment("QI_FORCE_TIP"):
		tip = Vector2(0.5, 0.3)
	if _face_card != null and is_instance_valid(_face_card) and _face_card.glint_mat != null:
		_face_card.glint_mat.set_shader_parameter("band_pos", sheen)
		_face_card.glint_mat.set_shader_parameter("tip_x", tip.x)
		_face_card.glint_mat.set_shader_parameter("tip_y", tip.y)
	_tilt_view.set_meta("tip", tip)
	_tilt_view.set_meta("sheen", sheen)
	_tilt_view.set_meta("hov", hov)
	mat.set_shader_parameter("tip_x", tip.x)
	mat.set_shader_parameter("tip_y", tip.y)
	mat.set_shader_parameter("sheen_phase", sheen)
	mat.set_shader_parameter("hover", hov)
