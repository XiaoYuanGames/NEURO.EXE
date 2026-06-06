extends CanvasLayer
## DialogInDev — 居中弹窗,显示"开发中"提示
##
## 用法:
##   var dlg = preload("res://scenes/ui/dialog_in_dev.tscn").instantiate()
##   get_tree().root.add_child(dlg)
##   await dlg.shown
##   # 用户点击确定

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _msg: Label = $Panel/Margin/VBox/Message
@onready var _ok_btn: CyberButton = $Panel/Margin/VBox/OkBtn

signal closed

var _i18n: Node


func _ready() -> void:
	_i18n = get_node_or_null("/root/I18n")
	_overlay.color = Color(0, 0, 0, 0)
	_panel.scale = Vector2(0.9, 0.9)
	_panel.modulate.a = 0.0
	_apply_text()
	_ok_btn.pressed.connect(_on_ok)
	_animate_in()


func _apply_text() -> void:
	if _i18n:
		_title.text = _i18n.tr_key("dialog_in_dev_title")
		_msg.text = _i18n.tr_key("dialog_in_dev_message")
		_ok_btn.set_text(_i18n.tr_key("dialog_ok"))


func _animate_in() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_overlay, "color:a", 0.6, 0.2)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_ok() -> void:
	_animate_out()


func _animate_out() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_overlay, "color:a", 0.0, 0.18)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.18)
	tw.tween_callback(func():
		closed.emit()
		queue_free()
	)


# 静态便捷方法
static func create():
	var scene: PackedScene = load("res://scenes/ui/dialog_in_dev.tscn")
	var inst = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(inst)
	return inst
