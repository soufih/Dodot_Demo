extends Node

class CountEffect extends SkillEffect:
	var executions := 0
	func execute(context: SkillContext) -> void:
		executions += 1

class Sensor extends Node:
	signal satisfied(value: float)

const HERO = preload(Path.HERO_SCENE)

func _ready() -> void:
	var hero: HeroProperty = HERO.instantiate()
	add_child(hero)
	hero.set_physics_process(false)
	var manager = hero.get_node("State")
	manager.set_physics_process(false)
	var input: InputController = hero.get_node("InputController")
	input.ban_input(false)
	var controller: SkillController = hero.get_node("SkillController")
	controller.set_physics_process(false)
	assert(controller.owned_skills.size() == 2)
	assert(not controller.owned_skills.has(&"jump"))
	assert(not controller.trigger_skill_map.has(^"InputController:jump_pressed"))
	assert(not controller.try_activate(&"multiple_jump"))
	assert(hero.is_ability_enabled(&"dash"))
	assert(not controller.trigger_skill_map.has(^"InputController:dash_pressed"))
	assert(hero.MaxJumpCount == 2 and hero.get_jump_count() == 2)
	_press_jump(input)
	assert(manager.Current.name == &"Jumping" and hero.get_jump_count() == 1)
	_press_jump(input)
	assert(hero.get_jump_count() == 0)
	var speed := hero.velocity
	_press_jump(input)
	assert(hero.velocity == speed)
	SignalBus.skill_remove_requested.emit(hero, &"multiple_jump")
	assert(hero.MaxJumpCount == 1)
	manager.switch_state(manager.get_node("Idle"), false)
	hero.jump_count_reset_requested.emit()
	_press_jump(input)
	assert(hero.get_jump_count() == 0 and manager.Current.name == &"Jumping")
	# 获取能力只应用上限；重复获取不刷新次数，普通跳跃独立处理。
	SignalBus.skill_acquire_requested.emit(hero, &"multiple_jump")
	assert(hero.MaxJumpCount == 2 and hero.get_jump_count() == 1)
	SignalBus.skill_acquire_requested.emit(hero, &"multiple_jump")
	assert(hero.get_jump_count() == 1)
	_press_jump(input)
	assert(hero.get_jump_count() == 0)
	# 一次性能力与瞬时性技能均在获取时执行，重复获取语义不同。
	var one_effect := CountEffect.new()
	var one := _register_test_skill(&"one_time_test", SkillDefinition.Kind.ONE_TIME, one_effect)
	assert(controller.acquire_skill(one.id))
	assert(not controller.acquire_skill(one.id))
	assert(not controller.remove_skill(one.id))
	assert(controller.once_records.has(one.id) and one_effect.executions == 1)
	var instant_effect := CountEffect.new()
	var instant := _register_test_skill(&"instant_test", SkillDefinition.Kind.INSTANT, instant_effect)
	SignalBus.skill_acquire_requested.emit(hero, instant.id)
	SignalBus.skill_acquire_requested.emit(hero, instant.id)
	assert(instant_effect.executions == 2 and not controller.owned_skills.has(instant.id))
	instant.cooldown = 0.1
	var cooldown_events: Array[String] = []
	var on_started := func(target: HeroProperty, id: StringName, duration: float):
		assert(target == hero and id == instant.id and duration == 0.1)
		assert(not controller.is_skill_ready(id))
		cooldown_events.append("started")
	var on_finished := func(target: HeroProperty, id: StringName):
		assert(target == hero and id == instant.id)
		assert(controller.is_skill_ready(id))
		cooldown_events.append("finished")
	SignalBus.skill_cooldown_started.connect(on_started)
	SignalBus.skill_cooldown_finished.connect(on_finished)
	assert(controller.acquire_skill(instant.id))
	assert(not controller.acquire_skill(instant.id))
	assert(cooldown_events == ["started"])
	await controller.skill_timer_map[instant.id].timeout
	assert(cooldown_events == ["started", "finished"])
	SignalBus.skill_cooldown_started.disconnect(on_started)
	SignalBus.skill_cooldown_finished.disconnect(on_finished)
	assert(controller.acquire_skill(instant.id) and instant_effect.executions == 4)
	# 持续性技能监听任意子节点条件信号，获得时不执行，冷却期间不重复触发。
	var sensor := Sensor.new()
	sensor.name = "Sensor"
	hero.add_child(sensor)
	var continuous_effect := CountEffect.new()
	var continuous := _register_test_skill(&"continuous_test", SkillDefinition.Kind.CONTINUOUS, continuous_effect)
	continuous.trigger = ^"Sensor:satisfied"
	continuous.duration = 0.25
	continuous.cooldown = 0.5
	assert(controller.acquire_skill(continuous.id))
	assert(continuous_effect.executions == 0)
	sensor.satisfied.emit(0.5)
	assert(continuous_effect.executions == 1 and controller.active_context != null)
	sensor.satisfied.emit(0.5)
	assert(continuous_effect.executions == 1)
	controller._physics_process(0.25)
	assert(controller.active_context == null)
	sensor.satisfied.emit(0.5)
	assert(continuous_effect.executions == 1)
	await controller.skill_timer_map[continuous.id].timeout
	sensor.satisfied.emit(0.5)
	assert(continuous_effect.executions == 2)
	assert(controller.remove_skill(continuous.id))
	assert(controller.active_context == null and sensor.satisfied.get_connections().is_empty())
	assert(controller.acquire_skill(continuous.id))
	assert(not controller.try_activate(continuous.id))
	assert(controller.remove_skill(continuous.id))
	# 非法来源不能加入获取表。
	continuous.trigger = ^"Missing:satisfied"
	assert(not controller.acquire_skill(continuous.id))
	# 不同人物的获得记录和能力效果相互隔离。
	var other: HeroProperty = HERO.instantiate()
	add_child(other)
	other.set_physics_process(false)
	other.get_node("State").set_physics_process(false)
	var other_controller: SkillController = other.get_node("SkillController")
	controller.start_skill_cooldown(&"dash")
	assert(not controller.is_skill_ready(&"dash") and other_controller.is_skill_ready(&"dash"))
	assert(controller.skill_timer_map[&"dash"] != other_controller.skill_timer_map[&"dash"])
	assert(not other_controller.once_records.has(one.id))
	assert(other_controller.acquire_skill(one.id))
	assert(one_effect.executions == 2)
	SignalBus.skill_remove_requested.emit(hero, &"multiple_jump")
	assert(hero.MaxJumpCount == 1 and other.MaxJumpCount == 2)
	SignalBus.skill_remove_requested.emit(hero, &"dash")
	assert(not hero.is_ability_enabled(&"dash") and other.is_ability_enabled(&"dash"))
	for definition in [one, instant, continuous]:
		ResourceManager.SkillConfigCache.erase(definition.id)
	print("SKILL_ARCHITECTURE_TESTS_PASSED")
	get_tree().quit()

func _register_test_skill(id: StringName, kind: SkillDefinition.Kind, effect: SkillEffect) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.kind = kind
	definition.effects.append(effect)
	ResourceManager.SkillConfigCache[id] = definition
	return definition

func _press_jump(input: InputController) -> void:
	var event := InputEventAction.new()
	event.action = &"Jump"
	event.pressed = true
	input._unhandled_input(event)
