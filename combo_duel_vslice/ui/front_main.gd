class_name FrontMain
extends Control

const RunScene = preload("res://ui/run_main.tscn")
const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const UiDesignScript = preload("res://ui/ui_design.gd")
const MenuPageScene = preload("res://ui/components/front_menu_page.tscn")
const BuildPageScene = preload("res://ui/components/starter_build_page.tscn")
const InfoPageScene = preload("res://ui/components/front_info_page.tscn")
const ContentFailurePageScript = preload("res://ui/components/content_failure_page.gd")

const COLORS := UiDesignScript.COLORS

var composition_root: GameCompositionRoot = GameCompositionRootScript.new()
var content_catalog: ContentCatalog
var starter_repository: StarterBuildRepository
var selected_starter_build_id: String = ""
var seed_value: int = 2308

var shell: Control
var menu_page: Control
var build_page: Control
var info_page: Control
var continue_button: Button
var begin_run_button: Button
var active_run = null
var new_game_confirmation: ConfirmationDialog
var _initialized: bool = false

func _ready() -> void:
    initialize_interface()

func initialize_interface() -> void:
    if _initialized:
        return
    _initialized = true
    theme = UiDesignScript.create_theme()
    var content_loaded := composition_root.initialize()
    content_catalog = composition_root.content_catalog
    starter_repository = composition_root.starter_build_repository
    if not content_loaded:
        var page := ContentFailurePageScript.new()
        add_child(page)
        page.present("内容校验失败，无法启动游戏", composition_root.content_errors())
        return
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
    menu_page.continue_requested.connect(_on_continue_game)
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
    new_game_confirmation = ConfirmationDialog.new()
    new_game_confirmation.title = "开始新行旅"
    new_game_confirmation.dialog_text = "开始新行旅会覆盖当前本局记录，是否继续？"
    new_game_confirmation.ok_button_text = "继续新行旅"
    new_game_confirmation.cancel_button_text = "保留当前记录"
    new_game_confirmation.confirmed.connect(_enter_new_game_configuration)
    add_child(new_game_confirmation)
    _refresh_starter_build_button()
    _show_menu()
    _refresh_continue_availability()

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
    var save_check: Dictionary = composition_root.run_save_application_service.execute({
        "type": "has_run_save",
    })
    if save_check.get("success", false) and save_check.get("exists", false):
        if new_game_confirmation.is_inside_tree():
            new_game_confirmation.popup_centered()
        return
    _enter_new_game_configuration()

func _enter_new_game_configuration() -> void:
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
    active_run.return_to_menu_requested.connect(_return_from_run_to_menu)
    active_run.new_run_requested.connect(_restart_from_terminal)
    add_child(active_run)
    # 场景可能在当前帧稍后才收到 _ready；入口必须在返回前完成建局，
    # 这样 UI、测试和后续存档读取都能看到同一个已生成的 RunSession。
    active_run.initialize_interface()

func _on_continue_game() -> void:
    var loaded: Dictionary = composition_root.run_save_application_service.execute({
        "type": "load_run",
    })
    if not loaded.get("success", false):
        _present_load_failure(loaded)
        return
    shell.visible = false
    active_run = RunScene.instantiate()
    active_run.configure_composition_root(composition_root)
    active_run.configure_restored_run(
        loaded["run_session"],
        str(loaded.get("resume_policy", "")),
        {
            "source": loaded.get("source", "primary"),
            "migrations": loaded.get("migrations", []).duplicate(),
            "recovery_restored_primary": loaded.get(
                "recovery_restored_primary", false),
            "recovery_warning": loaded.get("recovery_warning", ""),
        })
    active_run.return_to_menu_requested.connect(_return_from_run_to_menu)
    active_run.new_run_requested.connect(_restart_from_terminal)
    add_child(active_run)
    active_run.initialize_interface()

func _present_load_failure(result: Dictionary) -> void:
    var kind := str(result.get("kind", "domain_validation"))
    if kind == "missing":
        _refresh_continue_availability()
        _show_menu()
        return
    var title: String = {
        "corrupt": "存档损坏",
        "incompatible": "存档版本不兼容",
        "domain_validation": "存档内容校验失败",
    }.get(kind, "无法继续游戏")
    info_page.present(title, str(result.get("reason", "未知存档错误")))
    _show_page(info_page)

func _return_from_run_to_menu() -> void:
    _release_active_run()
    shell.visible = true
    _show_menu()
    _refresh_continue_availability()

func _restart_from_terminal() -> void:
    _release_active_run()
    shell.visible = true
    _show_menu()
    _refresh_continue_availability()
    _on_new_game()

func _release_active_run() -> void:
    if active_run == null:
        return
    active_run.shutdown_interface()
    active_run.queue_free()
    active_run = null

func _refresh_continue_availability() -> void:
    if menu_page == null or composition_root.run_save_application_service == null:
        return
    var result: Dictionary = composition_root.run_save_application_service.execute({
        "type": "has_run_save",
    })
    menu_page.present_continue_availability(
        bool(result.get("success", false) and result.get("exists", false)))

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
