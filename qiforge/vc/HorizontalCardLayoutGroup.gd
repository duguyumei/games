## 原版 HorizontalCardLayoutGroup 1:1（.../HorizontalCardLayoutGroup.cs，41 行）——
## 手牌横向布局特化：axis0＝主轴（行排）、axis1＝副轴（死路径早退）。
extends "res://qiforge/vc/CardLayoutGroup.gd"

## CalculateLayoutInputHorizontal（:21）
func CalculateLayoutInputHorizontal() -> void:
	CalculateSpacingAlongAxis(0, false)

## CalculateLayoutInputVertical（:27）
func CalculateLayoutInputVertical() -> void:
	CalculateSpacingAlongAxis(1, true)

## SetLayoutHorizontal（:32）
func SetLayoutHorizontal() -> void:
	AlignChildrenAlongAxis(0, false)

## SetLayoutVertical（:37）
func SetLayoutVertical() -> void:
	AlignChildrenAlongAxis(1, true)
