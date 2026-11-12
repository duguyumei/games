## 原版 HorizontalCardLayoutGroup 1:1（.../HorizontalCardLayoutGroup.cs，41 行）——
## 手牌横向布局特化：axis0＝主轴（行排＋间距＋劈开），axis1＝副轴（**弧线排布**）。
## 【2026-11-12 弧案翻案】原判「副轴死代码」系 survey 误读：SetLayoutVertical 实参
## isVertical:FALSE（HorizontalCardLayoutGroup.cs:37 直读），AlignChildrenAlongAxis
## 汇编 033-034 相等分支尾跳 0x3B333B0＝AlignOnSecondaryAxis 入口（本文件 1520 行块
## 验证）——(!isVertical)==axis 时走副轴。故纵向 pass → AlignOnSecondaryAxis →
## FanCardPosition 弧线偏移，每帧布局都在跑。两处 F6 旧判「平排对」作废。
extends "res://qiforge/vc/CardLayoutGroup.gd"

## CalculateLayoutInputHorizontal（:21）
func CalculateLayoutInputHorizontal() -> void:
	CalculateSpacingAlongAxis(0, false)

## CalculateLayoutInputVertical（:26）——实参 isVertical:FALSE（cs 直读）
func CalculateLayoutInputVertical() -> void:
	CalculateSpacingAlongAxis(1, false)

## SetLayoutHorizontal（:32）
func SetLayoutHorizontal() -> void:
	AlignChildrenAlongAxis(0, false)

## SetLayoutVertical（:37）——实参 isVertical:FALSE（弧线由此激活）
func SetLayoutVertical() -> void:
	AlignChildrenAlongAxis(1, false)
