extends AnimatedSprite2D


@export var Ani: AnimationPlayer
@export var HitBox: Area2D

var Speed: int
var Attacker: BaseCharacter
var Bullet: SeniorBullet
var Ctx: BulletContext
var end_moving: bool = true


func setup(attacker: BaseCharacter, speed: int):
	Attacker = attacker
	Speed = speed

#生成时触发
func _ready() -> void:
	Ctx = BulletContext.new(
		self,
		Bullet,
		Ani,
		HitBox,
		Attacker
	)
	for action:BulletAction in Bullet.Spawned:
		action.execute(Ctx)
	end_moving = false

#移动过程中触发
func _process(delta: float) -> void:
	if end_moving:
		return

	for action:BulletAction in Bullet.Moving:
		action.execute(Ctx)

#生存周期结束后触发
func _on_timer_timeout() -> void:
	end_moving = true
	for action:BulletAction in Bullet.Death:
		action.execute(Ctx)

#命中时触发
func _on_area_2d_body_entered(body: Node2D) -> void:
	end_moving = true
	for action:BulletAction in Bullet.Hit:
		action.execute(Ctx)
