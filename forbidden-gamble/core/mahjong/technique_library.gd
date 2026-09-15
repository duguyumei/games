class_name MJTechniqueLibrary
extends RefCounted

# 功法库（v3 首发四式，占位）：id -> 工厂。新功法＝techniques/ 下一个文件＋此处一行。


static func factory(id: String) -> Callable:
	match id:
		"beng_shan":
			return func() -> MJTechnique: return TechBengShan.new()
		"dian_lie":
			return func() -> MJTechnique: return TechDianLie.new()
		"duan_shi_zhan":
			return func() -> MJTechnique: return TechDuanShiZhan.new()
		"tie_bi":
			return func() -> MJTechnique: return TechTieBi.new()
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


static func all_ids() -> Array[String]:
	return ["beng_shan", "dian_lie", "duan_shi_zhan", "tie_bi"]
