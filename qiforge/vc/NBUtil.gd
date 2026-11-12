## 原版 NBUtil 写入原语 1:1（Nosebleed.Util/NBUtil.cs:985-1096）——「值不同才写」防每帧脏写。
## 引擎映射：Transform/Vector3（Unity 3D）→ CanvasItem/Vector2＋单轴 rotation（Godot 2D），
## SetRotationIfDifferent 的四元数 dot 判据 → 2D 角差判据（dot 0.999999 ⇔ 角差 ≈0.0028284 rad）。
extends RefCounted

const POS_SQ_EPSILON := 9.9999994e-11    # SetPositionIfDifferent 距离²阈值（NBUtil.cs:1003）
const ROT_DOT_EPSILON := 0.999999        # SetRotationIfDifferent 四元数 dot 阈值（NBUtil.cs:1096）
const ROT_ANGLE_EPSILON := 0.0028284     # 2D 映射：acos(0.999999)*2 rad

## NBUtil.cs:985 —— 位置不同才写
static func SetPositionIfDifferent(item: CanvasItem, position: Vector2) -> void:
	if (item as Control).position.distance_squared_to(position) >= POS_SQ_EPSILON:
		(item as Control).position = position

## NBUtil.cs:1009
static func SetLocalPositionIfDifferent(item: CanvasItem, local_position: Vector2) -> void:
	if item.position.distance_squared_to(local_position) >= POS_SQ_EPSILON:
		item.position = local_position

## NBUtil.cs:1033 —— 欧拉角不同才写（2D＝单轴 rotation）
static func SetEulerAnglesIfDifferent(item: CanvasItem, rotation_rad: float) -> void:
	if absf(wrapf(rotation_rad - item.rotation, -PI, PI)) >= ROT_ANGLE_EPSILON:
		item.rotation = rotation_rad

## NBUtil.cs:1057
static func SetLocalEulerAnglesIfDifferent(item: CanvasItem, rotation_rad: float) -> void:
	SetEulerAnglesIfDifferent(item, rotation_rad)   # Control 的 rotation 即 local

## NBUtil.cs:1081 —— 旋转不同才写（2D 角差判据映射）
static func SetRotationIfDifferent(item: CanvasItem, rotation_rad: float) -> void:
	SetEulerAnglesIfDifferent(item, rotation_rad)

# ── ApproximatelyEqual 族（NBUtil.cs:1903-1973）────────────────────────

static func ApproximatelyEqual(a: float, b: float) -> bool:      # :1903
	return absf(a - b) <= 9.9999997e-06

static func ApproximatelyEqualDouble(a: float, b: float) -> bool:  # :1920（double 档）
	return absf(a - b) <= 9.9999999e-12

static func ApproximatelyEqualVec(a: Vector2, b: Vector2) -> bool:  # :1932（Vector3→Vector2 映射）
	return absf(a.x - b.x) <= 9.9999997e-06 and absf(a.y - b.y) <= 9.9999997e-06

static func ApproximatelyEqualRot(a: float, b: float) -> bool:      # :1973（Quaternion→角差映射）
	return absf(wrapf(a - b, -PI, PI)) <= ROT_ANGLE_EPSILON
