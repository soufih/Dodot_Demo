extends Node2D
## 使用正式敌人场景和真实物理重叠，验证攻击、碰壁及状态切换的方向一致性。

const ENEMIES = [preload("res://Scene/Enemy/Enemy1.tscn"),
	preload("res://Scene/Enemy/Enemy2.tscn")]

var assertions := 0
var failures := 0
var stage: Node2D
var enemy: BaseEnemy
var hero: BaseCharacter
var root_transform: Transform2D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	EnemyManager.load_enemy()
	for scene in ENEMIES:
		for direction in [-1, 1]:
			await _test_patrol(scene, direction)
			await _test_chase(scene, direction)
			await _test_attack(scene, direction)
		await _test_trapped(scene)
	await _cleanup()
	print("ENEMY_AI_TEST_RESULT assertions=%d failures=%d" % [assertions, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _spawn(scene: PackedScene) -> void:
	stage = Node2D.new()
	add_child(stage)
	enemy = scene.instantiate() as BaseEnemy
	stage.add_child(enemy)
	# 手动驱动正式状态，让每一步的物理输入及状态转换可重复。
	enemy.get_node("FSM").set_physics_process(false)
	root_transform = enemy.transform
	hero = BaseCharacter.new()
	hero.name = "TestHero"
	hero.MaxHealth = 10000.0
	hero.MaxToughness = 10000.0
	hero.ToughnessRecover = 1.0
	hero.collision_layer = 2
	hero.collision_mask = 0
	hero.position = Vector2(1000, 0)
	hero.add_to_group("Hero")
	var timer := Timer.new()
	hero.add_child(timer)
	hero.RecoverTimer = timer
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	hero.add_child(shape)
	stage.add_child(hero)


func _test_patrol(scene: PackedScene, direction: int) -> void:
	_spawn(scene)
	enemy.set_facing(direction)
	# 左侧使用虚拟边界 Area，右侧使用实体墙，覆盖两类障碍。
	_add_barrier(direction, direction < 0)
	await _settle()
	var move: BaseState = enemy.get_node("FSM/Potrol/Move")
	move.enter()
	_expect(move._has_barrier(direction), "巡逻前检测到前方障碍")
	for frame in range(12):
		await _step(move)
		_expect(enemy.move_dir == -direction and enemy.velocity.x * direction < 0,
			"巡逻反向后持续远离同一面墙")
		_expect_facing(-direction)
	_expect(enemy.position.x * direction < -10.0, "巡逻实际位移离开墙面")
	_expect_root_basis()
	move.exit()
	await _cleanup()


func _test_chase(scene: PackedScene, direction: int) -> void:
	_spawn(scene)
	hero.position = Vector2(direction * 100, 0)
	enemy.set_facing(direction)
	var barrier := _add_barrier(direction)
	await _settle()
	var move: BaseState = enemy.get_node("FSM/Trace/Move")
	move.enter()
	for frame in range(8):
		await _step(move)
		_expect(enemy.move_dir == 0 and is_zero_approx(enemy.velocity.x), "追踪贴墙时停止水平移动")
		_expect_facing(direction)
	barrier.queue_free()
	await _settle()
	await _step(move)
	_expect(enemy.move_dir == direction and enemy.velocity.x * direction > 0,
		"障碍移除后恢复朝目标移动")
	_expect_facing(direction)
	# 玩家穿过敌人后，检查另一侧探测数据和朝向同步生效。
	hero.position = enemy.position + Vector2(-direction * 100, 0)
	await _settle()
	await _step(move)
	_expect(enemy.move_dir == -direction and enemy.velocity.x * direction < 0,
		"玩家换边后移动方向正确")
	_expect_facing(-direction)
	_expect_root_basis()
	move.exit()
	await _cleanup()


func _test_attack(scene: PackedScene, direction: int) -> void:
	_spawn(scene)
	hero.position = Vector2(direction * 40, 0)
	enemy.set_move_direction(direction, 100.0)
	_add_barrier(direction)
	await _settle()
	var manager: BaseEnemyStateManager = enemy.get_node("FSM")
	var trace: BaseState = enemy.get_node("FSM/Trace")
	var attack: BaseState = trace.get_node("Attack")
	var move: BaseState = trace.get_node("Move")
	manager.switch_state(trace)
	_expect(move._has_barrier(direction), "攻击前同侧碰壁条件成立")
	# 正式 Trace 通过真实攻击范围重叠触发攻击，墙面条件同帧存在。
	trace.do(1.0 / 60.0)
	_expect(trace.Current == attack, "目标进入攻击范围且贴墙时优先进入攻击")
	_expect(enemy.move_dir == 0 and is_zero_approx(enemy.velocity.x), "进入攻击立即清除水平移动")
	_expect_facing(direction)
	var target: Vector2 = attack.Target
	var position_before := enemy.position
	hero.position = Vector2(-direction * 100, 0)
	for frame in range(3):
		await _step(trace)
		_expect_facing(direction)
	_expect(enemy.position.is_equal_approx(position_before), "攻击期间碰壁和玩家换边均不引起位移")
	_expect(attack.Target == target, "本次攻击持续瞄准进入攻击时的位置")

	if enemy.has_node("BulletSpawn"):
		var origin: Vector2 = enemy.get_node("BulletSpawn").global_position
		_expect((origin.x - enemy.global_position.x) * direction > 0, "子弹出生点在攻击朝向一侧")
		attack.spawn_bullet()
		var found := false
		for bullet in BulletPoolManager.get_children():
			if bullet.get("active") and bullet.get("Attacker") == enemy:
				found = true
				_expect(bullet.global_position.is_equal_approx(origin), "子弹从同步后的出生点发射")
				_expect(bullet._direction.dot(origin.direction_to(target)) > 0.999,
					"子弹朝锁定的攻击目标发射")
		_expect(found, "远程攻击实际生成子弹")
	else:
		var polygon: CollisionPolygon2D = enemy.get_node("AnimatedSprite2D/Hitbox/CollisionPolygon2D")
		var point: Vector2 = polygon.to_global(polygon.polygon[3])
		_expect((point.x - enemy.global_position.x) * direction > 0, "近战攻击多边形随朝向镜像")

	# 推进正式动画，验证 end_attack 异步回调会解锁并返回移动。
	var animation: AnimationPlayer = enemy.get_node("AnimationPlayer")
	animation.advance(animation.get_animation("Attack").length + 0.1)
	await _settle()
	_expect(trace.Current == move, "攻击动画结束后回到移动状态")
	if enemy.has_node("BulletSpawn"):
		# 远程敌人的整个仇恨范围也是射程，目标仍在范围内时会继续攻击。
		await _step(trace)
		_expect(trace.Current == attack, "远程目标仍在射程内时重新攻击")
		_expect_facing(-direction)
		_expect(enemy.move_dir == 0, "连续远程攻击保持静止")
		hero.position = enemy.position + Vector2(-direction * 400, 0)
		animation.advance(animation.get_animation("Attack").length + 0.1)
		await _settle()
	await _step(trace)
	_expect(enemy.move_dir == -direction and enemy.velocity.x * direction < 0,
		"攻击结束后向另一侧目标恢复移动")
	_expect_facing(-direction)
	_expect_root_basis()

	# 攻击被硬直打断后也必须解锁，不能遗留攻击方向锁。
	trace._check("target_in_range")
	manager._check("breaked")
	_expect(manager.Current == manager.get_node("Break"), "硬直能够打断攻击")
	enemy.set_move_direction(direction, 100.0)
	_expect(enemy.move_dir == direction, "攻击被打断后释放方向锁")
	_expect_facing(direction)
	manager.switch_state(manager.get_node("Potrol"))
	_expect(enemy.move_dir == 0, "切回巡逻待机后清除移动方向")
	await _cleanup()


func _test_trapped(scene: PackedScene) -> void:
	_spawn(scene)
	_add_barrier(1)
	_add_barrier(-1, true)
	await _settle()
	var move: BaseState = enemy.get_node("FSM/Potrol/Move")
	move.enter()
	for frame in range(4):
		await _step(move)
		_expect(enemy.move_dir == 0 and is_zero_approx(enemy.velocity.x), "两侧受阻时停止移动")
		_expect_facing(1)
	_expect_root_basis()
	move.exit()
	await _cleanup()


func _add_barrier(direction: int, area: bool = false) -> CollisionObject2D:
	var barrier: CollisionObject2D = Area2D.new() if area else StaticBody2D.new()
	barrier.position = Vector2(direction * 30, 0)
	barrier.collision_layer = 8 if area else 1
	barrier.collision_mask = 16 if area else 2
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 1000)
	shape.shape = rectangle
	barrier.add_child(shape)
	stage.add_child(barrier)
	return barrier


func _step(state: BaseState) -> void:
	await get_tree().physics_frame
	state.do(1.0 / 60.0)
	await get_tree().process_frame


func _settle() -> void:
	for frame in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame


func _cleanup() -> void:
	BulletPoolManager.recycle_all()
	if is_instance_valid(stage):
		stage.queue_free()
	await _settle()


func _expect_facing(direction: int) -> void:
	_expect(enemy.facing_dir == direction and enemy.facing_sprite.flip_h == (direction < 0),
		"精灵朝向与逻辑方向一致")


func _expect_root_basis() -> void:
	_expect(enemy.transform.x.is_equal_approx(root_transform.x)
		and enemy.transform.y.is_equal_approx(root_transform.y), "转向不改变角色根节点缩放和旋转")


func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: %s / %s" % [enemy.name, label])
