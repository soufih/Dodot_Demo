extends AnimatedSprite2D

@export var Speed:int

var Direction:Vector2
var Target:String

func _ready() -> void:
	var NewParent = get_tree().current_scene
	reparent(NewParent,true)
	var Hero = get_tree().get_first_node_in_group("Hero")
	if Hero:
		Direction = global_position.direction_to(Hero.global_position)
		rotation = Direction.angle()
		
func _physics_process(delta: float) -> void:
	var velocity = Direction.normalized()*Speed
	self.position += velocity*delta


func set_bullet_porperty(target:String):
	Target = target


func _on_timer_timeout() -> void:
	self.queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group(Target):
		Speed = lerp(Speed,0,0.85)
		$AnimationPlayer.play("Boom")
	await $".".animation_finished
	queue_free()

func apply_damage():
	print("BOOM!")
