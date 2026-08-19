class_name FrontMenuPage
extends Control

signal new_game_requested
signal continue_requested
signal info_requested(title: String, body: String)
signal quit_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _main_row: HBoxContainer = %MainRow
@onready var _brand_column: VBoxContainer = %BrandColumn
@onready var _game_title: Label = %GameTitle
@onready var _subtitle: Label = %Subtitle
@onready var _menu_panel: PanelContainer = %MenuPanel
@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _collection_button: Button = %CollectionButton
@onready var _records_button: Button = %RecordsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
    _apply_visual_style()
    _connect_actions()
    resized.connect(_apply_responsive_layout)
    _apply_responsive_layout()

func continue_button() -> Button:
    # FrontMain 在把页面加入场景树前就会查询此按钮；静态场景节点此时已存在。
    return get_node("%ContinueButton") as Button

func present_continue_availability(available: bool) -> void:
    var button := continue_button()
    button.disabled = not available
    button.tooltip_text = (
        "读取最近一次稳定本局记录"
        if available
        else "当前尚未建立本局存档，暂无可继续记录")

func _connect_actions() -> void:
    _new_game_button.pressed.connect(func(): new_game_requested.emit())
    _continue_button.pressed.connect(func(): continue_requested.emit())
    _collection_button.pressed.connect(func():
        info_requested.emit(
            "图 鉴",
            "图鉴入口已经建立。卡牌、功法、内功、消耗品、异状与敌人条目的正式展示规则尚未确认，因此当前不生成虚假条目。"))
    _records_button.pressed.connect(func():
        info_requested.emit(
            "记 录",
            "记录入口已经建立。本局历史、战斗回放与统计持久化尚未完成；当前结构化日志只在运行中的会话内可审计。"))
    _settings_button.pressed.connect(func():
        info_requested.emit(
            "设 置",
            "设置入口已经建立。完整的音量、画面、操作与辅助功能尚未接入；远程 AI 的本机配置继续由现有设置服务管理。"))
    _quit_button.pressed.connect(func(): quit_requested.emit())

func _apply_visual_style() -> void:
    _menu_panel.add_theme_stylebox_override(
        "panel",
        UiDesignScript.box(
            Color(0.045, 0.085, 0.08, 0.96),
            UiDesignScript.RADIUS_LG,
            Color("6d5733"),
            UiDesignScript.BORDER_REGULAR,
            18,
            Vector2.ZERO))
    UiDesignScript.style_button(
        _new_game_button, UiDesignScript.COLORS["copper"], 62.0)
    UiDesignScript.style_button(
        _continue_button, Color("49666a"), 62.0)
    var secondary_buttons: Array[Button] = [
        _collection_button,
        _records_button,
        _settings_button,
    ]
    for button: Button in secondary_buttons:
        UiDesignScript.style_button(button, Color("303c39"), 48.0)
    UiDesignScript.style_button(
        _quit_button, UiDesignScript.COLORS["red"].darkened(0.32), 46.0)

func _apply_responsive_layout() -> void:
    if not is_instance_valid(_safe_area):
        return
    var compact := size.x < 1500.0 or size.y < 820.0
    var horizontal_margin := 38 if compact else 76
    var vertical_margin := 28 if compact else 48
    _safe_area.add_theme_constant_override("margin_left", horizontal_margin)
    _safe_area.add_theme_constant_override("margin_right", horizontal_margin)
    _safe_area.add_theme_constant_override("margin_top", vertical_margin)
    _safe_area.add_theme_constant_override("margin_bottom", vertical_margin)
    _main_row.add_theme_constant_override("separation", 32 if compact else 72)
    _brand_column.custom_minimum_size.x = 520.0 if compact else 650.0
    _menu_panel.custom_minimum_size.x = 370.0 if compact else 410.0
    _game_title.add_theme_font_size_override("font_size", 58 if compact else 76)
    _subtitle.add_theme_font_size_override("font_size", 17 if compact else 20)
