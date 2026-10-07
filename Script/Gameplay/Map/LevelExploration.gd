extends Node
## 只记录本次生成的关卡；房间范围与生成器的 BaseLayer 占地一致。

signal exploration_changed

@export var generator: LevelGenerator

var current_room_id: int = -1
var _rooms: Array[Dictionary] = []


func _ready() -> void:
	if generator == null:
		return
	generator.level_generated.connect(_on_level_generated)
	generator.level_clearing.connect(clear_exploration)
	if generator.generation_succeeded:
		_on_level_generated()


func _physics_process(_delta: float) -> void:
	var hero: HeroProperty = DataLoader.get_hero()
	if not is_instance_valid(hero) or hero.get_parent() != generator:
		return
	update_player_position(hero.global_position)


func _on_level_generated() -> void:
	_rooms.clear()
	current_room_id = -1
	for node in generator.get_children():
		var tiles := node.get_node_or_null("BaseLayer") as TileMapLayer
		if tiles == null or tiles.tile_set == null:
			continue
		var cells := tiles.get_used_rect()
		if not cells.has_area():
			continue
		var tile_size := Vector2(tiles.tile_set.tile_size)
		var bounds := tiles.global_transform * Rect2(Vector2(cells.position) * tile_size, Vector2(cells.size) * tile_size)
		_rooms.append({"id": _rooms.size(), "bounds": bounds, "explored": false})
	var hero: HeroProperty = DataLoader.get_hero()
	if is_instance_valid(hero) and hero.get_parent() == generator:
		update_player_position(hero.global_position)
	exploration_changed.emit()


func clear_exploration() -> void:
	_rooms.clear()
	current_room_id = -1
	exploration_changed.emit()


func update_player_position(world_position: Vector2) -> void:
	# 接缝允许少量重叠；仍在当前房间时不同时揭示邻接房间。
	if current_room_id >= 0 and _rooms[current_room_id].bounds.has_point(world_position):
		return
	var next_room := -1
	for room in _rooms:
		if room.bounds.has_point(world_position):
			next_room = room.id
			break
	if next_room == current_room_id:
		return
	current_room_id = next_room
	if current_room_id >= 0:
		_rooms[current_room_id].explored = true
	exploration_changed.emit()


func get_explored_rooms() -> Array[Dictionary]:
	var explored: Array[Dictionary] = []
	for room in _rooms:
		if room.explored:
			explored.append({"id": room.id, "bounds": room.bounds})
	return explored
