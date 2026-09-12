class_name BoardLayout

# 版图几何常量合一（board.gd 与 board_tile.gd 共用）。
# D-059 节点制：地块键＝舆图锚点像素坐标（Vector2i 取整，图纸 1672×940），
# pixel() 是恒等映射＋底图偏移；TILE/CARD 为控件实际尺寸。

# 舆图底图（纸）在 Continent 里的左上角；锚点已是画内绝对像素，零偏移即贴合。
const MAP_ORIGIN := Vector2.ZERO
# 图纸逻辑尺寸（qingfeng_map.png / qingfeng_map.json 同一坐标系）。
const WORLD_SIZE := Vector2(1672, 940)
const TILE_SIZE := Vector2(210, 296)
const CARD_SIZE := Vector2(88, 124)
const MINI_SIZE := Vector2(40, 56)
# C-028：当前地块放大成 3 列卡牌网格（高度封顶约 3 行，超出滚动）。
const GRID_COLS := 3
const GRID_GAP := 8
const GRID_PAD := 8
const GRID_HEADER := 44
const GRID_ROWS_SHOWN := 3
const CURRENT_TILE_SIZE := Vector2(
	GRID_COLS * CARD_SIZE.x + (GRID_COLS - 1) * GRID_GAP + GRID_PAD * 2,
	GRID_HEADER + GRID_ROWS_SHOWN * CARD_SIZE.y + (GRID_ROWS_SHOWN - 1) * GRID_GAP + 6.0)

static func pixel(pos: Vector2i) -> Vector2:
	return MAP_ORIGIN + Vector2(pos)
