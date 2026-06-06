extends Control
## MainMenu — 紫蓝霓虹科幻风主菜单
##
## 层级(下→上):
##   1. 深紫底色
##   2. breathing_bg shader 背景
##   3. 网格层(自绘,缓慢漂移)
##   4. StarField
##   5. ScanlineOverlay
##   6. 标题(GlitchLabel) + 副标题
##   7. 6 个 CyberButton
##   8. 底部 hint + 版本号
##
## 流程:
##   - 入场:标题淡入 + 按钮 staggered slide-in
##   - 键盘 ↑↓ 切换,Enter 触发
##   - 开始/继续:hide → loading 3s → 开发中弹窗 → show
##   - 成就/设置/制作人员:hide → 实例化子页 → 关闭后 show
##   - 退出:二次确认 → quit

class_name MainMenu

const BG_DARK := Color(0.04, 0.02, 0.10, 1.0)
const ACCENT := Color(0.13, 0.82, 0.93)
const ACCENT_PURPLE := Color(0.55, 0.10, 0.95)

var _bg_dark: ColorRect
var _bg_shader: ColorRect
var _grid: Control
var _starfield: StarField
var _scanline: ScanlineOverlay
var _title_layer: Control
var _glitch: GlitchLabel
var _subtitle: Label
var _hint: Label
var _version: Label
var _button_layer: VBoxContainer
var _buttons: Array[CyberButton] = []
var _focus_index: int = 0

var _i18n: Node
var _audio_manager: Node
var _loading_screen: Node
var _user_settings: Node

var _is_hidden: bool = false


func _ready() -> void:
	_i18n = get_node("/root/I18n")
	_loading_screen = get_node_or_null("/root/LoadingScreen")
	_audio_manager = get_node_or_null("/root/AudioManager")
	_user_settings = get_node_or_null("/root/UserSettings")
	_build()
	_animate_in()
	if _audio_manager:
		_audio_manager.play_music()
	if _i18n:
		_i18n.locale_changed.connect(_refresh_text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _build() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS

	# 1. 背景
	_bg_dark = ColorRect.new()
	_bg_dark.color = BG_DARK
	_bg_dark.anchor_right = 1.0
	_bg_dark.anchor_bottom = 1.0
	_bg_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_dark)

	_bg_shader = ColorRect.new()
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/breathing_bg.gdshader")
	_bg_shader.material = shader_mat
	_bg_shader.anchor_right = 1.0
	_bg_shader.anchor_bottom = 1.0
	_bg_shader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_shader)

	# 2. 网格
	_grid = Control.new()
	_grid.set_script(load("res://scenes/ui/main_menu_grid.gd"))
	_grid.anchor_right = 1.0
	_grid.anchor_bottom = 1.0
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)

	# 3. Star field
	_starfield = StarField.new()
	_starfield.emitting = true
	add_child(_starfield)

	# 4. 扫描线
	_scanline = ScanlineOverlay.new()
	_scanline.scan_alpha = 0.10
	_scanline.anchor_right = 1.0
	_scanline.anchor_bottom = 1.0
	add_child(_scanline)

	# 5. 标题层
	_title_layer = Control.new()
	_title_layer.anchor_right = 1.0
	_title_layer.custom_minimum_size = Vector2(0, 200)
	_title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_layer)

	_glitch = GlitchLabel.new()
	_glitch.text = "NEURO.EXE"
	_glitch.glitch_interval = 3.5
	_glitch.glitch_duration = 0.15
	_glitch.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	_glitch.add_theme_font_size_override("font_size", 96)
	_glitch.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	_glitch.add_theme_constant_override("outline_size", 4)
	_glitch.add_theme_color_override("font_outline_color", ACCENT)
	_glitch.size = Vector2(720, 130)
	_glitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glitch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch.pivot_offset = Vector2(360, 65)
	_title_layer.add_child(_glitch)

	_subtitle = Label.new()
	_subtitle.text = "// RHYTHM // SYSTEM // ONLINE //"
	_subtitle.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_color", Color(0.7, 0.75, 0.95, 0.85))
	_subtitle.size = Vector2(720, 28)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.modulate.a = 0.0
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(_subtitle)

	# 6. 按钮层
	_button_layer = VBoxContainer.new()
	_button_layer.add_theme_constant_override("separation", 14)
	_button_layer.alignment = BoxContainer.ALIGNMENT_BEGIN
	_button_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_button_layer)
	_build_buttons()

	# 7. 底部
	_hint = Label.new()
	_hint.text = _tr("menu_hint")
	_hint.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.85, 0.6))
	_hint.modulate.a = 0.0
	add_child(_hint)

	_version = Label.new()
	_version.text = _tr("version_tag")
	_version.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	_version.add_theme_font_size_override("font_size", 13)
	_version.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 0.8))
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version.modulate.a = 0.0
	add_child(_version)

	_relayout()
	_focus_index = 0
	_focus_button(0)


func _build_buttons() -> void:
	for c in _button_layer.get_children():
		c.queue_free()
	_buttons.clear()

	var labels := Array()
	labels.append(["menu_start", true])
	labels.append(["menu_continue", false])
	labels.append(["menu_achievements", false])
	labels.append(["menu_settings", false])
	labels.append(["menu_credits", false])
	labels.append(["menu_quit", false])
	for i in labels.size():
		var key: String = labels[i][0]
		var is_primary: bool = labels[i][1]
		var btn := CyberButton.new()
		btn.accent_color = ACCENT
		btn.is_primary = is_primary
		btn.set_text(_tr(key))
		btn.custom_minimum_size = Vector2(360, 52)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_on_button_pressed.bind(i))
		btn.modulate.a = 0.0
		btn.position.x = -30
		_button_layer.add_child(btn)
		_buttons.append(btn)


