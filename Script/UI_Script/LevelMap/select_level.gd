extends Node

var GenerateThread:Thread = null
static var LvGenerator:LevelGenerator = LevelGenerator.new()

func _ready() -> void:
	GenerateThread = Thread.new()
	LvGenerator.prepare_generating()
