class_name FrontMain
extends Control

const RunScene = preload("res://ui/run_main.tscn")
const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const UiDesignScript = preload("res://ui/ui_design.gd")
const MenuPageScene = preload("res://ui/components/front_menu_page.tscn")
const BuildPageScene = preload("res://ui/components/starter_build_page.tscn")
const InfoPageScene = preload("res://ui/components/front_info_page.tscn")

const COLORS := UiDesignScript.COLORS

var composition_root := GameCompositionRootScript.new()
var content_catalog
var starter_repository
var selected_starter_build_id: String = ""
var seed_value: int = 2308

var shell: Control
var menu_page: Control
var build_page: Control
var info_page: Control
var continue_button: Button
var begin_run_button: Button
var active_run = null
var _initialized: bool = false

func _ready() -> void:
    initialize_interface()

func initialize_interface() -> void:
    if _initialized:
        return
    _initialized = true
    theme = UiDesignScript.create_theme()
    composition_root.initialize()
    content_catalog = composition_root.content_catalog
    starter_repository = composition_root.starter_build_repository
    if content_catalog.loaded:
        starter_repository.configure(
            content_catalog.definition("starter_builds"))
        var builds: Array = starter_repository.available_builds()
        if builds.size() == 1:
            selected_starter_build_id = str(builds[0].get("id", ""))
    _build_background()
    shell = Control.new()
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shell)
    menu_page = MenuPageScene.instantiate()
    menu_page.new_game_requested.connect(_on_new_game)
    menu_page.info_requested.connect(_show_info)
    menu_page.quit_requested.connect(_quit_game)
    continue_button = menu_page.continue_button()
    build_page = BuildPageScene.instantiate()
    build_page.selection_requested.connect(_select_available_build)
    build_page.begin_requested.connect(_start_new_run)
    build_page.back_requested.connect(_show_menu)
    begin_run_button = build_page.begin_button()
    info_page = InfoPageScene.instantiate()
    info_page.back_requested.connect(_show_menu)
    shell.add_child(menu_page)
    shell.add_child(build_page)
    shell.add_child(info_page)
    _refresh_starter_build_button()
    _show_menu()

func _build_background() -> void:
    var background := ColorRect.new()
    background.color = COLORS["background"]
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var glow := GradientTexture2D.new()
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([
        Color(0.18, 0.38, 0.34, 0.32),
        Color(0.03, 0.08, 0.09, 0.0),
    ])
    glow.gradient = gradient
    glow.width = 1024
    glow.height = 1024
    glow.fill = GradientTexture2D.FILL_RADIAL
    glow.fill_from = Vector2(0.25, 0.38)
    glow.fill_to = Vector2(0.9, 0.9)
    var texture := TextureRect.new()
    texture.texture = glow
    texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture.stretch_mode = TextureRect.STRETCH_SCALE
    texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(texture)

func _on_new_game() -> void:
    var builds: Array = starter_repository.available_builds()
    selected_starter_build_id = (
        str(builds[0].get("id", "")) if builds.size() == 1 else "")
    _refresh_starter_build_button()
    _show_page(build_page)

func _select_available_build() -> void:
    var builds: Array = starter_repository.available_builds()
    if builds.size() == 1:
        selected_starter_build_id = str(builds[0].get("id", ""))
    _refresh_starter_build_button()

func _refresh_starter_build_button() -> void:
    if build_page == null:
        return
    var definition: Dictionary = starter_repository.get_build(selected_starter_build_id)
    build_page.present(definition)

func _start_new_run() -> void:
    var check: Dictionary = starter_repository.validate_selection(
        selected_starter_build_id)
    if not check.get("success", false):
        return
    shell.visible = false
    active_run = RunScene.instantiate()
    active_run.configure_composition_root(composition_root)
    active_run.configure_new_run({
        "seed": seed_value,
        "starter_build_id": selected_starter_build_id,
    })
    add_child(active_run)
    # 场景可能在当前帧稍后才收到 _ready；入口必须在返回前完成建局，
    # 这样 UI、测试和后续存档读取都能看到同一个已生成的 RunSession。
    active_run.initialize_interface()

func _show_info(title: String, body: String) -> void:
    info_page.present(title, body)
    _show_page(info_page)

func _show_menu() -> void:
    _show_page(menu_page)

func _show_page(page: Control) -> void:
    if menu_page != null:
        menu_page.visible = page == menu_page
    if build_page != null:
        build_page.visible = page == build_page
    if info_page != null:
        info_page.visible = page == info_page

func _quit_game() -> void:
    get_tree().quit()
