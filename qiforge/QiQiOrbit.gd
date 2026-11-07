## 气珠轨道（2026-11-06）：气值＝绕珠气粒的数量。
## 结构：轨道线（前后两段）＋ 每颗气粒自己带 z（前 +2 / 后 -1），
## 不靠父子容器分层——省掉 reparent，也就没有换层错乱。
extends Control

const MOTE_DRAW := preload("res://qiforge/QiQiMote.gd")

const SPIN := 0.95          # 队形整体转速（弧度/秒）
const RX := 86.0
const RY := 34.0
const TILT := -0.20
const MOTE_R := 9.0
const V_NORMAL := 0.95      # 常速（也是上限）
const V_MIN := 0.30         # 最慢（超前的减速等人；太慢会像卡住）
const V_MAX := 0.95         # 上限＝常速：只许减速等人，不许加速追（2026-11-06 用户令）
const V_GAIN := 4.0          # 减速修正力度（太高会把间距的微小浮动放大成速度抖动）
const ORB_R := 56.0          # 气珠半径（用于「转到背面」的淡出判定）
const MIN_GAP := 0.40       # 两颗气粒的最小角间距（不许重叠）

var _center := Vector2.ZERO
var _base := 0.0            # 队形基准角
var _value := 0
var hold := false
var _pending := -1
var _motes: Array = []      # {node, theta, idx, front, settling}
var _track_back: Line2D = null
var _track_front: Line2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

## 造一颗气珠（飞行段与轨道段共用同一外观）
static func make_bead(sz: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(sz, sz)
	c.pivot_offset = c.size * 0.5
	var sp := MOTE_DRAW.new()
	sp.size = c.size
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(sp)
	return c

func setup(center: Vector2) -> void:
	_center = center
	_build_track()

func set_value(v: int) -> void:
	if hold:
		_pending = maxi(0, v)
		return
	var want := maxi(0, v)
	_value = want
	while _motes.size() < want:
		_add_mote()
	while _motes.size() > want:
		_pop_mote()

## 给 N 颗新气粒规划位置：逐个挑最大空隙（与现有的一起算）
func plan_slots(n_new: int) -> Array:
	var out: Array = []
	var taken: Array = []
	for m in _motes:
		taken.append(float(m["theta"]))
	for j in n_new:
		var best := 0.0
		var best_gap := -1.0
		for k in 72:
			var cand := TAU * float(k) / 72.0
			var gap := 9.9
			for a in taken:
				gap = minf(gap, absf(wrapf(cand - float(a), -PI, PI)))
			if gap > best_gap:
				best_gap = gap
				best = cand
		out.append(best)
		taken.append(best)
	return out

func mote_point(th: float) -> Vector2:
	return _mote_pos(th)

## 该角度附近是否还有气粒（用于入轨前等待）
func angle_busy(th: float, gap := 0.42) -> bool:
	for m in _motes:
		if absf(wrapf(float(m["theta"]) - th, -PI, PI)) < gap:
			return true
	return false

## 接管一颗飞行中的气粒（同一个节点，不销毁不重建）
func adopt(n: Control, _th := PI) -> void:
	_value += 1
	_pending = _value
	# 落在轨道左端就**原地入轨**，不另做「滑到槽位」的补间——
	# 由速度调制自然把它带到空位（补间会变成一次快速扫掠，蹭到邻位）
	var th := _th
	var rec := {"node": n, "theta": th, "idx": _motes.size(),
		"front": sin(th) > 0.0, "settling": false, "blend": 0.0}
	_motes.append(rec)
	if n.get_parent() != self:
		n.reparent(self)
	n.pivot_offset = n.size * 0.5
	n.modulate.a = 1.0
	n.z_index = -1 if sin(th) < 0.0 else 2
	# 位置必须用**实际入口角**：之前写死成 PI，会在并入那一帧瞬移到左端再跳回来（＝闪一下）
	n.position = _mote_pos(th) - n.size * 0.5

## 新气粒的位置＝现有气粒之间的最大空隙（插进去之后再也不用挪）
func _theta_for_new() -> float:
	if _motes.is_empty():
		return _base
	var best := _base
	var best_gap := -1.0
	for k in 72:
		var cand := TAU * float(k) / 72.0
		var gap := 9.9
		for m in _motes:
			gap = minf(gap, absf(wrapf(cand - float(m["theta"]), -PI, PI)))
		if gap > best_gap:
			best_gap = gap
			best = cand
	return best

func _add_mote() -> void:
	var th := _theta_for_new()
	var my_idx := _motes.size()
	var is_front: bool = sin(th) > 0.0
	var n := make_bead(MOTE_R * 2.0)
	add_child(n)
	n.position = _mote_pos(th) - n.size * 0.5
	n.z_index = -1 if sin(th) < 0.0 else 2
	n.scale = Vector2(0.2, 0.2)
	n.modulate.a = 0.0
	_motes.append({"node": n, "theta": th, "idx": my_idx, "front": is_front, "settling": false})
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 1.0, 0.16)

