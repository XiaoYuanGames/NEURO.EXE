extends CanvasLayer

@onready var _container: HBoxContainer = $LoadingLabel

var _loading_key: String = "loading"
var _i18n: Node
var _rebuild_tween: Tween
var _is_transitioning := false

@export var wave_speed: float = 0.3
@export var char_delay: float = 0.15
@export var alpha_min: float = 0.5
@export var alpha_max: float = 1.0


func _ready() -> void:
	visible = false
	_i18n = get_node("/root/I18n")
	if _i18n:
		_i18n.locale_changed.connect(_on_locale_changed)
	_rebuild_chars()


func _process(_delta: float) -> void:
	if not visible or _is_transitioning:
		return
	var now: float = Time.get_ticks_msec() * 0.001
	var chars: Array[Node] = _container.get_children()
	for i: int in chars.size():
		var label: Label = chars[i] as Label
		if not label:
			continue
		var phase: float = now * wave_speed - i * char_delay
		var t: float = 0.5 + 0.5 * sin(phase * TAU)
		label.modulate.a = lerpf(alpha_min, alpha_max, t)


func show_screen(custom_key: String = "") -> void:
	_loading_key = custom_key if custom_key != "" else "loading"
	_rebuild_chars()
	visible = true


func hide_screen() -> void:
	visible = false


func set_loading_key(key: String) -> void:
	_loading_key = key
	_rebuild_chars()


func _on_locale_changed(_new_locale: String) -> void:
	_rebuild_chars()


func _rebuild_chars() -> void:
	if not visible:
		_rebuild_chars_internal()
		return

	if _rebuild_tween and _rebuild_tween.is_running():
		_rebuild_tween.kill()
	_rebuild_tween = create_tween()
	_is_transitioning = true

	_rebuild_tween.tween_property(_container, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	_rebuild_tween.tween_callback(func():
		_rebuild_chars_internal()
		_container.modulate.a = 0.0
	)
	_rebuild_tween.tween_property(_container, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	_rebuild_tween.tween_callback(func():
		_is_transitioning = false
	)


func _rebuild_chars_internal() -> void:
	for child in _container.get_children():
		_container.remove_child(child)
		child.queue_free()

	var text: String = ""
	if _i18n:
		text = _i18n.tr_key(_loading_key)
	if text == "":
		text = _loading_key

	var ls: LabelSettings = _container.get_meta(&"_label_settings", null)
	for ch in text:
		var label := Label.new()
		label.text = ch
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if ls:
			label.label_settings = ls
		_container.add_child(label)
