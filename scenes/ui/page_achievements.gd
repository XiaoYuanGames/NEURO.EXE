extends Control
## PageAchievements — 成就与结局页
##   顶部 Tab 切换(成就/结局)
##   中部 "已解锁 X / Y" + 进度条
##   主区 ScrollContainer + GridContainer,卡片 staggered 入场
##   锁定状态:desaturate + 0.3 alpha + 标题 "???"

class_name PageAchievements

signal closed

@onready var _header: Control = $Header
@onready var _tab_ach: CyberButton = $Tabs/AchBtn
@onready var _tab_end: CyberButton = $Tabs/EndBtn
@onready var _summary: Label = $Tabs/Summary
@onready var _progress: ProgressBar = $Tabs/Progress
@onready var _grid: GridContainer = $Scroll/Grid
@onready var _empty: Label = $Empty

const CARD_W := 260
const CARD_H := 190

var _i18n: Node
var _ach_data: Array = []
var _end_data: Array = []
var _current_tab: String = "achievements"
var _cards: Array = []


func _ready() -> void:
	_i18n = get_node("/root/I18n")
	_load_data()
	_apply_static_text()
	_setup_tabs()
	if _header and _header.has_signal("back_pressed"):
		_header.back_pressed.connect(func():
			var am := get_node_or_null("/root/AudioManager")
			if am: am.play_sfx("switch")
			closed.emit())
	switch_tab("achievements")


func _apply_static_text() -> void:
	if not _i18n:
		return
	_tab_ach.set_text(_i18n.tr_key("tab_achievements"))
	_tab_end.set_text(_i18n.tr_key("tab_endings"))


func _load_data() -> void:
	_ach_data = _read_json_array("res://data/achievements.json", "achievements")
	_end_data = _read_json_array("res://data/endings.json", "endings")


func _read_json_array(path: String, key: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return []
	var content := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return []
	return json.data.get(key, [])


func _setup_tabs() -> void:
	_tab_ach.accent_color = Color(0.13, 0.82, 0.93)
	_tab_ach.is_primary = true
	_tab_ach.pressed.connect(func(): switch_tab("achievements"))
	_tab_end.accent_color = Color(0.7, 0.4, 1.0)
	_tab_end.pressed.connect(func(): switch_tab("endings"))


func switch_tab(tab: String) -> void:
	_current_tab = tab
	# 切换 primary
	_tab_ach.is_primary = (tab == "achievements")
	_tab_end.is_primary = (tab == "endings")
	_tab_ach._refresh()
	_tab_end._refresh()
	# 重置 grid
	for c in _cards:
		c.queue_free()
	_cards.clear()
	# 加载数据
	var data: Array = _ach_data if tab == "achievements" else _end_data
	if data.is_empty():
		_empty.visible = true
		_empty.text = _i18n.tr_key("ach_empty") if _i18n else "No data"
	else:
		_empty.visible = false
	# 渲染
	var unlocked_count: int = 0
	for i in data.size():
		var item: Dictionary = data[i]
		if item.has("unlocked") and item["unlocked"]:
			unlocked_count += 1
		var card := _make_card(item)
		_grid.add_child(card)
		_cards.append(card)
		_stagger_in(card, i)
	# 更新 summary
	var total: int = data.size()
	var total_label: String = _i18n.tr_key("ach_total") if _i18n else "Unlocked"
	_summary.text = "%s %d / %d" % [total_label, unlocked_count, total]
	_progress.max_value = total
	_progress.value = unlocked_count
	# 重置滚动
	var sc := _grid.get_parent() as ScrollContainer
	if sc:
		sc.scroll_vertical = 0
	# SFX
	var am := get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("switch")


func _make_card(item: Dictionary) -> PanelContainer:
	var loc: String = _i18n.get_locale() if _i18n else "en"
	var is_zh: bool = loc == "zh"
	var title_key: String = "title_zh" if is_zh else "title_en"
	var title: String = item[title_key] if item.has(title_key) else "???"
	var desc_key: String = "desc_zh" if is_zh else "desc_en"
	var desc: String = item[desc_key] if item.has(desc_key) else ""
	var unlocked: bool = item["unlocked"] if item.has("unlocked") else false

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_W, CARD_H)
	panel.size = Vector2(CARD_W, CARD_H)
	panel.modulate = Color(1, 1, 1, 0)
	_apply_card_style(panel, unlocked)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# 图标
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size = Vector2(48, 48)
	if unlocked:
		icon.color = Color(0.13, 0.82, 0.93, 0.8)
	else:
		icon.color = Color(0.25, 0.25, 0.35, 0.6)
	vbox.add_child(icon)

	# 标题
	var title_lbl := Label.new()
	title_lbl.text = title if unlocked else "???"
	title_lbl.add_theme_font_override("font", load("res://assets/fonts/MiSans-Semibold.ttf"))
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0) if unlocked else Color(0.55, 0.6, 0.75, 0.7))
	vbox.add_child(title_lbl)

	# 描述
	var desc_lbl := Label.new()
	desc_lbl.text = desc if unlocked else (_i18n.tr_key("ach_locked") if _i18n else "Locked")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", load("res://assets/fonts/MiSans-Regular.ttf"))
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9, 0.85) if unlocked else Color(0.45, 0.5, 0.65, 0.5))
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	return panel


func _apply_card_style(panel: PanelContainer, unlocked: bool) -> void:
	var sb := StyleBoxFlat.new()
	if unlocked:
		sb.bg_color = Color(0.06, 0.03, 0.14, 0.9)
		sb.border_color = Color(0.13, 0.82, 0.93, 0.8)
		sb.shadow_color = Color(0.13, 0.82, 0.93, 0.25)
	else:
		sb.bg_color = Color(0.04, 0.03, 0.09, 0.75)
		sb.border_color = Color(0.35, 0.35, 0.5, 0.35)
		sb.shadow_color = Color(0.55, 0.15, 0.95, 0.1)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", sb)


func _stagger_in(card: Control, idx: int) -> void:
	card.scale = Vector2(0.7, 0.7)
	card.pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_interval(0.05 * idx)
	tw.tween_property(card, "modulate:a", 1.0, 0.3)
	tw.tween_property(card, "scale", Vector2.ONE, 0.35)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
