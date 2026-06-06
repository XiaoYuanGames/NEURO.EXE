extends Control
## PageSettings — 全功能设置页
##
## 7 大类(通用 / 显示 / 音频 / 玩法 / 控制 / 高级 / 关于)
## 左侧大类按钮,右侧动态构建细项。
## 所有改动通过 UserSettings.set() 持久化并广播,各 manager 自动响应。
## 试玩预览块根据 lane_count 实时绘制 lane + 下落音符演示。

class_name PageSettings

signal closed

# 大类 ID → 构建函数
var CATEGORIES: Array = []


func _init() -> void:
	CATEGORIES = [["general", "set_general"], ["display", "set_display"], ["audio", "set_audio"], ["gameplay", "set_gameplay"], ["controls", "set_controls"], ["advanced", "set_advanced"], ["about", "set_about"]]

const ACCENT := Color(0.13, 0.82, 0.93)
const ACCENT_PURPLE := Color(0.7, 0.4, 1.0)

@onready var _header: Control = $Header
@onready var _sidebar: VBoxContainer = $Body/Sidebar
@onready var _content: VBoxContainer = $Body/Content/Scroll/VBox
@onready var _toast: Label = $Footer/Toast
@onready var _reset_btn: CyberButton = $Footer/ResetBtn
@onready var _fps_label: Label = null  # 由 advanced toggle 控制

var _i18n: Node
var _user_settings: Node
var _audio_manager: Node
var _active_category: String = "general"
var _sidebar_buttons: Array = []
var _preview_root: Control = null
var _preview_lanes: Array = []  # VBox of lane panels
var _preview_notes: Array = []  # ColorRect notes
var _preview_lane_count: int = 4
var _preview_tween: Tween = null


func _ready() -> void:
	_i18n = get_node("/root/I18n")
	_user_settings = get_node_or_null("/root/UserSettings")
	_audio_manager = get_node_or_null("/root/AudioManager")
	_build_sidebar()
	_build_category("general")
	if _header and _header.has_signal("back_pressed"):
		_header.back_pressed.connect(_on_back)
	_reset_btn.accent_color = Color(0.95, 0.10, 0.65)
	_reset_btn.set_text("↺  " + _tr("set_reset"))
	_reset_btn.pressed.connect(_on_reset_pressed)
	# 监听 fps / ui scale
	if _user_settings:
		_user_settings.setting_changed.connect(_on_setting_changed)
		_apply_fps_label(bool(_user_settings.get_value("show_fps", true)))
		_apply_ui_scale()
	# 启动菜单 BGM
	if _audio_manager:
		_audio_manager.play_music()


func _process(delta: float) -> void:
	_update_preview(delta)
	if _fps_label and is_instance_valid(_fps_label):
		_fps_label.text = (_i18n.tr_key("fps_label") % int(Engine.get_frames_per_second())) if _i18n else "FPS: %d" % int(Engine.get_frames_per_second())


# ---- 侧边栏 ----

func _build_sidebar() -> void:
	for c in _sidebar.get_children():
		c.queue_free()
	_sidebar_buttons.clear()
	for cat in CATEGORIES:
		var id: String = cat[0]
		var label_key: String = cat[1]
		var btn := CyberButton.new()
		btn.accent_color = ACCENT
		btn.is_primary = (id == _active_category)
		if _i18n:
			btn.set_text(_i18n.tr_key(label_key))
		else:
			btn.set_text(label_key)
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_category_pressed.bind(id))
		_sidebar.add_child(btn)
		_sidebar_buttons.append(btn)
		_sidebar.add_child(_spacer(8))
	_refresh_sidebar()
	_animate_sidebar_in()


func _refresh_sidebar() -> void:
	for i in _sidebar_buttons.size():
		var btn: CyberButton = _sidebar_buttons[i]
		var id: String = CATEGORIES[i][0]
		btn.is_primary = (id == _active_category)
		btn._refresh()


func _animate_sidebar_in() -> void:
	for i in _sidebar_buttons.size():
		var btn: CyberButton = _sidebar_buttons[i]
		btn.modulate.a = 0.0
		btn.position.x = -20
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_interval(0.04 * i)
		tw.tween_property(btn, "modulate:a", 1.0, 0.3)
		tw.tween_property(btn, "position:x", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_category_pressed(id: String) -> void:
	if id == _active_category:
		return
	_active_category = id
	var am := get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("switch")
	_refresh_sidebar()
	_animate_content_out_then_in()


func _animate_content_out_then_in() -> void:
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		_clear_content()
		_build_category(_active_category)
		_animate_content_in()
	)


