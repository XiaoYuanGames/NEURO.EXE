extends Label
## GlitchLabel — 周期性触发 RGB 故障效果
##   颜色在青/紫/品红之间快速抖动 0.1s,然后回到白色

class_name GlitchLabel

@export var glitch_interval: float = 4.0
@export var glitch_duration: float = 0.12
@export var glitch_intensity: float = 1.0

const COLOR_WHITE := Color(0.95, 0.97, 1.0, 1.0)
const COLOR_CYAN := Color(0.13, 0.82, 0.93, 1.0)
const COLOR_MAGENTA := Color(0.95, 0.10, 0.65, 1.0)
const COLOR_PURPLE := Color(0.55, 0.10, 0.95, 1.0)

var _timer: float = 0.0
var _glitching: bool = false
var _glitch_t: float = 0.0


func _ready() -> void:
	modulate = COLOR_WHITE
	add_theme_color_override("font_color", COLOR_WHITE)
	add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))


func _process(delta: float) -> void:
	_timer += delta
	if not _glitching and _timer >= glitch_interval:
		_glitching = true
		_glitch_t = 0.0
		_timer = 0.0
	if _glitching:
		_glitch_t += delta
		var k: float = _glitch_t / glitch_duration
		if k >= 1.0:
			_glitching = false
			modulate = COLOR_WHITE
			add_theme_color_override("font_color", COLOR_WHITE)
			position = Vector2.ZERO
			rotation = 0.0
		else:
			# 抖位置
			position = Vector2(randf_range(-2, 2) * glitch_intensity, randf_range(-1, 1) * glitch_intensity)
			rotation = randf_range(-0.02, 0.02) * glitch_intensity
			# 闪颜色
			var c: Color
			var r: float = randf()
			if r < 0.33:
				c = COLOR_CYAN
			elif r < 0.66:
				c = COLOR_MAGENTA
			else:
				c = COLOR_PURPLE
			add_theme_color_override("font_color", c)
