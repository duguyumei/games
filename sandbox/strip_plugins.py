# 2026-11-08 文档清理：配件/插件/状态图标 → 移入 references/旧代_配件与插件_v0.1.md
import pathlib, sys
FAIL=[]
def read(p): return pathlib.Path(p).read_text(encoding='utf-8')
def write(p,s): pathlib.Path(p).write_text(s, encoding='utf-8')
def sub(p, s, pairs):
    for old,new in pairs:
        n=s.count(old)
        if n!=1: FAIL.append(f"{p}: count={n} :: {old[:50]!r}"); continue
        s=s.replace(old,new)
    return s

# ── 基础规则 v0.8 ─────────────────────────────
P='design-docs/基础规则_v0.8.md'
s=read(P)
s=sub(P,s,[
 ("**装备（插件）效果加、被动效果加 → 不进状态栏**（数值写在装备描述/被动描述里）",
  "**被动效果加 → 不进状态栏**（数值写在被动描述里）"),
 ("面板修正入状态栏的一律可见图标。","面板修正入状态栏的一律可见。"),
 ("（插件专属：改加所有伤害；升级 1：+2/层；升级 2：每累计获 3 层抽 1 张；插件 3 专属：回合末保留至多 5 层）",
  "（升级 1：+2/层；升级 2：每累计获 3 层抽 1 张）"),
 ("；获取源不限幽冥剑（两仪刀剑配件 3 可跨器灵授予，2026-10-28）",""),
 ("（插件 6 等效果层定义）","（效果层定义）"),
 ("；插件·丝蛊同源每层 +1 威力",""),
 ("（离场语义全套＝功法随档移除＋配件卸回背包）","（离场语义全套＝功法随档移除）"),
 ("。**装卸血件耐久联动（同日裁定）**：装/卸带耐久词条的配件，最大耐久随面板活变、当前耐久同步 ±词条值（存活下限 1——不够降 1；上限＝新最大；负血件对称）；阵亡（0 耐久）装卸件当前耐久不动。","。"),
 ("旧「Lv2 锚开局＋奇次抽牌/偶次能量」制（v0.7）退役；开局 Lv1 同时激活商店出货率表第一行（70/20/5/4/1）。",
  "旧「Lv2 锚开局＋奇次抽牌/偶次能量」制（v0.7）退役；开局 Lv1。"),
 ("效果＝§5 奇偶交替＋配件出货率上浮。","效果＝§5 奇偶交替。"),
 ("；插件可 +5/+10/+30",""),
 ("所有功法/敌方/插件数值对下表锚过秤","所有功法/敌方数值对下表锚过秤"),
 ("11. 功法/升级/插件对锚过秤清单","11. 功法/升级对锚过秤清单"),
])
out=[]; mode=None
for ln in s.split('\n'):
    st=ln.strip()
    if st.startswith("- **专属插件制（2026-10-27 立"): continue
    if st.startswith("- **配件绑定＝装备位资产"): continue
    if st.startswith("2. **专属插件正名**"): continue
    if st.startswith("| 配件价 |"): continue
    if st.startswith("| 配件数值带 |"): continue
    if st.startswith("- **商店**：货架 6 位——"):
        out.append("- **商店**：配件货架已退役（2026-11-08 用户裁定，原文见 `references/旧代_配件与插件_v0.1.md`）；货架第 6 位（最右）操作位保留——卖与奖励同池的七类操作一件（价目两档：功法类 50／器灵类 70；升级相关 +10；回复类价暂 50）；购后空位制；购买/刷新/升级一律直接执行，无二次确认（2026-10-27 裁定）。")
        mode="skip_table"; continue
    if mode=="skip_table":
        if st.startswith("| 5 | 10 |"): mode=None; continue
        continue
    out.append(ln)
write(P,'\n'.join(out))

# ── 武器样例 v0.4 ─────────────────────────────
P='design-docs/武器样例_v0.4.md'
s=read(P)
s=sub(P,s,[
 ("；幽冥插件 2 威力 +10→+5；通用插件 2 威力 +30→+8",""),
 ("；通用插件 1 翻倍→提升 80%（四回合归零，峰值入威力带）",""),
 ("／专属插件制",""),
 ("；插件名待确认暂占位「插件N」。**「配件」＝「插件」同物**（2026-10-28 起用户现用名，待全档统一正名）。","。"),
 ("（配件 2 回耐久、幽冥插件 1 上破绽、转刀形态等，同此口径）","（转刀形态等，同此口径）"),
 ("——插件按轴配平（幽冥插件 2 威力+10 vs 天丝插件 1 攻+5 威+5 生命−20 的交换制）",""),
 ("；天丝插件 3 让第二件器灵也能养蛊",""),
 ("、插件族全部防御系",""),
 ("。配件 3 杀意跨器灵＝与幽冥剑同队的协同位（杀意对任何器灵生效，见《基础规则 v0.8》状态表）","。"),
])
out=[]; skip=False
for ln in s.split('\n'):
    st=ln.strip()
    if st.startswith("> 2026-10-28 配件轮") or st.startswith("> 2026-10-29 专属呈现制") or st.startswith("> 2026-10-29 纯数值件品阶梯"):
        continue
    if st.startswith("## 六、通用插件十四件") or st.startswith("## 六、通用插件"):
        skip=True; continue
    if skip:
        if st.startswith("## 七、"): skip=False
        else: continue
    if st=="- **专属插件**：" or st.startswith("- **专属配件**（品级/价格暂定）"):
        skip_sub=True
        globals()['SKIPSUB']=True
        continue
    if globals().get('SKIPSUB') and (st.startswith("- 插件 ") or st.startswith("- 配件 ")):
        continue
    if globals().get('SKIPSUB') and not st.startswith("- "):
        pass
    globals()['SKIPSUB']=False
    if st.startswith("4. 负面数值插件（生命 −20／攻击 −2）＝交换制首次入案。"): continue
    out.append(ln)
s='\n'.join(out)
s=s.replace("# 武器样例（v0.4）\n","# 武器样例（v0.4）\n\n> **2026-11-08 用户裁定：配件（＝插件）系统退役**——元老设计，本档只写器灵与功法，原文移入 `references/旧代_配件与插件_v0.1.md`。代码仍留「老版」标注、不可参考。\n",1)
write(P,s)

print("FAIL:", FAIL if FAIL else "none")
