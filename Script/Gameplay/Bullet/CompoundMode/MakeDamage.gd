class_name MakeDamage
extends BulletAction


func execute(ctx: BulletContext):
	make_damage(ctx)


func make_damage(ctx: BulletContext):
	var hitbox := ctx.Hitbox
	var bullet := ctx.Bullet
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group(bullet.target):
			DamageSystem.damage_assess(ctx.Attacker, body, bullet.Porperty)