func _animate_content_in() -> void:
	for i in _content.get_child_count():
		var c: Control = _content.get_child(i)
		c.modulate.a = 0.0
		c.position.x = 16
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_interval(0.02 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.25)
		tw.tween_property(c, "position:x", 0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ---- 内容构建 ----

func _clear_content() -> void:
	for c in _content.get_children():
		c.queue_free()
	_preview_root = null
	_preview_lanes = []
	_preview_notes = []


func _build_category(id: String) -> void:
	_clear_content()
	match id:
		"general":  _build_general()
		"display":  _build_display()
		"audio":    _build_audio()
		"gameplay": _build_gameplay()
		"controls": _build_controls()
		"advanced": _build_advanced()
		"about":    _build_about()


# ---- 通用 ----

func _build_general() -> void:
	_add_section_label("set_language")
	var lang_opt := CyberOption.new()
	lang_opt.set_label_text("")
	lang_opt.set_options(PackedStringArray([
		"简体中文", "English"
	]))
	lang_opt.selected_index = 0 if (_user_settings.get_value("language", "zh") == "zh") else 1
	lang_opt.set_on_change(func(idx: int):
		var new_locale: String = "zh" if idx == 0 else "en"
		_user_settings.set_value("language", new_locale)
		_i18n.set_locale(new_locale)
		_rebuild_text_after_locale_change()
	)
	_content.add_child(lang_opt)
	_content.add_child(_spacer(16))


# ---- 显示 ----

func _build_display() -> void:
	# 显示模式
	_add_section_label("set_fullscreen")
	var mode_opt := CyberOption.new()
	mode_opt.set_options(PackedStringArray([
		_tr("set_mode_windowed"),
		_tr("set_mode_borderless"),
		_tr("set_mode_fullscreen"),
	]))
	mode_opt.selected_index = int(_user_settings.get_value("display_mode", 2))
	mode_opt.set_on_change(func(idx: int):
		_user_settings.set_value("display_mode", idx)
		_apply_display_mode()
	)
	_content.add_child(mode_opt)
	_content.add_child(_spacer(12))

	# 分辨率
	_add_section_label("set_resolution")
	var res_opt := CyberOption.new()
	res_opt.set_options(PackedStringArray(["1280x720", "1600x900", "1920x1080", "2560x1440"]))
	var cur_res: String = str(_user_settings.get_value("resolution", "1280x720"))
	res_opt.selected_index = res_opt.options.find(cur_res)
	if res_opt.selected_index < 0:
		res_opt.selected_index = 0
	res_opt.set_on_change(func(idx: int):
		var v: String = res_opt.options[idx]
		_user_settings.set_value("resolution", v)
		_apply_display_mode()
	)
	_content.add_child(res_opt)
	_content.add_child(_spacer(12))

	# VSync
	_add_section_label("set_vsync")
	var vs_opt := CyberOption.new()
	vs_opt.set_options(PackedStringArray([_tr("set_vsync_off"), _tr("set_vsync_on"), _tr("set_vsync_adaptive")]))
	vs_opt.selected_index = int(_user_settings.get_value("vsync_mode", 1))
	vs_opt.set_on_change(func(idx: int):
		_user_settings.set_value("vsync_mode", idx)
		DisplayServer.window_set_vsync_mode(idx as DisplayServer.VSyncMode)
	)
	_content.add_child(vs_opt)
	_content.add_child(_spacer(12))

	# FPS
	_add_section_label("set_fps_cap")
	var fps := CyberSlider.new()
	fps.min_value = 30
	fps.max_value = 240
	fps.step = 30
	fps.value = float(_user_settings.get_value("fps_cap", 240))
	fps.set_value_formatter(func(v): return "%d" % int(v))
	fps.set_on_change(func(v): _user_settings.set_value("fps_cap", int(v)))
	fps.set_on_release(func(v): Engine.max_fps = int(v))
	_content.add_child(fps)
	_content.add_child(_spacer(12))

	# 亮度
	_add_section_label("set_brightness")
	var bri := CyberSlider.new()
	bri.min_value = 50
	bri.max_value = 150
	bri.step = 1
	bri.value = float(_user_settings.get_value("brightness", 100))
	bri.set_value_formatter(func(v): return "%d" % int(v))
	bri.set_on_change(func(v): _user_settings.set_value("brightness", int(v)))
	_content.add_child(bri)
	_content.add_child(_spacer(12))

	# 对比度
	_add_section_label("set_contrast")
	var con := CyberSlider.new()
	con.min_value = 50
	con.max_value = 150
	con.step = 1
	con.value = float(_user_settings.get_value("contrast", 100))
	con.set_value_formatter(func(v): return "%d" % int(v))
	con.set_on_change(func(v): _user_settings.set_value("contrast", int(v)))
	_content.add_child(con)
	_content.add_child(_spacer(12))

	# 抗锯齿
	_add_section_label("set_antialias")
	var aa := CyberOption.new()
	aa.set_options(PackedStringArray([
		_tr("set_aa_off"), "MSAA 2x", "MSAA 4x", "MSAA 8x", "FXAA"
	]))
	aa.selected_index = int(_user_settings.get_value("antialias", 0))
	aa.set_on_change(func(idx: int):
		_user_settings.set_value("antialias", idx)
		_apply_aa(idx)
	)
	_content.add_child(aa)
	_content.add_child(_spacer(12))

	# 画质预设
	_add_section_label("set_quality")
	var q := CyberOption.new()
	q.set_options(PackedStringArray([
		_tr("set_quality_low"), _tr("set_quality_mid"),
		_tr("set_quality_high"), _tr("set_quality_ultra"),
	]))
	q.selected_index = int(_user_settings.get_value("quality_preset", 2))
	q.set_on_change(func(idx: int):
		_user_settings.set_value("quality_preset", idx)
		_apply_quality()
	)
	_content.add_child(q)
	_content.add_child(_spacer(12))


# ---- 音频 ----

func _build_audio() -> void:
	_add_section_label("set_master")
	var master := CyberSlider.new()
	master.min_value = 0
	master.max_value = 100
	master.step = 1
	master.value = float(_user_settings.get_value("master_volume", 100))
	master.set_value_formatter(func(v): return "%d%%" % int(v))
	master.set_on_change(func(v): _user_settings.set_value("master_volume", int(v)))
	_content.add_child(master)
	_content.add_child(_spacer(12))

	_add_section_label("set_music")
	var music := CyberSlider.new()
	music.min_value = 0
	music.max_value = 100
	music.step = 1
	music.value = float(_user_settings.get_value("music_volume", 80))
	music.set_value_formatter(func(v): return "%d%%" % int(v))
	music.set_on_change(func(v): _user_settings.set_value("music_volume", int(v)))
	_content.add_child(music)
	_content.add_child(_spacer(12))

	_add_section_label("set_sfx")
	var sfx := CyberSlider.new()
	sfx.min_value = 0
	sfx.max_value = 100
	sfx.step = 1
	sfx.value = float(_user_settings.get_value("sfx_volume", 100))
	sfx.set_value_formatter(func(v): return "%d%%" % int(v))
	sfx.set_on_change(func(v): _user_settings.set_value("sfx_volume", int(v)))
	_content.add_child(sfx)
	_content.add_child(_spacer(12))

	_add_section_label("set_hit")
	var hit := CyberSlider.new()
	hit.min_value = 0
	hit.max_value = 100
	hit.step = 1
	hit.value = float(_user_settings.get_value("hit_volume", 100))
	hit.set_value_formatter(func(v): return "%d%%" % int(v))
	hit.set_on_change(func(v): _user_settings.set_value("hit_volume", int(v)))
	_content.add_child(hit)
	_content.add_child(_spacer(12))

	# 静音
	_add_section_label("set_mute_all")
	var mute := CyberToggle.new()
	mute.set_label_text("")
	mute.toggled = bool(_user_settings.get_value("mute_all", false))
	mute.set_on_change(func(v): _user_settings.set_value("mute_all", v))
	_content.add_child(mute)
	_content.add_child(_spacer(12))

	# 音频设备
	_add_section_label("set_audio_dev")
	var dev := CyberOption.new()
	var devices := AudioServer.get_output_device_list()
	var devs := PackedStringArray()
	devs.append("Default")
	for d in devices:
		devs.append(d)
	dev.set_options(devs)
	var cur: String = str(_user_settings.get_value("audio_device", "Default"))
	dev.selected_index = devs.find(cur)
	if dev.selected_index < 0:
		dev.selected_index = 0
	dev.set_on_change(func(idx: int):
		var name: String = devs[idx]
		_user_settings.set_value("audio_device", name)
		if name != "Default":
			AudioServer.set_output_device(name)
	)
	_content.add_child(dev)
	_content.add_child(_spacer(12))

	# 试听
	_add_section_label("set_test")
	var test := CyberButton.new()
	test.accent_color = ACCENT
	test.set_text("▶  " + _tr("set_test"))
	test.pressed.connect(func():
		_audio_manager.play_sfx("click")
	)
	_content.add_child(test)
	_content.add_child(_spacer(12))


# ---- 玩法 ----

func _build_gameplay() -> void:
	# 键数
	_add_section_label("set_lane_count")
	var lane_opt := CyberOption.new()
	lane_opt.set_options(PackedStringArray(["4K", "5K", "6K", "7K", "8K"]))
	lane_opt.selected_index = int(_user_settings.get_value("lane_count", 4)) - 4
	if lane_opt.selected_index < 0:
		lane_opt.selected_index = 0
	lane_opt.set_on_change(func(idx: int):
		var n: int = idx + 4
		_user_settings.set_value("lane_count", n)
		_rebuild_preview()
	)
	_content.add_child(lane_opt)
	_content.add_child(_spacer(12))

	# 音符速度
	_add_section_label("set_note_speed")
	var ns := CyberSlider.new()
	ns.min_value = 0.5
	ns.max_value = 3.0
	ns.step = 0.1
	ns.value = float(_user_settings.get_value("note_speed", 1.0))
	ns.set_value_formatter(func(v): return "%.1fx" % v)
	ns.set_on_change(func(v): _user_settings.set_value("note_speed", v))
	_content.add_child(ns)
	_content.add_child(_spacer(12))

	# 判定偏移
	_add_section_label("set_judgment_offset")
	var jo := CyberSlider.new()
	jo.min_value = -200
	jo.max_value = 200
	jo.step = 5
	jo.value = float(_user_settings.get_value("judgment_offset_ms", 0))
	jo.set_value_formatter(func(v): return "%d ms" % int(v))
	jo.set_on_change(func(v): _user_settings.set_value("judgment_offset_ms", int(v)))
	_content.add_child(jo)
	_content.add_child(_spacer(12))

	# 背景暗化
	_add_section_label("set_bg_dim")
	var bd := CyberSlider.new()
	bd.min_value = 0
	bd.max_value = 100
	bd.step = 1
	bd.value = float(_user_settings.get_value("bg_dim", 30))
	bd.set_value_formatter(func(v): return "%d%%" % int(v))
	bd.set_on_change(func(v): _user_settings.set_value("bg_dim", int(v)))
	_content.add_child(bd)
	_content.add_child(_spacer(12))

	# BGA
	_add_section_label("set_bga")
	var bga := CyberToggle.new()
	bga.set_label_text("")
	bga.toggled = bool(_user_settings.get_value("bga_enabled", true))
	bga.set_on_change(func(v): _user_settings.set_value("bga_enabled", v))
	_content.add_child(bga)
	_content.add_child(_spacer(12))

	# 自动播放
	_add_section_label("set_auto_play")
	var ap := CyberToggle.new()
	ap.set_label_text("")
	ap.toggled = bool(_user_settings.get_value("auto_play", false))
	ap.set_on_change(func(v): _user_settings.set_value("auto_play", v))
	_content.add_child(ap)
	_content.add_child(_spacer(16))

	# 试玩预览
	_add_section_label("set_preview_lbl")
	_build_preview()
	_content.add_child(_preview_root)
	_content.add_child(_spacer(12))


func _build_preview() -> void:
	if _preview_root and is_instance_valid(_preview_root):
		_preview_root.queue_free()
	_preview_root = Control.new()
	_preview_root.custom_minimum_size = Vector2(360, 280)
	_preview_root.size = Vector2(360, 280)
	_preview_root.modulate = Color(1, 1, 1, 0.7)

	# 容器背景
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05, 0.9)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_root.add_child(bg)

	_preview_lane_count = int(_user_settings.get_value("lane_count", 4))

	# 创建 lane 列
	_preview_lanes = []
	_preview_notes = []
	var lane_w: float = 360.0 / float(_preview_lane_count)
	for i in _preview_lane_count:
		var lane := ColorRect.new()
		lane.color = Color(0.08, 0.05, 0.18, 0.6)
		lane.position = Vector2(i * lane_w, 0)
		lane.size = Vector2(lane_w - 1, 280)
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_root.add_child(lane)
		_preview_lanes.append(lane)

	# 判定线
	var judge := ColorRect.new()
	judge.color = Color(0.13, 0.82, 0.93, 0.8)
	judge.position = Vector2(0, 250)
	judge.size = Vector2(360, 2)
	judge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_root.add_child(judge)

	# 启动下落循环
	_preview_tween = create_tween()
	_preview_tween.set_loops()
	_spawn_preview_note()


