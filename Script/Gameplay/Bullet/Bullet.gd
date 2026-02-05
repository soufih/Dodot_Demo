extends AnimatedSprite2D

@export var Speed:int

@onready var HitBox:Area2D = $Area2D

var TargetPosion:Vector2
var Direction:Vector2
var Target:String
var Source:BaseCharacter


func _ready() -> void:
	var NewParent = get_tree().current_scene
	reparent(NewParent,true)
	#var Hero = get_tree().get_first_node_in_group("Hero")
	#if Hero:
		#Direction = global_position.direction_to(Hero.global_position)
		#rotation = Direction.angle()
	Direction = global_position.direction_to(TargetPosion)
	rotation = Direction.angle()


func _physics_process(delta: float) -> void:
	var velocity = Direction.normalized()*Speed
	self.position += velocity*delta


func apply_damage():
	var Attack = DamagePorperty.new(
		20,
		ENUM.DamageType.Physics,
		20,
		[],
		0.1,
	)
	
	for body in HitBox.get_overlapping_bodies():
		if body.is_in_group(Target):
			DamageSystem.damage_assess(Source,body, Attack)
			$Area2D.set_collision_mask_value(2, false)


#身存周期到后自动销毁
func _on_timer_timeout() -> void:
	queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group(Target):
		Speed = 0
		$AnimationPlayer.play("Boom")
		apply_damage()
	await $AnimationPlayer.animation_finished
	queue_free()


func set_bullet_porperty(target:String,source:BaseCharacter, target_postion:Vector2):
	Target = target
	Source = source
	TargetPosion = target_postion
