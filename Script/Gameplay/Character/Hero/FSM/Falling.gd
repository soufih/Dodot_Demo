extends BaseState

@export var safe_fall_speed = 800  # 安全下落速度
@export var max_fall_speed = 1500  # 最大下落速度
@export var base_damage = 5  # 基础伤害

var fall_speed:float

func enter():
	fall_speed = 0
	AniPlayer.play("Falling")


func do(delta):
	var direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")
	Entity.velocity.x = direct_x*Entity.Speed
	
	if !Entity.is_on_floor():
		Entity.velocity.y += delta*DataLoader.gravity
	Entity.move_and_slide()
	fall_speed = max(abs(Entity.velocity.y), fall_speed)

func exit():
	var damage:float
	if fall_speed > safe_fall_speed:
		var damage_ratio = (fall_speed - safe_fall_speed) / (max_fall_speed - safe_fall_speed)
		damage_ratio = clamp(damage_ratio, 0.0, 1.0)

		damage = base_damage + (50 - base_damage) * damage_ratio
		damage = round(damage)
	
		var fallen_damage:DamagePorperty = DamagePorperty.new()
		fallen_damage.setter(
			damage,
			ENUM.DamageType.Null,
			0,
			[],
			0)
		DamageSystem.damage_assess(null, Entity, fallen_damage)
