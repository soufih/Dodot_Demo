extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene: PackedScene = load(Path.AIR_WALL_SCENE)
	var wall: StaticBody2D = scene.instantiate()
	var other_wall: StaticBody2D = scene.instantiate()
	var shape := wall.get_node("CollisionShape2D") as CollisionShape2D
	var other_shape := other_wall.get_node("CollisionShape2D") as CollisionShape2D
	assert(shape.shape != other_shape.shape)
	shape.shape.size = Vector2(20, 200)
	assert(other_shape.shape.size == Vector2(16, 256))
	wall.position = Vector2(100, 0)
	other_wall.position = Vector2(500, 0)
	root.add_child(wall)
	root.add_child(other_wall)
	var hero := CharacterBody2D.new()
	hero.collision_layer = 2
	hero.collision_mask = 129
	var hero_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10, 10)
	hero_shape.shape = rectangle
	hero.add_child(hero_shape)
	root.add_child(hero)
	await physics_frame
	await physics_frame
	var collision := hero.move_and_collide(Vector2(200, 0))
	assert(collision != null and collision.get_collider() == wall)
	assert(hero.position.x < 90)
	shape.set_deferred("disabled", true)
	await physics_frame
	await physics_frame
	hero.position = Vector2.ZERO
	assert(hero.move_and_collide(Vector2(200, 0)) == null)
	assert(hero.position.is_equal_approx(Vector2(200, 0)))
	hero.queue_free()
	wall.queue_free()
	other_wall.queue_free()
	await process_frame
	print("PASS: air wall blocks character, can be disabled, and instances have independent sizes")
	quit()