func _spawn_preview_note() -> void:
	if not _preview_root or not is_instance_valid(_preview_root):
		return
	# 随机选一条 lane
	var lane_idx: int = randi() % _preview_lane_count
	var lane_w: float = 360.0 / float(_preview_lane_count)
	var note := ColorRect.new()
	note.color = Color(0.95, 0.10, 0.65, 1.0)
	note.size = Vector2(lane_w - 6, 12)
	note.position = Vector2(lane_idx * lane_w + 3, -16)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_root.add_child(note)
	_preview_notes.append(note)
	var speed_mult: float = float(_user_settings.get_value("note_speed", 1.0))
	var dur: float = 1.4 / clampf(speed_mult, 0.5, 3.0)
	var tw := create_tween()
	tw.tween_property(note, "position:y", 252.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(note):
			_preview_notes.erase(note)
			note.queue_free()
	)
	# 下一个 note 在 0.3-0.6s 后
	var next_delay: float = randf_range(0.3, 0.6)
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.tween_interval(next_delay)
		_preview_tween.tween_callback(_spawn_preview_note)


func _update_preview(_delta: float) -> void:
	# bg_dim 应用: 调整个 layer 的 modulate
	pass


func _rebuild_preview() -> void:
	if _preview_root:
		_build_preview()


