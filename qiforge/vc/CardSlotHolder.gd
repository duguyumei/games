## 原版 CardSlotHolder 1:1（Nosebleed.Pancake.View/CardSlotHolder.cs，4258 行）——核心法集。
## 缓后法（登记《原版差异登记》）：排序族 SortHand/SortByMana/SortByColor/GetManaCostPriority/
## GetTypePriority/SetDefaultSortType（#2 排序按钮）；拖拽划槽 Update 检测段（#4 拖拽）；
## 幽灵槽相关（#5）；调试字符串族 FormatAllSlots 等；OnValidate。
## 引擎映射：MonoBehaviour → Control（本件即槽位容器挂件）；BoolVariable 资产 → 常量；
## 槽对象池 Stack<CardSlot> → Array 做栈用。
extends "res://qiforge/vc/HorizontalCardLayoutGroup.gd"

signal CardSelectedEvent(interactable)     # 引擎映射：InteractableCard.CardSelected 转发（屏接出牌）
signal InteractionStartedEvent(interactable)   # 同上：InteractionStarted 转发（屏接预览/浮窗）
signal InteractionEndedEvent(interactable)     # 同上：InteractionEnded 转发

const CARD_SLOT := preload("res://qiforge/vc/CardSlot.gd")

var _card_slot_container: Control = null   # _cardSlotContainer（:208）——本件自身
var _pooled_card_slot_container: Control = null   # _pooledCardSlotContainer（:210）
var _card_slot_prefab := CARD_SLOT         # _cardSlotPrefab（:212）——脚本即 prefab
var _allows_hovering := true               # _allowsHovering（:216，BoolVariable 资产→常量）
var _allows_dragging := false              # _allowsDragging（:218）——拖拽不搬恒 false（登记#4）
var _card_pile_model = null                # _cardPileModel（:220）→ battle 手牌数组代理
var _player_model = null                   # _playerModel（:226）→ battle
var _active_card_slots: Array = []         # _activeCardSlots（:224）
var _current_selected_card_index := -1     # _currentSelectedCardIndex（:228）
var _currently_interacted_card = null      # _currentlyInteractedCard（:230）
var _card_slot_pool: Array = []            # _cardSlotPool（:232）
var _current_sort_type := 0                # _currentSortType（:234）SortType.Default

func _init() -> void:
	super()
	_card_slot_container = self   # 本件即槽位容器（Unity 槽容器引用 → 自指，引擎映射）
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## CurrentSortType（:236）
func CurrentSortType() -> int:
	return _current_sort_type

## AcquireSlotShiftsSelection（:238，虚——基类恒 true）
func AcquireSlotShiftsSelection() -> bool:
	return true

## SortedSlotStartIndex（:240，虚——基类恒 0）
func SortedSlotStartIndex() -> int:
	return 0

## AddCardToBottom（:242-286，ISIL/csall 直读 2026-11-13）——底加＝**最左槽＋卡视图垫底**：
## 池槽 SetAsFirstSibling（:328）＝槽插布局首位（左端→新卡从左进、旧卡右移）；
## 卡视图 SetAsFirstSibling（:269-270）＝渲染/命中垫底（新卡从手牌底下滑入）；
## 有选中卡 → SelectedIndex+1（:272-285，左插入把选中序右移）。
##〔列表同步插首：原版 _activeCardSlots 是 append 序、消费走兄弟序；我方消费走列表序，
## 保持列表＝树序免索引错位——登记〕
func AddCardToBottom(card: Dictionary) -> void:
	var slot = GetCardSlotForBottom(card)
	if slot == null:
		return
	move_child(slot, 0)                       # 槽 SetAsFirstSibling（:328）＝最左
	_active_card_slots.insert(0, slot)
	var interactable = _interactable_of(card)
	if interactable != null:
		slot.LinkCard(interactable)
		InitializeCardInteraction(card, slot)
		var cv = interactable._card_view
		if cv != null and cv.get_parent() != null:
			cv.get_parent().move_child(cv, 0)  # 卡视图 SetAsFirstSibling（:270）＝垫底
	var sel := GetSelectedIndex()             # :277-284 选中序右移
	if sel >= 0 and sel < _active_card_slots.size():
		SetSelectedIndex(sel + 1)
	ForceLayoutRefresh()

