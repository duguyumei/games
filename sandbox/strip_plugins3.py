import pathlib
FAIL=[]
def read(p): return pathlib.Path(p).read_text(encoding='utf-8')
def write(p,s): pathlib.Path(p).write_text(s, encoding='utf-8')
def sub(p,s,pairs):
    for old,new in pairs:
        n=s.count(old)
        if n!=1: FAIL.append(f"{p}: count={n} :: {old[:60]!r}"); continue
        s=s.replace(old,new)
    return s

P='design-docs/UI实施_v0.2.md'; s=read(P)
s=sub(P,s,[
 ("；状态列卡外右侧（图标 20×20、层数角标、悬停浮窗） |","（状态图标列已退役，2026-11-08） |"),
 ("；状态列同敌 |","（同上退役） |"),
])
write(P,s)

P='design-docs/剥离清单_v0.1.md'; s=read(P)
add = """
## 五、配件／插件／状态图标（2026-11-08 用户裁定退役）

> **退役理由**：元老设计，现役线不采用（用户原话：「这些都是元老的设计了」「我们也没有状态图标」）。当日**只清文档、不动代码**（用户裁定「游戏先留着、等后面再说」）；代码一律加「老版·不可参考」标注。

| 件 | 规模 | 状态 |
|---|---|---|
| 配件（＝插件）系统 | `QiPrepBay.gd` 全屏（1591 行：货架 5 位＋背包＋装配）＋`QiData` 装备表＋`QiBattle` 数值联动（如「回合首功法 −1 费」充能）＋存档 `equips` 字段 | **代码保留**（加老版标注）；文档已清（规则/武器样例/UI 三档）；原文移入 `references/旧代_配件与插件_v0.1.md` |
| 卡面状态图标列 | `QiBattleScreen._attach_status_col` / `_refill_status_col` / `_make_status_icon`（卡右外，图标＋×层数＋悬停浮窗） | **代码保留**（加老版标注）；文档已清；`assets/gi/` 图标库随之待退役 |

> 整批删除须另开一轮：涉 QiRoot 流程（备战舱是否留）、QiBattle 数值联动、存档结构迁移、`assets/gi/` 清理＋主菜单 CC BY 署名行。
"""
s = s.rstrip('\n') + '\n' + add
write(P,s)
print("FAIL:", FAIL if FAIL else "none")
