extends Node

@export var Level:int = 0
@export var LevelName:String = ""

func set_level_info(level:int, level_name:String) -> void:
	Level = level
	LevelName = level_name

func get_level_info() -> Dictionary:
	return {"Level": Level, "LevelName": LevelName}
