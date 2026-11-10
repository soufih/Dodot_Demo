extends Node2D
## 使用真实物理重叠、正式玩家与敌人验证即死区域和各自死亡流程的接入。

const ZONE = preload("res://Scene/Map/MapComponent/DeathZone.tscn")
const HERO = preload("res://Scene/Hero/Hero.tscn")
const ENEMIES = [preload("res://Scene/Enemy/Enemy1.tscn"),
	preload("res://Scene/Enemy/Enemy2.tscn")]

var assertions := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	UIManager.configure_scene(self, [UIId.DEATH])
	await _test_detection()
	for scene in ENEMIES:
		for active in [false, true]:
			await _test_enemy_death(scene, active)
	await _test_player_death(false)
	await _test_player_death(true)
	print("DEATH_ZONE_TEST_RESULT assertions=%d failures=%d" % [assertions, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _test_detection() -> void:
	var stage := Node2D.new()
	add_child(stage)
	var zone := ZONE.instantiate() as Area2D
	var other_zone := ZONE.instantiate() as Area2D
	stage.add_child(zone)
	other_zone.position = Vector2(1000, 0)
	stage.add_child(other_zone)
	_expect(zone.get_node("CollisionShape2D").shape != other_zone.get_node("CollisionShape2D").shape,
		"不同区域的碰撞形状可以独立调整")
	var enemy := _body(stage, false)
	var scenery := CharacterBody2D.new()
	scenery.collision_layer = 2
	scenery.collision_mask = 0
	_add_shape(scenery)
	stage.add_child(scenery)
	await _settle()
	_expect(zone.overlaps_body(enemy) and zone.overlaps_body(scenery), "角色和普通物体实际进入区域")
	_expect(enemy.CurrentHealth == 0.0, "即死区域同样影响非玩家角色")
	var player := _body(stage, true)
	var counts := {"death": 0, "health": 0}
	player.death.connect(func(): counts.death += 1)
	player.health_changed.connect(func(): counts.health += 1)
	await _settle()
	_expect(player.CurrentHealth == 0.0, "出生在区域内的玩家也会死亡")
	_expect(counts.death == 1 and counts.health > 0, "通过生命值接口通知死亡和血条更新")
	player.position = Vector2(300, 0)
	await _settle()
	player.position = Vector2.ZERO
	await _settle()
	_expect(counts.death == 1, "已死亡玩家再次进入不重复发出死亡信号")
	stage.queue_free()
	await _settle()


func _test_enemy_death(scene: PackedScene, active: bool) -> void:
	var stage := Node2D.new()
	add_child(stage)
	stage.add_child(ZONE.instantiate())
	stage.add_child(ZONE.instantiate())
	var enemy := scene.instantiate() as BaseEnemy
	enemy.position = Vector2(300, 0)
	stage.add_child(enemy)
	enemy.Atived = active
	enemy.get_node("FSM").set_physics_process(false)
	enemy.DamageResist = [1.0, 1.0, 1.0, 1.0, 1.0]
	# 固定正式掉落组件的清单，检查死亡完成后仍会产出物品。
	var item := droppedItemConfig.new()
	item.id = 24
	item.range_x = 1
	item.range_y = 1
	item.possbility = 100.0
	enemy.drop_component.items = [item]
	var counts := {"death": 0, "defeated": 0}
	enemy.death.connect(func(): counts.death += 1)
	var on_defeated := func(target: BaseEnemy):
		if target == enemy:
			counts.defeated += 1
	SignalBus.enemy_defeated.connect(on_defeated)
	await _settle()
	_expect(enemy.CurrentHealth == enemy.MaxHealth, "区域外的正式敌人保持存活")
	enemy.position = Vector2.ZERO
	await _settle()
	_expect(enemy.CurrentHealth == 0.0, "已激活或休眠的正式敌人进入后直接归零")
	_expect(enemy.get_node("FSM").Current == enemy.get_node("FSM/Death"), "敌人进入正式 Death 状态")
	_expect(counts.death == 1 and counts.defeated == 1, "重叠区域仅触发一次敌人死亡和击败通知")
	for frame in range(180):
		if not is_instance_valid(enemy):
			break
		await get_tree().process_frame
	_expect(not is_instance_valid(enemy), "正式敌人完成死亡动画后被移除")
	var drops: Array[DroppedItem] = []
	for child in get_children():
		if child is DroppedItem:
			drops.append(child)
	_expect(drops.size() == 1, "敌人死亡后沿用正式掉落流程且只掉落一次")
	if not drops.is_empty():
		_expect(drops[0].items == [{"id": 24, "amount": 1}], "敌人死亡保留配置的掉落清单")
	for drop in drops:
		drop.queue_free()
	SignalBus.enemy_defeated.disconnect(on_defeated)
	stage.queue_free()
	await _settle()


func _test_player_death(invulnerable: bool) -> void:
	var stage := Node2D.new()
	add_child(stage)
	var zone := ZONE.instantiate() as Area2D
	stage.add_child(zone)
	# 重叠区域不应导致同一角色重复死亡。
	stage.add_child(ZONE.instantiate())
	var hero := HERO.instantiate() as HeroProperty
	hero.position = Vector2(300, 0)
	stage.add_child(hero)
	# 保留正式状态切换与动画，仅固定移动以控制进入位置。
	hero.set_physics_process(false)
	hero.get_node("State").set_physics_process(false)
	hero.DamageResist.assign([1.0, 1.0, 1.0, 1.0, 1.0])
	var counts := {"death": 0, "result": 0}
	hero.death.connect(func(): counts.death += 1)
	var on_result := func(): counts.result += 1
	SignalBus.player_death.connect(on_result)
	await _settle()
	_expect(hero.CurrentHealth == hero.MaxHealth, "区域外的正式玩家保持存活")
	if invulnerable:
		hero.god_mode.emit()
		_expect(hero.collision_layer == 64, "正式无敌逻辑将玩家切换至无敌层")
	hero.position = Vector2.ZERO
	await _settle()
	_expect(hero.CurrentHealth == 0.0, "正式玩家进入后直接归零，不受无敌或抗性影响")
	_expect(hero.get_node("State").Current == hero.get_node("State/Death"), "进入正式 Death 状态")
	_expect(counts.death == 1, "多个重叠区域只触发一次死亡")
	# 等待真实死亡动画结束及死亡界面打开，驱动在世界暂停后继续运行。
	for frame in range(180):
		if counts.result > 0:
			break
		await get_tree().process_frame
	_expect(counts.result == 1, "死亡动画完成后发布一次全局死亡通知")
	_expect(UIManager.is_open(UIId.DEATH), "沿用正式死亡界面")
	SignalBus.player_death.disconnect(on_result)
	UIManager.ui_close_all()
	stage.queue_free()
	await _settle()


func _body(parent: Node, player: bool) -> BaseCharacter:
	var body := BaseCharacter.new()
	body.MaxHealth = 100.0
	body.collision_layer = 2
	body.collision_mask = 0
	if player:
		body.add_to_group("Hero")
	_add_shape(body)
	parent.add_child(body)
	return body


func _add_shape(body: CharacterBody2D) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 16)
	shape.shape = rectangle
	body.add_child(shape)


func _settle() -> void:
	for frame in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
