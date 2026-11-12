## 原版 CardSlot 1:1（全局命名空间 CardSlot.cs，104 行）——手牌槽位（100×100，锚 (0,0)-(0,0) 底左）。
## 幽灵槽三法（SetGhost/SetGhostInstant/SetHiddenGhost）属「幽灵槽＋手牌上限」缓后子系统
## （差异登记#5）——方法保留占位，GhostVisual 未建。
## 引擎映射：MonoBehaviour → Control；CanvasGroupFader 幽灵视觉未搬（随缓后子系统）。
extends Control

var _slotted_interactable_card = null    # _slottedInteractableCard（CardSlot.cs:28）→ InteractableCard
var _ghost_visual = null                 # _ghostVisual（:30）——缓后未建

func _init() -> void:
	# CardSlot.prefab:61 根 RectTransform sizeDelta 100×100；锚 (0,0)-(0,0) 底左
	# （prefab anchors 实测——「锚定律」：底左锚＋代码零 Y 干预＝平排的来源）
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(100.0, 100.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## SlottedInteractableCard 属性（CardSlot.cs:32）
func SlottedInteractableCard():
	return _slotted_interactable_card

## LinkCard（CardSlot.cs:34）——双向链接：槽记卡、卡记槽（card.LinkSlot(this)）
func LinkCard(interactable_card) -> void:
	_slotted_interactable_card = interactable_card
	if interactable_card != null:
		interactable_card.LinkSlot(self)

## SetGhost（CardSlot.cs:56）——幽灵槽淡入淡出（缓后子系统，差异登记#5；接入时补 CanvasGroupFader）
func SetGhost(_is_ghost: bool, _delay := 0.0, _on_complete: Callable = Callable()) -> void:
	pass

## SetGhostInstant（CardSlot.cs:65）——缓后同上
func SetGhostInstant(_is_ghost: bool) -> void:
	pass

## SetHiddenGhost（CardSlot.cs:86）——缓后同上
func SetHiddenGhost() -> void:
	pass
