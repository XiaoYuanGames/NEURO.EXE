extends Node
## Main — 入口场景
##   启动时直接挂载主菜单(不显示 loading)
##   loading 仅在点击开始/继续游戏时由主菜单主动显示

func _ready() -> void:
	# 等一帧让 autoload 全部就绪
	await get_tree().process_frame
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu: Node = menu_scene.instantiate()
	add_child(menu)
