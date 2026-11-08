## 特效档案表（2026-11-07 用户令「先定工作流」；现行档＝design-docs/特效管线_v0.1.md）。
## 只登记「走语法轨」的卡：有档案 → QiCombatFx.strike 播全套语法；没档案 → 继续走旧
## thrust 笔锋线（逐张迁移，每迁一张跑一次截图批验收）。加卡＝在这张表里填一行，不改调用方。
##
## 字段（§2.1）：carrier 载体 / impact 命中族 / amps 幅度 / ornament 装饰件开关 /
##              repeat_jitter 同敌连击散点半径 / gap_* 节拍 / lead 起手。
## trajectory 与 impact 的派生值由卡表 targeting/stance 推出——本表只写「幅度」，
## 不写轨迹（防同是斩的名卡各长一个样）。
extends RefCounted

## ── 直刺 v1：右→左六连点刺（首个样板）──
## 需求句：数得出五六下、看得出从右往左扫、刺是点不是弧、收在左端。
const ZHICI := {
	"carrier": "arrow",           # 墨箭（从血珠射出）
	"impact": "pierce",
	"trajectory": "sweep_rl",     # 右→左顺发（right_left）
	"amps": {
		"blade_len": 250.0,            # 右下角那把剑的剑长（剑格→剑尖）
		"blade_w": 21.0,               # 剑身宽（白刃口贴在上沿外侧）
		"light_len": 120.0,            # 剑光长度（飞行体）
		"shake": 1.8,
		"hitstop": 25,
		"recoil": 4.0,
	},
	"ornament": ["hole", "flash", "trail"],   # 卡面留洞／卡面白闪／剑锋拖影
	"repeat_jitter": 9.0,          # 同敌连击：落点绕环散开（不叠成一坨）
	"gap_budget": 0.42,            # 节拍预算：gap = clamp(预算/n, 0.07, 0.10)——多段要数得清
	"gap_min": 0.07,
	"gap_max": 0.10,
	"travel": 0.20,                # 一支墨箭的飞行时间
	"lead": 0.06,
	"scabbard": true,            # 剑鞘制：从血珠出鞘、再从下方上弧（2026-11-08 用户令）
}

static var TABLE := {
	"zhici": ZHICI,
}

static func has_spec(cid: String) -> bool:
	return TABLE.has(cid)

static func get_spec(cid: String) -> Dictionary:
	return TABLE.get(cid, {})
