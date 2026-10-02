class_name Loop
extends BulletAction

@export var times: int
@export var Subactions:Array[BulletAction]



func execute(ctx: BulletContext):
	loop(ctx)


func loop(ctx: BulletContext):
	for i in range(0, times):
		for action in  Subactions:
			if not ctx.Valid:
				return
			if action != null:
				await action.execute(ctx)
	
