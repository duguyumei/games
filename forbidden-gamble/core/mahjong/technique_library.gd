class_name MJTechniqueLibrary
extends RefCounted

# 构筑三轨槽（v3.5）：功法槽（攻）／护身槽（护体）／心法槽。
# 初始各 1、解锁至 5（解锁＝搜集层，暂只有基础件）。旧四功法/心法内容件已全删。
# 新功法＝techniques/ 下一个文件＋此处一行；新心法＝根目录一个文件＋此处一行。


static func factory(id: String) -> Callable:
	match id:
		"dian_xue":
			return func() -> MJTechnique: return TechDianXue.new()
		"tie_bu_shan":
			return func() -> MJTechnique: return TechTieBuShan.new()
	return Callable()


static func make(id: String) -> MJTechnique:
	var f := factory(id)
	if not f.is_valid():
		return null
	return f.call()


static func make_all(ids: Array) -> Array[MJTechnique]:
	var list: Array[MJTechnique] = []
	for id in ids:
		var t := make(str(id))
		if t != null:
			list.append(t)
	return list


# —— 三轨缺省（全占位）——
static func all_ids() -> Array[String]:
	return ["dian_xue"]


static func defense_ids() -> Array[String]:
	return ["tie_bu_shan"]


static func make_xinfa(id: String) -> MJXinfa:
	if id == "zhao_jia_jue":
		return MJXinfaZhaoJiaJue.new()
	return null


static func xinfa_ids() -> Array[String]:
	return ["zhao_jia_jue"]
