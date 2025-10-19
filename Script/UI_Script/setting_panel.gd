extends Control

@onready var Resolution:int
@onready var DisplayMode:int
@onready var Fps:int
@onready var volume_slider = $"Background/Panel/Tabs/音频设置/MarginContainer/Sound/Main_music_HS"

func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_resolution_option_button_item_selected(index: int) -> void:
	Resolution = index
#获取分辨率设置值

func _on_display_mode_option_button_item_selected(index: int) -> void:
	DisplayMode = index
#获取视频模式设置值

func _on_fps_option_button_item_selected(index: int) -> void:
	Fps = index
#获取帧率设置值

func _on_save_button_pressed() -> void:
	match Resolution:
		0:DisplayServer.window_set_size(Vector2(2560,1440))
		1:DisplayServer.window_set_size(Vector2(1920,1080))
		2:DisplayServer.window_set_size(Vector2(1280,720))
	#更新分辨率
	
	match DisplayMode:
		0:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	#更新视频模式
	
	match  Fps:
		0:Engine.max_fps = 60
		1:Engine.max_fps = 120
		2:Engine.max_fps = 0#帧率无上限
	#更新帧率
	
	volume_slider.value = VolumeManager.get_master_volume()
	volume_slider.value_changed.connect(_on_volume_changed)
	#更新音量
	
func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_packed(preload("res://UI/MainScene_UI/Mainmenu.tscn"))
	

func _on_volume_changed(value: float):
	VolumeManager.set_master_volume(value)
