## 原版 InteractableCard 1:1（Nosebleed.Pancake.GameLogic/InteractableCard.cs，2191 行）。
## 每帧链（Update :753）：UpdateHandTilt → UpdatePosition（双层跟随）→ RotateToFollowVelocity
## → CheckForHoveringPlayablePos（拖拽专用，缓后）→ hover 中 CheckTooltipScreenPos。
## 拖拽族（OnDragStarted/OnDragEnded/CheckForHoveringPlayablePos/DoCardHoveringPlayablePositionAnim）
## 不搬（原版代码存在、实际鼠标游玩未启用——用户实机口供＋差异登记#4）。
## 手柄选牌族（OnSelect/OnDeselect/HandleControllerInput…）缓后（差异登记#3）。
## 引擎映射：UGUI PointerEvents → HitRect（缩放子树内 180×277 矩形）gui_input/
## mouse_entered/exited——2026-11-12 挂点修正：对位原版 PointerEvents 挂 PositionOffset
##（Card_Hand.prefab:1864，TweenContainer 子树内），uGUI 射线走世界空间＝命中随 ×1.5/抬升
## 同长；旧挂卡根壳（不缩放）→ 放大后卡面探出壳 45px 处失悬停（用户 F6 抓出）。
## 本组件为卡根子节点、写卡根与 TweenContainer 变换（Unity 多组件同物体→子节点组件制，登记）。
## 悬停抬升层：原版 _hoverOffset Transform＋TransformMover2D；我方＝TweenContainer 位置寻的
## （速度/减速带＝hoverCardConfig 750/0.5 真值）——登记「抬升走偏移层」。
extends Node

signal InteractionStarted(card)         # InteractionStarted（InteractableCard.cs:131）
signal InteractionEnded(card)           # InteractionEnded（:199）
signal CardSelected(card)               # CardSelected（:267）

const VC := preload("res://qiforge/vc/VcConfig.gd")
const NBU := preload("res://qiforge/vc/NBUtil.gd")

var IsHoverable := true                 # IsHoverable（:51）
var IsDraggable := false                # IsDraggable（:53）——拖拽通道不搬，恒 false

var _card_view = null                   # _cardView（:55）→ vc/CardView（父节点）
var _current_card_slot = null           # _currentCardSlot（:79）→ vc/CardSlot
var _is_hovering := false               # _isHovering（:85）
var _is_dragging := false               # _isDragging（:87）——恒 false（拖拽不搬）
var _follow_rotation := 0.0             # _followRotation（:95）
var _follow_velocity := Vector2.ZERO    # _followVelocity（:93）
var _is_selected := false               # _isSelected（:107）
var _hover_lift := 0.0                  # 悬停抬升目标（hoverCardConfig.hoverHeightOffset 两档）
var _prev_tween_pos := Vector2.ZERO     # RotateToFollowVelocity 速度采样（root−visual 上帧差）
var _time_since_last_card_interaction := 0.0   # HandCardSlotHolder._timeSinceLastCardInteraction 同名职责
var _hover_sound := ""                  # DoCardHoveredAnim 音效位（音效轮接入）

func _init() -> void:
	IsHoverable = true
	IsDraggable = false

func _ready() -> void:                  # Awake（:678）——取卡根＋接命中层（HitRect）
	_card_view = get_parent()
	var hit: Control = _card_view._hit_rect
	if hit != null:                      # 命中在缩放子树内（挂点修正 2026-11-12）
		hit.mouse_entered.connect(_on_mouse_entered)
		hit.mouse_exited.connect(_on_mouse_exited)
		hit.gui_input.connect(_on_gui_input)

func CurrentHoveredOverSlot():          # CurrentHoveredOverSlot 属性（:115）——拖拽专用，恒 null
	return null

# ── 输入（PointerEvents → Control 事件，引擎映射）──────────────────────

func _on_mouse_entered() -> void:       # OnHoverStarted（:1420）
	OnHoverStarted(null)

func _on_mouse_exited() -> void:        # OnHoverEnded（:1719）
	OnHoverEnded(null)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		OnCardClicked(null)             # OnCardClicked（:1410）

## ForceEndInteraction（:335）
func ForceEndInteraction() -> void:
	if _is_hovering or _is_dragging:
		EndInteraction()

