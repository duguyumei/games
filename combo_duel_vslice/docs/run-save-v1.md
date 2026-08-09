# 本局存档 v1

`RunSaveApplicationService` 是 UI 和应用层唯一需要调用的边界：

- `execute({"type": "save_run", "run_session": session})`
- `execute({"type": "load_run"})`，成功时返回新的 `run_session`
- `execute({"type": "has_run_save"})`

v1 保存种子、初始构筑稳定 ID、层数、完整生成地图、当前/已完成节点、待领取奖励、历练、当前生命与生命上限、消耗品、八种牌型的功法槽位与序列、当前修习商店、功法 ID、持有/装备内功 ID、功法结算槽位、修习购买和完整 `RunDeck`/`QiCardInstanceData` 持久状态。显示名称不进入身份字段。

`growth` 段字段为 `experience`、`life`、`max_life`、`consumable_ids`、`hand_technique_progression`、`practice_shop_state`、`learned_technique_ids`、`learned_inner_skill_ids`、`equipped_inner_skill_ids`、`technique_slot_index`、`practice_purchase_ids` 与 `run_deck`。`hand_technique_progression` 分别保存八种具体牌型的 `slot_count` 与 `sequence`；`practice_shop_state` 保存当前普通商品、补充包、优惠券空位以及商店序号和冥想次数。`life`、`max_life` 两者存在时必须是正整数，且当前生命不得大于上限；损坏值不会被静默修正。

存档只允许以下节点边界：`awaiting_node`、`node_in_progress`、`awaiting_reward`、`boss_chest`、`run_complete`。`node_in_progress` 只表示已经进入节点；存档不包含手牌、牌堆顺序、战斗异状、行动队列或 AI 会话，载入结果明确返回 `restart_node_from_start`，由调用方重新创建战斗。这里保存的是战斗结束后已同步回本局的生命，不保存战斗中间态。

磁盘格式是带 `schema_version`、`content_version`、payload SHA-256 的 envelope。写入先落同目录临时文件并回读校验，再替换主文件；替换前将上一份可解析主文件原子更新到 `.bak`。主文件 JSON 或校验和损坏时读取备份并尝试恢复主文件；未知未来 schema 会拒绝读取，不会静默回退旧备份。

## UI 后续接入清单

1. 在建局、进入节点、结算完成、领取奖励、Boss 宝箱完成等应用层合法边界调用 `save_run`。
2. 战斗场景不得直接调用仓储；回到本局层并完成 `sync_progress_snapshot` 后再保存。
3. “继续游戏”先调用 `has_run_save`，再调用 `load_run`；若 `resume_policy` 为 `restart_node_from_start`，按当前节点内容重新创建战斗。
4. 将 `source == "backup"` 和恢复警告展示为非阻断提示；未知版本错误需要阻断并保留原文件。
