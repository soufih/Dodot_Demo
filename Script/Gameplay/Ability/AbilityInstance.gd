class_name AbilityInstance
extends RefCounted

enum State{
	READY,
	ACTIVE,
	COOLDOWN
}

var data:AbilityConfig
var state: State = State.READY

var remainng_cooldown: float = 0.0
var elapsed_time: float = 0.0
var context: AbilityContext


func get_data()->AbilityConfig:
	return data

func _init(p_data: AbilityConfig) -> void:
	data = p_data


func can_activate(ctx: AbilityContext)->bool:
	return state == State.READY


func activate(ctx: AbilityContext)->void:
	if not can_activate(ctx):
		return
	
	context = ctx
	elapsed_time = 0.0
	if on_activate():
		state = State.ACTIVE


func tick(delta: float) -> void:
	if state == State.COOLDOWN:
		remainng_cooldown= maxf(
			remainng_cooldown - delta, 0.0
		)

		if remainng_cooldown <= 0.0:
			state = State.READY
		return
	
	if state != State.ACTIVE:
		return
	
	elapsed_time += delta
	on_tick(delta)


func interrupt(reason: StringName = &"interrupted") -> void:
	if state != State.ACTIVE:
		return
	
	on_interrupt(reason)
	finish()


func end()-> void:
	if state != State.ACTIVE:
		return
	
	on_end()
	finish()


func finish() -> void:
	on_cleanup()
	
	remainng_cooldown = data.cooldown
	
	if remainng_cooldown > 0.0:
		state = State.COOLDOWN
	else: 
		state =  State.READY

	context = null


func on_activate()->bool:
	return true


func on_tick(delta: float):
	pass


func on_interrupt(reason: StringName = &"interrupted"):
	pass


func on_end():
	pass


func on_cleanup():
	pass
