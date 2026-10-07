extends Node

func _ready() -> void:
	var target := BaseCharacter.new()
	target.MaxHealth = 100.0
	target.position = Vector2(100, 150)
	add_child(target)
	var bar := preload(Path.ENEMY_HEALTH_BAR_SCENE).instantiate() as EnemyHealthBar
	target.add_child(bar)
	assert(bar.target == target)
	assert(bar.health_bar.value == 100.0 and not bar.visible)
	target.set_character_current_health(60.0)
	assert(bar.visible and bar.health_bar.value == 60.0)
	assert(bar.damage_bar.value == 100.0)
	await get_tree().create_timer(0.6).timeout
	assert(is_equal_approx(bar.damage_bar.value, 60.0))
	target.scale.x = -1.0
	await get_tree().process_frame
	assert(bar.global_position.is_equal_approx(target.global_position + bar.head_offset))
	assert(bar.global_scale.is_equal_approx(Vector2.ONE))
	target.set_character_current_health(80.0)
	assert(bar.health_bar.value == 80.0 and bar.damage_bar.value == 80.0)
	target.set_character_max_health(200.0)
	assert(bar.health_bar.max_value == 200.0)
	target.set_character_current_health(0.0)
	assert(not bar.visible and bar.health_bar.value == 0.0)
	target.set_character_max_health(0.0)
	assert(not bar.visible)
	target.remove_child(bar)
	assert(not target.health_changed.is_connected(bar.refresh))
	bar.free()
	target.free()
	print("enemy_health_bar_test: PASS")
	get_tree().quit()
