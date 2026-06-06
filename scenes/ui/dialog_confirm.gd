extends CanvasLayer
## DialogConfirm — 二次确认弹窗
##
## 用法:
##   var dlg = preload("res://scenes/ui/dialog_confirm.tscn").instantiate()
##   dlg.setup(title_key, msg_key, on_confirm_callable)
##   get_tree().root.add_child(dlg)
##   await dlg.closed

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _msg: Label = $Panel/Margin/VBox/Message
@onready var _ok_btn: CyberButton = $Panel/Margin/VBox/HBox/OkBtn
@onready var _cancel_btn: CyberButton = $Panel/Margin/VBox/HBox/CancelBtn

signal closed(confirmed: bool)

var _on_confirm: Callable = Callable()
var _i18n: Node


func _ready() -> void:
	_i18n = get_node_or_null("/root/I18n")
	_overlay.color = Color(0, 0, 0, 0)
	_panel.scale = Vector2(0.9, 0.9)
	_panel.modulate.a = 0.0
	_apply_default_text()
	_ok_btn.pressed.connect(_on_ok)
	_cancel_btn.pressed.connect(_on_cancel)
	_animate_in()


func setup(title_key: String, msg_key: String, on_confirm: Callable) -> void:
	if _i18n:
		_title.text = _i18n.tr_key(title_key)
		_msg.text = _i18n.tr_key(msg_key)
	else:
		_title.text = title_key
		_msg.text = msg_key
	_on_confirm = on_confirm


func _apply_default_text() -> void:
	if _i18n:
		_ok_btn.set_text(_i18n.tr_key("dialog_ok"))
		_cancel_btn.set_text(_i18n.tr_key("dialog_cancel"))


func _animate_in() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_overlay, "color:a", 0.6, 0.2)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_ok() -> void:
	_emit(true)


func _on_cancel() -> void:
	_emit(false)


func _emit(ok: bool) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_overlay, "color:a", 0.0, 0.18)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.18)
	tw.tween_callback(func():
		if ok and _on_confirm.is_valid():
			_on_confirm.call()
		closed.emit(ok)
		queue_free()
	)


# 静态便捷
static func create(title_key: String, msg_key: String, on_confirm: Callable = Callable()):
	var scene: PackedScene = load("res://scenes/ui/dialog_confirm.tscn")
	var inst = scene.instantiate()
	inst.setup(title_key, msg_key, on_confirm)
	(Engine.get_main_loop() as SceneTree).root.add_child(inst)
	return inst


static func quit():
	return create("dialog_quit_title", "dialog_quit_message", func(): (Engine.get_main_loop() as SceneTree).quit())


static func reset(on_confirm: Callable):
	return create("dialog_reset_title", "dialog_reset_message", on_confirm)
