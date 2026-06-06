extends Control
## CyberSlider — 紫蓝霓虹风滑块
##
## 暴露:
##   min_value, max_value, step, value
##   value_text_func(Callable)  — 决定右侧显示文本(默认百分比)
##   accent_color
##   value_changed(value) 信号
##
## 行为:实时回调 on_change(value),释放时 SFX。

class_name CyberSlider

signal value_changed(value: float)

@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var step: float = 1.0
@export var value: float = 50.0 : set = set_value
@export var accent_color: Color = Color(0.13, 0.82, 0.93)
@export var show_value_text: bool = true

var _track: ColorRect       # 背景轨道
var _fill: ColorRect        # 已填充
var _handle: ColorRect      # 拖拽手柄
var _value_label: Label     # 右侧显示值
var _label: Label           # 左侧 label
var _label_text: String = ""
var _dragging: bool = false
var _on_change: Callable = Callable()
var _on_release: Callable = Callable()
var _value_formatter: Callable = Callable()  # (value) -> String

const TRACK_H := 6.0
const HANDLE_W := 14.0
const HANDLE_H := 24.0
const SIDE_PAD := 12.0


func _ready() -> void:
	custom_minimum_size = Vector2(360, 32)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	_label = Label.new()
	_label.name = "Label"
	_label.position = Vector2(0, 6)
	_label.size = Vector2(140, 24)
	_label.text = _label_text
	_label.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0, 0.95))
	add_child(_label)

	_track = ColorRect.new()
	_track.name = "Track"
	_track.color = Color(0.10, 0.06, 0.20, 0.9)
	_track.position = Vector2(0, (custom_minimum_size.y - TRACK_H) * 0.5)
	_track.size = Vector2(custom_minimum_size.x - 160, TRACK_H)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)

	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = accent_color
	_fill.size = Vector2(50, TRACK_H)
	_fill.position = _track.position
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	_handle = ColorRect.new()
	_handle.name = "Handle"
	_handle.color = Color(0.95, 0.97, 1.0, 1.0)
	_handle.size = Vector2(HANDLE_W, HANDLE_H)
	_handle.position = _track.position + Vector2(0, -9)
	_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_handle)

	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	_value_label.position = Vector2(custom_minimum_size.x - 80, 6)
	_value_label.size = Vector2(80, 24)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	_value_label.add_theme_font_size_override("font_size", 16)
	_value_label.add_theme_color_override("font_color", accent_color)
	_value_label.visible = show_value_text
	add_child(_value_label)

	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var tw := float(custom_minimum_size.x - 160)
	var range: float = max_value - min_value
	if range <= 0:
		return
	var ratio: float = clampf((value - min_value) / range, 0.0, 1.0)
	_fill.size.x = tw * ratio
	_handle.position.x = _track.position.x + tw * ratio - HANDLE_W * 0.5
	# 文本
	if _value_formatter.is_valid():
		_value_label.text = str(_value_formatter.call(value))
	else:
		_value_label.text = str(int(value))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_update_from_mouse(mb.position.x)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _dragging:
			_update_from_mouse(event.position.x)


func _update_from_mouse(local_x: float) -> void:
	var tw := float(custom_minimum_size.x - 160)
	var ratio: float = clampf((local_x - _track.position.x) / tw, 0.0, 1.0)
	var new_value: float = min_value + ratio * (max_value - min_value)
	if step > 0:
		new_value = snappedf(new_value, step)
	set_value(new_value)
	if _on_change.is_valid():
		_on_change.call(value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT_SELF or what == NOTIFICATION_WM_MOUSE_EXIT:
		if _dragging:
			_dragging = false
			_release_sfx()
	elif what == NOTIFICATION_DRAG_END:
		_dragging = false
		_release_sfx()


func _release_sfx() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("click")
	if _on_release.is_valid():
		_on_release.call(value)


# ---- API ----

func set_value(v: float) -> void:
	var old: float = value
	value = clampf(v, min_value, max_value)
	if value != old:
		value_changed.emit(value)
		_refresh()


func set_label_text(s: String) -> void:
	_label_text = s
	if _label:
		_label.text = s


func set_value_formatter(c: Callable) -> void:
	_value_formatter = c
	_refresh()


func set_on_change(c: Callable) -> void:
	_on_change = c


func set_on_release(c: Callable) -> void:
	_on_release = c
