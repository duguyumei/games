## 原版 HandCardSlotHolder 1:1（Nosebleed.Pancake.View/HandCardSlotHolder.cs，6398 行）——核心法集。
## 缓后法（登记）：手柄/键盘选牌状态机族（HandleControllerInput/MoveSelection/JumpToNextGroup/
## CheckForSelectInput/OnSelectionStarted/TrySelectCard/CheckAutoPlay/CheckDragState/
## CheckSortButtonState/StartDragging/WaitForPosition…约 30 法，#3）；幽灵槽族
## （InitializeGhostSlots/RevealGhostsStaggered/GrowGhostSlots*/BeginGhostsFadeOut/
## FadeOutGhostsAfterDelay/ForceClearGhosts/RemoveCardWithGhostShift 幽灵段，#5）；
## 排序自动触发段（AwaitCommandRunnerAndSort/TrySelectPlayableCard/IsHandStillSorted/
## CompareByMana/CompareByColor，#2）。
## AreCardPositionsLocked（:2549-2583）＝本轮新落地：交互后 0.5s 锁牌位（邻牌收拢延迟——
## handPileConfig.defaultCardReorderDelayTime 0.5，GlobalConfig.asset:335-337）。
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

## AddCardToBottom（:2630）——手牌底加（幽灵揭示段缓后）；原版尾段 OnCardAdded 自动排序
## 段属排序子系统（#2 缓后）——仅记交互时刻
func AddCardToBottom(card: Dictionary) -> void:
	super(card)
	OnCardInteracted(null)

## AddCardToTop（:2673）
func AddCardToTop(card: Dictionary) -> void:
	super(card)
	OnCardInteracted(null)

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

## OnCardInteracted（:5996）/ OnCardPlayed（:6007）/ ResetInteractionTimer（:6012）——
## 交互计时清零（0.5s 锁位的驱动源）
func OnCardInteracted(_card) -> void:
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
