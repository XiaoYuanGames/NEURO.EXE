extends Control
## CyberOption — 紫蓝霓虹风下拉选择
##
## 用 Popup + ItemList 自行实现,以获得完全自定义外观。

class_name CyberOption

signal selected(index: int)

@export var options: PackedStringArray = [] : set = set_options
@export var selected_index: int = 0 : set = set_selected
@export var accent_color: Color = Color(0.13, 0.82, 0.93)
@export var label_text: String = "" : set = set_label_text

const ROW_H := 30.0

var _label: Label
var _value_btn: Button           # 显示当前值
var _popup: Popup
var _list: ItemList
var _on_change: Callable = Callable()


func _ready() -> void:
	custom_minimum_size = Vector2(360, 32)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()


func _build() -> void:
	_label = Label.new()
	_label.text = label_text
	_label.position = Vector2(0, 6)
	_label.size = Vector2(160, 20)
	_label.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0, 0.95))
	add_child(_label)

	_value_btn = Button.new()
	_value_btn.text = ""
	_value_btn.position = Vector2(170, 0)
	_value_btn.size = Vector2(custom_minimum_size.x - 170, 32)
	_value_btn.focus_mode = Control.FOCUS_NONE
	_value_btn.flat = true
	_apply_btn_style()
	_value_btn.pressed.connect(_on_btn_pressed)
	add_child(_value_btn)

	_popup = Popup.new()
	_popup.size = Vector2(custom_minimum_size.x - 170, ROW_H * max(1, options.size()) + 4)
	_popup.transparent_bg = false
	_popup.hide()
	add_child(_popup)

	_list = ItemList.new()
	_list.anchor_right = 1.0
	_list.anchor_bottom = 1.0
	_list.size = Vector2(custom_minimum_size.x - 170, ROW_H * max(1, options.size()))
	_list.custom_minimum_size = Vector2(custom_minimum_size.x - 170, ROW_H * max(1, options.size()))
	_list.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	_list.add_theme_font_size_override("font_size", 16)
	_list.add_theme_constant_override("line_spacing", 0)
	_popup.add_child(_list)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.14, 0.98)
	sb.border_color = accent_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.15)
	_list.add_theme_stylebox_override("panel", sb)
	_list.add_theme_stylebox_override("focus", sb)
	_list.add_theme_stylebox_override("selected", sb_hover)
	_list.add_theme_stylebox_override("selected_focus", sb_hover)
	_list.add_theme_stylebox_override("hovered", sb_hover)
	_list.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	_list.add_theme_color_override("font_hovered_color", accent_color)
	_list.add_theme_color_override("font_selected_color", accent_color)

	_list.item_selected.connect(_on_item_selected)
	_refresh_options()


func _apply_btn_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.14, 0.95)
	sb.border_color = accent_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 32
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
	_value_btn.add_theme_stylebox_override("normal", sb)
	_value_btn.add_theme_stylebox_override("hover", sb_hover)
	_value_btn.add_theme_stylebox_override("pressed", sb_hover)
	_value_btn.add_theme_stylebox_override("focus", sb_hover)
	_value_btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	_value_btn.add_theme_color_override("font_hover_color", accent_color)
	_value_btn.add_theme_color_override("font_pressed_color", accent_color)
	_value_btn.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	_value_btn.add_theme_font_size_override("font_size", 16)
	# 右箭头标识
	_value_btn.clip_text = true
	_value_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _on_btn_pressed() -> void:
	if options.is_empty():
		return
	if _popup.visible:
		_popup.hide()
		return
	# 定位弹窗
	var gp: Vector2 = get_global_position()
	_popup.position = Vector2i(int(gp.x + 170), int(gp.y + 32))
	_popup.popup()
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("switch")


func _process(_delta: float) -> void:
	if not _popup.visible:
		return
	# 点击弹窗外则关闭
	var mouse := get_global_mouse_position()
	var pr := Rect2(_popup.position, _popup.size)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not pr.has_point(mouse):
		_popup.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _popup.visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE:
			_popup.hide()
			get_viewport().set_input_as_handled()


func _on_item_selected(idx: int) -> void:
	set_selected(idx)
	_popup.hide()
	_emit()


func _emit() -> void:
	selected.emit(selected_index)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("click")
	if _on_change.is_valid():
		_on_change.call(selected_index)


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _value_btn and options.size() > 0:
		var idx: int = clamp(selected_index, 0, options.size() - 1)
		_value_btn.text = options[idx]
	if _label:
		_label.text = label_text


func _refresh_options() -> void:
	if not _list:
		return
	_list.clear()
	for o in options:
		_list.add_item(o)


# ---- API ----

func set_options(arr: PackedStringArray) -> void:
	options = arr
	if _list:
		_refresh_options()
		_popup.size.y = ROW_H * max(1, options.size()) + 4
	_refresh()


func set_selected(idx: int) -> void:
	selected_index = idx
	_refresh()


func set_label_text(s: String) -> void:
	label_text = s
	if _label:
		_label.text = s


func set_on_change(c: Callable) -> void:
	_on_change = c
