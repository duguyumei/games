extends GutTest

# 备战页交互回归：选中态/按钮联动/装载动作经 UI 路径走通（test_prep 钉纯逻辑，
# 这里钉场景接线——按钮 disabled 状态机、动作落库、标题随行囊变化）。
# 注：场景 _ready 有 await，须等一帧再戳内部；注入的 archive 与渲染统一走 prep 出口。

const TEST_META_PATH := "user://test_prep_ui_meta.json"
const PrepScene := preload("res://scenes/prep/prep.tscn")
const ArchiveScript := preload("res://core/meta/meta_archive.gd")

const STOCK := [
	{"id": "tiejian", "name": "制式铁剑", "type": "weapon", "qty": 1, "value": 15,
		"rarity": "common", "weapon": {"school": "剑法", "level": 1, "base_dur": 3, "effects": []}},
	{"id": "cubu", "name": "粗布行囊", "type": "container", "qty": 1, "value": 10,
		"rarity": "common", "container": {"slots": 5}},
	{"id": "shangyao", "name": "伤药", "type": "consumable", "qty": 3, "value": 10,
		"max_stack": 5, "rarity": "common"},
	{"id": "jinchuang", "name": "金创药", "type": "consumable", "qty": 2, "value": 15,
		"max_stack": 5, "rarity": "common"},
	{"id": "muqiang", "name": "练习木枪", "type": "weapon", "qty": 1, "value": 8,
		"rarity": "common", "weapon": {"school": "枪法", "level": 1, "base_dur": 2, "effects": []}},
]

func after_each() -> void:
	if FileAccess.file_exists(TEST_META_PATH):
		DirAccess.remove_absolute(TEST_META_PATH)

func _seed_archive() -> Node:
	var archive := ArchiveScript.new()
	archive.meta_path = TEST_META_PATH
	add_child_autofree(archive)  # 先入树（_ready 读档），再填货，防止 load_meta 清掉
	for entry in STOCK:
		archive.store_items([entry.duplicate(true)])
	return archive

func _make_prep(archive: Node) -> Control:
	var prep_ui: Control = PrepScene.instantiate()
	add_child_autofree(prep_ui)
	await get_tree().process_frame  # _ready 经帧才落地（含其内部 await）
	prep_ui.prep.setup(archive, {"backpack_size": 5})
	prep_ui._refresh()
	return prep_ui

func test_ui_click_wear_take_stash_flow() -> void:
	var archive := _seed_archive()
	var ui: Control = await _make_prep(archive)
	# 未选中：带走按钮全禁用
	assert_true(ui._btn_take.disabled)
	assert_true(ui._btn_pouch.disabled)
	# 点铁剑＝直接穿上（仓库顺序：行囊/伤药/金创药/木枪）
	ui._on_wh_slot_click(0)
	assert_eq(str(archive.equipped["weapon"]["id"]), "tiejian", "点击装备即穿")
	# 点行囊＝穿上
	ui._on_wh_slot_click(0)
	assert_eq(str(archive.equipped["bag"]["id"]), "cubu", "点击行囊即穿")
	# 点木枪＝替换兵器，铁剑回仓库
	ui._on_wh_slot_click(2)
	assert_eq(str(archive.equipped["weapon"]["id"]), "muqiang", "点击即替换")
	assert_true(archive.warehouse.any(func(w): return str(w.get("id", "")) == "tiejian"), "旧件回仓库")
	# 点消耗品＝选中（供带走按钮用）：伤药可入囊
	ui._select("warehouse", 0)
	assert_false(ui._btn_pouch.disabled, "伤药可入囊")
	ui._on_take()
	assert_eq(ui.prep.backpack.size(), 1, "伤药入购物车")
	assert_eq(int(ui.prep.backpack[0]["qty"]), 3)
	# 金创药贴身 → 锦囊
	ui._select("warehouse", 0)
	ui._on_take_pouch()
	assert_eq(ui.prep.pouch.size(), 1)
	assert_eq(int(ui.prep.pouch[0]["qty"]), 2)
	# 背包格标题随行囊变成 5
	assert_true(("背包 1/5") in ui._cart_title.text)
	# 背包/锦囊格点击＝整堆放回仓库
	ui._on_cart_slot_click(0)
	assert_eq(ui.prep.backpack.size(), 0, "背包格点击放回")
	ui._on_pouch_slot_click(0)
	assert_eq(ui.prep.pouch.size(), 0, "锦囊格点击放回")
	# 身上点击＝卸下回仓库；空槽点击无副作用
	ui._on_wear_slot_click("weapon")
	assert_true(archive.equipped["weapon"].is_empty(), "点击身上即卸下")
	assert_true(archive.warehouse.any(func(w): return str(w.get("id", "")) == "muqiang"), "卸下回仓库")
	ui._on_wear_slot_click("weapon")
	assert_true(archive.equipped["weapon"].is_empty(), "空槽点击无副作用")

func test_ui_depart_payload() -> void:
	var archive := _seed_archive()
	var ui: Control = await _make_prep(archive)
	ui._on_wh_slot_click(0)
	# 出发会切场景——GUT 里不能真切，改为验证载荷可用
	var payload: Dictionary = ui.prep.payload()
	assert_eq(str(payload["equipped"]["weapon"]["id"]), "tiejian")
	assert_true(payload["inventory"].is_empty())
	assert_true(payload["pouch"].is_empty())