# ---- 控制 ----

func _build_controls() -> void:
	# 动态创建 8 个 keybind(根据 lane_count 显示 active)
	var lane_count: int = int(_user_settings.get_value("lane_count", 4))
	for i in 8:
		_add_section_label("set_keybind_lane_%d" % (i + 1))
		var kb := CyberKeybind.new()
		var action: String = "lane_%d" % (i + 1)
		kb.action_name = action
		kb.set_display_name("")
		kb.set_on_change(func(act: String, kc: int):
			_show_toast("Bound %s → %s" % [act, OS.get_keycode_string(kc) if kc != KEY_NONE else "—"])
		)
		kb.modulate.a = 0.4 if i >= lane_count else 1.0
		kb.disabled = (i >= lane_count)
		_content.add_child(kb)
		_content.add_child(_spacer(8))
	_add_section_label("set_keybind_pause")
	var pause := CyberKeybind.new()
	pause.action_name = "ui_cancel"
	pause.set_display_name("")
	_content.add_child(pause)
	_content.add_child(_spacer(8))
	# 重置键位
	var reset := CyberButton.new()
	reset.accent_color = Color(0.95, 0.10, 0.65)
	reset.set_text("↺  " + _tr("set_keybind_reset"))
	reset.pressed.connect(func():
		InputMap.load_from_project_settings()
		_show_toast(_tr("set_toast_reset"))
		_clear_content()
		_build_category("controls")
	)
	_content.add_child(reset)


