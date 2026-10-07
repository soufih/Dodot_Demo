extends "res://Script/Gameplay/Map/LevelGenerator v1.gd"
func _ready() -> void:
	pass
func assemble_room(_level: int) -> bool:
	var start = load(Path.S1_SCENE).instantiate()
	add_child(start)
	var corridor = load(Path.C1_SCENE).instantiate()
	corridor.position = start.get_node("RIGHT").position
	add_child(corridor)
	corridor.get_node("CameraBoundary").priority = 5
	return true
func generate_enemy(_level: int) -> bool:
	return true
func generate_player() -> bool:
	return true