## OnDragStarted（:340）/ OnDragEnded（:438）——拖拽通道不搬（差异登记#4），占位
func OnDragStarted(_event) -> void:
	pass

func OnDragEnded(_event) -> void:
	pass

# ── 槽位链接 ──────────────────────────────────────────────────────────

## LinkSlot（:545）
func LinkSlot(card_slot) -> void:
	_current_card_slot = card_slot

## UnlinkSlot（:575）——解链＋卡视图对齐回根位
func UnlinkSlot() -> void:
	_current_card_slot = null
	if _card_view != null and is_instance_valid(_card_view):
		_card_view.position = (_card_view as Control).position   # transform.position 对齐（:585-588）
		_card_view._visual_root.position = Vector2.ZERO          # visualRoot 归零（:589-592＝拖尾层；
		                                                           # 旧写 tween 层系错层，unlink 后残余不自清）

## EnableInteraction（:595）——命中层开（HitRect）
func EnableInteraction() -> void:
	if _card_view._hit_rect != null:
		_card_view._hit_rect.mouse_filter = Control.MOUSE_FILTER_STOP

## DisableInteractionAndUnlink（:600）
func DisableInteractionAndUnlink() -> void:
	UnlinkSlot()
	_is_selected = false
	if _card_view._hit_rect != null:
		_card_view._hit_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

## DisableInteraction（:609）
func DisableInteraction() -> void:
	_is_selected = false
	if _card_view._hit_rect != null:
		_card_view._hit_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

## SelectCard（:615）——广播 CardSelected
func SelectCard() -> void:
	CardSelected.emit(self)

## OnSelect（:624）/ OnDeselect（:671）/ ForceHover（:664）——手柄选牌族，缓后（登记#3）
func OnSelect(_selected: bool) -> void:
	pass

func OnDeselect() -> void:
	pass

func ForceHover() -> void:
	OnHoverStarted(null)

# ── 每帧链（Update :753）──────────────────────────────────────────────

func _process(delta: float) -> void:
	_time_since_last_card_interaction += delta
	UpdateHandTilt(delta)
	UpdatePosition(delta)
	RotateToFollowVelocity(delta)
	CheckForHoveringPlayablePos()
	if _is_hovering or _is_dragging:
		_card_view.CheckTooltipScreenPos()

## CheckForHoveringPlayablePos（:811）——拖拽越线检测，缓后（登记#4），占位
func CheckForHoveringPlayablePos() -> void:
	pass

## StartInteraction（:773）——独占校验＋广播＋悬停动画
func StartInteraction() -> void:
	InteractionStarted.emit(self)
	_time_since_last_card_interaction = 0.0
	DoCardHoveredAnim()

## EndInteraction（:790）——收悬停动画＋广播
func EndInteraction() -> void:
	_is_hovering = false
	DoCardUnhoveredAnim()
	InteractionEnded.emit(self)
	_card_view._tween_container.rotation = 0.0   # _hoverOffset.localRotation 归零（:807）

## OnHoverStarted（:1420）——IsHoverable 门＋独占＋起交互；
## 飞行中不接悬停（2026-11-12 用户令：抽牌动画中不放大，落地后鼠标仍指着→事件自然再进）
func OnHoverStarted(_event) -> void:
	if not IsHoverable:
		return
	if not _can_interact():
		return
	if _card_view.has_meta("fly_speed") or _card_view.modulate.a < 0.99:
		return
	_is_hovering = true
	StartInteraction()

## OnHoverEnded（:1719）
func OnHoverEnded(_event) -> void:
	EndInteraction()

## OnCardClicked（:1410）——点击＝广播 CardSelected（点击施放，2026-11-01 用户裁定）
func OnCardClicked(_event) -> void:
	if not _can_interact():
		return
	CardSelected.emit(self)

## 交互门（我方扩展：终局/敌方回合关交互——原版＝PlayerTurnState 外输入失效的同位职能；
## 屏以 meta "interaction_allowed" 注入（默认按 player_model.phase 判））
func _can_interact() -> bool:
	if _card_view.has_meta("interaction_allowed"):
		return bool(_card_view.get_meta("interaction_allowed"))
	var pm = _card_view.get_meta("player_model", null)
	if pm == null:
		return true
	return String(pm.phase) == "player"

