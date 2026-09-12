extends Node

# 局外仓库与角色穿戴（备战层数据，跨局持久化）：撤离成功背包/锦囊入库（同 id 叠数量），
# 死亡/力竭物资全丢不入库；穿戴栏是角色状态——撤离原样带回（含耐久），倒下即散失。
# 与远征存档分离（user://meta_save.json）。制作/购买/升级/图鉴等据点系统随立项再扩。
# 注：autoload 名即 MetaArchive，脚本不写 class_name（Godot 禁止同名遮蔽）。

# v1：仓库＋锦囊格数。v2（M4）：仓库收装备实例（{id,uid,dur} 不叠堆）＋uid 发号器；
# v3（C-027）：穿戴栏 equipped 入档（跨局角色状态；旧 v1/v2 档免迁移直读，穿戴为空）。
# v4：备战购物车 prep_cart 入档（搜打撤档案逻辑——出发装配持续保存，退出/重进/崩溃不丢；
# 出发 consume_cart 清车，物资生死交给局内结算）。旧 v1~v3 档免迁移直读，车为空。
# v5（D-060）：已学功法/心法清单（研读秘籍习得，参悟即蚀）＋构筑配置 loadout
# （功法 4 位/心法 5 平权槽，上阵组合）。旧档免迁移直读，默认取 player.json 初始构筑。
# v6（D-062）：账面资产——银两（钱包，获取渠道随折银/商店后置）＋历练（积累展示，
# 作用后置；获取＝胜仗/撤离/研读）。旧档免迁移直读，均从 0 起。
const META_VERSION := 6
# 项目改名（战斗沙盒→禁地牌局）前的旧 user:// 根目录名，用于一次性存档迁移
const LEGACY_PROJECT_NAME := "江湖险地：战斗沙盒"
# 贴身锦囊格数：局外升级（初始 1 封顶 3；据点设施/商店立项后由它驱动，set_pouch_slots 占位）。
const POUCH_SLOTS_MIN := 1
const POUCH_SLOTS_MAX := 3
# 构筑配置常数（27 号；后续可调）：功法随身位数与心法平权槽数
const TECHNIQUE_SLOTS := 4
const XINFA_SLOTS := 5
# 历练获取（数值占位进《10》）：胜仗 / 撤离成功 / 研读秘籍
const EXP_PER_BATTLE_WIN := 2
const EXP_PER_EXTRACTION := 3
const EXP_PER_STUDY := 1

# 测试可改写路径（裸实例 + 注入时用）
var meta_path := "user://meta_save.json"
# 仓库物品与背包同构：{id, name, qty, value, rarity, ...}；装备实例带 uid/dur 且永不叠堆。
var warehouse: Array = []
var pouch_slots := POUCH_SLOTS_MIN
# 装备实例 uid 发号器（跨局唯一；BoardState.issue_uid 接线到这里）
var uid_next := 1
# 穿戴栏（C-027 角色状态）：三槽装备实例，撤离带回/死亡散失；备战页（ExpeditionPrep）
# 在这里换装，ExpeditionSession 结算时写回。编解码复用 BoardCodec.read_equipped。
var equipped := {"weapon": {}, "armor": {}, "bag": {}}
# 备战购物车（v4 角色状态）：出发装配的背包/锦囊，与穿戴同构持续保存——
# ExpeditionPrep.setup 直接绑这两列数组（一切增删即改档案，save_meta 即落盘）；
# 出发时 consume_cart 清空，物资转入远征档由结算定生死。
var prep_cart := {"backpack": [], "pouch": []}
# 已学清单（v5）：研读秘籍习得的功法/心法。参悟即蚀——同一门只在清单上出现一次。
var learned_techniques: Array = []
var learned_xinfa: Array = []
# 构筑配置（v5）：上阵的功法 4 位与心法 5 槽（从已学清单里选，同名唯一）。
var loadout := {"techniques": [], "xinfa": []}
# 账面资产（v6，D-062）：银两＝钱包货币（折银/商店后置）；历练＝闯荡积累
# （胜仗/撤离/研读获取，只展示不消费，作用随《10》数值框架再挂）。
var silver := 0
var experience := 0

func _ready() -> void:
	_migrate_legacy_saves()
	load_meta()

# 项目改名会更换 user:// 根目录（app_userdata/<项目名>）：把旧目录里的两份存档
# 一次性拷到新目录（新目录已有同名档则不覆盖）。本 autoload 排最前，迁移先于所有读取。
func _migrate_legacy_saves() -> void:
	var new_root := ProjectSettings.globalize_path("user://")
	var legacy_root: String = new_root.get_base_dir().path_join(LEGACY_PROJECT_NAME)
	if not DirAccess.dir_exists_absolute(legacy_root):
		return
	var dir := DirAccess.open(legacy_root)
	if dir == null:
		return
	for save_name in ["meta_save.json", "expedition_save.json"]:
		var src := legacy_root.path_join(save_name)
		var dst := new_root.path_join(save_name)
		if not FileAccess.file_exists(dst) and FileAccess.file_exists(src):
			if dir.copy(src, dst) == OK:
				print("已迁移旧项目存档：", save_name)

