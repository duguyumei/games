# 内容批量生产工具链

本目录在现有 `ContentCatalog` / `ContentValidator` 之上提供独立的作者工作流，不修改
`CombatEngine`，也不把草稿写入正在由其他任务录入的 `data/techniques/*.tres`。

## 全量校验

在仓库根目录串行运行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --log-file /tmp/taiwu-content-validation.log \
  --path combo_duel_vslice \
  --script res://tools/content_pipeline/validate_content.gd \
  -- --pretty --report /tmp/taiwu-content-validation.json
```

合法内容退出码为 `0`，内容错误为 `1`，CLI/报告写入错误为 `2`。脚本输出的最后一行为
JSON，`--report` 文件是纯 JSON；`diagnostics[].code/path/message` 适合 CI 注解。校验会递归扫描 `res://data` 下所有
JSON/TRES，并额外检查：

- 顶层 `version` / 非运行时工件的 `schema_version`；
- snake_case 稳定 ID、同类型重复 ID、功法文件名与 ID 一致；
- `techniques.json` 的 TRES 路径重复、缺失、越界目录与未登记资源；
- 功法池、序列、真气、状态、重塑、消耗品、敌人装配和节点场景的跨文件引用；
- 运行时已注册操作码、递归数值规格、目标阵营/牌区/顺序/不足策略；
- 内功 `on_play_resolve` 与延迟效果 `turn_end` / `after_normal_draw` 事件时点；
- `production_enemy_entry.json`、`production_node_content.json`、`production_sequences.json`
  这类并行生产文件也会被识别，并以相同核心契约验证。

Godot 自身即使退出 `0`，调用方仍须把 stdout 中的 `Can't load script` 或 `File not found`
视为失败。

测试夹具或独立草稿目录可用 `--data-root res://path/to/drafts` 指定；核心目录仍会作为跨文件
引用基线加载，指定目录中的作者工件会叠加到基线上验证。

## 生成骨架

支持 `technique`、`inner_skill`、`consumable`、`enemy`、`node` 五类：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --log-file /tmp/taiwu-generate-content.log \
  --path combo_duel_vslice \
  --script res://tools/content_pipeline/generate_skeleton.gd \
  -- --type technique --id sample_guard --name 样本守势 \
  --output /tmp/sample_guard.tres
```

生成器拒绝覆盖已有文件。功法输出可加载的 `.tres`；其余类型输出带
`schema_version/content_type/content` 的 `.content.json` 作者工件。作者工件可以先放在独立
草稿目录中由全量入口校验，再把 `content` 合并到对应正式文件：内功和消耗品追加到同名数组，
敌人作为完整场景文件，节点以 `node_type` 为键追加。正式合并后再次运行全量校验；不要绕过
`ContentCatalog` 直接在 `CombatEngine` 添加按内容 ID 分支。

骨架中的数值和说明只是可通过契约的占位值，必须替换为确认后的设计。新增操作语义时，应先扩展
通用效果处理器与校验器；普通内容批量新增只登记数据，不修改 `CombatEngine`。

## 验收测试

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --log-file /tmp/taiwu-content-pipeline-tests.log \
  --path combo_duel_vslice \
  --script res://tests/test_content_pipeline.gd
```

测试会批量注入两份功法、内功、消耗品、敌人和节点骨架，并明确断言重复 ID、缺失引用、
未知 op、非法目标策略、非法时点、非法数值规格、不稳定 ID 与缺失版本均被拒绝。
