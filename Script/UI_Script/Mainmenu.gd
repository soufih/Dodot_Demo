extends Control

@onready var start_button = $ButtonContainer/gamestart
@onready var setting_button = $ButtonContainer/setting
@onready var quit_button = $ButtonContainer/quit


func _ready() -> void:
	start_button.pressed.connect(on_start_pressed)
	setting_button.pressed.connect(on_setting_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	pass 

func on_start_pressed():
	pass
	
func on_setting_pressed():
	pass
	
func on_quit_pressed():
	get_tree().quit()
