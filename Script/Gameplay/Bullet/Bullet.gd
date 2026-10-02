extends AnimatedSprite2D

@export var Ani: AnimationPlayer
@export var HitBox: Area2D
var Speed: float = 0.0
var Attacker: BaseCharacter
var Bullet: ElementaryBullet
var Ctx: BulletContext
var end_moving: bool = true
var active: bool = false
var _direction: Vector2
var _moving_actions_running: bool = false
@onready var _lifecycle: Timer = $Lifecycle
@onready var _shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	deactivate()


func activate(data: ElementaryBullet, attacker: BaseCharacter, origin: Vector2,
		direction: Vector2, speed: float, target: String) -> void:
	Bullet = data
	Attacker = attacker
	Speed = speed
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	global_position = origin
	global_rotation = _direction.angle()
	scale = Vector2.ONE
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	flip_h = false
	flip_v = false
	speed_scale = 1.0
	sprite_frames = data.AniTres
	# 命中动作可能在物理查询回调中生成弹幕，替换形状也必须延迟。
	# 此调用先入队，确保随后启用碰撞前已经应用新形状。
	_shape.set_deferred("shape", data.CollisionShape)
	
	var SubBullets:Array[ElementaryBullet] = []
	if data.get("Subbullets"):
		SubBullets = data.get("Subbullets")
	Ctx = BulletContext.new(self, data, SubBullets,Ani, HitBox, attacker)
	Ctx.Target = target
	
	active = true
	end_moving = false
	_moving_actions_running = false
	show()
	set_process(true)
	HitBox.set_deferred("monitoring", true)
	HitBox.set_deferred("monitorable", true)
	_shape.set_deferred("disabled", false)
	if sprite_frames != null and sprite_frames.has_animation("Move"):
		play("Move")
	_lifecycle.start(maxf(data.Lifecycle, 0.001))
	_run_actions(data.Spawned, Ctx)

func deactivate() -> void:
	active = false
	end_moving = true
	if Ctx != null:
		Ctx.Valid = false
	_lifecycle.stop()
	Ani.stop()
	stop()
	frame = 0
	hide()
	set_process(false)
	HitBox.set_deferred("monitoring", false)
	HitBox.set_deferred("monitorable", false)
	_shape.set_deferred("disabled", true)
	Ctx = null
	Bullet = null
	Attacker = null
	Speed = 0.0


func release() -> void:
	BulletPoolManager.recycle(self)


func _process(delta: float) -> void:
	if not active or end_moving:
		return
	global_position += _direction * Speed * delta
	if not _moving_actions_running:
		_moving_actions_running = true
		var context := Ctx
		await _run_actions(Bullet.Moving, context)
		if context.Valid:
			_moving_actions_running = false


func _run_actions(actions: Array[BulletAction], context: BulletContext) -> void:
	for action in actions:
		if not context.Valid:
			return
		if action != null:
			await action.execute(context)


func _finish(actions: Array[BulletAction]) -> void:
	if not active or end_moving:
		return
	end_moving = true
	_lifecycle.stop()
	var context := Ctx
	await _run_actions(actions, context)
	if context.Valid:
		release()


func _on_timer_timeout() -> void:
	if active:
		_finish(Bullet.Death)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not active or end_moving or body == Attacker or not body.is_in_group(Ctx.Target):
		return
	Ctx.HitBody = body
	_finish(Bullet.Hit)
