extends BaseState

@onready var FSM = $".."
@onready var Spirte = $"../../AnimatedSprite2D"

var Target:Vector2

func enter():
	FSM.SelfBody.velocity.x=0
	FSM.Attacking = true


func do(delta: int):
	#追踪玩家
	for body in FSM.Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			var HeroPos = body.global_position
			var SelfPos = FSM.SelfBody.global_position
			if FSM.SelfBody.scale.y*(HeroPos.x-SelfPos.x) > 0:
				FSM.SelfBody.scale.x = abs(FSM.SelfBody.scale.x)
			else:
				FSM.SelfBody.scale.x = -abs(FSM.SelfBody.scale.x)
			
			if HeroPos > SelfPos:
				$"../Move".Direct = 1
			else:
				$"../Move".Direct = -1

	#获取玩家位置
	for body in FSM.Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			if body.global_position != Vector2(0, 0):
				Target = body.global_position

	FSM.ani.play("Attack")
	await Spirte.animation_finished
 
func spawn_bullet():
	#生成弹幕攻击玩家
	var Bullet = $"../..".BulletPreload.instantiate()
	Bullet.set_bullet_porperty("Hero")
	$"../../BulletSpawn".add_child(Bullet)
	
		
	

func _on_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("Hero"):
		await Spirte.animation_finished
		FSM.Attacking = false


#func _on_hitbox_body_entered(body: Node2D) -> void:
	#pass
	##if body.is_in_group("Hero"):
		##var HeroPos = body.global_position
		##var SelfPos = FSM.SelfBody.global_position
		##print(FSM.SelfBody.scale.y)
		##if FSM.SelfBody.scale.y*(HeroPos.x-SelfPos.x) > 0:
			##FSM.SelfBody.scale.x = abs(FSM.SelfBody.scale.x)
		##else:
			##FSM.SelfBody.scale.x = -abs(FSM.SelfBody.scale.x)
		##
		##if HeroPos > SelfPos:
			##$"../Move".Direct = 1
		##else:
			##$"../Move".Direct = -1
			##
	#
