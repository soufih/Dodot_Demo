extends BaseUI

@onready var start_button = $ButtonContainer/gamestart
@onready var setting_button = $ButtonContainer/setting
@onready var quit_button = $ButtonContainer/quit

var setting_panel_instance:BaseUI

func _ready() -> void:
	start_button.pressed.connect(on_start_pressed)
	setting_button.pressed.connect(on_setting_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	setting_panel_instance = UIManager.load_ui("uid://di38xxftqwhae")


func on_start_pressed():
	$".".visible = false
	var loading_scene = load("res://UI/Loading_screen/loading_screen.tscn").instantiate()
	loading_scene.set_next_scene("res://Scene/Map/Home/Home.tscn")
	$"..".add_child(loading_scene)


func on_setting_pressed():
	setting_panel_instance.show()


func on_quit_pressed():
	get_tree().quit()