# ---- 高级 ----

func _build_advanced() -> void:
	_add_section_label("set_show_fps")
	var fps := CyberToggle.new()
	fps.set_label_text("")
	fps.toggled = bool(_user_settings.get_value("show_fps", true))
	fps.set_on_change(func(v):
		_user_settings.set_value("show_fps", v)
		_apply_fps_label(v)
	)
	_content.add_child(fps)
	_content.add_child(_spacer(8))

	_add_section_label("set_show_judge")
	var sj := CyberToggle.new()
	sj.set_label_text("")
	sj.toggled = bool(_user_settings.get_value("show_judge", true))
	sj.set_on_change(func(v): _user_settings.set_value("show_judge", v))
	_content.add_child(sj)
	_content.add_child(_spacer(8))

	_add_section_label("set_show_combo")
	var sc := CyberToggle.new()
	sc.set_label_text("")
	sc.toggled = bool(_user_settings.get_value("show_combo", true))
	sc.set_on_change(func(v): _user_settings.set_value("show_combo", v))
	_content.add_child(sc)
	_content.add_child(_spacer(12))

	_add_section_label("set_particle")
	var p := CyberOption.new()
	p.set_options(PackedStringArray([_tr("set_particle_low"), _tr("set_particle_mid"), _tr("set_particle_high")]))
	p.selected_index = int(_user_settings.get_value("particle_density", 1))
	p.set_on_change(func(idx: int):
		_user_settings.set_value("particle_density", idx)
		_apply_particle(idx)
	)
	_content.add_child(p)
	_content.add_child(_spacer(12))

	_add_section_label("set_bloom")
	var bloom := CyberSlider.new()
	bloom.min_value = 0
	bloom.max_value = 200
	bloom.step = 1
	bloom.value = float(_user_settings.get_value("bloom", 100))
	bloom.set_value_formatter(func(v): return "%d%%" % int(v))
	bloom.set_on_change(func(v): _user_settings.set_value("bloom", int(v)))
	_content.add_child(bloom)
	_content.add_child(_spacer(12))

	_add_section_label("set_chromatic")
	var ch := CyberSlider.new()
	ch.min_value = 0
	ch.max_value = 100
	ch.step = 1
	ch.value = float(_user_settings.get_value("chromatic", 30))
	ch.set_value_formatter(func(v): return "%d%%" % int(v))
	ch.set_on_change(func(v): _user_settings.set_value("chromatic", int(v)))
	_content.add_child(ch)
	_content.add_child(_spacer(12))

	_add_section_label("set_motion_blur")
	var mb := CyberToggle.new()
	mb.set_label_text("")
	mb.toggled = bool(_user_settings.get_value("motion_blur", false))
	mb.set_on_change(func(v): _user_settings.set_value("motion_blur", v))
	_content.add_child(mb)
	_content.add_child(_spacer(8))

	_add_section_label("set_screen_shake")
	var ss := CyberToggle.new()
	ss.set_label_text("")
	ss.toggled = bool(_user_settings.get_value("screen_shake", true))
	ss.set_on_change(func(v): _user_settings.set_value("screen_shake", v))
	_content.add_child(ss)
	_content.add_child(_spacer(12))

	_add_section_label("set_cb_mode")
	var cb := CyberOption.new()
	cb.set_options(PackedStringArray([
		_tr("set_cb_off"), _tr("set_cb_prot"),
		_tr("set_cb_deut"), _tr("set_cb_trit"),
	]))
	cb.selected_index = int(_user_settings.get_value("color_blind_mode", 0))
	cb.set_on_change(func(idx: int):
		_user_settings.set_value("color_blind_mode", idx)
		_apply_cb(idx)
	)
	_content.add_child(cb)
	_content.add_child(_spacer(12))

	_add_section_label("set_ui_scale")
	var us := CyberSlider.new()
	us.min_value = 50
	us.max_value = 200
	us.step = 5
	us.value = float(_user_settings.get_value("ui_scale", 100))
	us.set_value_formatter(func(v): return "%d%%" % int(v))
	us.set_on_change(func(v):
		_user_settings.set_value("ui_scale", int(v))
		_apply_ui_scale()
	)
	_content.add_child(us)
	_content.add_child(_spacer(12))

	_add_section_label("set_reduce_motion")
	var rm := CyberToggle.new()
	rm.set_label_text("")
	rm.toggled = bool(_user_settings.get_value("reduce_motion", false))
	rm.set_on_change(func(v): _user_settings.set_value("reduce_motion", v))
	_content.add_child(rm)
	_content.add_child(_spacer(8))

	_add_section_label("set_high_contrast")
	var hc := CyberToggle.new()
	hc.set_label_text("")
	hc.toggled = bool(_user_settings.get_value("high_contrast", false))
	hc.set_on_change(func(v): _user_settings.set_value("high_contrast", v))
	_content.add_child(hc)
	_content.add_child(_spacer(12))


