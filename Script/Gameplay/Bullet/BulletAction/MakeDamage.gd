class_name BulletMakeDamage
extends BulletAction

func execute(ctx: BulletContext):
	make_damage(ctx)

func make_damage(ctx: BulletContext):
	if not ctx.Valid or ctx.Bullet.Porperty == null:
		return
	var bodies: Array[Node2D] = ctx.Hitbox.get_overlapping_bodies()
	if is_instance_valid(ctx.HitBody) and not bodies.has(ctx.HitBody):
		bodies.append(ctx.HitBody)
	for body in bodies:
		if body is BaseCharacter and body != ctx.Attacker and body.is_in_group(ctx.Target):
			var source: BaseCharacter = ctx.Attacker if is_instance_valid(ctx.Attacker) else null
			DamageSystem.damage_assess(source, body, ctx.Bullet.Porperty)
