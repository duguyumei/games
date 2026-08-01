---
name: taiwu-boss-design
description: 设计太吾卡牌游戏的剑冢Boss与终局Boss，包括战斗身份、阶段转换、招牌能力、公开预告、规则例外、克制窗口、专属卡组、战后奖励类别和重复挑战变化。不要设计通用AI算法或整体剑冢顺序。
---

# 太吾Boss设计

## 读取

- 完整读取 `references/boss-foundation.md`；讨论具体Boss时再读取该Boss独立文件。

## 边界

- Boss在一局中的顺序、解锁与奖励数量归 `taiwu-run-design`。
- Boss如何从合法行动中选择归 `taiwu-ai-design`。
- 通用伤害、时序与资源归 `taiwu-combat-design`。
- 本 Skill只设计Boss拥有的内容、阶段与可读反制。

## 设计规则

每个Boss明确核心考题、阶段触发、玩家预告、反制窗口、失败学习点和专属奖励类别。规则例外保持少量，不用不可见信息制造难度。

## 维护

用户确认Boss后写入独立参考；基础约束更新到 `boss-foundation.md`。
