extends Control
## PageCredits — 制作人员页
##   自动向上滚动的字幕,用户可滚轮手动滚动或按 ESC 返回

class_name PageCredits

signal closed

@onready var _header: Control = $Header
@onready var _scroll: ScrollContainer = $Scroll
@onready var _list: VBoxContainer = $Scroll/List
@onready var _hint: Label = $Footer/Hint

var _data: Dictionary = {}
var _auto_scroll: bool = true
var _scroll_speed: float = 60.0
var _user_paused: bool = false
var _pause_timer: float = 0.0
var _i18n: Node


func _ready() -> void:
	_i18n = get_node("/root/I18n")
	if _i18n and is_instance_valid(_header) and _header.has_method("set_title"):
		_header.set_title("credits_title")
	_apply_text()
	_load_data()
	_build()
	_auto_scroll = true


func _apply_text() -> void:
	if _i18n and is_instance_valid(_hint):
		_hint.text = _i18n.tr_key("credits_scroll_hint")


func _load_data() -> void:
	var f := FileAccess.open("res://data/credits.json", FileAccess.READ)
	if not f:
		return
	var content := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(content) == OK:
		_data = json.data


func _build() -> void:
	# 顶部 logo
	var logo := GlitchLabel.new()
	logo.text = "NEURO.EXE"
	logo.glitch_interval = 3.0
	logo.glitch_duration = 0.15
	logo.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	logo.add_theme_font_size_override("font_size", 72)
	logo.add_theme_color_override("font_color", Color(0.13, 0.82, 0.93, 1))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.add_child(logo)
	_list.add_child(_spacer(60))

	var sections: Array = _data.get("sections", [])
	var loc: String = _i18n.get_locale() if _i18n else "en"
	var is_zh: bool = loc == "zh"

	for sec in sections:
		var role_key: String = sec.get("role_key", "")
		var role: String = _i18n.tr_key(role_key) if _i18n else role_key
		var names_key: String = "names_zh" if is_zh else "names_en"
		var names: Array = sec.get(names_key, sec.get("names_en", []))

		var role_lbl := Label.new()
		role_lbl.text = role
		role_lbl.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
		role_lbl.add_theme_font_size_override("font_size", 24)
		role_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 0.9))
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_list.add_child(role_lbl)
		_list.add_child(_spacer(12))

		for n in names:
			var name_lbl := Label.new()
			name_lbl.text = str(n)
			name_lbl.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
			name_lbl.add_theme_font_size_override("font_size", 28)
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_list.add_child(name_lbl)

		# 分隔线
		var sep := ColorRect.new()
		sep.color = Color(0.55, 0.15, 0.95, 0.15)
		sep.custom_minimum_size = Vector2(400, 1)
		sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_list.add_child(sep)
		_list.add_child(_spacer(30))

	# 底部 thank you
	var thanks := Label.new()
	thanks.text = _i18n.tr_key("credits_thanks") if _i18n else "Thank you for playing."
	thanks.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	thanks.add_theme_font_size_override("font_size", 36)
	thanks.add_theme_color_override("font_color", Color(0.13, 0.82, 0.93, 1))
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thanks.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.add_child(_spacer(60))
	_list.add_child(thanks)
	_list.add_child(_spacer(80))

	# 绑定 header 返回
	if _header and _header.has_signal("back_pressed"):
		_header.back_pressed.connect(_on_back)


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


func _process(delta: float) -> void:
	if not _auto_scroll or _user_paused:
		return
	# 暂停计时
	if _pause_timer > 0:
		_pause_timer -= delta
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar:
		bar.value += _scroll_speed * delta
		if bar.value >= bar.max_value - 4:
			_auto_scroll = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()


func _on_back() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("switch")
	closed.emit()


func _on_scroll_started() -> void:
	_user_paused = true
	_pause_timer = 1.5  # 用户操作 1.5s 后恢复自动滚动
