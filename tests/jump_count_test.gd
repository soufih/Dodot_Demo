extends Node

const HERO_SCENE = preload(Path.HERO_SCENE)
var notifications: Array[Vector2i] = []
var states_on_change: Array[StringName] = []


func _ready() -> void:
	var hero: HeroProperty = HERO_SCENE.instantiate()
	hero.MaxJumpCount = 2
	add_child(hero)
	hero.set_physics_process(false)
	var manager = hero.get_node("State")
	manager.set_physics_process(false)
	var input: InputController = hero.get_node("InputController")
	input.ban_input(false)
	hero.jump_count_changed.connect(func(remaining: int, maximum: int):
		notifications.append(Vector2i(remaining, maximum))
		states_on_change.append(manager.Current.name))
	assert(hero.get_jump_count() == 2)
	var event := InputEventAction.new()
	event.action = &"Jump"
	event.pressed = true
	input._unhandled_input(event)
	assert(manager.Current.name == "Jumping" and hero.get_jump_count() == 1)
	assert(states_on_change.back() == &"Jumping")
	assert(not input.has_buffered_action("Jumping"))
	input._unhandled_input(event)
	assert(manager.Current.name == "Jumping" and hero.get_jump_count() == 0)
	var velocity := hero.velocity
	assert(not hero.can_continue_jump())
	var count_before_rejected := notifications.size()
	input._unhandled_input(event)
	assert(hero.get_jump_count() == 0 and hero.velocity == velocity)
	assert(notifications.size() == count_before_rejected)
	assert(not input.has_buffered_action("Jumping"))
	manager.switch_state(manager.get_node("Falling"), false)
	input._unhandled_input(event)
	assert(manager.Current.name == "Falling")
	hero.jump_count_reset_requested.emit()
	assert(hero.can_continue_jump())
	input._unhandled_input(event)
	assert(manager.Current.name == "Jumping" and hero.get_jump_count() == 1)
	hero.jump_count_change_requested.emit(100)
	assert(hero.get_jump_count() == 2)
	hero.jump_count_change_requested.emit(-100)
	assert(hero.get_jump_count() == 0)
	hero.climb_started.emit()
	assert(hero.get_jump_count() == 2)
	hero.MaxJumpCount = 1
	assert(hero.get_jump_count() == 1)
	assert(notifications.back() == Vector2i(1, 1))
	var count := notifications.size()
	hero.jump_count_reset_requested.emit()
	assert(notifications.size() == count)
	print("JUMP_COUNT_TESTS_PASSED")
	get_tree().quit()
