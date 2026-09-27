extends BaseState

var fall_speed:float

func enter():
	fall_speed = 0
	AniPlayer.play("Falling")
	_InputController.switch_weapon_pressed.connect(_check.bind("switch_weapon_pressed"))

func do(delta):
	Entity.filp_character()
	var direct_x = _InputController.get_move_direction()
	Entity.velocity.x = direct_x*Entity.Speed
	
	if !Entity.is_on_floor():
		Entity.velocity.y += delta*DataLoader.gravity
	Entity.move_and_slide()
	fall_speed = max(abs(Entity.velocity.y), fall_speed)

func exit():
	_InputController.switch_weapon_pressed.disconnect(_check.bind("switch_weapon_pressed"))
	if !Entity.is_on_floor():
		return
	var damage:float
	if fall_speed > Entity.safe_fall_speed:
		var damage_ratio = (fall_speed - Entity.safe_fall_speed) / (Entity.max_fall_speed - Entity.safe_fall_speed)
		damage_ratio = clamp(damage_ratio, 0.0, 1.0)

		damage = Entity.base_damage + (50 - Entity.base_damage) * damage_ratio
		damage = round(damage)
	
		var fallen_damage:DamagePorperty = DamagePorperty.new()
		fallen_damage.setter(
			damage,
			ENUM.DamageType.Null,
			0,
			[],
			0)
		DamageSystem.call_deferred("damage_assess", null, Entity, fallen_damage)
