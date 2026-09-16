class_name MJTechniqueLibrary
extends RefCounted

# 构筑三轨槽（v3.5）：功法槽（攻）／护身槽（护体）／心法槽。
# 新功法＝techniques/ 下一个文件＋此处一行；新心法＝根目录一个文件＋此处一行。
# 挑战层起分两组接口：**roster＝全量名册**（图鉴/池交叉校验）；
# **缺省表＝对局 setup 无配置时的缺省**（演武场现状：每轨一件基础件，行为不变）。


static func factory(id: String) -> Callable:
	match id:
		"dian_xue":
			return func() -> MJTechnique: return TechDianXue.new()
		"lianhuan_zhang":
			return func() -> MJTechnique: return TechLianHuanZhang.new()
		"po_jia_quan":
			return func() -> MJTechnique: return TechPoJiaQuan.new()
		"tie_bu_shan":
			return func() -> MJTechnique: return TechTieBuShan.new()
		"jin_zhong_zhao":
			return func() -> MJTechnique: return TechJinZhongZhao.new()
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


# —— 全量名册（图鉴/数据交叉校验）——
static func attack_roster() -> Array[String]:
	return ["dian_xue", "lianhuan_zhang", "po_jia_quan"]


static func defense_roster() -> Array[String]:
	return ["tie_bu_shan", "jin_zhong_zhao"]


static func xinfa_roster() -> Array[String]:
	return ["zhao_jia_jue", "yun_zhou_jue", "xi_lian_jue"]


static func make_xinfa(id: String) -> MJXinfa:
	match id:
		"zhao_jia_jue":
			return MJXinfaZhaoJiaJue.new()
		"yun_zhou_jue":
			return MJXinfaYunZhouJue.new()
		"xi_lian_jue":
			return MJXinfaXiLianJue.new()
	return null


# —— 对局缺省（演武场路径：每轨一件基础件）——
static func all_ids() -> Array[String]:
	return ["dian_xue"]


static func defense_ids() -> Array[String]:
	return ["tie_bu_shan"]


static func xinfa_ids() -> Array[String]:
	return ["zhao_jia_jue"]
