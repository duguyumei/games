extends GutTest

# 功法数据表的 schema 校验：每门功法一份参数，新增功法自动纳入检查。
# 真气语法 v2：效果＝基值＋系数×数值和；牌型＝刻子/顺子，输入固定三张。

const KNOWN_PATTERNS := ["KEZI", "SHUNZI"]
const KNOWN_EFFECTS := ["damage", "guard_cover", "remove_guard", "apply_status", "heal", "draw", "self_hp_loss"]
const KNOWN_SCHOOLS := ["通用", "剑法", "刀法", "掌法"]

func _technique_params() -> Array:
	var params: Array = []
	for technique_id in TechniqueResolver.technique_ids():
		params.append([technique_id])
	return params

func test_technique_schema(p = use_parameters(_technique_params())) -> void:
	var technique_id: String = p[0]
	var data := TechniqueResolver.data_for(technique_id)
	assert_false(data.is_empty(), "功法数据应存在: " + technique_id)

	var school := str(data.get("school", "通用"))
	assert_has(KNOWN_SCHOOLS, school, technique_id + " 的功法系别未知: " + school)

	assert_true(data.has("level"), technique_id + " 缺 level 字段")
	var level := int(data.get("level", 0))
	assert_between(level, 1, 5, technique_id + " 的 level 应在 1~5: " + str(level))

	var patterns: Array = data.get("patterns", [])
	assert_false(patterns.is_empty(), technique_id + " 必须声明牌型")
	for pattern in patterns:
		assert_has(KNOWN_PATTERNS, pattern, technique_id + " 的牌型要求未知: " + str(pattern))

	var effects: Array = data.get("effects", [])
	assert_false(effects.is_empty(), technique_id + " 至少应有一个效果")
	for effect in effects:
		var effect_type := str(effect.get("type", ""))
		assert_has(KNOWN_EFFECTS, effect_type, technique_id + " 的效果类型未知: " + effect_type)
		match effect_type:
			"damage", "guard_cover", "draw":
				assert_true(effect.has("base"), technique_id + " 的 " + effect_type + " 需要 base（基值）")
				for num_field in ["base", "scale"]:
					if effect.has(num_field):
						assert_true(int(effect[num_field]) >= 0, technique_id + " 的 " + num_field + " 应非负")
			"apply_status":
				assert_true(effect.has("status"), technique_id + " 的 apply_status 需要 status 字段")
