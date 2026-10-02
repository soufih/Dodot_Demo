extends Node

func _ready() -> void:
	await get_tree().process_frame
	var pool = get_node("/root/BulletPoolManager")
	var attacker := BaseCharacter.new()
	add_child(attacker)
	var first_data: ElementaryBullet = preload("res://Rescource/Bullet/ElementaryBullet/FireBall.tres")
	var second_data: ElementaryBullet = preload("res://Rescource/Bullet/ElementaryBullet/PurpleWave.tres")
	assert(pool.get_stats().idle == 32)
	var first = pool.spawn(first_data, attacker, Vector2(10, 20), Vector2.RIGHT, 100, "Enemy")
	var id = first.get_instance_id()
	var old_context = first.Ctx
	first._process(0.5)
	assert(first.global_position == Vector2(60, 20))
	pool.recycle(first)
	pool.recycle(first)
	assert(not old_context.Valid)
	await get_tree().process_frame
	assert(pool.get_stats().idle == 32)
	var reused = pool.spawn(second_data, attacker, Vector2.ZERO, Vector2.LEFT, 200, "Hero")
	assert(reused.get_instance_id() == id)
	assert(reused.Ctx.Target == "Hero")
	assert(reused.sprite_frames == second_data.AniTres)
	assert(first_data.target == "" and second_data.target == "")
	# 动画执行中回收，旧协程不得回收下一次发射。
	reused._on_timer_timeout()
	pool.recycle(reused)
	await get_tree().process_frame
	var next = pool.spawn(first_data, attacker, Vector2.ZERO, Vector2.RIGHT)
	await get_tree().process_frame
	assert(next.active)
	pool.recycle_all()
	await get_tree().process_frame
	# 命中目标后等待 Boom 动画，再执行 Exit 回池。
	var target := Node2D.new()
	add_child(target)
	target.add_to_group("Enemy")
	var hit = pool.spawn(first_data, attacker, Vector2.ZERO, Vector2.RIGHT)
	hit._on_area_2d_body_entered(attacker)
	assert(not hit.end_moving)
	hit._on_area_2d_body_entered(target)
	assert(hit.end_moving and hit.active)
	await get_tree().create_timer(0.5).timeout
	assert(pool.get_stats().active == 0)
	# 无动作的弹幕仍应按寿命自动回收。
	var short_lived := ElementaryBullet.new()
	short_lived.Lifecycle = 0.01
	pool.spawn(short_lived, attacker, Vector2.ZERO, Vector2.RIGHT)
	await get_tree().create_timer(0.1).timeout
	assert(pool.get_stats().active == 0)
	# 扩容、空闲上限和场景退出清理。
	pool.max_idle_count = 4
	for i in range(40):
		pool.spawn(first_data, attacker, Vector2.ZERO, Vector2.RIGHT)
	assert(pool.get_stats().active == 40)
	pool._on_scene_exiting(get_tree().current_scene)
	await get_tree().process_frame
	assert(pool.get_stats().active == 0)
	assert(pool.get_stats().idle == 4)
	print("BULLET_POOL_TESTS_PASSED")
	get_tree().quit()
