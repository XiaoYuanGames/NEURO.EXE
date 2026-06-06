extends Control
## PageHeader — 子页面统一顶部条
##   左: 大字号标题(带出现动画:字符逐个 fade+glide)
##   右: 返回按钮
## 信号: back_pressed

class_name PageHeader

signal back_pressed

@export var title_key: String = "" : set = set_title
@export var accent_color: Color = Color(0.13, 0.82, 0.93)

var _title_hbox: HBoxContainer
var _back_btn: CyberButton
var _i18n: Node
var _char_labels: Array[Label] = []


func _ready() -> void:
	custom_minimum_size = Vector2(0, 80)
	_i18n = get_node_or_null("/root/I18n")
	_build()
	_animate_in()


func _build() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.10, 0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 底部分隔线
	var line := ColorRect.new()
	line.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.4)
	line.position = Vector2(40, 78)
	line.size = Vector2(size.x - 80, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	# 标题
	_title_hbox = HBoxContainer.new()
	_title_hbox.position = Vector2(48, 22)
	_title_hbox.add_theme_constant_override("separation", 0)
	_title_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_hbox)

	_rebuild_title()

	# 返回按钮
	_back_btn = CyberButton.new()
	_back_btn.accent_color = Color(0.7, 0.4, 1.0)
	_back_btn.set_text("← BACK")
	_back_btn.position = Vector2(size.x - 180, 20)
	_back_btn.size = Vector2(140, 40)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	add_child(_back_btn)


func _rebuild_title() -> void:
	for c in _title_hbox.get_children():
		c.queue_free()
	_char_labels.clear()

	var text: String = ""
	if _i18n and title_key != "":
		text = _i18n.tr_key(title_key)
	if text == "":
		text = title_key

	for ch in text:
		var lbl := Label.new()
		lbl.text = ch
		lbl.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
		lbl.add_theme_font_size_override("font_size", 38)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
		lbl.modulate.a = 0.0
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_hbox.add_child(lbl)
		_char_labels.append(lbl)


func _animate_in() -> void:
	for i in _char_labels.size():
		var lbl: Label = _char_labels[i]
		var tw := create_tween()
		tw.tween_interval(0.04 * i)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
		tw.tween_property(lbl, "position:y", 0.0, 0.25)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		lbl.position.y = 8


func set_title(s: String) -> void:
	title_key = s
	if is_inside_tree():
		_rebuild_title()
		_animate_in()


# 重新计算返回按钮位置
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _back_btn:
		_back_btn.position = Vector2(size.x - 180, 20)
