class_name MapView
extends RefCounted

# 两档吸附视图（D-059 细化，替代旧自由缩放 BoardCamera）：
# - 地块档：scale=1，当前地块面板居中（战术层，C-028 明牌网格）。
# - 大地图档：整张舆图 fit 进可视区（战略层，节点印＋路网）。
# 两档之间只做补间切换，没有连续缩放中间态；无自由平移。

const TWEEN_TIME := 0.38

var map_mode := false

var _viewport: Control  # continent：视图作用的容器
var _frame: Control     # 场景根：取可视尺寸
var _hero: Vector2i = Vector2i.ZERO
var _tween: Tween

func setup(viewport: Control, frame: Control) -> void:
	_viewport = viewport
	_frame = frame

func apply() -> void:
	var target := tile_transform() if not map_mode else map_transform()
	_viewport.position = target[0]
	_viewport.scale = target[1]

# 切档（animate=false 用于首帧与测试）。
func set_mode(to_map: bool, animate: bool = true) -> void:
	if to_map == map_mode:
		if not animate:
			apply()
		return
	map_mode = to_map
	if not animate:
		apply()
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var from_p := _viewport.position
	var from_s := _viewport.scale
	var target := map_transform() if map_mode else tile_transform()
	_tween = _viewport.create_tween()
	_tween.tween_method(_lerp_transform, [from_p, from_s], [target[0], target[1]], TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _lerp_transform(state: Array) -> void:
	_viewport.position = state[0]
	_viewport.scale = state[1]

# 当前节点变化后重算目标（不改变档位）。
func on_hero_moved(hero: Vector2i) -> void:
	_hero = hero

# 立即应用当前档位的变换；补间进行中跳过（补间才是权威）。
func apply_if_idle() -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		return
	apply()

# 地块档变换：当前地块面板中心对准画面中心。
func tile_transform() -> Array:
	var focus: Vector2 = BoardLayout.pixel(_hero) + BoardLayout.CURRENT_TILE_SIZE / 2.0
	return [_frame.size / 2.0 - focus, Vector2.ONE]

# 大地图档变换：舆图 fit 进可视区（留边给 HUD 与节点印的标签）。
func map_transform() -> Array:
	var margin: float = minf(_frame.size.x, _frame.size.y) * 0.10
	var s: float = minf((_frame.size.x - margin * 2.0) / BoardLayout.WORLD_SIZE.x,
		(_frame.size.y - margin * 2.0) / BoardLayout.WORLD_SIZE.y)
	var top_left := (_frame.size - BoardLayout.WORLD_SIZE * s) / 2.0
	return [top_left, Vector2(s, s)]

# 大地图档当前缩放（节点印反缩放保持可读尺寸用）。
func map_scale() -> float:
	return map_transform()[1].x
