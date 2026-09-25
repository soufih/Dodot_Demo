extends BaseBullet

@export var Speed:int
@export var Ani:AnimationPlayer

@onready var HitBox:Area2D = $Area2D

var TargetPosion:Vector2
var Direction:Vector2
var Target:String
var Source:BaseCharacter
var Damage = DamagePorperty.new(

)

func _ready() -> void:
	Damage.setter(
	20,
	ENUM.DamageType.Physics,
	20,
	[],
	0.1,
	)
	
	var NewParent = get_tree().current_scene
	reparent(NewParent,true)

	Direction = global_position.direction_to(TargetPosion)
	rotation = Direction.angle()


func _physics_process(delta: float) -> void:
	var velocity = Direction.normalized()*Speed
	self.position += velocity*delta


func setup(target:String,source:BaseCharacter, target_postion:Vector2):
	Target = target
	Source = source
	TargetPosion = target_postion


func apply_damage():
	for body in HitBox.get_overlapping_bodies():
		if body.is_in_group(Target):
			DamageSystem.damage_assess(Source,body, Damage)
			$Area2D.set_collision_mask_value(2, false)


#生存周期到后自动销毁
func _on_timer_timeout() -> void:
	queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group(Target):
		Speed = 0
		Ani.play("Boom")
		apply_damage()
	await Ani.animation_finished
	queue_free()
