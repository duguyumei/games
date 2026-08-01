return {
    Title = "对话优化",
    Author = "cc",
    Version = "0.1.5",
    GameVersion = "1.0.1",
    Source = 0,
    FileId = 0,
    FrontendPlugins = {
        [1] = "TaiwuBehaviorOptionSort.dll",
    },
    Description = "优化事件对话选项排序与单选项快捷键操作。",
    DefaultSettings = {
        {
            SettingType = "Toggle",
            Key = "PrioritizeSameBehaviorOptions",
            DisplayName = "自身性格选项优先",
            Description = "对话选项中存在符合太吾当前处世立场的选项时，将其排到最前。",
            DefaultValue = true,
        },
        {
            SettingType = "Toggle",
            Key = "SingleOptionHotkeyCompat",
            DisplayName = "单选项快捷键兼容",
            Description = "对话只有一个选项时，快捷键 1 和 Esc 都可以选择该选项。",
            DefaultValue = true,
        },
        {
            SettingType = "Toggle",
            Key = "MoveSideOptionsAfterNormalOptions",
            DisplayName = "支线选项后置",
            Description = "将未读/已读支线对话选项排到普通选项后面，同时保持 Esc 选项在最底部。",
            DefaultValue = true,
        },
    },
    NeedRestartWhenSettingChanged = false,
    TagList = {
        [1] = "Modifications",
    },
    Visibility = 0,
}
