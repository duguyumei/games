# 本地化文本约定

默认语言为 `zh_CN`。目录使用 `entries` 数组而不是 JSON 对象，校验器因此能在解析后可靠发现重复 key。

稳定 key 只使用小写 ASCII、数字与下划线，并至少包含一个点。命名空间约定：

- `content.<内容类型>.<稳定逻辑 id>.<字段>`，例如 `content.technique.localization_probe_technique.name`
- `ui.<页面或组件>.<用途>`，例如 `ui.sample.turn_summary`
- `keyword.<稳定 id>.name`
- `tooltip.<稳定 id>.description`

内容逻辑始终引用 `id`。新内容保存 `name_key` / `description_key`；迁移期间，缺少 key 的旧记录可在 `LocalizedContentAdapter` 边界读取 `name` / `description`。一旦记录声明了 key，缺失翻译会显示为 `⟦key⟧`，不再被旧中文静默掩盖。

变量写作 `{parameter_name}`；字面花括号使用 `{{` 与 `}}`。所有语言必须为同一 key 提供完全一致的参数集合。数字、百分比、富文本关键词与 tooltip 统一由 `LocalizationCatalog` / `LocalizationTextFormatter` 格式化。

`LocalizedTextPresenter` 在窗口环境依次尝试 Noto Sans CJK SC、思源黑体、苹方、微软雅黑和 Arial Unicode，并允许系统继续 fallback；无窗口测试使用 Godot 内置字体，规避 macOS headless TextServer 解析系统字体集合的已知问题。展示器也为 `Label` / `RichTextLabel` 开启智能自动换行。布局宽度仍由具体组件负责，不应在翻译中手工插入换行来适配单一语言。