## UpdateHandTilt（:908）——VisualRoot 旋钮向**槽位旋钮全值**贴合（Quaternion.Lerp 速率
## slottedRotationMatchSpeed 0.2）：槽位旋钮带布局层 ±15°（FanCardRotation）→ 静态扇角
## 完整可见（2026-11-12 弧案翻案后归位：旧 ×(3.5/15) 缩幅系「速度层钳幅」误读——
## ±3.5° 属 RotateToFollowVelocity 速度层，两者写不同节点、互不覆盖）
func UpdateHandTilt(delta: float) -> void:
	if _current_card_slot == null or _card_view == null:
		return
	var slot_rot: float = (_current_card_slot as Control).rotation
	var k: float = 1.0 - pow(1.0 - VC.INTERACTABLE["slottedRotationMatchSpeed"], delta * 60.0)
	NBU.SetEulerAnglesIfDifferent(_card_view._visual_root,
		lerpf(_card_view._visual_root.rotation, slot_rot, k))

## UpdatePosition（:944）——双层跟随：
## 层1 卡根：目标＝槽心−卡心在壳内偏移（非拖拽分支 :1151-1171）；速度上限
## draggedPositionChangeSpeed 1000；抽牌微滑期以 meta fly_speed/fly_decel 覆盖（真值档 v0.2）
## 层2 VisualRoot：视觉拖尾（死区 0.0001＋指数趋近 clamp 1，:1216-1253）
func UpdatePosition(delta: float) -> void:
	if _current_card_slot == null or _card_view == null or not is_instance_valid(_card_view):
		return
	# 锁位（AreCardPositionsLocked 真义＝卡位不追槽：交互后 0.5s 内邻牌不收拢；
	# 飞行中的卡不受锁——出场微滑必须入格）
	if not _card_view.has_meta("fly_speed"):
		var holder = (_current_card_slot as Node).get_parent()
		if holder != null and holder.has_method("AreCardPositionsLocked") \
				and holder.AreCardPositionsLocked():
			return
	var root: Control = _card_view
	var slot: Control = _current_card_slot
	var target: Vector2 = slot.position + slot.size * 0.5 - VC.CARD_CENTER_IN_SHELL
	var to := target - root.position
	if to.length() > 0.00001:            # 方向死区 1E-05（:1101）
		# 2026-11-13 ISIL 定案：原版 UpdatePosition 直接写位置（NBUtil.SetPositionIfDifferent），
		# 速度＝min(1000, dist/dt) 自然减速——不走 mover、无 500 覆盖、无减速带；
		# mover（SetSpeed/SetTargetPosition）仅住 DoCardHoveredAnim 悬停层
		var speed: float = VC.INTERACTABLE["draggedPositionChangeSpeed"]   # 1000（:1135, 0x502BBBC）
		var step := to.length()
		step = minf(step, speed * delta)
		NBU.SetPositionIfDifferent(root, root.position + to / to.length() * step)
		if (target - root.position).length_squared() < 0.6:
			if root.has_meta("anim_t0"):    # [VCANIM] 临时（验收完删）：微滑落地时刻＋残余误差
				print("[VCANIM] draw-land uid=%s +%dms err=%.1f" % [
					root.get_meta("hand_uid", -1),
					Time.get_ticks_msec() - int(root.get_meta("anim_t0")),
					(target - root.position).length()])
				root.remove_meta("anim_t0")
			root.position = target
			root.remove_meta("fly_speed")   # 落地：飞行标记退役（锁豁免/悬停门恢复）
	# 层2 视觉拖尾（visualRoot local → 0；速度值坏点——draggedFollowSpeed 30 候选，登记待 ISIL）
	var vr: Control = _card_view._visual_root
	var dead := 0.0001                   # :1216
	if vr.position.length_squared() >= dead:
		var t: float = clampf(VC.INTERACTABLE["draggedFollowSpeed"] * delta, 0.0, 1.0)
		NBU.SetLocalPositionIfDifferent(vr, vr.position.lerp(Vector2.ZERO, t))

