class_name PlayAni
extends BulletAction

@export var AniName: String

func execute(ctx: BulletContext):
	await play_moving_ani(ctx)

func play_moving_ani(ctx: BulletContext):
	if not ctx.Valid or not ctx.Ani.has_animation(AniName):
		return
	ctx.Ani.play(AniName)
	# 逐帧检查上下文，回收会使其失效，不留下等待已停止动画的协程。
	while ctx.Valid and ctx.Ani.is_playing():
		await ctx.BulletNode.get_tree().process_frame
