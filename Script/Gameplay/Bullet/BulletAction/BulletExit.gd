class_name BulletExit
extends BulletAction

func execute(ctx: BulletContext):
	exit(ctx)

func exit(ctx: BulletContext):
	if ctx.Valid:
		ctx.BulletNode.release()