## RotateToFollowVelocity（:1294）——视觉层旋钮＝速度驱动、限幅 rotationDegrees 3.5°；
## 速度源＝卡根−视觉层位置差（root 移动时 visual 滞后产生角速度）
func RotateToFollowVelocity(delta: float) -> void:
	if _card_view == null or not is_instance_valid(_card_view):
		return
	var root: Control = _card_view
	var vr: Control = _card_view._visual_root
	var vel: Vector2 = root.position - vr.position - _prev_tween_pos
	_prev_tween_pos = root.position - vr.position
	# 平滑＋clamp 1f（deltaTime 平滑 :1317-1352）
	_follow_velocity = _follow_velocity.lerp(vel, clampf(delta * 30.0, 0.0, 1.0))
	# 角速度→旋钮：rotationVelMult 0.4×横向速度，限幅 ±3.5°（draggedRotationAmountDegrees）
	var deg: float = clampf(_follow_velocity.x * VC.INTERACTABLE["rotationVelMult"] * 0.1,
		-VC.INTERACTABLE["rotationDegrees"], VC.INTERACTABLE["rotationDegrees"])
	NBU.SetEulerAnglesIfDifferent(_card_view._tween_container, deg_to_rad(deg))

## DoCardHoveredAnim（:1796）——两档放大＋抬升（hoverCardConfig 全段实测：
## 可付费 scaleTo 1.5/hoverHeightOffset 38；不可付费 invalidScaleTo 1.05/invalidHeightOffset 15
## ——汇编 cmovne +2B4/+2D8 二选一机关，资产 :239/:247 直读，坏点已破）
func DoCardHoveredAnim() -> void:
	var pm = _card_view.get_meta("player_model", null)
	var afford: bool = _card_view._can_afford(pm)
	var scl: Vector2 = VC.HOVER_CARD["scaleTo"] if afford else VC.HOVER_CARD["invalidScaleTo"]
	_hover_lift = VC.HOVER_CARD["hoverHeightOffset"] if afford else VC.HOVER_CARD["invalidHeightOffset"]
	_card_view.ScaleTo(scl, VC.HOVER_CARD["scaleDuration"], VC.EASE_IN_OUT_CUBIC, 0.0)

## DoCardUnhoveredAnim（:1928）——缩放回默认＋抬升归零（mover 回静止位——寻的在 _process）
func DoCardUnhoveredAnim() -> void:
	_hover_lift = 0.0
	_card_view.ResetScale(VC.HOVER_CARD["scaleDuration"], 0.0, VC.EASE_OUT_BACK)

## DoCardHoveringPlayablePositionAnim（:1957）——拖拽越线放大，缓后（登记#4），占位
func DoCardHoveringPlayablePositionAnim(_past_threshold: bool) -> void:
	pass

## OnTooltipsToggled（:2010）
func OnTooltipsToggled() -> void:
	_card_view.ToggleTooltips(_is_selected)

# ── 我方扩展（登记）：悬停抬升寻的（原版＝TransformMover2D 驱动 _hoverOffset）────────

## 悬停抬升目标（屏每帧调——由 HandPileView 驱动统一节拍）：TweenContainer y 寻的
func HoverOffsetSeek(delta: float) -> void:
	if _card_view == null or not is_instance_valid(_card_view):
		return
	var tc: Control = _card_view._tween_container
	var shake := 0.0
	if _card_view.shake_t > 0.0:
		_card_view.shake_t -= delta
		if _card_view.shake_t <= 0.0:
			_card_view.shake_t = 0.0
		else:
			shake = sin(_card_view.shake_t * TAU * 15.0) * _card_view.SHAKE_AMP \
				* (_card_view.shake_t / _card_view.SHAKE_TIME)
	var target := Vector2(shake, -_hover_lift)
	var d := target - tc.position
	var dist := d.length()
	var speed: float = VC.HOVER_CARD["moveSpeed"]
	var decel: float = VC.HOVER_CARD["decelerateDistance"]
	if dist <= 0.001:
		tc.position = target
		return
	if dist < decel:
		speed = speed * clampf(dist / decel, 0.02, 1.0)
	var step := speed * delta
	tc.position = target if step >= dist else tc.position + d / dist * step

func IsHovering() -> bool:
	return _is_hovering