# ---- 关于 ----

func _build_about() -> void:
	var logo := GlitchLabel.new()
	logo.text = "NEURO.EXE"
	logo.glitch_interval = 2.5
	logo.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	logo.add_theme_font_size_override("font_size", 48)
	logo.add_theme_color_override("font_color", ACCENT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(logo)
	_content.add_child(_spacer(8))

	var ver := Label.new()
	ver.text = "v0.1.0"
	ver.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	ver.add_theme_font_size_override("font_size", 20)
	ver.add_theme_color_override("font_color", Color(0.7, 0.75, 0.95, 0.9))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(ver)
	_content.add_child(_spacer(4))

	var engine_lbl := Label.new()
	engine_lbl.text = _tr("set_about_engine")
	engine_lbl.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	engine_lbl.add_theme_font_size_override("font_size", 14)
	engine_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.85, 0.7))
	engine_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	engine_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(engine_lbl)
	_content.add_child(_spacer(16))

	var desc := Label.new()
	desc.text = _tr("set_about_text")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.85, 0.88, 1, 0.8))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(400, 60)
	_content.add_child(desc)
	_content.add_child(_spacer(20))

	var credit_btn := CyberButton.new()
	credit_btn.accent_color = ACCENT_PURPLE
	credit_btn.set_text("▶  " + _tr("set_about_credit_btn"))
	credit_btn.pressed.connect(func():
		_show_credits()
	)
	_content.add_child(credit_btn)


