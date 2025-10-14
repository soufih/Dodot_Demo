extends Node


# Called when the node enters the scene tree for the first time.
var master_volume: float = 1.0

func _ready():
	load_settings()

# 设置主音量
func set_master_volume(volume: float):
	master_volume = volume
	# 转换为分贝并设置
	var db_volume = linear_to_db(volume)
	AudioServer.set_bus_volume_db(0, db_volume)
	save_settings()

# 获取主音量
func get_master_volume() -> float:
	return master_volume

# 保存设置
func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.save("user://settings.cfg")

# 加载设置
func load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		set_master_volume(master_volume)
