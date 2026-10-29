class_name MJBPerspective
extends RefCounted

## 全桌单一透视源（2026-09-18 用户令：所有牌物理同大，屏幕大小只由桌深决定——近大远小）。
## 桌布梯形＝透视定义：收敛比＝桌布 top_width_ratio（同一旋钮，改一全桌同步）；
## 各行缩放 s(t)＝lerp(收敛比, 1, t)，t 由行**实测 y** 派生（编辑器拖行自动跟随，不写死）。
## 牌长宽比沿用手牌现行 1.42（3:4 满铺语言）。根协调器每刷新先 sync。


static var far_y := 0.0     # 呢面远端 y（sync 写入）
static var near_y := 720.0  # 呢面近端 y
static var ratio := 0.65    # 收敛比（sync 从桌布读）
static var base_w := 50     # 近端基准牌宽（s=1；REST_TOTAL=20 一行定标）


static func scale_at(y: float) -> float:
	var span := maxf(1.0, near_y - far_y)
	var t := clampf((y - far_y) / span, 0.0, 1.0)
	return lerpf(ratio, 1.0, t)


static func tile_size_at(y: float) -> Vector2i:
	var w := roundi(base_w * scale_at(y))
	return Vector2i(w, roundi(w * 1.42))


## 根协调器每刷新调：桌布矩形＋收敛比 → 静态源。
static func sync(cloth: Control, top_ratio: float) -> void:
	var r: Rect2 = cloth.get_global_rect()
	ratio = clampf(top_ratio, 0.3, 1.0)
	far_y = r.position.y
	near_y = r.end.y
