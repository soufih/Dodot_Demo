extends Node

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)


func _ready() -> void:
	await get_tree().process_frame
	UIManager.tmp_slot.set_process(false)
	var home := SceneLoading.get_scene(SceneLoading.HOME_SCENE_PATH).instantiate()
	get_tree().root.add_child(home)
	get_tree().current_scene = home
	await get_tree().process_frame
	var hero: HeroProperty = DataLoader.get_hero()
	hero._InputController.ban_input(false)
	var warehouse_before := WarehouseSystem.get_warehouse().duplicate(true)
	BackpackSystem.quick_add_item(21, 130)
	BackpackSystem.quick_add_item(22, 3)
	var weapon_slots := EquipmentSlotSystem.get_weapon_slot()
	var relic_slots := EquipmentSlotSystem.get_relic_slot()
	EquipmentSlotSystem.interact_with_equipment_slot(10, 1, 1, weapon_slots)
	EquipmentSlotSystem.interact_with_equipment_slot(11, 1, 2, weapon_slots)
	EquipmentSlotSystem.switch_current_weapon(2)
	# 当前配置表还没有遗物；补一个仅在测试进程中使用的配置。
	var relic := ItemConfig.new()
	relic.ItemID = 9901
	relic.ItemName = "TestRelic"
	relic.MainItemType = ENUM.ItemType.Relic
	relic.ItemType.append(ENUM.ItemType.Relic)
	relic.IconTexture = ResourceManager.get_item_icon(21)
	ResourceManager.ReferItemCatalog.Item.append(relic)
	EquipmentSlotSystem.interact_with_equipment_slot(relic.ItemID, 1, 1, relic_slots)
	UIManager.tmp_slot.set_tmp_item(10, 1)
	UIManager.tmp_slot.refresh()
	assert(BackpackSystem.get_backpack().size() > 1)
	assert(EquipmentSlotSystem.get_weapon_current_contianer() == 2)
	assert(EquipmentSlotSystem.get_relic_current_contianer() == 1)
	assert(hero.get_node("WeaponController").Weapon != null)
	assert(hero.get_node("WeaponController").WeaponTexture.texture != null)
	UIManager.ui_open_backpack()
	assert(home.inventoryUI.visible)
	# 受击状态也必须能进入死亡，不被输入缓冲覆盖。
	hero.get_node("State").switch_state(hero.get_node("State/Break"), false)
	hero.set_character_current_health(0.0)
	assert(hero.get_node("State").Current.name == "Death")
	assert(hero.velocity == Vector2.ZERO and hero._InputController.is_banned)
	assert(not is_instance_valid(UIManager.death_ui))
	assert_empty_inventory(hero, home.inventoryUI)
	assert(not home.inventoryUI.visible and UIManager.is_banned)
	var open_inventory := InputEventAction.new()
	open_inventory.action = &"OpenBackpack"
	open_inventory.pressed = true
	UIManager._input(open_inventory)
	assert(not home.inventoryUI.visible)
	# 掉落物在死亡动画期间碰到遗体，也不能把背包重新填满。
	var dropped := DroppedItem.new()
	dropped.add_item([{"id": 21, "amount": 5}])
	dropped._on_pickup_area_body_entered(hero)
	assert(dropped.get_items().size() == 1)
	assert(BackpackSystem.get_backpack().is_empty())
	dropped.free()
	# 系统必须原地清空，已有格子持有的数组引用也同步变空。
	assert(weapon_slots.slice(1) == [-1, -1])
	assert(relic_slots.slice(1) == [-1, -1, -1, -1])
	assert(WarehouseSystem.get_warehouse() == warehouse_before)
	# 死亡精灵动画结束后才显示界面。
	await hero.Spirte.animation_finished
	await get_tree().process_frame
	var death_ui := UIManager.death_ui
	assert(is_instance_valid(death_ui) and death_ui.visible)
	assert(home.has_node("DeathLayer"))
	assert(hero.mainCamera.get_parent() == hero)
	assert(hero.collision_layer == 0)
	var layout := death_ui.get_node("CenterContainer/Panel/MarginContainer/Layout")
	var button := layout.get_node("ConfirmButton") as Button
	var prompt := layout.get_node("Prompt") as Label
	assert(button.text == "确认" and prompt.text.contains("返回家园"))
	assert(button.has_focus())
	SignalBus.player_death.emit()
	assert(home.find_children("DeathLayer", "", false, false).size() == 1)

	if OS.get_cmdline_user_args().has("--preview"):
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Path.DEATH_UI_PREVIEW_TEXTURE)
		print("DEATH_UI_PREVIEW_SAVED")
		get_tree().quit()
		return

	# ESC 不得关闭死亡界面；确认后只发起一次场景切换。
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	UIManager._input(cancel)
	assert(death_ui.visible)
	button.pressed.emit()
	death_ui._on_confirm_pressed()
	assert(button.disabled)
	assert(home.find_children("SceneLoadingLayer", "", false, false).size() == 1)
	var loading_ui := home.get_node("SceneLoadingLayer").get_child(0)
	assert(not loading_ui.wait_for_input)
	await get_tree().scene_changed
	assert(get_tree().current_scene.name == "Home")
	assert(not is_instance_valid(home) and not is_instance_valid(hero))
	assert(not is_instance_valid(death_ui) and not is_instance_valid(UIManager.death_ui))
	assert(is_instance_valid(DataLoader.get_hero()) and DataLoader.get_hero().CurrentHealth > 0.0)
	assert(not UIManager.is_banned)
	await get_tree().process_frame
	assert_empty_inventory(DataLoader.get_hero(), get_tree().current_scene.inventoryUI)
	assert(WarehouseSystem.get_warehouse() == warehouse_before)
	print("DEATH_UI_TESTS_PASSED")
	get_tree().quit()


