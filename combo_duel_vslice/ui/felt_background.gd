extends Control

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("0d4739"))
    var grid_color := Color(0.4, 0.82, 0.68, 0.045)
    var dark_grid := Color(0.01, 0.12, 0.09, 0.08)
    var step := 46
    for x in range(-int(size.y), int(size.x) + int(size.y), step):
        draw_line(Vector2(x, 0), Vector2(x + size.y, size.y), grid_color, 1.0)
    for x in range(0, int(size.x) + step, step):
        draw_line(Vector2(x, 0), Vector2(x, size.y), dark_grid, 1.0)
    for y in range(0, int(size.y) + step, step):
        draw_line(Vector2(0, y), Vector2(size.x, y), dark_grid, 1.0)
    for y in range(18, int(size.y), 37):
        for x in range(22, int(size.x), 43):
            var offset := 11 if int(y / 37) % 2 == 0 else 0
            draw_circle(Vector2(x + offset, y), 1.25, Color(0.82, 0.94, 0.78, 0.08))
    draw_circle(Vector2(-80, -70), 360, Color(0.01, 0.08, 0.06, 0.18))
    draw_circle(Vector2(size.x + 100, size.y + 80), 430, Color(0.01, 0.08, 0.06, 0.2))
