class_name ExpeditionPrep
extends RefCounted

# 备战装配（C-027 备战页核心，纯逻辑无 UI）：出发前的角色整备。
# - 穿戴（角色状态，改动即时提交 meta 档）：仓库 → 穿戴（旧件收回仓库）；穿戴 → 仓库。
#   换小行囊受"要带行李的堆数"约束；卸行囊后行李不能超过兜底格数。
# - 装载（出发载荷，购物车——meta v4 起持续保存，与穿戴同构的档案状态）：
#   仓库整堆带走 → 背包（上限＝所穿行囊格数，没穿行囊走兜底；同名叠放、装备实例各占一格）
#   或 → 锦囊（1~3 格，兵器/护具/行囊放不进）；背包/锦囊 → 仓库整堆放回。
#   退出备战页/退出游戏/崩溃都不丢——下次进备战页原样恢复；只有「出发」
#   consume_cart 才清车（物资转入远征档，生死由局内结算决定）。
# 出发经 payload() 交给 ExpeditionSession.start_run；带不带、穿什么全由玩家决定——
# 没有任何自动配发（保底配发 C-027 取消）。
# 播报走 last_note（UI 展示/测试断言）；返回 false 即被拒，原因在里面。

var archive: Node      # MetaArchive（autoload 或测试注入裸实例）
var config: Dictionary # 禁地配置（backpack_size 兜底格数等）
var backpack: Array = []  # 出发背包购物车（绑定 archive.prep_cart.backpack，档案即真相）
var pouch: Array = []     # 出发锦囊购物车（绑定 archive.prep_cart.pouch）
var last_note := ""

func setup(p_archive: Node, p_config: Dictionary) -> void:
	archive = p_archive
	config = p_config
	# 购物车直接绑档案里的数组（GDScript 数组是引用）：此后 take/stash 的一切增删
	# 都落在 archive 上，save_meta 即随档落盘——重开备份战页 setup 原样恢复。
	backpack = archive.prep_cart["backpack"]
	pouch = archive.prep_cart["pouch"]

# ---------- 容量 ----------

# 读写统一出口（场景/测试都从这里取，注入的 archive 与全局 autoload 不劈叉）。
func warehouse() -> Array:
	return archive.warehouse

func equipped() -> Dictionary:
	return archive.equipped

func warehouse_value() -> int:
	return archive.warehouse_value()

# 背包购物车上限＝所穿行囊格数；没穿行囊走禁地配置兜底（随身衣兜基线）。
func backpack_capacity() -> int:
	var bag: Dictionary = archive.equipped.get("bag", {})
	if not bag.is_empty():
		return int(bag.get("container", {}).get("slots", BoardState.DEFAULT_BACKPACK_SIZE))
	return _fallback_capacity()

func _fallback_capacity() -> int:
	return int(config.get("backpack_size", BoardState.DEFAULT_BACKPACK_SIZE))

# 锦囊格数＝局外升级（MetaArchive.pouch_slots）。
func pouch_capacity() -> int:
	return archive.pouch_slots

# ---------- 穿戴（仓库 ⇄ 角色穿戴栏） ----------

# 仓库 → 穿戴：旧件先收回仓库（实例带耐久原样入库）；换小行囊时行李堆数不能超新格数。
func wear(warehouse_index: int) -> bool:
	if warehouse_index < 0 or warehouse_index >= archive.warehouse.size():
		return false
	var entry: Dictionary = archive.warehouse[warehouse_index]
	var slot := _slot_for(entry)
	if slot.is_empty():
		last_note = "%s 不是能穿戴的东西。" % str(entry.get("name", ""))
		return false
	if slot == "bag":
		var new_cap := int(entry.get("container", {}).get("slots", 0))
		if backpack.size() > new_cap:
			last_note = "要带的行李有 %d 堆，放不进 %d 格的新行囊。" % [backpack.size(), new_cap]
			return false
	var inst: Dictionary = entry.duplicate(true)
	if not inst.has("uid"):
		inst = _instance_of(inst)
	var old: Dictionary = archive.equipped.get(slot, {})
	archive.warehouse.remove_at(warehouse_index)
	if not old.is_empty():
		archive.store_items([old.duplicate(true)])
	archive.set_equipped_slot(slot, inst)
	archive.save_meta()
	last_note = "你穿上了 %s。" % str(inst.get("name", ""))
	return true

# 穿戴 → 仓库：卸下收回仓库；卸行囊后行李堆数不能超过兜底格数。
func unwear(slot: String) -> bool:
	if not BoardState.EQUIP_SLOTS.has(slot):
		return false
	var entry: Dictionary = archive.equipped.get(slot, {})
	if entry.is_empty():
		last_note = "那个位置本来就没穿东西。"
		return false
	if slot == "bag" and backpack.size() > _fallback_capacity():
		last_note = "要带的行李有 %d 堆，卸下行囊后只剩 %d 格兜底，装不下。" % [backpack.size(), _fallback_capacity()]
		return false
	archive.set_equipped_slot(slot, {})
	archive.store_items([entry.duplicate(true)])
	archive.save_meta()
	last_note = "你把 %s 收回了仓库。" % str(entry.get("name", ""))
	return true

