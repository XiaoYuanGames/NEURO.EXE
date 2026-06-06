extends ColorRect
## ScanlineOverlay — 全屏 CRT 扫描线
##   极细横向暗紫线条,缓慢上移。可调透明度 0-0.3。

class_name ScanlineOverlay

@export var scan_alpha: float = 0.12 : set = set_scan_alpha
@export var scan_spacing: int = 3
@export var drift_speed: float = 22.0

var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0, 0, 0, 0)
	anchor_right = 1.0
	anchor_bottom = 1.0


func set_scan_alpha(v: float) -> void:
	scan_alpha = clampf(v, 0.0, 0.3)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if scan_alpha <= 0.0:
		return
	var w: float = size.x
	var h: float = size.y
	var offset: float = fmod(_t * drift_speed, float(scan_spacing))
	var y: float = -float(scan_spacing) + offset
	while y < h:
		draw_rect(Rect2(0, y, w, 1), Color(0, 0, 0, scan_alpha))
		y += scan_spacing
