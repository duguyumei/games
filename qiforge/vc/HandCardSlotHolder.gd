## 原版 HandCardSlotHolder 1:1（Nosebleed.Pancake.View/HandCardSlotHolder.cs，6398 行）——核心法集。
## 缓后法（登记）：手柄/键盘选牌状态机族（HandleControllerInput/MoveSelection/JumpToNextGroup/
## CheckForSelectInput/OnSelectionStarted/TrySelectCard/CheckAutoPlay/CheckDragState/
## CheckSortButtonState/StartDragging/WaitForPosition…约 30 法，#3）；幽灵槽族
## （InitializeGhostSlots/RevealGhostsStaggered/GrowGhostSlots*/BeginGhostsFadeOut/
## FadeOutGhostsAfterDelay/ForceClearGhosts/RemoveCardWithGhostShift 幽灵段，#5）；
## 排序自动触发段（AwaitCommandRunnerAndSort/TrySelectPlayableCard/IsHandStillSorted/
## CompareByMana/CompareByColor，#2）。
## 锁位语义（2026-11-12 ISIL 定案，HandCardSlotHolder.txt get_AreCardPositionsLocked/OnCardInteracted
## ＋csall Update:3728/OnCardAdded:4350/OnCardPlayed:6007）：timer 每帧**递增**（unscaledDeltaTime），
## locked＝timer < 0.5；**无条件清零源＝加牌/打出/回合开始**；OnCardInteracted（悬停路径）只在
## **已锁**时清零续锁——**悬停从不引入锁**，空手悬停＝劈开即时生效（我方旧版「悬停即清零」
## ＝「指上去要过一小会儿邻牌才让位」真凶，2026-11-12 用户 F6 抓出已修）。
## OnCardInteracted 订阅的原版事件名未从反编译噪声读出（OnEnable 委托构造为地址常量）——
## 现按悬停路径挂，登记开放。
extends "res://qiforge/vc/CardSlotHolder.gd"

var _card_reorder_delay := 0.5                  # _cardReorderDelay（FloatAsset→GlobalConfig 真值）
var _time_since_last_card_interaction := 0.0    # _timeSinceLastCardInteraction（:2473）
var _hand_size_limit_active := false            # _handSizeLimitActive（:2461）——上限默认关（登记#5）
var _current_hover_index := -1                  # _currentHoverIndex（:2477）

## Start（:3549）——初始化
func _ready() -> void:
	_card_reorder_delay = VC.HAND_PILE["defaultCardReorderDelayTime"]

## AreCardPositionsLocked（:2549-2583）——控制指针方案或交互后 0.5s 内锁位
##（控制方案缓后——仅交互延迟条件生效）
func AreCardPositionsLocked() -> bool:
	return _time_since_last_card_interaction < _card_reorder_delay

## IsHandSizeLimitGhostModeActive（:2567）——上限关＝恒 false
func IsHandSizeLimitGhostModeActive() -> bool:
	return _hand_size_limit_active and false

## GhostSlotCount（:2572）
func GhostSlotCount() -> int:
	return 0

## ActiveCardCount（:2585）
func ActiveCardCount() -> int:
	return _active_card_slots.size()

## AcquireSlotShiftsSelection（:2596）——幽灵模式关＝基类 true
func AcquireSlotShiftsSelection() -> bool:
	return true

## SortedSlotStartIndex（:2599）——幽灵模式关＝0
func SortedSlotStartIndex() -> int:
	return 0

## AddCardToBottom（:2630）——手牌底加（幽灵揭示段缓后）；原版尾段 OnCardAdded **无条件清零
## 计时**（:4350）＝加牌引入 0.5s 锁（新牌落位期间邻牌不动）
func AddCardToBottom(card: Dictionary) -> void:
	super(card)
	ResetInteractionTimer()

## AddCardToTop（:2673）
func AddCardToTop(card: Dictionary) -> void:
	super(card)
	ResetInteractionTimer()

## GetCardSlotForBottom（:2680）——幽灵区段缓后＝基类行为
## GetCardViewSiblingIndex（:2713）——同上

## TryRemoveCard（:2730）——原版走 RemoveCardWithGhostShift（幽灵左移段缓后＝基类行为＋锁位重排）
func TryRemoveCard(card: Dictionary) -> void:
	super(card)

# —— 幽灵槽族（#5 缓后）占位
func RevealGhostsStaggered() -> void:
	pass

func InitializeGhostSlots() -> void:
	pass

func GrowGhostSlotsToCapacity() -> void:
	pass

func ForceClearGhosts() -> void:
	pass

## OnTurnStarted（:3199）——回合开始：交互计时清零
func OnTurnStarted() -> void:
	_time_since_last_card_interaction = 0.0

## OnEncounterEnding（:3294）——遭遇结束（幽灵淡出段缓后）
func OnEncounterEnding() -> void:
	pass

## Update（:3629）——手柄输入主循环（缓后#3）；本件驱动＝交互计时
##（锁位真义＝InteractableCard.UpdatePosition 不追槽——槽位布局即时刷新、卡 0.5s 后才收拢）
func _process(delta: float) -> void:
	_time_since_last_card_interaction += delta

## OnCardAdded（:4327）——加牌后自动排序/选牌（排序子系统缓后，占位）
func OnCardAdded(_card: Dictionary, _added_card_index: int, _playable_cards_before_adding: int) -> void:
	pass

## OnCardInteracted（:5996，ISIL :9791-9846 直译）——**仅已锁时清零续锁**（`delay > timer`
## 才写 0；未锁时无操作）：悬停从不引入锁，只能延长既有锁（旧版无条件清零＝悬停延迟真凶）
func OnCardInteracted(_card) -> void:
	if _time_since_last_card_interaction < _card_reorder_delay:
		_time_since_last_card_interaction = 0.0

func OnCardPlayed(_card) -> void:
	_time_since_last_card_interaction = 0.0

func ResetInteractionTimer() -> void:
	_time_since_last_card_interaction = 0.0

## GetNumberOfPlayableSlottedCards（:6020）/ TryGetFirstPlayableCardIndex（:6172）——
## 手柄自动选牌用（缓后#3），占位
func GetNumberOfPlayableSlottedCards() -> int:
	return 0

func TryGetFirstPlayableCardIndex() -> int:
	return -1

## DeselectAll（:5963）/ OnAutoPlayerFinished（:5957）——缓后，占位
func DeselectAll() -> void:
	pass

func OnAutoPlayerFinished() -> void:
	pass
