extends BaseState

var fallen_height_start
var fallen_height_end


func enter():
	AniPlayer.play("Falling")
	fallen_height_start = Entity.global_position.y


func do(delta):
	var direct_x = Input.get_action_strength("MoveRight")-Input.get_action_strength("MoveLeft")
	Entity.velocity.x = direct_x*Entity.Speed
	
	if !Entity.is_on_floor():
		Entity.velocity.y += delta*DataLoader.gravity
	Entity.move_and_slide()

func exit():
	fallen_height_end = Entity.global_position.y
	if fallen_height_end-fallen_height_start <= 500:
		return
	var fallen_damage:DamagePorperty = DamagePorperty.new(
		(fallen_height_end-fallen_height_start-500),
		ENUM.DamageType.Null,
		0,
		[],
		0)
	print(fallen_damage.traverse_damage_property())
	print("health: ", Entity.get_character_current_health())
	DamageSystem.damage_assess(null, Entity, fallen_damage)
