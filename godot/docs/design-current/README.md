# 组合出招模块化权威设计源

状态：当前 v0.30 权威设计源的模块化入口。
日期：2026-08-15

原权威源元数据：

> 组合出招当前设计源 v0.30
>
> 状态：52张完整真气牌组、基础八脉容量8、寄脉、打出／明确弃牌后消散的虚无、临时牌阶、高牌／对子／三条／顺子／炸弹五个普通功法池与葫芦跨池读取、具体牌型独立槽位与循环序列、八种心得、同步出招、协同、属性集中倍率与同气槽连动继续生效。当前运行时五个普通正式池共169门：高牌49门、对子38门、三条27门、顺子26门、炸弹29门；另有“散招”“守招”两门基础通用功法，当前正式资源总数171。风系51门与本批调整的林系功法均已完成正式资源、公共底层和专项测试接入。实现只承接权威规则，不反向定义设计。
>
> 日期：2026-08-15

本目录中的模块文件共同组成当前唯一权威设计正文；本 README 是唯一入口和治理文件。具体规则只能在一个模块文件中定义，其他模块必须链接引用。原始长文档已转为迁移指针，不能继续作为第二份规则正文。

## 推荐阅读顺序

1. [设计目标与术语](./01-vision-and-language.md)
2. [牌型、真气值与倍率](./combat/10-hand-ranking-and-values.md)
3. [牌组、手牌与牌区](./combat/11-deck-hand-and-zones.md)
4. [行动结算、触发队列与连击](./combat/12-action-resolution.md)
5. [伤害、防御与对战结果](./combat/13-damage-defense-and-results.md)
6. [真气效果、重塑与异状](./combat/14-qi-effects-and-statuses.md)
7. [功法系统框架](./martial-arts/20-gongfa-framework.md)；[首批高牌正式功法目录](./martial-arts/24-gongfa-high-card-pool.md)；[蛊毒功法](./martial-arts/25-gongfa-poison-candidate-pool.md)、[成长功法](./martial-arts/26-gongfa-growth-candidate-pool.md)、[跨系统桥接功法](./martial-arts/27-gongfa-bridge-candidate-pool.md)、[山·阵势与壁垒流](./martial-arts/29-gongfa-mountain-candidate-pool.md)与[风·运转与扰乱流正式目录](./martial-arts/33-gongfa-wind-pool.md)共同维护当前正式正文，稳定ID、池归属及当前数量见[扩展功法正式索引](./martial-arts/28-gongfa-expanded-formal-pool-index.md)；[旧蛊毒](./martial-arts/21-gongfa-poison-pool.md)、[旧风运转](./martial-arts/22-gongfa-wind-pool.md)与[旧火反击](./martial-arts/23-gongfa-fire-pool.md)仅为历史归档
8. [内功系统与目录](./martial-arts/30-neigong-framework.md)
9. [玩家成长与消耗品](./progression/40-progression-overview.md)
10. [修习与历练经济](./economy/50-training-and-experience.md)及[地图流程](./run/60-map-run-and-health.md)、[正式敌人内容](./run/61-enemy-content.md)
11. [敌方 AI](./ai/70-enemy-ai.md)
12. [验证与开放问题](./validation/90-rule-calculator.md)

## 模块所有权

| 模块 | 权威正文 | 禁止承载 |
|---|---|---|
| 战斗规则核 | `combat/` | 不重复功法池内容、成长商品和 AI 协议 |
| 武学内容 | `martial-arts/` | 不重定义牌型、伤害、地图和经济规则 |
| 成长与经济 | `progression/`、`economy/` | 不复制战斗时序和真气生命周期 |
| 地图流程 | `run/` | 不重定义战斗内部结算 |
| 敌方 AI | `ai/` | 只能选择规则核提供的合法候选，不能产生第二套规则 |
| 验证与开放问题 | `validation/` | 未确认项不得写成已确认规则 |

## 依赖方向

```text
设计目标与术语
  → 牌型/数值与牌区
  → 行动结算与伤害结果
  → 真气效果
  → 功法/内功框架与具体内容
  → 成长、经济与地图流程
  → AI 合法候选与验证
```

## 权威边界

- `godot/docs/combo-duel-current.md` 现在只是迁移指针。
- `combo_duel_vslice/data/*.json` 是运行子集或测试夹具，不反向定义设计。
- `combo_duel_vslice/docs/technique-content-status.md` 只记录接入状态。
- `combo_duel_vslice/docs/unconfirmed-rules.md` 只记录未确认问题。
- 原 `skills/` 下声明依赖缺失旧战斗文档的另一套规则，不属于本项目当前组合出招权威源；
  已于 2026-08-07 移出仓库至 `taiwu-deprecated/2026-08-07-dangling-skills/`。
- 旧 Godot 工程归档不作为当前规则或实现输入。

## 修改协议

新增或修改规则时，先判断其唯一所属模块；只在该模块正文中维护。跨模块影响通过相对链接和变更说明表达。迁移核对完成前，原章节编号只用于审计，不得据此创建第二份规则正文。
