class_name PracticeOfferCard
extends Button

signal purchase_requested(consumable_id: String)

const UiDesignScript = preload("res://ui/ui_design.gd")

var _consumable_id := ""

func _ready() -> void:
    custom_minimum_size = Vector2(290, 330)
    add_theme_font_size_override("font_size", 18)
    pressed.connect(func(): purchase_requested.emit(_consumable_id))

func present(definition: Dictionary) -> void:
    _consumable_id = str(definition.get("id", ""))
    var price := int(definition.get("price", 0))
    text = "%s\n\n%s\n\n%d 历练\n\n%s" % [
        {"insight": "心 得", "pill": "丹 药", "treasure": "天材地宝"}.get(
            definition.get("kind", ""), "修习物"),
        definition.get("name", "未命名"), price,
        "已获得" if bool(definition.get("purchased", false)) else "点击购入共享栏"]
    tooltip_text = str(definition.get("description", ""))
    disabled = not bool(definition.get("can_purchase", false))
    add_theme_stylebox_override(
        "normal", UiDesignScript.box(Color("30283a"), 15, UiDesignScript.COLORS["purple"], 3, 9))
    add_theme_stylebox_override(
        "hover", UiDesignScript.box(Color("44344f"), 15, UiDesignScript.COLORS["gold"], 4, 13))
    add_theme_stylebox_override(
        "disabled", UiDesignScript.box(Color("25262b"), 15, Color("4c4f55"), 2, 2))
