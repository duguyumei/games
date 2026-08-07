# Godot 美术资源管线 v1.0

## 目录与命名

所有正式资源位于 `res://assets/<category>/`，使用小写 ASCII、下划线和三位版本号。运行时内容 ID 与文件版本分离，升级资源不修改游戏数据 ID。

| 类别 | 目录 | 文件名 | 母版尺寸 | 锚点 / 透明区 |
| --- | --- | --- | --- | --- |
| 真气卡图 | `cards/` | `card_<属性>_<牌阶>_vNNN` | 744×1039 | 中心 `(0.5,0.5)`；四边 24 px 安全区 |
| 头像 | `portraits/` | `portrait_<阵营>_<角色>_vNNN` | 512×512 | 脚点 `(0.5,0.92)`；四边 32 px |
| 背景 | `backgrounds/` | `bg_<场景>_<变体>_vNNN` | 1920×1080 | 中心；关键主体避开左右各 12% UI 区 |
| 图标 | `icons/` | `icon_<语义>_<状态>_vNNN` | 128×128 | 中心；四边 12 px；按 64/32 px 检查 |
| 特效 | `vfx/` | `fx_<效果>_<变体>_vNNN` | 512×512 | 默认中心；四边 40 px 防裁切 |
| 音频 | `audio/` | `audio_<类别>_<名称>_vNNN` | 48 kHz / 16 或 24 bit | 循环点写入 metadata；峰值 ≤ -1 dBFS |
| 字体 | `fonts/` | `font_<家族>_vNNN` | TTF/OTF | 必须含授权；不改字体内部 family 名称 |

允许扩展名和机器可读参数见 `res://config/art_import_profiles.json`。`README.md` 与同名 `.asset.json` 不作为可加载资源。

## Godot 导入策略

- 卡图、头像、图标与 UI 特效：filter 开、mipmap 关、无损压缩；透明边保持直通 alpha，禁止有色脏边。
- 背景：filter 与 mipmap 开；桌面可用有损压缩，若渐变出现色带则改无损。背景不进入图集。
- 图标图集按同一语义域分组，特效图集按同一效果分组；禁止把生命周期不同的资源塞入一张超大图集。单张图集建议不超过 2048²（移动端）/4096²（桌面）。
- 像素密度以 1440×900 基准 UI 为 1×；图标与特效母版按 2×制作，运行时缩至 50%。像素画资源若未来加入，必须使用独立 profile 且关闭 filter，不能混用当前 profile。
- macOS/Windows/Linux 桌面遵循 profile 的 lossless/lossy；移动端发布时使用 Basis Universal 并检查文字边缘；Web 优先无损，按下载体积再单独降级。
- 音效源文件用 WAV，发布可转 OGG；环境与音乐循环必须无缝并记录 loop start/end。语音与一次性短音效不得误设循环。
- 字体通过 DynamicFont 导入，不烘焙进纹理图集。提交前确认简体中文常用字、正式术语、数字与符号覆盖。

Godot 首次导入会生成 `*.import` 和 `.godot/imported/` 缓存；缓存不作为规范源。每次导入后运行校验器，必要时在 Inspector 按 profile 调整，然后在目标平台做一次视觉抽查。

## 元数据

每个资源旁必须存在 `<完整文件名>.asset.json`，例如 `icon_defense_default_v001.svg.asset.json`。最低字段：

```json
{
  "asset_id": "icon_defense_default_v001",
  "category": "icons",
  "version": 1,
  "source": {
    "kind": "ai_generated|commissioned|licensed|internal|generated_placeholder",
    "provider": "来源或制作人",
    "license": "明确许可名称或内部版权声明",
    "source_url": "可为空但字段保留"
  },
  "generation": {"model": "模型或 n/a", "prompt": "完整提示词或 n/a", "seed": 0},
  "edits": [{"tool": "工具", "summary": "人工修改"}],
  "approval": {"status": "draft|approved|rejected", "reviewer": "姓名/角色", "reviewed_at": "ISO-8601", "notes": "结论"},
  "anchors": {"x": 0.5, "y": 0.5},
  "transparent_padding": {"left": 12, "top": 12, "right": 12, "bottom": 12}
}
```

生成参数、输入参考与人工修改应完整保留；二次导出只新增版本，不覆盖旧版元数据。授权不明时使用 `draft` 并禁止发布，不得填写“网络素材”“可商用”等模糊表述。

## 校验与接入

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --log-file /tmp/taiwu-art-validate.log \
  --path combo_duel_vslice --script res://tools/run_art_asset_validator.gd
```

校验器递归扫描七类目录，检测扩展名、命名、母版尺寸、元数据存在性、授权字段、生成参数和批准状态。任何 `ART ERROR` 或非零退出码都阻止合并。首次接入流程：

1. 从只读原稿导出新版本到正确目录，不覆盖已批准文件。
2. 复制并填写同名元数据；批准前保持 `draft`。
3. 在 Godot Inspector 应用该类别 profile，检查缩放、透明边和目标平台压缩。
4. 运行校验器；在实际 UI 尺寸完成人工验收后改为 `approved`。

当前 `*_placeholder_*` 样本只验证目录、导入和元数据链路，不代表正式美术质量。
