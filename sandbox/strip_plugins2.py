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

# 基础规则：变更日志里的配件子句
P='design-docs/基础规则_v0.8.md'; s=read(P)
s=sub(P,s,[
 ("；杀意获取源扩至两仪刀剑配件（机制对任何器灵生效）",""),
 ("**配件离队自动卸回背包（2026-10-28 裁定：入后备/被替换删除即卸下全部配件）**；",""),
])
write(P,s)

# 武器样例：七 → 六
P='design-docs/武器样例_v0.4.md'; s=read(P)
s=sub(P,s,[("## 七、设计点验证","## 六、设计点验证")]); write(P,s)

# UI实施
P='design-docs/UI实施_v0.2.md'; s=read(P)
s=sub(P,s,[
 ("＋出货率公示＋（右）刷新·30铜；货架＝**前 5 位配件＋第 6 位（最右）操作位（六类操作，两档定价）**；货位＝正方形 170×170 小卡＋价格签（2026-10-27 裁定），整行居中",
  "＋（右）刷新·30铜（配件货架已退役，2026-11-08）"),
 ("- 机制：配件购后补货·战后整架刷新·锁定免刷新·刷新带价；系统升级＝奇偶交替（奇次抽牌+1/偶次能量+1）＋出货率上浮；",
  "- 机制：系统升级＝奇偶交替（奇次抽牌+1/偶次能量+1）；"),
 ("（装/卸插件即时连锁，无快照字段）","（实时连锁，无快照字段）"),
 ("**装卸血件耐久联动（2026-10-29 用户裁定）**：±`stats.hp` 同步当前耐久；存活下限 1（不够降 1）、上限＝新 mhp；阵亡（0 血）当前耐久不动（复活只走回复通道）；负血件对称。三链路＝装备窗卸下／装配替换（**旧件回包，2026-10-29 补「覆盖即蒸发」之修**）／离队自动卸（`QiData.unequip_all`）。",""),
 ("（状态＋插件隐藏账）","（状态隐藏账）"),
])
write(P,s)
print("FAIL:", FAIL if FAIL else "none")
