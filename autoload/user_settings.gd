extends Node
## UserSettings — 全局设置持久化与广播
##
## 负责:
## - 在 user://settings.cfg 中以 ConfigFile 持久化
## - 启动时从 cfg 加载并应用(分辨率/全屏/音量/UI 缩放 等)
## - 通过 signal setting_changed 广播任意键值变化
## - 任何子系统都可订阅此信号做实时响应
##
## 用法:
##   UserSettings.set("music_volume", 80)
##   var v = UserSettings.call("get", "music_volume", 100)
##   UserSettings.setting_changed.connect(_on_setting_changed)

signal setting_changed(key: String, value: Variant)

const CFG_PATH := "user://settings.cfg"
const SECTION := "user"

# 首次启动时的默认值
const DEFAULTS: Dictionary = {
	# 通用
	"language": "zh",

	# 显示
	"display_mode": 0,            # 0=windowed, 1=borderless, 2=fullscreen
	"resolution": "1280x720",
	"vsync_mode": 1,              # 0=off, 1=on, 2=adaptive
	"fps_cap": 240,
	"brightness": 100,            # 0-200
	"contrast": 100,              # 0-200
	"antialias": 0,               # 0=off, 1=msaa2, 2=msaa4, 3=msaa8, 4=fxaa
	"quality_preset": 2,          # 0=low, 1=mid, 2=high, 3=ultra

	# 音频
	"master_volume": 100,         # 0-100
	"music_volume": 50,
	"sfx_volume": 70,
	"hit_volume": 100,
	"mute_all": false,
	"audio_device": "Default",

	# 玩法
	"lane_count": 4,              # 4 / 5 / 6 / 7 / 8
	"note_speed": 1.0,            # 0.5 - 3.0
	"judgment_offset_ms": 0,      # -200 ~ +200
	"bg_dim": 30,                 # 0-100
	"bga_enabled": true,
	"auto_play": false,

	# 高级
	"show_fps": true,
	"show_judge": true,
	"show_combo": true,
	"particle_density": 1,        # 0=low, 1=mid, 2=high
	"bloom": 100,                 # 0-200
	"chromatic": 30,              # 0-100
	"motion_blur": false,
	"screen_shake": true,
	"color_blind_mode": 0,        # 0=off, 1=prot, 2=deut, 3=trit
	"ui_scale": 100,              # 50-200
	"reduce_motion": false,
	"high_contrast": false,
}

var _values: Dictionary = {}
var _i18n: Node


func _ready() -> void:
	_load()
	_apply_i18n()
	_apply_window()
	_apply_engine()
	_apply_ui_scale()
	# 推送到 AudioManager
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.call("_apply_initial_volumes")
	_i18n = get_node_or_null("/root/I18n")
	if _i18n:
		_i18n.locale_changed.connect(_on_locale_changed)


func _load() -> void:
	# 默认值
	_values = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	var err := cfg.load(CFG_PATH)
	if err == OK:
		for k in DEFAULTS.keys():
			_values[k] = cfg.get_value(SECTION, k, DEFAULTS[k])
	else:
		# 首次启动:写入默认值
		save()


func save() -> void:
	var cfg := ConfigFile.new()
	for k in _values.keys():
		cfg.set_value(SECTION, k, _values[k])
	cfg.save(CFG_PATH)


func get_value(key: String, fallback: Variant = null) -> Variant:
	if _values.has(key):
		return _values[key]
	if fallback != null:
		return fallback
	return DEFAULTS.get(key, null)


func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	setting_changed.emit(key, value)
	# 立即保存,避免意外退出丢失
	save()


func reset_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	save()
	# 广播所有键
	for k in _values.keys():
		setting_changed.emit(k, _values[k])
	_apply_window()
	_apply_engine()
	_apply_ui_scale()


func has(key: String) -> bool:
	return _values.has(key)


# ---- 应用层 ----

func _apply_window() -> void:
	var win := get_window()
	if not win:
		return
	# display_mode
	match int(get_value("display_mode", 2)):
		0:
			win.mode = Window.MODE_WINDOWED
		1:
			win.mode = Window.MODE_MAXIMIZED if OS.has_feature("pc") else Window.MODE_WINDOWED
		2:
			win.mode = Window.MODE_FULLSCREEN
	# resolution (仅在窗口模式下生效)
	if win.mode == Window.MODE_WINDOWED:
		var res_str: String = get_value("resolution", "1280x720")
		var parts := res_str.split("x")
		if parts.size() == 2:
			var sz := Vector2i(int(parts[0]), int(parts[1]))
			win.size = sz
	# vsync
	var vs: int = int(get_value("vsync_mode", 1))
	DisplayServer.window_set_vsync_mode(vs as DisplayServer.VSyncMode)


func _apply_engine() -> void:
	Engine.max_fps = int(get_value("fps_cap", 240))


func _apply_ui_scale() -> void:
	var pct: float = float(get_value("ui_scale", 100)) / 100.0
	get_tree().root.content_scale_factor = clampf(pct, 0.5, 2.0)


func _apply_i18n() -> void:
	var i18n := get_node_or_null("/root/I18n")
	if not i18n:
		return
	var lang: String = get_value("language", "zh")
	if i18n.get_available_locales().has(lang):
		i18n.set_locale(lang)


func _on_locale_changed(_new_locale: String) -> void:
	# i18n 单独通过 tr_key 调用,这里只同步"language"键保持持久化一致
	pass