func _show_credits() -> void:
	var cs: PackedScene = load("res://scenes/ui/page_credits.tscn")
	var page: Control = cs.instantiate()
	get_tree().root.add_child(page)
	if page.has_signal("closed"):
		page.closed.connect(func():
			page.queue_free()
		)
	# 关闭自己, 让 credits 接管
	closed.emit()


# ---- 工具 ----

func _add_section_label(key: String) -> void:
	var lbl := Label.new()
	lbl.text = _tr(key)
	lbl.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 0.9))
	_content.add_child(lbl)


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


func _tr(key: String) -> String:
	if _i18n:
		return _i18n.tr_key(key)
	return key


func _show_toast(text: String) -> void:
	if not _toast:
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


# ---- 应用回调 ----

func _on_setting_changed(key: String, _value: Variant) -> void:
	pass  # 大部分由 UserSettings 自己处理


func _on_back() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("switch")
	closed.emit()


func _on_reset_pressed() -> void:
	var dlg_scene: PackedScene = load("res://scenes/ui/dialog_confirm.tscn")
	var dlg = dlg_scene.instantiate()
	get_tree().root.add_child(dlg)
	var callback = func():
		_user_settings.reset_defaults()
		_show_toast(_tr("set_toast_reset"))
		_clear_content()
		_build_category(_active_category)
		_animate_content_in()
		_rebuild_sidebar()
	dlg.setup("dialog_reset_title", "dialog_reset_message", callback)


func _rebuild_sidebar() -> void:
	# 语言切换后重新生成 sidebar 文案
	_build_sidebar()


func _rebuild_text_after_locale_change() -> void:
	_clear_content()
	_build_category(_active_category)
	_animate_content_in()
	_rebuild_sidebar()


# ---- 各类应用 ----

func _apply_display_mode() -> void:
	_user_settings._apply_window()


func _apply_aa(idx: int) -> void:
	# 2D 项目的 msaa
	var v: Viewport.MSAA
	match idx:
		0: v = Viewport.MSAA_DISABLED
		1: v = Viewport.MSAA_2X
		2: v = Viewport.MSAA_4X
		3: v = Viewport.MSAA_8X
		4: v = Viewport.MSAA_DISABLED  # FXAA 暂用 disabled 占位
	get_viewport().msaa_2d = v


func _apply_quality() -> void:
	var p: int = int(_user_settings.get_value("quality_preset", 2))
	# 应用到 StarField (子页或主菜单找到则修改)
	var sf: StarField = get_tree().root.find_child("StarField", true, false)
	if sf:
		match p:
			0: sf.set_density(0)
			1: sf.set_density(1)
			2: sf.set_density(2)
			3: sf.set_density(2)


func _apply_particle(d: int) -> void:
	_apply_quality()


func _apply_fps_label(show: bool) -> void:
	if show:
		if not _fps_label or not is_instance_valid(_fps_label):
			_fps_label = Label.new()
			_fps_label.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
			_fps_label.add_theme_font_size_override("font_size", 14)
			_fps_label.add_theme_color_override("font_color", Color(0.13, 0.82, 0.93, 0.9))
			_fps_label.position = Vector2(size.x - 110, 10)
			add_child(_fps_label)
		else:
			_fps_label.visible = true
	else:
		if _fps_label and is_instance_valid(_fps_label):
			_fps_label.visible = false


func _apply_ui_scale() -> void:
	_user_settings._apply_ui_scale()


func _apply_cb(_idx: int) -> void:
	# 通过 global_canvas_modulate 简化(项目无 ColorMatrix 用,这里只演示占位)
	pass
