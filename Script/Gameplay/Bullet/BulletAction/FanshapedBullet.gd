class_name FanshapedBullet
extends BulletAction

## 每次触发生成的弹幕数量；为 0 时不生成。
@export_range(0, 360, 1, "or_greater") var _BulletCount: int = 5
## 扇形总角度（度），以当前弹幕朝向为中心。
@export_range(0.0, 360.0, 0.1) var _FanAngle: float = 60.0

func execute(ctx: BulletContext):
	generate_fanshaped_bullet(ctx)


func generate_fanshaped_bullet(ctx: BulletContext) -> void:
	if ctx == null or not ctx.Valid or _BulletCount <= 0:
		return
	var senior_bullet := ctx.Bullet as SeniorBullet
	if senior_bullet == null:
		return
	if ctx.subBullet.is_empty():
		return
	if not is_instance_valid(ctx.BulletNode) or not ctx.BulletNode.is_inside_tree():
		return
	if not is_instance_valid(ctx.Attacker) or not ctx.Attacker.is_inside_tree():
		return

	var origin: Vector2 = ctx.BulletNode.global_position
	var center_angle: float = ctx.BulletNode.global_rotation
	var fan_angle: float = deg_to_rad(clampf(_FanAngle, 0.0, 360.0))
	var start_angle: float = center_angle
	var angle_step: float = 0.0
	if _BulletCount > 1:
		start_angle -= fan_angle * 0.5
		# 整圆不重复首尾方向；普通扇形包含两侧边界。
		var intervals: int = _BulletCount if is_equal_approx(fan_angle, TAU) else _BulletCount - 1
		angle_step = fan_angle / intervals

	for i in range(_BulletCount):
		if not ctx.Valid:
			return
		# 每次发射从数组首项开始，数量超过数组长度时循环取用。
		var bullet_data: ElementaryBullet = ctx.subBullet[i % ctx.subBullet.size()]
		if bullet_data == null:
			continue
		var direction: Vector2 = Vector2.RIGHT.rotated(start_angle + angle_step * i)
		BulletPoolManager.spawn(bullet_data, ctx.Attacker, origin,
			direction, senior_bullet.Speed, ctx.Target)
