extends BaseUI

@onready var Resolution:int
@onready var DisplayMode:int
@onready var Fps:int
@onready var volume_slider = $"Background/Panel/Tabs/音频设置/MarginContainer/Sound/Main_music_HS"
@onready var Resolution_OptionButton :	OptionButton = $"Background/Panel/Tabs/视频设置/MarginContainer/Video/Resolution_OptionButton"
@onready var DisplayMode_OptionButton :	OptionButton = $"Background/Panel/Tabs/视频设置/MarginContainer/Video/DisplayMode_OptionButton"
@onready var Fps_OptionButton :			OptionButton = $"Background/Panel/Tabs/视频设置/MarginContainer/Video/Fps_OptionButton"

func _ready() -> void:
	begin()


##显示设置面板时获取当前设置值
func _on_visibility_changed():
	super._on_visibility_changed()
	if visible:
		#获取当前设置值
		var window_size:Vector2i = DisplayServer.window_get_size()
		match window_size:
			Vector2i(2560,1440):
				Resolution_OptionButton.selected = 0
			Vector2i(1920,1080):
				Resolution_OptionButton.selected = 1
			Vector2i(1280,720):
				Resolution_OptionButton.selected = 2
			_:
				Resolution_OptionButton.selected = 3#默认自定义
		Resolution = Resolution_OptionButton.selected
		
		var window_mode = DisplayServer.window_get_mode()
		match window_mode:
			DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayMode_OptionButton.selected = 0
			DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayMode_OptionButton.selected = 1
		DisplayMode = DisplayMode_OptionButton.selected

		var max_fps = Engine.max_fps
		match max_fps:
			60:
				Fps_OptionButton.selected = 0
			120:
				Fps_OptionButton.selected = 1
			0:
				Fps_OptionButton.selected = 2
		Fps = Fps_OptionButton.selected


func _on_resolution_option_button_item_selected(index: int) -> void:
	Resolution = index
#获取分辨率设置值

func _on_display_mode_option_button_item_selected(index: int) -> void:
	DisplayMode = index
#获取视频模式设置值

func _on_fps_option_button_item_selected(index: int) -> void:
	Fps = index
#获取帧率设置值

##保存设置
func _on_save_button_pressed() -> void:
	match Resolution:
		0:DisplayServer.window_set_size(Vector2(2560,1440))
		1:DisplayServer.window_set_size(Vector2(1920,1080))
		2:DisplayServer.window_set_size(Vector2(1280,720))
		3:pass#自定义分辨率不更改
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

##返回
func _on_back_button_pressed() -> void:
	hide()
	

func _on_volume_changed(value: float):
	VolumeManager.set_master_volume(value)