func assert_empty_inventory(hero: HeroProperty, inventory_ui: BaseUI) -> void:
	assert(BackpackSystem.get_backpack().is_empty())
	assert(BackpackSystem.get_amounts().is_empty())
	assert(BackpackSystem.get_current_contianer() == 0)
	assert(BackpackSystem.get_max_contianer() == 16)
	assert(EquipmentSlotSystem.WeaponSlot.size() == EquipmentSlotSystem.WeaponMaxContianer + 1)
	assert(EquipmentSlotSystem.RelicSlot.size() == EquipmentSlotSystem.RelicMaxContianer + 1)
	assert(EquipmentSlotSystem.WeaponSlot[0] == ENUM.ItemType.Weapon)
	assert(EquipmentSlotSystem.RelicSlot[0] == ENUM.ItemType.Relic)
	for id in EquipmentSlotSystem.WeaponSlot.slice(1):
		assert(id == -1)
	for id in EquipmentSlotSystem.RelicSlot.slice(1):
		assert(id == -1)
	assert(EquipmentSlotSystem.CurrentWeapon == 1)
	assert(EquipmentSlotSystem.get_current_weapon() == -1)
	assert(EquipmentSlotSystem.get_weapon_current_contianer() == 0)
	assert(EquipmentSlotSystem.get_relic_current_contianer() == 0)
	assert(UIManager.tmp_slot.get_tmp_item() == Vector2i(-1, 0))
	assert(UIManager.tmp_slot.Icon.texture == null)
	var controller := hero.get_node("WeaponController")
	assert(controller.Weapon == null and controller.Context == null)
	assert(controller.WeaponTexture.texture == null)
	for slot in inventory_ui.get_node("item_bar").item_container.get_children():
		var button = slot.get_node("Button")
		assert(button.self_id == -1 and button.item_icon.texture == null)
		assert(not button.label_item_amount.visible)
	var equipment := inventory_ui.get_node("equipment_bar")
	for container in [equipment.weapon_container, equipment.relic_container]:
		for slot in container.get_children():
			var button = slot.get_node("Button")
			assert(button.self_id == -1 and button.icon == null)
