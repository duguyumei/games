class_name MJTile
extends RefCounted

# 真气牌（真气语法 v3 §1）：属性（万/筒/条，与麻将同三门，2026-09-15 拍板）× 数值（1–9）。
# 数值＝结构身份，不扛力度——力度住在功法配方与词条（《真气语法_v3》§1）。

const SUITS: Array[String] = ["万", "筒", "条"]
const VALUE_MIN := 1
const VALUE_MAX := 9

var suit: String
var value: int


func _init(new_suit: String = "", new_value: int = 0) -> void:
	suit = new_suit
	value = new_value


static func make(new_suit: String, new_value: int) -> MJTile:
	return MJTile.new(new_suit, new_value)


# 同一张牌（属性＋数值都同）——对子/刻子/杠的比对基础。
func same(other: MJTile) -> bool:
	return suit == other.suit and value == other.value


func key() -> String:
	return "%s%d" % [suit, value]


func display() -> String:
	return key()