## AddCardToTop（:288-318）——顶加＝**最右槽＋卡视图置顶**（:316/:343 SetAsLastSibling 对称）
func AddCardToTop(card: Dictionary) -> void:
	var slot = GetCardSlotForTop(card)
	if slot == null:
		return
	move_child(slot, get_child_count() - 1)   # 槽 SetAsLastSibling（:343）＝最右
	_active_card_slots.push_back(slot)
	var interactable = _interactable_of(card)
	if interactable != null:
		slot.LinkCard(interactable)
		InitializeCardInteraction(card, slot)
		var cv = interactable._card_view
		if cv != null and cv.get_parent() != null:
			cv.get_parent().move_child(cv, cv.get_parent().get_child_count() - 1)
	ForceLayoutRefresh()

## GetCardSlotForBottom（:320）——找空槽，无则取池槽
func GetCardSlotForBottom(card: Dictionary):
	return _find_or_pooled_slot(card)

## GetCardSlotForTop（:335）
func GetCardSlotForTop(card: Dictionary):
	return _find_or_pooled_slot(card)

func _find_or_pooled_slot(card: Dictionary):
	var slot = TryFindSlotForCard(card)
	if slot != null:
		return slot
	return GetPooledCardSlot()

## TryRemoveCard（:350）——找卡所在槽→解绑交互→槽回池
func TryRemoveCard(card: Dictionary) -> void:
	var idx := FindActiveSlotIndexForCard(card)
	if idx < 0:
		return
	var slot: Control = _active_card_slots[idx]
	var interactable = slot.SlottedInteractableCard()
	if interactable != null:
		DetachCardInteractionHandlers(interactable)
	_active_card_slots.remove_at(idx)
	PoolCardSlot(slot)
	ForceLayoutRefresh()

## DetachCardInteractionHandlers（:921）——解绑三事件
func DetachCardInteractionHandlers(interactable) -> void:
	if interactable.InteractionStarted.is_connected(_on_interaction_started):
		interactable.InteractionStarted.disconnect(_on_interaction_started)
	if interactable.InteractionEnded.is_connected(_on_interaction_ended):
		interactable.InteractionEnded.disconnect(_on_interaction_ended)
	if interactable.CardSelected.is_connected(_on_card_selected):
		interactable.CardSelected.disconnect(_on_card_selected)

# —— 排序族（:930-1063）——缓后（差异登记#2），占位保名
func SetDefaultSortType() -> void:
	_current_sort_type = 0

func SortHand(_sort_type: int) -> void:
	pass

func SortByMana() -> void:
	pass

func SortByColor() -> void:
	pass

func GetManaCostPriority(_model: Dictionary) -> int:
	return 0

func GetTypePriority(_model: Dictionary) -> int:
	return 0

func OnPileSorted() -> void:
	pass

## Update（:1253）——拖拽划槽检测（拖拽不搬→空驱动，占位）
func _process(delta: float) -> void:
	OnCardSlotHolderUpdate(delta)

func OnCardSlotHolderUpdate(_delta: float) -> void:
	pass

## InitializeCardInteraction（:1671）——绑 InteractableCard 三事件＋LinkCard
func InitializeCardInteraction(card: Dictionary, card_slot) -> void:
	var interactable = _interactable_of(card)
	if interactable == null:
		return
	if not interactable.InteractionStarted.is_connected(_on_interaction_started):
		interactable.InteractionStarted.connect(_on_interaction_started)
	if not interactable.InteractionEnded.is_connected(_on_interaction_ended):
		interactable.InteractionEnded.connect(_on_interaction_ended)
	if not interactable.CardSelected.is_connected(_on_card_selected):
		interactable.CardSelected.connect(_on_card_selected)
	card_slot.LinkCard(interactable)

