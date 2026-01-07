extends BaseUI

func _ready() -> void:
	begin()
	hide()

func _on_button_button_down() -> void:
	var loading_scene = load("res://UI/Loading_screen/loading_screen.tscn").instantiate()
	loading_scene.set_next_scene("uid://dn6etfky2c7oa") #加载关卡
	get_tree().current_scene.add_child(loading_scene)
