extends Control

@onready var Resolution:int
@onready var DisplayMode:int
@onready var Fps:int

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_resolution_option_button_item_selected(index: int) -> void:
	Resolution = index


func _on_display_mode_option_button_item_selected(index: int) -> void:
	DisplayMode = index


func _on_fps_option_button_item_selected(index: int) -> void:
	Fps = index


func _on_save_button_pressed() -> void:
	match Resolution:
		0:DisplayServer.window_set_size(Vector2(1920,1080))
		1:DisplayServer.window_set_size(Vector2(1280,720))
		2:DisplayServer.window_set_size(Vector2(960,540))
	
	match DisplayMode:
		0:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	match  Fps:
		0:Engine.max_fps = 60
		1:Engine.max_fps = 120
		2:Engine.max_fps = 0
	
func _on_back_button_pressed() -> void:
	get_tree().quit()
