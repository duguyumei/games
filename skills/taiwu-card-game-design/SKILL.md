---
name: taiwu-card-game-design
description: 仅处理太吾卡牌游戏中同时跨越两个或以上设计域的总览、规则冲突、归属判断与全局审计。普通的流程、事件、战斗、卡牌、UI、AI、Boss、敌人或物品讨论应使用对应专用 Skill，不使用本路由 Skill。
---

# 太吾卡牌游戏设计路由

## 专用 Skill

| 讨论内容 | 使用 Skill |
| --- | --- |
| 单局流程、剑冢顺序、构筑阶段、解锁、奖励节奏 | `taiwu-run-design` |
| 随机事件、剧情选择、代价收益、事件池 | `taiwu-event-design` |
| 战场、时序、资源、伤害、状态、武器基础规则 | `taiwu-combat-design` |
| 卡牌分类、卡面文本、具名功法与内功卡池 | `taiwu-card-design` |
| 敌方决策、隐藏信息、搜索策略与难度 | `taiwu-ai-design` |
| 剑冢Boss机制、阶段、预告与专属奖励 | `taiwu-boss-design` |
| 普通敌人、精英敌人、敌群组合与遭遇梯度 | `taiwu-enemy-design` |
| 武器物品、护具、消耗品、遗物与掉落 | `taiwu-item-design` |

## 路由规则

1. 只加载用户问题的直接所有者，不为保险加载本 Skill或其他专用 Skill。
2. 用户明确同时修改多个系统时，只加载涉及的最少 Skill，并分别更新各自设计源。
3. 数值平衡跟随规则所有者；只有用户要求批量曲线、CSV或平衡报告时额外使用 `card-game-ip-dev`。
4. 总体流程内部包含构筑、局内成长和奖励经济，不再单独建立成长 Skill。
5. 不读取 `design-archive/`；归档只用于人工追溯旧讨论，不是当前规则源。
6. 始终区分`已确认`、`暂定`、`待定`和`已否决`，用户确认后在同轮更新所有者文档。
