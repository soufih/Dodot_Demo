class_name DashAbility
extends AbilityInstance

@export var dash_speed: float
@export var dash_duration: float

func can_activate(ctx: AbilityContext) -> bool:
	if not super(ctx):
		return false
	return true


func on_activate() -> bool:
	if context.get_state()._check("when_dash_trigger"):
		SignalBus.ability_cooldown_start.emit(context.actor, data.id, data.ico ,data.cooldown)
		return true
	return false


func on_tick(delta: float):
	if elapsed_time >= dash_duration:
		end()
