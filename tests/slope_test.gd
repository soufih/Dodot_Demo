extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var slope: StaticBody2D = load(Path.SLOPE_SCENE).instantiate()
	slope.position = Vector2(0, 200)
	root.add_child(slope)
	var opposite: StaticBody2D = load(Path.SLOPE_SCENE).instantiate()
	opposite.slope_size = Vector2(200, 80)
	opposite.rise_to_right = false
	opposite.position = Vector2(400, 200)
	root.add_child(opposite)
	await physics_frame
	await physics_frame
	assert(slope.get_node("CollisionPolygon2D").polygon == PackedVector2Array([Vector2.ZERO, Vector2(128, -64), Vector2(128, 0)]))
	assert(opposite.get_node("CollisionPolygon2D").polygon == PackedVector2Array([Vector2(0, -80), Vector2(200, 0), Vector2.ZERO]))
	assert(slope.get_node("Surface").polygon == slope.get_node("CollisionPolygon2D").polygon)
	var hero := CharacterBody2D.new()
	hero.collision_layer = 2
	hero.collision_mask = 129
	hero.floor_snap_length = 8.0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5
	collision.shape = shape
	hero.add_child(collision)
	hero.position = Vector2(40, 150)
	root.add_child(hero)
	for frame in 30:
		await physics_frame
		hero.velocity = Vector2(0, 120)
		hero.move_and_slide()
	assert(hero.is_on_floor())
	var start := hero.position
	for frame in 30:
		await physics_frame
		hero.velocity = Vector2(100, 0)
		hero.move_and_slide()
	assert(hero.is_on_floor())
	assert(hero.position.x > start.x + 20 and hero.position.y < start.y - 10)
	var peak := hero.position
	for frame in 20:
		await physics_frame
		hero.velocity = Vector2(-100, 0)
		hero.move_and_slide()
	assert(hero.is_on_floor())
	assert(hero.position.x < peak.x - 10 and hero.position.y > peak.y + 5)
	slope.slope_size = Vector2(160, 40)
	await physics_frame
	await physics_frame
	assert(slope.get_node("CollisionPolygon2D").polygon[1] == Vector2(160, -40))
	assert(opposite.slope_size == Vector2(200, 80))
	hero.queue_free()
	slope.queue_free()
	opposite.queue_free()
	await process_frame
	print("PASS: slope geometry, orientation, independent sizes, uphill and downhill floor contact")
	quit()