## TryFindSlotForCard（:2992）——找空槽（无卡之槽）；引擎映射：C# out 参数 → 返回槽或 null
func TryFindSlotForCard(_card: Dictionary):
	for s in _active_card_slots:
		if s.SlottedInteractableCard() == null:
			return s
	return null

## OnCardInteractionStarted（:3154）——记录当前交互卡＋定位选中序号
func OnCardInteractionStarted(interactable) -> void:
	_currently_interacted_card = interactable
	FindAndSetCurrentSelected(interactable)

## OnCardInteractionEnded（:3679）——清当前交互卡
func OnCardInteractionEnded(_interactable) -> void:
	_currently_interacted_card = null

func _on_interaction_started(interactable) -> void:
	OnCardInteractionStarted(interactable)
	InteractionStartedEvent.emit(interactable)

func _on_interaction_ended(interactable) -> void:
	OnCardInteractionEnded(interactable)
	InteractionEndedEvent.emit(interactable)

## CurrentSelectedCardIndex 属性（_currentSelectedCardIndex 读口）
func CurrentSelectedCardIndex() -> int:
	return _current_selected_card_index

func _on_card_selected(interactable) -> void:
	CardSelectedEvent.emit(interactable)

## GetCardViewSiblingIndex（:3741）——槽在布局中的序号
func GetCardViewSiblingIndex(slot) -> int:
	return _active_card_slots.find(slot)

## PoolCardSlot（:3756）——槽回池：入栈＋出活跃表＋挪池容器＋隐藏
func PoolCardSlot(to_pool) -> void:
	_card_slot_pool.push_back(to_pool)
	_active_card_slots.erase(to_pool)
	if _pooled_card_slot_container != null and to_pool.get_parent() != _pooled_card_slot_container:
		to_pool.reparent(_pooled_card_slot_container, false)
	to_pool.visible = false

## GetPooledCardSlot（:3766）——池空则建（Instantiate prefab）、否则出栈；挂容器＋显示
##（引擎映射：Unity SetParent 直接换爹 → Godot 须 reparent，add_child 拒收有父节点）
func GetPooledCardSlot():
	var slot: Control = null
	if _card_slot_pool.is_empty():
		slot = CARD_SLOT.new()
	else:
		slot = _card_slot_pool.pop_back()
	if slot.get_parent() != _card_slot_container:
		if slot.get_parent() != null:
			slot.reparent(_card_slot_container, false)
		else:
			_card_slot_container.add_child(slot)
	slot.visible = true
	return slot

## TrySetLayoutGroupIndex（:3823）——布局组选中序号（悬停劈开的驱动位）
func TrySetLayoutGroupIndex(index: int) -> void:
	SetSelectedIndex(index)

## FindAndSetCurrentSelected（:3977）——定位当前交互卡 index
func FindAndSetCurrentSelected(interactable) -> void:
	for i in _active_card_slots.size():
		var s = _active_card_slots[i]
		if s.SlottedInteractableCard() == interactable:
			_current_selected_card_index = i
			return
	_current_selected_card_index = -1

## FindActiveSlotIndexForCard（HandCardSlotHolder.cs:3027 同名；基类共用）——按卡定槽序
func FindActiveSlotIndexForCard(card: Dictionary) -> int:
	var uid := int(card.get("uid", -1))
	for i in _active_card_slots.size():
		var s = _active_card_slots[i]
		var it = s.SlottedInteractableCard()
		if it != null and it._card_view.has_meta("hand_uid") \
				and int(it._card_view.get_meta("hand_uid")) == uid:
			return i
	return -1

## 卡字典 → InteractableCard（经 uid 查 HandPileView 视图表——引擎映射：原版 CardModel._cardView 直引；
## HandPileView 以 meta "interactable_of" 注入查询函数）
func _interactable_of(card: Dictionary):
	var fn: Callable = get_meta("interactable_of", Callable())
	if fn.is_valid():
		return fn.call(card)
	return null
