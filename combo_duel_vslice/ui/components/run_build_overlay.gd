class_name RunBuildOverlay
extends ColorRect

## 输入完整 RunBuildDTO，并把五个分页组件组合为本局构筑页面。
## 输出消耗品、功法与内功的用户意图 signal，由 run_main 唯一转发命令。
## 不持有 RunSession；快照替换或关闭前会明确处理未保存草稿。

signal close_requested
signal consumable_query_requested(slot_index: int)
signal consumable_use_requested(
    slot_index: int,
    selected_instance_ids: Array,
    choice_payload: Dictionary)
signal hand_loadout_save_requested(hand_id: String, technique_ids: Array)
signal inner_skill_loadout_save_requested(
    equipped_inner_skill_ids: Array,
    technique_slot_index: int)
signal inner_skill_forget_requested(inner_skill_id: String)

const UiDesignScript = preload("res://ui/ui_design.gd")
const DeckPanelScene = preload(
    "res://ui/components/run_deck_panel.tscn")
const ConsumablePanelScene = preload(
    "res://ui/components/run_consumable_panel.tscn")
const TechniquePanelScene = preload(
    "res://ui/components/run_technique_loadout_panel.tscn")
const InnerSkillPanelScene = preload(
    "res://ui/components/run_inner_skill_loadout_panel.tscn")
const ItemPanelScene = preload(
    "res://ui/components/run_item_inventory_panel.tscn")
const SelectionDialogScene = preload(
    "res://ui/components/run_card_selection_dialog.tscn")

var deck_panel: RunDeckPanel
var consumable_panel: RunConsumablePanel
var technique_panel: RunTechniqueLoadoutPanel
var inner_skill_panel: RunInnerSkillLoadoutPanel
var item_panel: RunItemInventoryPanel
var selection_dialog: RunCardSelectionDialog
var tabs: TabContainer
var _status: Label
var _build: RunBuildDTO
var _pending_build: RunBuildDTO
var _confirm_discard: ConfirmationDialog
var _discard_action: String = ""
var _built := false

func _ready() -> void:
    _ensure_built()

func present(build: RunBuildDTO, preserve_drafts: bool = false) -> void:
    _ensure_built()
    if not preserve_drafts and _build != null and has_unsaved_changes():
        _pending_build = build
        _discard_action = "snapshot"
        _confirm_discard.dialog_text = "构筑中有未保存草稿。放弃草稿并刷新当前构筑吗？"
        _confirm_discard.popup_centered()
        return
    _apply_build(build, preserve_drafts)

func present_consumable_query(slot_index: int, query: Dictionary) -> void:
    if _build == null:
        return
    selection_dialog.present_query(slot_index, query, _build)

func close_consumable_dialog() -> void:
    selection_dialog.visible = false

func request_close() -> void:
    if has_unsaved_changes():
        _discard_action = "close"
        _confirm_discard.dialog_text = "构筑中有未保存草稿。放弃草稿并返回地图吗？"
        _confirm_discard.popup_centered()
        return
    visible = false
    close_requested.emit()

func has_unsaved_changes() -> bool:
    return (
        technique_panel != null and technique_panel.has_unsaved_changes()
        or inner_skill_panel != null and inner_skill_panel.has_unsaved_changes())

func mark_hand_saved(hand_id: String) -> void:
    technique_panel.mark_saved(hand_id)

func mark_inner_skill_saved() -> void:
    inner_skill_panel.mark_saved()

func _apply_build(build: RunBuildDTO, preserve_drafts: bool) -> void:
    _build = build
    deck_panel.present(build)
    consumable_panel.present(build)
    technique_panel.present(build, preserve_drafts)
    inner_skill_panel.present(build, preserve_drafts)
    item_panel.present(build)
    _status.text = (
        "可编辑 · 真气 %d · 消耗品 %d/%d · 历练 %d" % [
            build.cards.size(), _filled_consumables(build),
            build.consumable_limit, build.experience]
        if build.editable
        else "只读 · %s · 真气 %d · 消耗品 %d/%d · 历练 %d" % [
            build.blocked_reason, build.cards.size(),
            _filled_consumables(build), build.consumable_limit,
            build.experience])
    visible = true

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    color = Color(0.015, 0.02, 0.025, 0.96)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visible = false
    # 地图节点、奖励和战斗层之上均可打开只读构筑。
    z_index = 400
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 48)
    margin.add_theme_constant_override("margin_right", 48)
    margin.add_theme_constant_override("margin_top", 32)
    margin.add_theme_constant_override("margin_bottom", 32)
    add_child(margin)
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(
            Color("172126"), 18, Color("56717a"), 3, 12))
    margin.add_child(panel)
    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 10)
    panel.add_child(page)
    var header := HBoxContainer.new()
    var title := Label.new()
    title.text = "本 局 构 筑"
    title.add_theme_font_size_override("font_size", 28)
    header.add_child(title)
    _status = Label.new()
    _status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(_status)
    var close := Button.new()
    close.text = "返回地图"
    close.pressed.connect(request_close)
    header.add_child(close)
    page.add_child(header)
    tabs = TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tabs.custom_minimum_size = Vector2(1180, 680)
    deck_panel = DeckPanelScene.instantiate()
    consumable_panel = ConsumablePanelScene.instantiate()
    technique_panel = TechniquePanelScene.instantiate()
    inner_skill_panel = InnerSkillPanelScene.instantiate()
    item_panel = ItemPanelScene.instantiate()
    _add_tab("真气", deck_panel)
    _add_tab("消耗品", consumable_panel)
    _add_tab("功法", technique_panel)
    _add_tab("内功", inner_skill_panel)
    _add_tab("物品", item_panel)
    page.add_child(tabs)
    consumable_panel.slot_activated.connect(
        func(slot_index: int): consumable_query_requested.emit(slot_index))
    technique_panel.save_requested.connect(
        func(hand_id: String, ids: Array):
            hand_loadout_save_requested.emit(hand_id, ids))
    inner_skill_panel.save_requested.connect(
        func(ids: Array, position: int):
            inner_skill_loadout_save_requested.emit(ids, position))
    inner_skill_panel.forget_requested.connect(
        func(inner_skill_id: String):
            inner_skill_forget_requested.emit(inner_skill_id))
    selection_dialog = SelectionDialogScene.instantiate()
    selection_dialog.use_requested.connect(
        func(slot_index: int, ids: Array, payload: Dictionary):
            consumable_use_requested.emit(slot_index, ids, payload))
    add_child(selection_dialog)
    _confirm_discard = ConfirmationDialog.new()
    _confirm_discard.title = "放弃未保存草稿"
    _confirm_discard.confirmed.connect(_confirm_discard_drafts)
    add_child(_confirm_discard)

func _add_tab(tab_name: String, component: Control) -> void:
    var scroll := ScrollContainer.new()
    scroll.name = tab_name
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    component.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    component.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.add_child(component)
    tabs.add_child(scroll)

func _confirm_discard_drafts() -> void:
    technique_panel.discard_drafts()
    inner_skill_panel.discard_draft()
    if _discard_action == "snapshot" and _pending_build != null:
        var next_build := _pending_build
        _pending_build = null
        _discard_action = ""
        _apply_build(next_build, false)
        return
    _discard_action = ""
    visible = false
    close_requested.emit()

func _filled_consumables(build: RunBuildDTO) -> int:
    var count := 0
    for slot in build.consumables:
        if str(slot.get("id", "")) != "":
            count += 1
    return count
