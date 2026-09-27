class_name PlayAni
extends BulletAction

@export var AniName:String


func execute(ctx: BulletContext):
	play_moving_ani(ctx)


func play_moving_ani(ctx: BulletContext):
	if !ctx.Ani.has_animation(AniName):
		return
	ctx.Ani.play("AniName")

	await ctx.Ani.animation_finished
