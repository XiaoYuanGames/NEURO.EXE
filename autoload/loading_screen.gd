extends CanvasLayer

@onready var _label: Label = $LoadingLabel

var _loading_key: String = "loading"
var _i18n: Node


func _ready() -> void:
	visible = false
	_i18n = get_node("/root/I18n")
	if _i18n:
		_i18n.locale_changed.connect(_on_locale_changed)
	_update_text()


func show_screen(custom_key: String = "") -> void:
	_loading_key = custom_key if custom_key != "" else "loading"
	_update_text()
	visible = true


func hide_screen() -> void:
	visible = false


func set_loading_key(key: String) -> void:
	_loading_key = key
	_update_text()


func _update_text() -> void:
	if _label and _i18n:
		_label.text = _i18n.tr_key(_loading_key)


func _on_locale_changed(_new_locale: String) -> void:
	_update_text()
