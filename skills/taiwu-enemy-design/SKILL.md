---
name: taiwu-enemy-design
description: 设计太吾卡牌游戏的普通敌人、精英敌人和敌群遭遇，包括战斗定位、牌组结构、招式组合、强弱项、教学目标、精英变体、遭遇梯度与奖励类别。不要设计剑冢Boss、通用战斗AI或流程节点数量。
---

# 太吾敌人与精英设计

## 读取

- 完整读取 `references/enemy-foundation.md`；讨论具体敌人族群时再读取对应独立文件。

## 边界

- 普通敌人和精英敌人的内容归这里，Boss归 `taiwu-boss-design`。
- 行动选择算法归 `taiwu-ai-design`，通用规则归 `taiwu-combat-design`。
- 遭遇在地图中的出现频率归 `taiwu-run-design`。

## 设计规则

- 普通敌人教会或检验一个主要机制。
- 精英组合两个机制，并提供清楚的高风险高收益理由。
- 同一阶段的敌人共享有限规则词汇，通过卡组比例、位置偏好和资源曲线区分。

## 维护

用户确认敌人后写入对应族群文件；共同模板更新到 `enemy-foundation.md`。
