class_name Exit
extends BulletAction

func execute(ctx: BulletContext):
	exit(ctx)


func exit(ctx: BulletContext):
	ctx.BulletNode.queue_free()
