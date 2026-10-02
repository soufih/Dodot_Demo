class_name BulletAwait
extends BulletAction

## 等待时间（秒）；为 0 时立即执行后续动作。
@export_range(0.0, 60.0, 0.01, "or_greater") var _WaitTime: float = 1.0

func execute(ctx: BulletContext) -> void:
	await bullet_awit(ctx)


func bullet_awit(ctx: BulletContext) -> void:
	if ctx == null or not ctx.Valid or _WaitTime <= 0.0:
		return
	if not is_instance_valid(ctx.BulletNode) or not ctx.BulletNode.is_inside_tree():
		return
	# 每次执行独立计时，避免共享动作资源的弹幕互相影响。
	# 随游戏暂停及时间缩放；超时后由动作执行器检查 ctx.Valid。
	var timer: SceneTreeTimer = ctx.BulletNode.get_tree().create_timer(_WaitTime, false)
	await timer.timeout
