@tool
class_name MJBPlayLine
extends HBoxContainer

## 最新打出行（打出交换区，2026-09-17 用户令）：居中显示敌我双方最近一次打出的牌
## ——普攻/虚招/反击（POSTURE）与重击付式（TECH_FIRE）都进这里；
## 被招架截走的牌置灰。**滞后入河**：牌还挂在本区时不出现在气河行（根协调器隐藏同名张），
## 换打/回合翻页（跳过）后本区让位、牌落气河——两处不同时出现同一张牌（防误扰）。


const KIND_TAGS := {"xu": "虚招", "normal": "普攻", "counter": "反击", "tech": "重击付式"}
const KIND_TIPS := {
	"xu": ["打出时无超额，0 伤试探", "可被吃/碰/杠截走"],
	"normal": ["100% ＋ 50%×副露光环", "可被碰/杠拦截——拦截＝拆招，伤害取消"],
	"counter": ["招架后的打出", "不可被截——绝对安全弃牌"],
	"tech": ["功法打出的式（发动即入河明牌）", "不可被截；天然预告"],
}

var _enemy_row := HBoxContainer.new()
var _player_row := HBoxContainer.new()


func _init() -> void:
	size_flags_horizontal = Control.SIZE_FILL  # 占满中央列
	custom_minimum_size = Vector2(0, 58)  # 预留牌行高度：牌出现/消失不推挤下方日志
	add_theme_constant_override("separation", 16)
	# 标签居中相邻（敌｜我），牌向两侧展开（2026-09-17 用户令）
	add_child(_make_block("敌方", _enemy_row, Color(0.82, 0.55, 0.5), false))
	var sep := Label.new()
	sep.text = "｜"
	sep.add_theme_font_size_override("font_size", 14)
	sep.add_theme_color_override("font_color", Color(0.4, 0.38, 0.34))
	add_child(sep)
	add_child(_make_block("我方", _player_row, Color(0.6, 0.75, 0.58), true))


# label_inside_left＝我方块（标签贴分隔符、牌右展开）；敌方块镜像（牌左展开、标签贴分隔符）。
func _make_block(who: String, row: HBoxContainer, color: Color, label_left: bool) -> HBoxContainer:
	var block := HBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 双块等分整行：位置恒定不跳
	block.custom_minimum_size = Vector2(250, 0)
	var who_label := Label.new()
	who_label.text = who
	who_label.add_theme_font_size_override("font_size", 13)
	who_label.add_theme_color_override("font_color", color)
	# 牌行整体下移 10px（用户令）——上缘留白走 MarginContainer，布局稳定不吃回写
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 10)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 3)
	if not label_left:
		row.alignment = BoxContainer.ALIGNMENT_END  # 敌方牌贴分隔符、向标签侧收拢（靠中间）
		pad.add_child(row)
		block.add_child(pad)
		block.add_child(who_label)  # 标签贴分隔符
	else:
		row.alignment = BoxContainer.ALIGNMENT_BEGIN  # 我方牌贴分隔符（靠中间）
		block.add_child(who_label)  # 标签贴分隔符
		pad.add_child(row)
		block.add_child(pad)
	return block


## playing＝{side:{batch,kind}}；melds＝{side: 副露数组}（对侧副露含截走的牌→置灰）。
func update(playing: Dictionary, melds := {}) -> void:
	_update_block(_enemy_row, playing.get("enemy", {}), melds.get("player", []))
	_update_block(_player_row, playing.get("player", {}), melds.get("enemy", []))


func _update_block(row: HBoxContainer, info: Dictionary, claimer_melds: Array) -> void:
	for child in row.get_children():
		child.queue_free()
	if info.is_empty():
		return
	var kind := String(info.get("kind", ""))
	var batch: Array = info.get("batch", [])
	# 透视定尺寸＋大批次动态收窄：块宽有限（半列），9 张也能一行放下（2026-09-17 用户令的 9 张要求）
	var n := batch.size()
	var sz := MJBPerspective.tile_size_at(row.get_global_rect().get_center().y)
	var w := sz.x
	if n * (w + 2) > 260:
		w = clampi(int(260.0 / n) - 2, 18, sz.x)
	var h := int(w * 1.42)
	for t in batch:
		var tile := t as MJTile
		var claimed := _in_melds(tile, claimer_melds)
		var widget := MJBTileFace.make_tile(tile, w, h, claimed)
		MJBTipFloat.bind(widget, KIND_TAGS.get(kind, "打出"),
			KIND_TIPS.get(kind, []) + (["已被招架截走（入对方副露）"] if claimed else []))
		row.add_child(widget)


# 截走的牌进了截者副露（同一实例）——按实例 id 对账。
func _in_melds(tile: MJTile, melds: Array) -> bool:
	var id := tile.get_instance_id()
	for meld in melds:
		for t in (meld as Dictionary)["tiles"]:
			if (t as MJTile).get_instance_id() == id:
				return true
	return false