func _relayout() -> void:
	if not is_inside_tree():
		return
	var vw: float = size.x
	var vh: float = size.y
	if vw <= 0:
		vw = get_viewport_rect().size.x
	if vh <= 0:
		vh = get_viewport_rect().size.y

	# 标题居中
	if _glitch:
		_glitch.position = Vector2(vw * 0.5 - 360, vh * 0.18)
	if _subtitle:
		_subtitle.position = Vector2(vw * 0.5 - 360, vh * 0.18 + 130)

	# 按钮左侧
	if _button_layer:
		var total_h: float = _buttons.size() * 52 + (_buttons.size() - 1) * 14
		_button_layer.position = Vector2(120, vh * 0.45 - total_h * 0.5)
		_button_layer.size = Vector2(360, total_h)

	# 底部
	if _hint:
		_hint.position = Vector2(28, vh - 36)
	if _version:
		_version.position = Vector2(vw - 220, vh - 36)
		_version.size = Vector2(192, 20)

	# Star field 居中发射
	if _starfield:
		_starfield.position = Vector2(vw * 0.5, vh * 0.5)
		_starfield.emission_rect_extents = Vector2(vw * 0.5, vh * 0.5)


# ---- 入场动画 ----

func _animate_in() -> void:
	_glitch.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_glitch, "modulate:a", 1.0, 0.5)
	tw.tween_property(_subtitle, "modulate:a", 0.9, 0.5).set_delay(0.3)
	tw.tween_property(_version, "modulate:a", 0.9, 0.5).set_delay(0.4)
	tw.tween_property(_hint, "modulate:a", 1.0, 0.5).set_delay(0.5)

	for i in _buttons.size():
		var btn: CyberButton = _buttons[i]
		var btn_tw := create_tween()
		btn_tw.set_parallel(true)
		btn_tw.tween_interval(0.6 + 0.08 * i)
		btn_tw.tween_property(btn, "modulate:a", 1.0, 0.3)
		btn_tw.tween_property(btn, "position:x", 0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 网格漂移循环
	var grid_tw := create_tween()
	grid_tw.set_loops()
	grid_tw.tween_property(_grid, "offset", Vector2(0, 0), 8.0)
	grid_tw.tween_property(_grid, "offset", Vector2(60, 60), 8.0)


# ---- 按钮事件 ----

func _on_button_pressed(idx: int) -> void:
	if _is_hidden:
		return
	if _audio_manager:
		_audio_manager.play_sfx("click")
	match idx:
		0: _on_start()
		1: _on_continue()
		2: _open_page("res://scenes/ui/page_achievements.tscn")
		3: _open_page("res://scenes/ui/page_settings.tscn")
		4: _open_page("res://scenes/ui/page_credits.tscn")
		5: _on_quit()


func _on_start() -> void:
	_run_in_dev_flow()


func _on_continue() -> void:
	_run_in_dev_flow()


func _on_quit() -> void:
	var dlg_scene: PackedScene = load("res://scenes/ui/dialog_confirm.tscn")
	var dlg = dlg_scene.instantiate()
	get_tree().root.add_child(dlg)
	dlg.setup("dialog_quit_title", "dialog_quit_message", func(): get_tree().quit())


func _run_in_dev_flow() -> void:
	_hide_menu()
	if _loading_screen:
		_loading_screen.show_screen("loading_start")
	await get_tree().create_timer(3.0).timeout
	if _loading_screen:
		_loading_screen.hide_screen()
	var dlg: CanvasLayer = load("res://scenes/ui/dialog_in_dev.tscn").instantiate()
	get_tree().root.add_child(dlg)
	if dlg.has_signal("closed"):
		await dlg.closed
	_show_menu()


# ---- 子页面 ----

func _open_page(path: String) -> void:
	_hide_menu()
	var page: Control = load(path).instantiate()
	get_tree().root.add_child(page)
	if page.has_signal("closed"):
		await page.closed
	page.queue_free()
	_show_menu()


# ---- 显隐 ----

func _hide_menu() -> void:
	_is_hidden = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		visible = false
		modulate.a = 1.0
	)


func _show_menu() -> void:
	_is_hidden = false
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	_focus_button(_focus_index)


# ---- 键盘 ----

func _unhandled_input(event: InputEvent) -> void:
	if _is_hidden:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed:
			return
		match k.keycode:
			KEY_UP:
				_focus_button((_focus_index - 1 + _buttons.size()) % _buttons.size())
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_focus_button((_focus_index + 1) % _buttons.size())
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_on_button_pressed(_focus_index)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_on_quit()
				get_viewport().set_input_as_handled()


func _focus_button(idx: int) -> void:
	if _focus_index >= 0 and _focus_index < _buttons.size():
		_buttons[_focus_index].set_focus_visual(false)
	_focus_index = idx % _buttons.size()
	_buttons[_focus_index].set_focus_visual(true)


# ---- 文本刷新 ----

func _refresh_text(_locale: String) -> void:
	_hint.text = _tr("menu_hint")
	_version.text = _tr("version_tag")
	_subtitle.text = "// RHYTHM // SYSTEM // ONLINE //"
	var labels := ["menu_start", "menu_continue", "menu_achievements", "menu_settings", "menu_credits", "menu_quit"]
	for i in _buttons.size():
		_buttons[i].set_text(_tr(labels[i]))


func _tr(key: String) -> String:
	if _i18n:
		return _i18n.tr_key(key)
	return key