## 消耗：沿弧线被吸进珠心
func _pop_mote() -> void:
	if _motes.is_empty():
		return
	var rec: Dictionary = _motes.pop_back()
	var i2 := 0
	for r2 in _motes:
		r2["idx"] = i2
		i2 += 1
	var n: Control = rec["node"]
	if not is_instance_valid(n):
		return
	var p0: Vector2 = n.position + n.size * 0.5
	var p2: Vector2 = _center
	var ctrl: Vector2 = (p0 + p2) * 0.5 + (p2 - p0).rotated(PI * 0.5).normalized() * 44.0
	var tw := n.create_tween()
	tw.tween_method(func(t: float) -> void:
		var u := 1.0 - t
		var p := p0 * (u * u) + ctrl * (2.0 * u * t) + p2 * (t * t)
		n.position = p - n.size * 0.5
		n.scale = Vector2.ONE * lerpf(1.0, 0.15, t)
		n.modulate.a = lerpf(1.0, 0.0, t)
	, 0.0, 1.0, 0.34)
	tw.tween_callback(n.queue_free)

func _mote_pos(theta: float) -> Vector2:
	var p := Vector2(cos(theta) * RX, sin(theta) * RY)
	return _center + p.rotated(TILT)

func _build_track() -> void:
	if _track_back != null:
		return
	var back_pts := PackedVector2Array()
	var front_pts := PackedVector2Array()
	for i in 49:
		var th := TAU * float(i) / 48.0
		var p := _mote_pos(th)
		if sin(th) >= 0.0:
			front_pts.append(p)
		else:
			back_pts.append(p)
	_track_back = _mk_track(back_pts, Color(0.30, 0.42, 0.60, 0.30), 1.6)
	_track_back.z_index = -1
	add_child(_track_back)
	_track_front = _mk_track(front_pts, Color(0.30, 0.42, 0.60, 0.46), 1.8)
	_track_front.z_index = 1
	add_child(_track_front)

func _mk_track(pts: PackedVector2Array, col: Color, w: float) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = w
	l.default_color = col
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = true
	return l

func _process(delta: float) -> void:
	if _center == Vector2.ZERO:
		return
	_base += SPIN * delta
	var cnt := _motes.size()
	if cnt == 0:
		return
	# 2026-11-06 用户方案：**用速度调制收敛到等分**。
	# 不用「槽位编号」（0/2π 接缝会错位、导致抢槽聚堆），改用**邻居间距松弛**：
	# 后面空得多就加速、前面挤得紧就减速，局部调节自然收敛到等分。
	var order := _motes.duplicate()
	order.sort_custom(func(a, b) -> bool:
		return wrapf(float(a["theta"]), 0.0, TAU) < wrapf(float(b["theta"]), 0.0, TAU))
	for k in cnt:
		var cur: Dictionary = order[k]
		var prev: Dictionary = order[(k - 1 + cnt) % cnt]
		var nxt: Dictionary = order[(k + 1) % cnt]
		var gap_behind := wrapf(float(cur["theta"]) - float(prev["theta"]), 0.0, TAU)
		var gap_ahead := wrapf(float(nxt["theta"]) - float(cur["theta"]), 0.0, TAU)
		var err := gap_behind - gap_ahead
		# 符号：**后面空得多 → 减速**让后车追上来（之前写成加速，正反馈导致聚堆）
		var spd0 := clampf(V_NORMAL - err * V_GAIN, V_MIN, V_MAX)
		# 速度变化本身也做平滑：否则并入/数量变化那一帧会突然加速，看着像「位置跳了一下」
		var prev_spd: float = float(cur.get("spd", V_NORMAL))
		spd0 = lerpf(prev_spd, spd0, clampf(delta * 5.0, 0.0, 1.0))
		# 防重叠：接近最小间距时**平滑**限速（硬除法会让速度一帧掉到 0，看起来像抽搐）
		var room := maxf(0.0, gap_ahead - MIN_GAP)
		var allow: float = clampf(room / 0.22, 0.0, 1.0)
		var cap: float = lerpf(V_MIN * 0.9, V_MAX, allow)
		cur["spd"] = minf(spd0, cap)
	for rec in _motes:
		rec["theta"] = float(rec["theta"]) + float(rec.get("spd", V_NORMAL)) * delta
		var n: Control = rec["node"]
		if not is_instance_valid(n):
			continue
		var th: float = rec["theta"]
		var depth: float = (sin(th) + 1.0) * 0.5
		# 并入后 0.25 秒内从「飞行态」（满亮、1.0 大小）平滑过渡到轨道态，
		# 否则会在并入那一帧突然变暗变小——看起来就是闪一下
		rec["blend"] = minf(1.0, float(rec.get("blend", 1.0)) + delta / 0.25)
		var bl: float = float(rec["blend"])
		n.modulate.a = lerpf(1.0, lerpf(0.62, 1.0, depth), bl)

		n.position = _mote_pos(th) - n.size * 0.5
		# 不切层级（z 切换会闪）：转到**背面且落在珠子轮廓内**时，用 alpha 淡出代替遮挡，
		# 滑进珠后逐渐隐去、再转出来逐渐浮现——没有层级变化，也就没有闪。
		var sn2: float = sin(th)
		if absf(sn2) > 0.10:
			n.z_index = -1 if sn2 < 0.0 else 2
		# 大小几乎不变（0.92→1.0），前后靠亮度与遮挡区分——缩小会看成「两种珠子」
		n.scale = Vector2.ONE * lerpf(1.0, lerpf(0.92, 1.0, depth), bl)
