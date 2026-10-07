extends Node

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	UIManager.tmp_slot.set_process(false)
	CurrentLevel.set_level_info(0, "结算流程测试")
	var level := SceneLoading.get_scene(SceneLoading.LEVEL_SCENE_PATH).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	var hero: HeroProperty = DataLoader.get_hero()
	assert(is_instance_valid(hero))
	hero._InputController.ban_input(false)
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	BackpackSystem.quick_add_item(21, 3)
	EquipmentSlotSystem.interact_with_equipment_slot(10, 1, 1, EquipmentSlotSystem.get_weapon_slot())
	var backpack_before := BackpackSystem.get_backpack().duplicate(true)
	var amounts_before := BackpackSystem.get_amounts().duplicate(true)
	var warehouse_before := WarehouseSystem.get_warehouse().duplicate(true)
	var endpoint := level.find_child("ExitPoint*", true, false) as Interactable
	assert(endpoint != null and endpoint.can_interact(hero))
	assert(not endpoint.can_interact(self))
	# 验证实际终点进入玩家交互检测范围。
	hero.global_position = endpoint.global_position
	for frame in range(60):
		await get_tree().physics_frame
	assert(hero.is_on_floor())
	assert(hero.InteractBox.get_overlapping_areas().has(endpoint))
	hero.get_node("InteractionController").try_interact()
	assert(not hero.get_node("PlayerUI/InteractionPrompt").visible)
	var end_ui := UIManager.end_ui
	assert(is_instance_valid(end_ui) and end_ui.visible)
	assert(get_tree().paused)
	assert(end_ui.level_label.text == "结算流程测试")
	assert(end_ui.return_button.has_focus())
	assert(end_ui.materials_content.size.x > 0)
	UIManager.show_end_screen()
	assert(level.find_children("EndLayer", "", false, false).size() == 1)
	assert(not endpoint.can_interact(hero))
	UIManager.ui_cancel()
	assert(end_ui.visible)
	assert(BackpackSystem.get_backpack() == backpack_before)
	if OS.get_cmdline_user_args().has("--preview"):
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Path.END_UI_PREVIEW_TEXTURE)
		print("END_UI_PREVIEW_SAVED")
		get_tree().quit()
		return
	# 立即失败不锁死按钮；加载失败后允许重试。
	end_ui.return_scene_path = Path.MISSING_HOME_SCENE
	end_ui._on_return_pressed()
	for frame in range(120):
		if not end_ui._returning:
			break
		await get_tree().process_frame
	assert(not end_ui._returning and not end_ui.return_button.disabled)
	assert(end_ui.prompt_label.text.contains("失败"))
	assert(get_tree().paused)
	await get_tree().process_frame
	end_ui.return_scene_path = SceneLoading.HOME_SCENE_PATH
	end_ui.return_button.pressed.emit()
	end_ui._on_return_pressed()
	assert(end_ui.return_button.disabled)
	assert(level.find_children("SceneLoadingLayer", "", false, false).size() == 1)
	assert(not level.get_node("SceneLoadingLayer").get_child(0).wait_for_input)
	await get_tree().scene_changed
	assert(get_tree().current_scene.name == "Home")
	assert(not get_tree().paused and not UIManager.is_banned)
	assert(not is_instance_valid(level) and not is_instance_valid(hero))
	assert(not is_instance_valid(UIManager.end_ui))
	assert(BackpackSystem.get_backpack() == backpack_before)
	assert(BackpackSystem.get_amounts() == amounts_before)
	assert(EquipmentSlotSystem.get_current_weapon() == 10)
	assert(WarehouseSystem.get_warehouse() == warehouse_before)
	assert(is_instance_valid(DataLoader.get_hero()))
	print("END_UI_TESTS_PASSED")
	get_tree().quit()
