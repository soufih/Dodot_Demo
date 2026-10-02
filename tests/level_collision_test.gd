extends Node

class TestGenerator extends "res://Script/Gameplay/Map/LevelGenerator v1.gd":
	var candidates: Array[PackedScene] = []
	func _init() -> void:
		pass
	func _ready() -> void:
		pass
	func corridor_candidates(_level: int, _entrance: String) -> Array[PackedScene]:
		return candidates

func make_room(height: int, branch: bool = false) -> PackedScene:
	var room := Node2D.new()
	var layer := TileMapLayer.new()
	layer.name = "BaseLayer"
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i.ZERO)
	tiles.add_source(atlas, 0)
	layer.tile_set = tiles
	for y in range(height):
		layer.set_cell(Vector2i(0, y), 0, Vector2i.ZERO)
	room.add_child(layer)
	layer.owner = room
	var marker := Marker2D.new()
	marker.name = "RIGHT"
	marker.position = Vector2(16, 0)
	room.add_child(marker)
	marker.owner = room
	if branch:
		var extra := Marker2D.new()
		extra.name = "BOTTOM"
		room.add_child(extra)
		extra.owner = room
	var scene := PackedScene.new()
	assert(scene.pack(room) == OK)
	room.free()
	return scene

func _ready() -> void:
	var generator := TestGenerator.new()
	var real_start := load("res://Scene/Map/Room/Start/S1.tscn").instantiate() as Node2D
	var real_corridor := load("res://Scene/Map/Room/Corridor/C1.tscn").instantiate() as Node2D
	real_corridor.position = real_start.get_node("RIGHT").position
	var real_occupied: Array[Rect2] = [generator.room_bounds(real_start)]
	assert(not generator.overlaps_rooms(generator.room_bounds(real_corridor), real_occupied))
	real_start.free()
	real_corridor.free()
	var corridor := make_room(1)
	var target := make_room(2)
	var neighbour := corridor.instantiate() as Node2D
	generator.add_child(neighbour)
	var occupied: Array[Rect2] = [generator.room_bounds(neighbour)]
	# 邻接边界允许接触，缩放参与占地计算。
	assert(not generator.overlaps_rooms(Rect2(16, 0, 16, 16), occupied))
	neighbour.scale = Vector2(2, 2)
	assert(generator.room_bounds(neighbour).size == Vector2(32, 32))
	neighbour.scale = Vector2.ONE
	# 当前房间碰撞而短走廊可放置；原房间接到新增走廊末端。
	occupied.append(Rect2(16, 16, 16, 16))
	generator.candidates = [corridor]
	var result := generator.place_room_with_corridors(target, neighbour, "LEFT", 0, occupied)
	assert(result != null and result.position == Vector2(32, 0))
	assert(generator.get_child_count() == 3 and occupied.size() == 4)
	generator.free()
	# 达到上限后撤销走廊，不能留下孤立节点或占地。
	generator = TestGenerator.new()
	neighbour = corridor.instantiate()
	generator.add_child(neighbour)
	occupied = [generator.room_bounds(neighbour), Rect2(16, 16, 160, 16)]
	generator.candidates = [corridor]
	generator.max_corridor_retries = 2
	assert(generator.place_room_with_corridors(target, neighbour, "LEFT", 0, occupied) == null)
	assert(generator.get_child_count() == 1 and occupied.size() == 2)
	# 多出口场景即使被误选，也不能产生支路。
	generator.candidates = [make_room(1, true)]
	assert(generator.place_room_with_corridors(target, neighbour, "LEFT", 0, occupied) == null)
	assert(generator.get_child_count() == 1)
	generator.free()
	print("LEVEL_COLLISION_TESTS_PASSED")
	get_tree().quit()
