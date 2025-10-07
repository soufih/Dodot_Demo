extends PanelContainer

@onready var resolution_option = $MarginContainer/Video/Resolution_OptionButton
@onready var display_mode_option = $MarginContainer/Video/DisplayMode_OptionButton
@onready var fps_option = $MarginContainer/Video/Fps_OptionButton

var video_settings = {
	"resolution": Vector2i(1920, 1080),  # 默认1080P
	"display_mode": 1,  # 0=窗口, 1=全屏, 2=无边框窗口
	"fps": 60,
}

var resolutions = [
	Vector2i(1280, 720),   # 720P
	Vector2i(1920, 1080),  # 1080P
	Vector2i(2560, 1440),  # 2K
	Vector2i(3840, 2160)   # 4K
]

var display_modes = ["窗口模式", "全屏模式", "无边框窗口"]

var fps_options = [30, 60, 120, 144]  

func _ready() -> void:
	pass
	
func _init_dropdowns():
	for res in resolutions:
		resolution_option.add_item("%dx%d" % [res.x,res.y])

	for mode in display_modes:
		display_mode_option.add_item(mode)

	for fps in fps_options:
		fps_option.add_item("%d FPS" % fps)

func _load_saved_settings():
	var config = ConfigFile.new()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
