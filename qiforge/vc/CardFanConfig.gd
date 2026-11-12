## 原版 CardFanConfig 1:1（Nosebleed.Pancake.GameConfig/CardFanConfig.cs，240 行）。
## 数值＝HandPileFanConfig.asset 全量直读（~/Documents/vc_decomp/cfg/HandPileFanConfig.yaml:15-112）。
## 引擎映射：ScriptableObject + AnimationCurve → preload 常量＋Godot Curve（切线直译）。
extends RefCounted

const VC := preload("res://qiforge/vc/VcConfig.gd")

var MaxPositionOffset: float = 32.0          # yaml:15
var MaxRotationOffset: float = 15.0          # yaml:49
var DefaultCardRotation: Vector3 = Vector3.ZERO   # yaml:74
var SelectedCardRepelAmount: float = 64.0    # yaml:75
var MaxRepelOffset: float = 64.0             # yaml:76
var MinMaxCardsForSplit: Vector2i = Vector2i(6, 20)     # yaml:110
var LeftSplitMinMaxOffset: Vector2 = Vector2(0.0, 48.0)   # yaml:111
var RightSplitMinMaxOffset: Vector2 = Vector2(0.0, 96.0)  # yaml:112

var PositionOffsetCurve: Curve = null        # yaml:16-48
var RotationOffsetCurve: Curve = null        # yaml:50-73
var RepelFalloffCurve: Curve = null          # yaml:77-109

func _init() -> void:                        # 构造（CardFanConfig.cs:151；曲线键 YAML 直译）
	PositionOffsetCurve = _curve_from(VC.FAN["PositionOffsetCurve"])
	RotationOffsetCurve = _curve_from(VC.FAN["RotationOffsetCurve"])
	RepelFalloffCurve = _curve_from(VC.FAN["RepelFalloffCurve"])

static func _curve_from(keys: Array) -> Curve:
	var c := Curve.new()
	for k in keys:
		c.add_point(Vector2(k[0], k[1]), k[2], k[3])   # [time, value, inSlope, outSlope]
	return c

## GetLeftSplitOffset（:73）——卡数∈[MinMaxCardsForSplit] 时 0→1 归一线性插值 Left min→max
func GetLeftSplitOffset(number_of_cards: int) -> float:
	return _split_offset(number_of_cards, LeftSplitMinMaxOffset)

## GetRightSplitOffset（:112）
func GetRightSplitOffset(number_of_cards: int) -> float:
	return _split_offset(number_of_cards, RightSplitMinMaxOffset)

func _split_offset(number_of_cards: int, min_max: Vector2) -> float:
	var lo := float(MinMaxCardsForSplit.x)
	var hi := float(MinMaxCardsForSplit.y)
	var t := clampf((float(number_of_cards) - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	return lerpf(min_max.x, min_max.y, t)
