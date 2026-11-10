extends Node2D
## 正式伤害、死亡状态、拾取与结算界面的集成回归。

const STATISTICS = preload("res://Script/Gameplay/Map/LevelStatistics.gd")
const ENEMY = preload("res://Scene/Enemy/Enemy1.tscn")
const DROP = preload("res://Scene/DroppedItem/DroppedItem.tscn")
const LEVEL = preload("res://Scene/Map/Level/LevelScene.tscn")

var assertions := 0
var failures := 0
var generator: LevelGenerator
var statistics: Node
var hero: BaseCharacter
var inventory: PlayerInventoryComponent


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	UIManager.configure_scene(self, [UIId.PAUSE, UIId.END, UIId.DEATH])
	get_window().content_scale_size = Vector2i(1152, 648)
	get_window().size = Vector2i(1152, 648)
	_setup()
	_test_combat()
	_test_pickup()
	_test_isolation()
	await _test_timing_and_settlement()
	_test_reset()
	UIManager.ui_close_all()
	var container_id := inventory.definition.container_id
	generator.queue_free()
	statistics.queue_free()
	await get_tree().process_frame
	InventoryManager.unregister_container(container_id)
	await _test_scene_binding()
	print("LEVEL_STATISTICS_TEST_RESULT assertions=%d failures=%d" % [assertions, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _setup() -> void:
	generator = LevelGenerator.new()
	generator.auto_generate = false
	generator.generation_succeeded = true
	add_child(generator)
	statistics = STATISTICS.new()
	statistics.generator = generator
	add_child(statistics)
	statistics.set_process(false)
	hero = BaseCharacter.new()
	hero.MaxHealth = 100.0
	hero.add_to_group("Hero")
	generator.add_child(hero)
	inventory = PlayerInventoryComponent.new()
	inventory.definition = load("res://tests/inventory/gameplay_definition.tres").duplicate()
	inventory.definition.container_id = "statistics_spec_backpack"
	var footprint: Vector2i = ResourceManager.get_item_config(21).GridSize
	inventory.definition.size = Vector2i(footprint.x * 2, footprint.y)
	hero.add_child(inventory)
	_expect(inventory.initialization_result.is_ok(), "统计测试使用正式背包组件")


func _enemy(boss: bool = false) -> BaseEnemy:
	var enemy: BaseEnemy = ENEMY.instantiate()
	var spawn := Node2D.new()
	generator.add_child(spawn)
	spawn.add_child(enemy)
	enemy.get_node("FSM").set_physics_process(false)
	if boss:
		enemy.Porperty = enemy.Porperty.duplicate(true)
		enemy.Porperty.EnemyLevel = ENUM.EnemyLevel.Boss
	return enemy


func _attack(amount: float) -> DamagePorperty:
	var attack := DamagePorperty.new()
	attack.Damage = amount
	attack.CriticalHit = -1.0
	return attack


func _test_combat() -> void:
	var normal := _enemy()
	normal.CurrentHealth = 30.0
	normal.DamageResist = []
	DamageSystem.apply_damage(hero, normal, _attack(100.0))
	_expect(statistics.get_statistics().damage_dealt == 30.0, "过量伤害只统计实际扣血")
	_expect(statistics.get_statistics().enemies_defeated == 1, "正式敌人死亡状态发布击败事件")
	SignalBus.enemy_defeated.emit(normal)
	DamageSystem.apply_damage(hero, normal, _attack(100.0))
	_expect(statistics.get_statistics().damage_dealt == 30.0
		and statistics.get_statistics().enemies_defeated == 1, "重复死亡与攻击遗体不重复统计")
	var boss := _enemy(true)
	boss.CurrentHealth = 20.0
	boss.DamageResist = []
	DamageSystem.apply_damage(hero, boss, _attack(20.0))
	_expect(statistics.get_statistics().enemies_defeated == 2
		and statistics.get_statistics().bosses_defeated == 1, "首领包含在击败总数并单独统计")
	DamageSystem.apply_damage(boss, hero, _attack(12.0))
	DamageSystem.apply_damage(null, hero, _attack(7.0))
	DamageSystem.apply_damage(null, hero, _attack(-5.0))
	_expect(statistics.get_statistics().damage_taken == 19.0, "承伤包含环境伤害且排除治疗")


func _test_pickup() -> void:
	var dropped: DroppedItem = DROP.instantiate()
	dropped.configure([{"id": 21, "amount": 250}])
	add_child(dropped)
	dropped.freeze = true
	var pickup: PickupInteractable = dropped.get_node("Pickup")
	pickup.interact(hero)
	_expect(statistics.get_statistics().items_collected == {21: 200}, "部分拾取只累计实际入包数量")
	pickup.interact(hero)
	_expect(statistics.get_statistics().items_collected == {21: 200}, "背包已满时重试不增加统计")
	InventoryManager.remove_from_container(inventory.definition.container_id, Vector2i.ZERO)
	pickup.interact(hero)
	_expect(statistics.get_statistics().items_collected == {21: 250}, "腾空后只追加剩余成功拾取数量")
	var snapshot: Dictionary = statistics.get_statistics()
	snapshot.items_collected.clear()
	_expect(statistics.get_statistics().items_collected == {21: 250}, "外部修改快照不影响关卡数据")


func _test_isolation() -> void:
	var foreign := BaseCharacter.new()
	foreign.MaxHealth = 100.0
	foreign.add_to_group("Hero")
	add_child(foreign)
	var enemy := _enemy()
	var before: Dictionary = statistics.get_statistics()
	SignalBus.item_picked_up.emit(foreign, 21, 99)
	SignalBus.character_damaged.emit(foreign, enemy, 99.0)
	SignalBus.character_damaged.emit(null, foreign, 99.0)
	SignalBus.item_picked_up.emit(hero, 21, 0)
	_expect(statistics.get_statistics() == before, "不采集其他场景角色或无效数量的事件")
	foreign.queue_free()


func _test_timing_and_settlement() -> void:
	statistics.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(statistics.get_statistics().elapsed_seconds > 0.0, "关卡运行时累计耗时")
	UIManager.open(UIId.PAUSE)
	var before_pause: float = statistics.get_statistics().elapsed_seconds
	for frame in range(3):
		await get_tree().process_frame
	_expect(statistics.get_statistics().elapsed_seconds == before_pause, "打开暂停菜单后不计时")
	UIManager.close(UIId.PAUSE)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(statistics.get_statistics().elapsed_seconds > before_pause, "关闭暂停菜单后继续计时")
	statistics.set_process(false)
	statistics._process(125.0)
	UIManager.show_end_screen()
	var end_ui = UIManager.get_ui(UIId.END)
	_expect(end_ui != null and get_tree().paused, "正式结算界面打开并暂停")
	if end_ui == null:
		return
	_expect(end_ui.statistics_label.text.contains("击败敌人：2")
		and end_ui.statistics_label.text.contains("首领：1")
		and end_ui.statistics_label.text.contains("造成伤害：50.0")
		and end_ui.statistics_label.text.contains("承受伤害：19.0"), "结算展示真实战斗数据")
	_expect(end_ui.statistics_label.text.contains("通关耗时：02:05"), "通关耗时按分秒呈现")
	_expect(end_ui.materials_content.get_child_count() == 1
		and end_ui.materials_content.get_child(0).get_child(2).text == "× 250", "战利品按配置展示累计数量")
	var before_finish: Dictionary = statistics.get_statistics()
	statistics._process(10.0)
	SignalBus.item_picked_up.emit(hero, 21, 99)
	SignalBus.character_damaged.emit(null, hero, 99.0)
	SignalBus.enemy_defeated.emit(_enemy())
	_expect(statistics.get_statistics() == before_finish, "结算后停止计时及采集全部事件")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			for frame in range(4):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	UIManager.close(UIId.END)
	statistics._process(10.0)
	_expect(statistics.get_statistics() == before_finish, "关闭结算页也不会恢复已结束的统计")


func _test_reset() -> void:
	generator.level_generated.emit()
	var fresh: Dictionary = statistics.get_statistics()
	_expect(fresh.enemies_defeated == 0 and fresh.bosses_defeated == 0
		and fresh.damage_dealt == 0.0 and fresh.damage_taken == 0.0
		and fresh.elapsed_seconds == 0.0 and fresh.items_collected.is_empty(), "重新生成关卡清空所有统计")
	SignalBus.item_picked_up.emit(hero, 21, 3)
	_expect(statistics.get_statistics().items_collected == {21: 3}, "新一轮生成重新开始采集")
	generator.level_clearing.emit()
	SignalBus.item_picked_up.emit(hero, 21, 5)
	_expect(statistics.get_statistics().items_collected.is_empty(), "清理关卡期间停止采集")
	generator.level_generated.emit()
	SignalBus.player_death.emit()
	statistics._process(10.0)
	SignalBus.item_picked_up.emit(hero, 21, 5)
	_expect(statistics.get_statistics().elapsed_seconds == 0.0
		and statistics.get_statistics().items_collected.is_empty(), "死亡后停止采集")
	UIManager.close(UIId.DEATH)
	generator.level_generated.emit()
	UIManager.show_end_screen()
	var end_ui = UIManager.get_ui(UIId.END)
	_expect(end_ui != null and end_ui.materials_content.get_child(0).text == "本关未拾取战利品",
		"空战利品显示明确提示")


func _test_scene_binding() -> void:
	var level := LEVEL.instantiate()
	level.get_node("LevelGenerator").auto_generate = false
	add_child(level)
	var tracker = level.get_node("LevelStatistics")
	_expect(tracker.generator == level.get_node("LevelGenerator"), "正式关卡场景绑定统计组件和生成器")
	level.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("LEVEL_STATISTICS: " + label)
