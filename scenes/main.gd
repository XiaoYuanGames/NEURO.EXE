extends Node


func _ready() -> void:
	var loading_screen: Node = get_node_or_null("/root/LoadingScreen")
	if loading_screen and loading_screen.has_method("show_screen"):
		loading_screen.show_screen()
