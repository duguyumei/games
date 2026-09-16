class_name MJBHpStrip
extends HBoxContainer

## 分段气血条（参照我地麻 PlayerHp 的 template＋images 分段制）：
## 每段＝10 点气血，段数随 max_hp 动态增减（不吃死数量）；半段以亮色近似。
## 数值侧＝ceil 显示（引擎定点两位小数的明码出口）。

const SEGMENT_HP := 10
const COL_FILLED := Color(0.72, 0.25, 0.2)
const COL_PARTIAL := Color(0.82, 0.45, 0.35)
const COL_EMPTY := Color(0.2, 0.18, 0.16)

var _segments: Array[ColorRect] = []
var _label := Label.new()


func _init() -> void:
	add_theme_constant_override("separation", 3)
	_label.add_theme_font_size_override("font_size", 15)
	add_child(_label)


func update_hp(hp: int, max_hp: int, precise_line := "") -> void:
	if not precise_line.is_empty():
		MJBTipFloat.bind(_label, "气血", [precise_line])
	var seg_count := maxi(1, ceili(max_hp / float(SEGMENT_HP)))
	if _segments.size() != seg_count:
		for seg in _segments:
			seg.queue_free()
		_segments.clear()
		for _i in range(seg_count):
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(18, 16)
			add_child(seg)
			_segments.append(seg)
		move_child(_label, _segments.size())
	var hp_left := hp
	for i in range(_segments.size()):
		var seg := _segments[i]
		if hp_left >= SEGMENT_HP:
			seg.color = COL_FILLED
		elif hp_left > 0:
			seg.color = COL_PARTIAL
		else:
			seg.color = COL_EMPTY
		hp_left -= SEGMENT_HP
	_label.text = "%d / %d" % [hp, max_hp]
