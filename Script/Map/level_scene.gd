extends Node2D

static var LvGenerator:LevelGenerator = LevelGenerator.new()

func _init() -> void:
	generate_level(LevelInformation.get_level_info()["Level"])

##生成关卡
func generate_level(level:int) -> void:
	if LvGenerator:
		LvGenerator.call_deferred("generate_level", level)
