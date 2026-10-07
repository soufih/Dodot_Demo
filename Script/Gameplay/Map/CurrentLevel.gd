extends Node

@export var CurrentLevel:int = 0
@export var LevelName:String = ""

func set_level_info(level:int, level_name:String) -> void:
	CurrentLevel = level
	LevelName = level_name

func get_level_info() -> Dictionary:
	return {"level": CurrentLevel, "levelName": LevelName}
