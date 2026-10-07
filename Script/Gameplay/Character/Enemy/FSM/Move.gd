extends BaseState

@export var BarrierDetect:Area2D
@export var Spirte:AnimatedSprite2D
@export var Speed:int
@export var Hatebox:Area2D

var HasBarrier:bool = false
var Direct = Vector2i.RIGHT.x

func _on_enter():
	AniPlayer.play("Move")
	
func _on_do(delta: float):
	for body in Hatebox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			var HeroPos = body.global_position
			var SelfPos = Entity.global_position
			if Entity.scale.y*(HeroPos.x-SelfPos.x) > 0:
				Entity.scale.x = abs(Entity.scale.x)
			else:
				Entity.scale.x = -abs(Entity.scale.x)
			
			if HeroPos.x > SelfPos.x:
				Direct = 1
			else:
				Direct = -1
	
	if BarrierDetect.has_overlapping_bodies() || BarrierDetect.get_overlapping_areas():
		Entity.scale.x= -Entity.scale.x
		Direct= -Direct

	Entity.velocity.x = Direct*Speed
	Entity.velocity.y += DataLoader.gravity * delta

	Entity.move_and_slide()
