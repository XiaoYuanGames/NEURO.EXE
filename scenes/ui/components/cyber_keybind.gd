extends Control
## CyberKeybind — 紫蓝霓虹风按键绑定
##
## 显示当前绑定的 keycode,点击进入"等待按键"状态。
## 任意键按下后写入 action 的 InputMap (替换现有 events)。
##
## 暴露:
##   action_name (String, 如 "lane_1")
##   display_name (String, 用于左侧 label)
##   on_change: Callable(action_name: String, keycode: int)

class_name CyberKeybind

signal key_bound(action_name: String, keycode: int)
signal unbound(action_name: String)

@export var action_name: String = "" : set = set_action
@export var display_name: String = "" : set = set_display_name
@export var accent_color: Color = Color(0.13, 0.82, 0.93)

var _disabled: bool = false
var _label: Label
var _key_btn: Button
var _clear_btn: Button
var _waiting: bool = false
var _on_change: Callable = Callable()
var _i18n: Node


func _ready() -> void:
	custom_minimum_size = Vector2(360, 32)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_i18n = get_node_or_null("/root/I18n")
	_build()
	_refresh()


func _build() -> void:
	_label = Label.new()
	_label.text = display_name
	_label.position = Vector2(0, 6)
	_label.size = Vector2(160, 20)
	_label.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0, 0.95))
	add_child(_label)

	_key_btn = Button.new()
	_key_btn.position = Vector2(170, 0)
	_key_btn.size = Vector2(120, 32)
	_key_btn.focus_mode = Control.FOCUS_NONE
	_key_btn.flat = true
	_key_btn.pressed.connect(_on_key_pressed)
	_apply_btn_style()
	add_child(_key_btn)

	_clear_btn = Button.new()
	_clear_btn.text = "✕"
	_clear_btn.position = Vector2(300, 0)
	_clear_btn.size = Vector2(36, 32)
	_clear_btn.focus_mode = Control.FOCUS_NONE
	_clear_btn.flat = true
	_clear_btn.pressed.connect(_on_clear)
	_apply_clear_style()
	add_child(_clear_btn)


func _apply_btn_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.14, 0.95)
	sb.border_color = accent_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
	var sb_active := sb.duplicate()
	sb_active.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.25)
	_key_btn.add_theme_stylebox_override("normal", sb)
	_key_btn.add_theme_stylebox_override("hover", sb_hover)
	_key_btn.add_theme_stylebox_override("pressed", sb_active)
	_key_btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	_key_btn.add_theme_color_override("font_hover_color", accent_color)
	_key_btn.add_theme_color_override("font_pressed_color", accent_color)
	_key_btn.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	_key_btn.add_theme_font_size_override("font_size", 14)


func _apply_clear_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.06, 0.20, 0.7)
	sb.set_corner_radius_all(2)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.8, 0.2, 0.4, 0.6)
	_clear_btn.add_theme_stylebox_override("normal", sb)
	_clear_btn.add_theme_stylebox_override("hover", sb_hover)
	_clear_btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.9))
	_clear_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_clear_btn.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))


func _on_key_pressed() -> void:
	_waiting = true
	_key_btn.text = _tr("dialog_wait_key")
	_key_btn.modulate = accent_color
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("switch")


func _on_clear() -> void:
	_bind_key(KEY_NONE)


func _unhandled_input(event: InputEvent) -> void:
	if _disabled or not _waiting:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			_waiting = false
			_bind_key(k.keycode)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_waiting = false
			_bind_key(KEY_NONE)
			get_viewport().set_input_as_handled()


func _bind_key(keycode: int) -> void:
	if action_name.is_empty():
		return
	# 替换 InputMap
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	if keycode != KEY_NONE:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		InputMap.action_add_event(action_name, ev)
		key_bound.emit(action_name, keycode)
		_emit_change(keycode)
	else:
		unbound.emit(action_name)
		_emit_change(keycode)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("click")
	_refresh()


func _emit_change(keycode: int) -> void:
	if _on_change.is_valid():
		_on_change.call(action_name, keycode)


func _refresh() -> void:
	if not is_inside_tree():
		return
	_waiting = false
	_key_btn.modulate = Color.WHITE
	if action_name.is_empty() or not InputMap.has_action(action_name):
		_key_btn.text = _tr("dialog_unbound")
		return
	var evs := InputMap.action_get_events(action_name)
	if evs.is_empty():
		_key_btn.text = _tr("dialog_unbound")
		return
	for e in evs:
		if e is InputEventKey:
			var k: int = (e as InputEventKey).keycode
			_key_btn.text = OS.get_keycode_string(k) if k != KEY_NONE else _tr("dialog_unbound")
			return
	_key_btn.text = _tr("dialog_unbound")


# ---- API ----

func set_action(s: String) -> void:
	action_name = s
	_refresh()


func set_display_name(s: String) -> void:
	display_name = s
	if _label:
		_label.text = s


func set_on_change(c: Callable) -> void:
	_on_change = c


func set_disabled(v: bool) -> void:
	_disabled = v
	modulate.a = 0.4 if v else 1.0
	if _key_btn:
		_key_btn.disabled = v
	if _clear_btn:
		_clear_btn.disabled = v


func is_disabled() -> bool:
	return _disabled


func _tr(key: String) -> String:
	if _i18n:
		return _i18n.tr_key(key)
	return key
