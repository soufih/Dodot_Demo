extends Node

const SceneLoading = preload("res://Script/Gameplay/System/SceneLoader.gd")


func _ready() -> void:
	await get_tree().process_frame
	UIManager.tmp_slot.set_process(false)
	var home := SceneLoading.get_scene(SceneLoading.HOME_SCENE_PATH).instantiate()
	get_tree().root.add_child(home)
	get_tree().current_scene = home
	await get_tree().process_frame
	var hero: HeroProperty = DataLoader.get_hero()
	hero._InputController.ban_input(false)
	# 受击状态也必须能进入死亡，不被输入缓冲覆盖。
	hero.get_node("State").switch_state(hero.get_node("State/Break"), false)
	hero.set_character_current_health(0.0)
	assert(hero.get_node("State").Current.name == "Death")
	assert(hero.velocity == Vector2.ZERO and hero._InputController.is_banned)
	assert(not is_instance_valid(UIManager.death_ui))
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
		get_viewport().get_texture().get_image().save_png("res://tests/death_ui_preview.png")
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
	print("DEATH_UI_TESTS_PASSED")
	get_tree().quit()
