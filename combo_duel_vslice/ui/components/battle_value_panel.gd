class_name BattleValuePanel
extends VBoxContainer

## 左控制台的牌型与数值展示区。
##
## 这里只负责把当前选牌状态渲染成文字，不读取战斗会话、不发起命令、不做规则判断。
## 面板一共只有四种状态，每种对应一个 present 方法；调用方选择状态，面板不自行推断。
## 此前这七个标签由主战斗页面直接持有，四种状态的文案散落在 30 余处赋值中。

const UiDesignScript = preload("res://ui/ui_design.gd")

const COLORS := UiDesignScript.COLORS

const IDLE_HAND_NAME := "等待选牌"
const IDLE_BASELINE := "牌型基准值 0 · 不自动伤害"
const IDLE_TECHNIQUE_NAME := "当前功法：—"
const IDLE_TECHNIQUE_DESCRIPTION := "选择真气后显示功法效果。"

var _hand_name: Label
var _base_value: Label
var _multiplier: Label
var _power_value: Label
var _baseline: Label
var _technique_name: Label
var _technique_description: Label
var _built: bool = false

func _ready() -> void:
    _ensure_built()

## 未选牌。数值归零，功法区提示等待。
func present_idle() -> void:
    _ensure_built()
    _hand_name.text = IDLE_HAND_NAME
    _base_value.text = "0"
    _multiplier.text = "0"
    _power_value.text = "0"
    _baseline.text = IDLE_BASELINE
    _technique_name.text = IDLE_TECHNIQUE_NAME
    _technique_description.text = IDLE_TECHNIQUE_DESCRIPTION

## 选牌不构成合法牌型。只更新牌型名，其余保留上一次内容供对照。
func present_invalid() -> void:
    _ensure_built()
    _hand_name.text = "无效选择"

## 合法预览。`values` 来自行动预览结果，`technique` 为当前精确牌型对应功法。
func present_preview(
        hand: Dictionary,
        values: Dictionary,
        technique: Dictionary,
        inner_skill_defense: int,
        same_qi_gain: int = 0) -> void:
    _ensure_built()
    _hand_name.text = str(hand["name"])
    _base_value.text = str(values["contribution_total"])
    _multiplier.text = str(values["attribute_concentration"])
    _power_value.text = str(values["technique_value"])
    _baseline.text = "C %d · N %d · M %d · P₀ %d · P %d" % [
        int(values["contribution_total"]),
        int(values["attribute_concentration"]),
        int(values["technique_multiplier"]),
        int(values["initial_power"]),
        int(values["technique_value"]),
    ]
    _technique_name.text = "当前功法：%s" % str(technique.get("name", "空序列"))
    var description := str(technique.get("description", "该精确牌型当前没有功法。"))
    if inner_skill_defense > 0:
        description += "\n内功预计获得 %d 防御。" % inner_skill_defense
    description += "\n本次同气 +%d。" % same_qi_gain
    _technique_description.text = description

## 消耗品定向中。数值不适用，功法区改为展示消耗品。
func present_consumable(definition: Dictionary) -> void:
    _ensure_built()
    _hand_name.text = "使用 · %s" % str(definition.get("name", "消耗品"))
    _base_value.text = "—"
    _multiplier.text = "—"
    _power_value.text = "—"
    _baseline.text = "构筑改造 · 使用后立即刷新预览"
    var kind_label: String = {
        "insight": "心得",
        "pill": "丹药",
        "treasure": "天材地宝",
    }.get(str(definition.get("kind", "")), "消耗品")
    _technique_name.text = "%s · %s" % [kind_label, str(definition.get("name", ""))]
    _technique_description.text = str(definition.get("description", ""))

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    add_theme_constant_override("separation", 9)

    var type_caption := Label.new()
    type_caption.text = "当前牌型"
    type_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    type_caption.add_theme_color_override("font_color", COLORS["muted"])
    add_child(type_caption)

    _hand_name = Label.new()
    _hand_name.text = IDLE_HAND_NAME
    _hand_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hand_name.add_theme_font_size_override("font_size", 28)
    _hand_name.add_theme_color_override("font_color", COLORS["cream"])
    add_child(_hand_name)

    add_child(_build_equation())
    add_child(_build_power_panel())

    _technique_name = Label.new()
    _technique_name.text = IDLE_TECHNIQUE_NAME
    _technique_name.add_theme_font_size_override("font_size", 16)
    _technique_name.add_theme_color_override("font_color", COLORS["gold"])
    add_child(_technique_name)

    _technique_description = Label.new()
    _technique_description.text = IDLE_TECHNIQUE_DESCRIPTION
    _technique_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _technique_description.add_theme_font_size_override("font_size", 12)
    _technique_description.add_theme_color_override("font_color", COLORS["muted"])
    add_child(_technique_description)

func _build_equation() -> Control:
    var equation := HBoxContainer.new()
    equation.alignment = BoxContainer.ALIGNMENT_CENTER
    equation.add_theme_constant_override("separation", 7)
    var base_tile := UiDesignScript.number_tile("0", "贡献 C", COLORS["red"])
    _base_value = base_tile["value"]
    equation.add_child(base_tile["root"])
    var times := Label.new()
    times.text = "×"
    times.add_theme_font_size_override("font_size", 28)
    times.add_theme_color_override("font_color", COLORS["muted"])
    equation.add_child(times)
    var multiplier_tile := UiDesignScript.number_tile("0", "属性集中 N", COLORS["blue"])
    _multiplier = multiplier_tile["value"]
    equation.add_child(multiplier_tile["root"])
    return equation

func _build_power_panel() -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color("3b3120"), 11, COLORS["gold"], 2, 5))
    var column := VBoxContainer.new()
    var caption := Label.new()
    caption.text = "功法值  P"
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_color_override("font_color", Color("d8c79f"))
    column.add_child(caption)

    _power_value = Label.new()
    _power_value.text = "0"
    _power_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _power_value.add_theme_font_size_override("font_size", 34)
    _power_value.add_theme_color_override("font_color", Color("ffe08a"))
    column.add_child(_power_value)

    _baseline = Label.new()
    _baseline.text = IDLE_BASELINE
    _baseline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _baseline.add_theme_font_size_override("font_size", 11)
    _baseline.add_theme_color_override("font_color", Color("cbbd98"))
    column.add_child(_baseline)

    panel.add_child(column)
    return panel