func load_meta() -> void:
	warehouse = []
	uid_next = 1
	prep_cart = {"backpack": [], "pouch": []}
	equipped = BoardCodec.read_equipped({})
	_load_learned_defaults()
	if not FileAccess.file_exists(meta_path):
		return
	var file := FileAccess.open(meta_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var version := int((parsed as Dictionary).get("version", 0))
	if version < 1 or version > META_VERSION:
		return
	warehouse = (parsed as Dictionary).get("warehouse", [])
	pouch_slots = clampi(int((parsed as Dictionary).get("pouch_slots", POUCH_SLOTS_MIN)), POUCH_SLOTS_MIN, POUCH_SLOTS_MAX)
	uid_next = maxi(1, int((parsed as Dictionary).get("uid_next", 1)))
	if version >= 3:
		equipped = BoardCodec.read_equipped((parsed as Dictionary).get("equipped", {}))
	if version >= 4:
		var cart: Dictionary = (parsed as Dictionary).get("prep_cart", {})
		prep_cart["backpack"] = _cart_items(cart.get("backpack", []))
		prep_cart["pouch"] = _cart_items(cart.get("pouch", []))
	if version >= 5:
		var saved_learned: Dictionary = (parsed as Dictionary).get("learned", {})
		learned_techniques = _string_items(saved_learned.get("techniques", []))
		learned_xinfa = _string_items(saved_learned.get("xinfa", []))
		var saved_loadout: Dictionary = (parsed as Dictionary).get("loadout", {})
		loadout["techniques"] = _string_items(saved_loadout.get("techniques", loadout["techniques"]))
		loadout["xinfa"] = _string_items(saved_loadout.get("xinfa", loadout["xinfa"]))
	if version >= 6:
		silver = maxi(0, int((parsed as Dictionary).get("silver", 0)))
		experience = maxi(0, int((parsed as Dictionary).get("experience", 0)))

func save_meta() -> void:
	var file := FileAccess.open(meta_path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入据点存档: " + meta_path)
		return
	file.store_string(JSON.stringify({
		"version": META_VERSION,
		"warehouse": warehouse,
		"pouch_slots": pouch_slots,
		"uid_next": uid_next,
		"equipped": equipped,
		"prep_cart": prep_cart,
		"learned": {"techniques": learned_techniques, "xinfa": learned_xinfa},
		"loadout": loadout,
		"silver": silver,
		"experience": experience,
	}))

# 购物车条目只收字典（坏档/手改档防御，非字典条目丢弃；条目字段在使用点照旧 int 归一）。
func _cart_items(arr: Variant) -> Array:
	var out: Array = []
	if arr is Array:
		for entry in arr:
			if entry is Dictionary:
				out.append(entry)
	return out

# 装备实例 uid 发号（递增不回收）；BoardState 经 issue_uid 回调取号。
func next_uid() -> int:
	var uid := uid_next
	uid_next += 1
	return uid

# 仓库总价值（按件计＝价值×数量，与随身价值同口径）
func warehouse_value() -> int:
	var total := 0
	for item in warehouse:
		total += int(item.get("value", 0)) * int(item.get("qty", 1))
	return total

# 锦囊格数局外升级入口（每级 +1；越界收口在 MIN~MAX，据点设施/商店立项后由它驱动）
func set_pouch_slots(n: int) -> void:
	pouch_slots = clampi(n, POUCH_SLOTS_MIN, POUCH_SLOTS_MAX)

# ---------- 已学清单与构筑配置（v5，D-060） ----------

# 无档/旧档的默认构筑：取 player.json 初始角色定义（功法与心法各带一套）。
func _load_learned_defaults() -> void:
	var def := DataRepo.player_def()
	learned_techniques = _string_items(def.get("techniques", []))
	learned_xinfa = _string_items(def.get("xinfa", []))
	loadout = {
		"techniques": learned_techniques.duplicate(),
		"xinfa": learned_xinfa.duplicate(),
	}

# 坏档防御：清单/构筑只收字符串条目。
func _string_items(arr: Variant) -> Array:
	var out: Array = []
	if arr is Array:
		for entry in arr:
			if entry is String and not (entry as String).is_empty():
				out.append(entry)
	return out

# ---------- 账面资产（v6，D-062） ----------

# 历练入账（胜仗/撤离由 ExpeditionSession 调，研读在 study_manual 内部）。
func gain_experience(amount: int) -> void:
	experience += maxi(amount, 0)

# 银两入账（折银/商店落地前的预留入口，测试与未来系统用）。
func gain_silver(amount: int) -> void:
	silver += maxi(amount, 0)

func knows_technique(technique_id: String) -> bool:
	return learned_techniques.has(technique_id)

func knows_xinfa(xf_id: String) -> bool:
	return learned_xinfa.has(xf_id)

# 直接入册（研读之外的授予入口：剧情传授等；同名幂等）
func learn_technique(technique_id: String) -> void:
	if not learned_techniques.has(technique_id):
		learned_techniques.append(technique_id)

func learn_xinfa(xf_id: String) -> void:
	if not learned_xinfa.has(xf_id):
		learned_xinfa.append(xf_id)

# 研读秘籍（参悟即蚀，D-047）：按物品 id 从 DataRepo 取权威定义的 teach 字段
# （仓库条目是定义副本，字段流转不可依赖）；已在清单上的再读是白卷
# （重复研读换参悟点——参悟点系统后置，v1 拒绝研读）。成功即销毁该秘籍并落盘。
# 返回 {ok, reason, kind, id}。
func study_manual(item_id: String) -> Dictionary:
	var item: Dictionary = DataRepo.items().get(item_id, {})
	if item.is_empty():
		return {"ok": false, "reason": "查无此物"}
	var teach: Dictionary = item.get("teach", {})
	var kind := str(teach.get("kind", ""))
	var id := str(teach.get("id", ""))
	if kind == "" or id == "":
		return {"ok": false, "reason": "此书无可参悟之处"}
	if kind == "technique":
		if knows_technique(id):
			return {"ok": false, "reason": "已参悟过，卷上文字散去（白卷）"}
		if TechniqueResolver.data_for(id).is_empty():
			return {"ok": false, "reason": "卷上功法晦涩难明（数据缺失）"}
		learned_techniques.append(id)
	elif kind == "xinfa":
		if knows_xinfa(id):
			return {"ok": false, "reason": "已参悟过，卷上文字散去（白卷）"}
		if XinfaRuntime.xinfa_data(id).is_empty():
			return {"ok": false, "reason": "卷上心法晦涩难明（数据缺失）"}
		learned_xinfa.append(id)
	else:
		return {"ok": false, "reason": "未知的传授类型"}
	remove_warehouse_item(item_id, 1)
	experience += EXP_PER_STUDY
	save_meta()
	return {"ok": true, "reason": "参悟有成", "kind": kind, "id": id}

# 从仓库移除物品（研读销毁秘籍用）：可叠物减数量、减到零移除；装备实例按 uid 匹配。
func remove_warehouse_item(item_id: String, qty: int = 1) -> bool:
	for index in range(warehouse.size()):
		var entry: Dictionary = warehouse[index]
		if str(entry.get("id", "")) != item_id:
			continue
		if entry.has("uid"):
			warehouse.remove_at(index)
			return true
		var remaining := int(entry.get("qty", 1)) - maxi(qty, 1)
		if remaining > 0:
			entry["qty"] = remaining
		else:
			warehouse.remove_at(index)
		return true
	return false

# 构筑配置写入（据点构筑面板用）：ids 必须是已学清单的子集、无重复、不超槽位。
# 超出的部分静默截断（防御手改档）；同名心法唯一由去重保证。
func set_loadout(slot_type: String, ids: Array) -> void:
	if not ["techniques", "xinfa"].has(slot_type):
		return
	var known: Array = learned_techniques if slot_type == "techniques" else learned_xinfa
	var cap := TECHNIQUE_SLOTS if slot_type == "techniques" else XINFA_SLOTS
	var picked: Array = []
	for id in ids:
		if str(id) in known and not picked.has(id) and picked.size() < cap:
			picked.append(str(id))
	loadout[slot_type] = picked

# ---------- 穿戴栏（角色状态读写；规范化统一走 BoardCodec） ----------

# 整副写回（read_equipped 内部深拷贝＋int 归一；ExpeditionSession 撤离结算用）。
func set_equipped(data: Dictionary) -> void:
	equipped = BoardCodec.read_equipped(data)

# 单槽写入（备战页换装用；entry 为空字典即清槽）。
func set_equipped_slot(slot: String, entry: Dictionary) -> void:
	if not BoardState.EQUIP_SLOTS.has(slot):
		return
	equipped[slot] = BoardCodec.read_equipped({slot: entry})[slot]

# 全部散失（死亡/力竭/弃局）。
func clear_equipped() -> void:
	equipped = {"weapon": {}, "armor": {}, "bag": {}}

# 一批物品入库：可叠物同 id 叠数量；装备实例（带 uid）各占一条，返回入库件数。
func store_items(items: Array) -> int:
	var stored := 0
	for item in items:
		_store_item(item)
		stored += 1
	return stored

func _store_item(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	# 装备实例永不合并（各有各的耐久）；JSON 回读的数字归一成 int。
	# 老档/手喂数据可能没有 uid——只要带 weapon/armor/container 参数包就不并堆。
	if item.has("uid") or _is_equipment(item):
		var inst: Dictionary = item.duplicate()
		if inst.has("uid"):
			inst["uid"] = int(inst["uid"])
		if inst.has("dur"):
			inst["dur"] = int(inst["dur"])
		warehouse.append(inst)
		return
	for w in warehouse:
		if str(w.get("id", "")) == item_id and not w.has("uid") and not _is_equipment(w):
			w["qty"] = int(w.get("qty", 1)) + int(item.get("qty", 1))
			return
	var entry := item.duplicate()
	entry["qty"] = int(item.get("qty", 1))
	warehouse.append(entry)

func _is_equipment(entry: Dictionary) -> bool:
	return entry.has("weapon") or entry.has("armor") or entry.has("container")
