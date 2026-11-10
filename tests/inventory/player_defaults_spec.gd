extends Node
## 验证正式初始资源、主菜单入口、装备消费者及仓库演示材料的合成流程。

const BAG = preload("res://Rescource/Data/Inventory/player_backpack.tres")
const GEAR = preload("res://Rescource/Data/Inventory/player_equipment.tres")
const WAREHOUSE = preload("res://Rescource/Data/Inventory/home_warehouse.tres")
const InitialItem = preload("res://Script/Config/Model/ResourceManager/InventoryInitialItem.gd")
const HOME := "res://Scene/Map/Home/Home.tscn"
const MATERIAL_IDS := [20, 21, 22, 23, 24, 26, 28, 29, 210, 211]
var checks = preload("res://tests/inventory/spec_context.gd").new()
var hero: HeroProperty

## 等待全局管理器就绪，再启动跨场景测试。
func _ready() -> void:
	_run.call_deferred()

## 直接运行家园、主菜单进入、合成及清空后重载均使用正式会话。
func _run() -> void:
	reparent(get_tree().root)
	_test_failed_initialization()
	checks.equal(get_tree().change_scene_to_file(HOME), OK, "直接运行家园")
	await _wait_for_hero()
	_check_defaults()
	await _start_from_menu()
	_check_defaults()
	var bag_before: Dictionary = checks.value(InventoryManager.get_snapshot(BAG.container_id))
	var gear_before: Dictionary = checks.value(InventoryManager.get_snapshot(GEAR.container_id))
	var warehouse_before: Dictionary = checks.value(InventoryManager.get_snapshot(WAREHOUSE.container_id))
	checks.code(PlayerInventorySession.ensure(BAG, InventoryManager), InventoryResult.Code.OK, "再次绑定背包成功")
	checks.code(PlayerInventorySession.ensure(GEAR, InventoryManager), InventoryResult.Code.OK, "再次绑定装备成功")
	checks.code(PlayerInventorySession.ensure(WAREHOUSE, InventoryManager), InventoryResult.Code.OK, "再次绑定仓库成功")
	checks.equal(checks.value(InventoryManager.get_snapshot(BAG.container_id)), bag_before, "重复绑定背包不改变状态")
	checks.equal(checks.value(InventoryManager.get_snapshot(GEAR.container_id)), gear_before, "重复绑定不重复装备武器")
	checks.equal(checks.value(InventoryManager.get_snapshot(WAREHOUSE.container_id)), warehouse_before, "重复绑定仓库不增加材料或改变实例版本")
	var equipment: PlayerEquipmentComponent = hero.get_node("Equipment")
	checks.code(equipment.switch_weapon(), InventoryResult.Code.OK, "默认副武器可以切换")
	checks.equal(equipment.get_current_weapon(), 11, "切换后使用武器 11")
	_check_weapon_consumer(11)
	checks.code(equipment.start_new(), InventoryResult.Code.OK, "角色显式重置装备")
	checks.equal(equipment.get_current_weapon(), 10, "显式重置重新选择主武器 10")
	_test_crafting_materials()
	var stored_before: Dictionary = checks.value(InventoryManager.get_snapshot(WAREHOUSE.container_id))
	gear_before = checks.value(InventoryManager.get_snapshot(GEAR.container_id))
	checks.equal(get_tree().reload_current_scene(), OK, "重载正式家园")
	await _wait_for_hero()
	checks.expect(InventoryManager.get_snapshot(BAG.container_id).items.is_empty(), "背包始终不发放演示材料")
	checks.equal(checks.value(InventoryManager.get_snapshot(GEAR.container_id)), gear_before, "切场景保留装备实例与版本")
	checks.equal(checks.value(InventoryManager.get_snapshot(WAREHOUSE.container_id)), stored_before, "切场景保留合成后的库存")
	for record: Dictionary in InventoryManager.get_snapshot(WAREHOUSE.container_id).items.values():
		InventoryManager.remove_from_container(WAREHOUSE.container_id, record.anchor)
	stored_before = checks.value(InventoryManager.get_snapshot(WAREHOUSE.container_id))
	checks.equal(get_tree().reload_current_scene(), OK, "清空仓库后重载家园")
	await _wait_for_hero()
	checks.equal(checks.value(InventoryManager.get_snapshot(WAREHOUSE.container_id)), stored_before, "已清空的仓库重载后也不补发材料")
	await _start_from_menu()
	_check_defaults()
	print("PLAYER_DEFAULTS_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 初始化中途失败时不留下半成品容器，允许修正资源后重新初始化。
func _test_failed_initialization() -> void:
	var manager: Node = $FixtureManager
	var definition := InventoryDefinition.new()
	definition.container_id = "invalid_initial_items"
	definition.size = Vector2i(10, 12)
	var first := InitialItem.new()
	first.config_id = 20
	var invalid := InitialItem.new()
	invalid.config_id = 22
	invalid.quantity = 0
	definition.initial_items.assign([first, invalid])
	checks.expect(not PlayerInventorySession.ensure(definition, manager).is_ok(), "第二项数量非法时初始化失败")
	checks.expect(not manager.has_container(definition.container_id), "初始化失败注销已放入第一项的容器")
	definition.initial_items.assign([first])
	checks.code(PlayerInventorySession.ensure(definition, manager), InventoryResult.Code.OK, "修正配置后可以重新创建")
	checks.equal(manager.get_snapshot(definition.container_id).items.size(), 1, "修正后只发放一次物品")
	var equipment: InventoryDefinition = GEAR.duplicate(true)
	equipment.container_id = "invalid_initial_slot"
	equipment.initial_items[1].slot_id = &"missing_slot"
	checks.expect(not PlayerInventorySession.ensure(equipment, manager).is_ok(), "不存在的初始装备槽位明确失败")
	checks.expect(not manager.has_container(equipment.container_id), "装备初始化失败不残留主武器")

## 触发真实开始按钮并通过加载屏进入家园，覆盖菜单预建容器和 Hero 复用顺序。
func _start_from_menu() -> void:
	checks.equal(get_tree().change_scene_to_file("res://Scene/Map/MainScene/MainScene.tscn"), OK, "加载正式主菜单")
	for frame in range(4):
		await get_tree().process_frame
	get_tree().current_scene.get_node("CanvasLayer/Mainmenu/ButtonContainer/gamestart").pressed.emit()
	var loading: LoadingScreenUI = UIManager.get_ui(UIId.LOADING)
	for frame in range(300):
		if loading._ready_to_continue or loading._failed:
			break
		await get_tree().physics_frame
		await get_tree().process_frame
	checks.expect(loading._ready_to_continue and not loading._failed, "家园加载完成")
	await _key(KEY_SPACE)
	await _wait_for_hero()
	checks.equal(get_tree().current_scene.scene_file_path, HOME, "主菜单进入正式家园")

## 等待出生和物理初始化完成，取得当前场景实际生成的 Hero。
func _wait_for_hero() -> void:
	for frame in range(90):
		await get_tree().physics_frame
		await get_tree().process_frame
	hero = get_tree().current_scene.hero

## 固定演示预期独立于待测资源，避免资源误改后测试随之通过。
func _check_defaults() -> void:
	var expected := {}
	for id in MATERIAL_IDS:
		expected[id] = 20
	checks.expect(InventoryManager.get_snapshot(BAG.container_id).items.is_empty(), "新游戏背包为空")
	checks.equal(WarehouseManager.get_item_counts(WAREHOUSE.container_id).payload, expected, "仓库包含十种配方材料各 20 个")
	checks.equal(InventoryManager.get_snapshot(WAREHOUSE.container_id).items.size(), 10, "十种仓库材料各占一栈")
	checks.equal(InventoryManager.get_snapshot(GEAR.container_id).items.size(), 2, "装备栏恰好有两件初始武器")
	for pair in [[&"main_hand", 10], [&"off_hand", 11]]:
		var position: Vector2i = InventoryManager.get_slot_position(GEAR.container_id, pair[0]).payload
		checks.equal(InventoryManager.get_item_at(GEAR.container_id, position).instance.config_id, pair[1], "默认武器放入命名槽 " + str(pair[0]))
	var equipment: PlayerEquipmentComponent = hero.get_node("Equipment")
	checks.equal(equipment.get_current_weapon(), 10, "新游戏当前武器为 10")
	checks.equal(equipment.get_next_weapon(), 11, "新游戏备用武器为 11")
	checks.expect(hero._InputController.equipment == equipment, "攻击输入绑定真实装备组件")
	_check_weapon_consumer(10)
	checks.equal(WarehouseManager.get_total_item_count(WAREHOUSE.container_id).payload, 200, "新游戏仓库共有 200 份演示材料")

## 武器属性与 HUD 都应随默认装备和武器切换同步。
func _check_weapon_consumer(id: int) -> void:
	checks.equal(hero.get_node("WeaponController").Weapon, WeaponManager.get_weapon_porperty(ResourceManager.get_item_name(id)), "攻击控制器使用当前武器属性")
	checks.equal(hero.get_node("PlayerUI/weapon_state_ui").current_item.texture, ResourceManager.get_item_icon(id), "HUD 显示当前武器图标")

## 直接使用仓库初始材料逐个预览和执行正式配方，按配方验证数量守恒。
func _test_crafting_materials() -> void:
	var expected: Dictionary = WarehouseManager.get_item_counts(WAREHOUSE.container_id).payload
	var recipes: Array[CraftingRecipe] = CraftingManager.list_recipes()
	checks.equal(recipes.size(), 5, "覆盖当前五份正式配方")
	for recipe in recipes:
		var preview: InventoryResult = CraftingManager.preview(WAREHOUSE.container_id, recipe.recipe_id)
		checks.code(preview, InventoryResult.Code.OK, "预览配方 " + str(recipe.recipe_id))
		checks.expect(preview.is_ok() and preview.payload.can_craft, "演示材料足够合成 " + str(recipe.recipe_id))
		checks.code(CraftingManager.craft(WAREHOUSE.container_id, recipe.recipe_id), InventoryResult.Code.OK, "执行配方 " + str(recipe.recipe_id))
		for id: int in recipe.inputs:
			expected[id] -= recipe.inputs[id]
		for id: int in recipe.outputs:
			expected[id] = expected.get(id, 0) + recipe.outputs[id]
	checks.equal(WarehouseManager.get_item_counts(WAREHOUSE.container_id).payload, expected, "全部配方执行后的材料消耗和产物数量正确")
	for id in [10, 11, 12]:
		checks.equal(WarehouseManager.get_item_count(WAREHOUSE.container_id, id).payload, 1, "仓库生成演示武器 " + str(id))

## 发送完整按下释放事件，通过加载屏的实际输入处理继续游戏。
func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