# ---------- 装载（仓库 → 出发购物车；整堆带走） ----------

# 仓库 → 背包购物车：整堆带走（同名叠放至上限，放不下的留在仓库）。
func take(warehouse_index: int) -> bool:
	return _take_into(warehouse_index, backpack, backpack_capacity(), func(_e: Dictionary) -> bool: return true, "背包")

# 仓库 → 锦囊购物车：整堆带走；兵器/护具/行囊放不进贴身锦囊。
func take_pouch(warehouse_index: int) -> bool:
	return _take_into(warehouse_index, pouch, pouch_capacity(),
		func(e: Dictionary) -> bool: return not BoardState.POUCH_BLOCKED_TYPES.has(str(e.get("type", ""))),
		"锦囊")

# 背包购物车 → 仓库：整堆放回（可叠物同 id 叠数量）。
func stash(cart_index: int) -> bool:
	return _stash_from(backpack, cart_index, "背包")

# 锦囊购物车 → 仓库：整堆放回。
func stash_pouch(pouch_index: int) -> bool:
	return _stash_from(pouch, pouch_index, "锦囊")

# 出发载荷：{equipped, inventory, pouch} 全深拷贝——局内磨损/消耗不回写角色状态。
func payload() -> Dictionary:
	return {
		"equipped": (archive.equipped as Dictionary).duplicate(true),
		"inventory": backpack.duplicate(true),
		"pouch": pouch.duplicate(true),
	}

# 出发消费购物车（远征档落盘之后调用）：清车并提交 meta——之后这批物资的生死
# 由局内结算决定（撤离入库、死亡只保锦囊、弃局全丢）。payload() 本身保持只读。
func consume_cart() -> void:
	backpack.clear()
	pouch.clear()
	archive.save_meta()

# ---------- 内部 ----------

# 整堆搬运：先叠进同名堆（至上限），叠不下再开新堆（受 cap 格数约束）；装不完的留仓库。
func _take_into(warehouse_index: int, into: Array, cap: int, allow: Callable, what: String) -> bool:
	if warehouse_index < 0 or warehouse_index >= archive.warehouse.size():
		return false
	var entry: Dictionary = archive.warehouse[warehouse_index]
	if not allow.call(entry):
		last_note = "%s 放不进%s。" % [str(entry.get("name", "")), "" if what == "背包" else what]
		return false
	var qty := int(entry.get("qty", 1))
	var max_stack := 1 if _is_equipment(entry) else maxi(1, int(entry.get("max_stack", 99)))
	var moved := 0
	while moved < qty:
		if max_stack > 1:
			var piled := false
			for stack in into:
				if str((stack as Dictionary).get("id", "")) == str(entry.get("id", "")) \
						and int((stack as Dictionary).get("qty", 1)) < max_stack:
					var add: int = mini(max_stack - int((stack as Dictionary).get("qty", 1)), qty - moved)
					(stack as Dictionary)["qty"] = int((stack as Dictionary).get("qty", 1)) + add
					moved += add
					piled = true
					break
			if piled and moved >= qty:
				break
			if piled:
				continue
		if into.size() >= cap:
			break
		var fresh: Dictionary = entry.duplicate(true)
		fresh["qty"] = mini(max_stack, qty - moved)
		if _is_equipment(fresh) and not fresh.has("uid"):
			fresh = _instance_of(fresh)
		moved += int(fresh["qty"])
		into.append(fresh)
	if moved <= 0:
		last_note = "%s装满了，%s 带不走。" % [what, str(entry.get("name", ""))]
		return false
	if moved >= qty:
		archive.warehouse.remove_at(warehouse_index)
	else:
		entry["qty"] = qty - moved
	archive.save_meta()
	last_note = "带走 %s ×%d。" % [str(entry.get("name", "")), moved]
	return true

func _stash_from(arr: Array, index: int, what: String) -> bool:
	if index < 0 or index >= arr.size():
		return false
	var entry: Dictionary = arr[index]
	arr.remove_at(index)
	archive.store_items([entry.duplicate(true)])
	archive.save_meta()
	last_note = "%s里的 %s 放回了仓库。" % [what, str(entry.get("name", ""))]
	return true

# 该物品应放入哪个穿戴槽（""＝不可穿戴）。
func _slot_for(entry: Dictionary) -> String:
	var type_id := str(entry.get("type", ""))
	for slot in BoardState.EQUIP_SLOTS:
		if BoardState.EQUIP_SLOT_TYPES[slot] == type_id:
			return slot
	return ""

func _is_equipment(entry: Dictionary) -> bool:
	return entry.has("weapon") or entry.has("armor") or entry.has("container")

# 定义副本 → 装备实例（补 uid 与初始耐久；兵器/护具有耐久，行囊没有）。
func _instance_of(item: Dictionary) -> Dictionary:
	var inst: Dictionary = item.duplicate(true)
	inst["qty"] = 1
	inst["uid"] = archive.next_uid()
	for pkg in ["weapon", "armor"]:
		if inst.has(pkg) and not inst.has("dur"):
			inst["dur"] = int((inst[pkg] as Dictionary).get("base_dur", 1))
	return inst
