extends Control
## _GridDrawer — 主菜单背景网格层
##   60px 网格:1px 暗紫主线,每 5 格 1px 亮紫
##   通过 tween offset 字段漂移

const GRID := 60.0
const COLOR_MAIN := Color(0.55, 0.10, 0.95, 0.18)
const COLOR_SUB := Color(0.55, 0.10, 0.95, 0.08)

var offset := Vector2.ZERO


func _process(delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var ox: float = fmod(offset.x, GRID)
	var oy: float = fmod(offset.y, GRID)
	var x: float = ox - GRID
	var col: int = -1
	while x < w + GRID:
		col += 1
		var c: Color = COLOR_MAIN if (col % 5 == 0) else COLOR_SUB
		draw_rect(Rect2(x, 0, 1, h), c)
		x += GRID
	var y: float = oy - GRID
	var row: int = -1
	while y < h + GRID:
		row += 1
		var c2: Color = COLOR_MAIN if (row % 5 == 0) else COLOR_SUB
		draw_rect(Rect2(0, y, w, 1), c2)
		y += GRID
	# 中心十字
	var cx: float = w * 0.5
	var cy: float = h * 0.5
	draw_rect(Rect2(cx - 1, 0, 2, h), Color(0.13, 0.82, 0.93, 0.10))
	draw_rect(Rect2(0, cy - 1, w, 2), Color(0.13, 0.82, 0.93, 0.10))
