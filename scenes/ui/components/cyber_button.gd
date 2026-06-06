extends Control
## CyberButton — 紫蓝霓虹风按钮
##
## 状态机 + Tween 动画:
##   NORMAL:  1px 边框 accent 0.5, 静态
##   HOVER:   2px 边框 accent 1.0, scale 1.03, 扫描线从左向右划过
##   PRESSED: scale 0.96, 1 次脉冲光圈, 触发 pressed 信号 + SFX
##   DISABLED: 灰, 0.4 alpha, 不可交互
##
## 暴露参数:
##   text         (get/set)
##   accent_color (Color, 默认青蓝)
##   is_primary   (bool, 决定底色填充: 主按钮青蓝填充 + 深色字)
##   disabled     (bool)

class_name CyberButton

signal pressed

const COLOR_BG := Color(0.04, 0.02, 0.10, 0.85)
const COLOR_BG_PRIMARY := Color(0.13, 0.82, 0.93, 0.95)
const COLOR_TEXT := Color(0.95, 0.97, 1.0, 1.0)
const COLOR_TEXT_PRIMARY := Color(0.04, 0.02, 0.10, 1.0)
const COLOR_DISABLED := Color(0.20, 0.18, 0.28, 0.85)

@export var accent_color: Color = Color(0.13, 0.82, 0.93)  # 22D3EE
@export var is_primary: bool = false
@export var disabled: bool = false : set = set_disabled

var _bg: ColorRect
var _scanline: ColorRect
var _pulse: ColorRect
var _label: Label
var _tween: Tween
var _state: String = "NORMAL"
var _mouse_inside: bool = false
var _has_focus: bool = false
var _text: String = "BUTTON"


func _ready() -> void:
	custom_minimum_size = Vector2(240, 48)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply_state(true)


func _build() -> void:
	_bg = ColorRect.new()
	_bg.name = "Bg"
	_bg.color = COLOR_BG
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_scanline = ColorRect.new()
	_scanline.name = "Scanline"
	_scanline.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.0)
	_scanline.size = Vector2(40, 0)
	_scanline.anchor_top = 0.0
	_scanline.anchor_bottom = 1.0
	_scanline.anchor_right = 0.0
	_scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scanline)

	_pulse = ColorRect.new()
	_pulse.name = "Pulse"
	_pulse.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.0)
	_pulse.anchor_right = 1.0
	_pulse.anchor_bottom = 1.0
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pulse)

	_label = Label.new()
	_label.name = "Label"
	_label.text = _text
	_label.anchor_right = 1.0
	_label.anchor_bottom = 1.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_typography()


func _apply_typography() -> void:
	var font := load("res://assets/fonts/MiSans-Semibold.ttf")
	if font:
		_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY if is_primary else COLOR_TEXT)


# ---- 输入 ----

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_state = "PRESSED"
				_apply_state()
			else:
				if _mouse_inside:
					_state = "HOVER"
					_emit_pressed()
				else:
					_state = "NORMAL"
				_apply_state()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and (k.keycode == KEY_ENTER or k.keycode == KEY_SPACE or k.keycode == KEY_KP_ENTER):
			_state = "PRESSED"
			_apply_state()
			_emit_pressed()
			get_viewport().set_input_as_handled()


func _emit_pressed() -> void:
	_play_sfx("click")
	pressed.emit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_mouse_inside = true
			if not disabled and _state != "PRESSED":
				_state = "HOVER"
				_apply_state()
				_play_sfx("hover")
		NOTIFICATION_MOUSE_EXIT:
			_mouse_inside = false
			if not disabled:
				_state = "NORMAL"
				_apply_state()


# 主动高亮(用于键盘导航)— 不播 SFX,避免噪音
func set_focus_visual(focused: bool) -> void:
	if focused:
		if not disabled and _state != "PRESSED":
			_state = "HOVER"
			_apply_state()
	else:
		if not disabled:
			_state = "NORMAL"
			_apply_state()


# ---- API ----

func set_text(value: String) -> void:
	_text = value
	if _label:
		_label.text = value


func get_text() -> String:
	return _text


func set_disabled(v: bool) -> void:
	disabled = v
	if is_inside_tree():
		_state = "DISABLED" if v else "NORMAL"
		_apply_state(true)


func _refresh() -> void:
	_apply_state(true)


# ---- 状态 ----

func _apply_state(immediate: bool = false) -> void:
	if not is_inside_tree():
		return
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)

	var bg_col: Color = COLOR_BG
	var scanline_a: float = 0.0
	var scale_v: Vector2 = Vector2.ONE
	var disabled_alpha: float = 1.0

	match _state:
		"NORMAL":
			bg_col = COLOR_BG if not is_primary else COLOR_BG_PRIMARY
			scale_v = Vector2.ONE
			scanline_a = 0.0
		"HOVER":
			bg_col = COLOR_BG if not is_primary else COLOR_BG_PRIMARY
			scale_v = Vector2(1.03, 1.03)
			scanline_a = 0.18
		"PRESSED":
			bg_col = COLOR_BG if not is_primary else Color(0.10, 0.90, 1.0, 1.0)
			scale_v = Vector2(0.96, 0.96)
			scanline_a = 0.35
		"DISABLED":
			bg_col = COLOR_DISABLED
			scale_v = Vector2.ONE
			scanline_a = 0.0
			disabled_alpha = 0.5

	if immediate:
		_bg.color = bg_col
		_scanline.color.a = scanline_a
		scale = scale_v
		modulate = Color(1, 1, 1, disabled_alpha)
	else:
		_tween.tween_property(_bg, "color", bg_col, 0.15)
		_tween.tween_property(self, "scale", scale_v, 0.15)
		_tween.tween_property(_scanline, "color:a", scanline_a, 0.2)
		_tween.tween_property(self, "modulate:a", disabled_alpha, 0.15)

	if _state == "HOVER" or _state == "PRESSED":
		_scanline.size.y = size.y
		_scanline.size.x = max(40.0, size.x * 0.35)
		_scanline.color = Color(accent_color.r, accent_color.g, accent_color.b, scanline_a)
		_run_scanline()
	if _state == "PRESSED":
		_run_pulse()


func _run_scanline() -> void:
	if _scanline.size.x <= 0:
		return
	_scanline.position = Vector2(-_scanline.size.x, 0)
	var tw := create_tween()
	tw.tween_property(_scanline, "position:x", size.x + _scanline.size.x, 0.6)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _run_pulse() -> void:
	_pulse.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.7)
	var tw := create_tween()
	tw.tween_property(_pulse, "color:a", 0.0, 0.5)


func _play_sfx(name: String) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(name)
