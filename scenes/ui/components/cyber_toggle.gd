extends Control
## CyberToggle — 紫蓝霓虹风开关
##
## 暴露:
##   toggled (bool)
##   label_text (String)
##   on_change: Callable(bool)
##   accent_color

class_name CyberToggle

signal value_toggled(val: bool)

@export var toggled: bool = false : set = set_toggled
@export var label_text: String = "" : set = set_label_text
@export var accent_color: Color = Color(0.13, 0.82, 0.93)

const TRACK_W := 50.0
const TRACK_H := 24.0
const KNOB := 18.0

var _track: ColorRect
var _knob: ColorRect
var _label: Label
var _tween: Tween
var _on_change: Callable = Callable()


func _ready() -> void:
	custom_minimum_size = Vector2(60 + 200, 28)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()


func _build() -> void:
	_label = Label.new()
	_label.name = "Label"
	_label.text = label_text
	_label.position = Vector2(0, 6)
	_label.size = Vector2(200, 20)
	_label.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0, 0.95))
	add_child(_label)

	_track = ColorRect.new()
	_track.name = "Track"
	_track.color = Color(0.10, 0.06, 0.20, 0.9)
	_track.size = Vector2(TRACK_W, TRACK_H)
	_track.position = Vector2(220, (custom_minimum_size.y - TRACK_H) * 0.5)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)

	_knob = ColorRect.new()
	_knob.name = "Knob"
	_knob.size = Vector2(KNOB, KNOB)
	_knob.color = Color(0.95, 0.97, 1.0, 1.0)
	_knob.position = Vector2(220 + 3, (custom_minimum_size.y - KNOB) * 0.5)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_knob)


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	var track_col: Color = Color(0.10, 0.06, 0.20, 0.9)
	var knob_x: float = _track.position.x + 3
	if toggled:
		track_col = accent_color
		knob_x = _track.position.x + TRACK_W - KNOB - 3
	_tween.tween_property(_track, "color", track_col, 0.18)
	_tween.tween_property(_knob, "position:x", knob_x, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _label:
		_label.text = label_text


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			set_toggled(not toggled)
			_emit()
			get_viewport().set_input_as_handled()


func _emit() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("switch")
	value_toggled.emit(toggled)
	if _on_change.is_valid():
		_on_change.call(toggled)


# ---- API ----

func set_toggled(v: bool) -> void:
	if v == toggled:
		return
	toggled = v
	_refresh()


func set_label_text(s: String) -> void:
	label_text = s
	if _label:
		_label.text = s


func set_on_change(c: Callable) -> void:
	_on_change = c
