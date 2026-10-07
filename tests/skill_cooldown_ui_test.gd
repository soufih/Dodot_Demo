extends Node

const HERO = preload(Path.HERO_SCENE)

func _ready() -> void:
	var hero: HeroProperty = HERO.instantiate()
	add_child(hero)
	hero.set_physics_process(false)
	hero.get_node("State").set_physics_process(false)
	var skills: SkillController = hero.get_node("SkillController")
	var ui = hero.get_node("PlayerUI/SkillCooldownUI")
	assert(not ui.visible and ui.entries.is_empty())
	skills.start_skill_cooldown(&"dash")
	assert(ui.visible and ui.entries.size() == 1)
	var item = ui.entries[&"dash"]
	assert(item.icon == ResourceManager.get_skill_config(&"dash").icon and item.icon != null)
	var first_progress: float = item.progress
	await get_tree().create_timer(0.2).timeout
	assert(item.progress < first_progress and item.progress > 0.0)
	if "--preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Path.COOLDOWN_UI_PREVIEW_TEXTURE)
		print("SKILL_COOLDOWN_UI_PREVIEW_READY")
		get_tree().quit()
		return
	# 同一技能重新开始冷却更新现有条目，不重复添加图标。
	skills.start_skill_cooldown(&"dash")
	assert(ui.entries.size() == 1 and ui.entries[&"dash"] == item)
	# 来自其他人物的通知不影响此 UI。
	var other := HeroProperty.new()
	SignalBus.skill_cooldown_finished.emit(other, &"dash")
	assert(ui.entries.size() == 1)
	other.free()
	# 第二项技能可并排显示，未配置图标时仍提供占位文字。
	var definition := SkillDefinition.new()
	definition.id = &"ui_test"
	definition.cooldown = 0.4
	ResourceManager.SkillConfigCache[definition.id] = definition
	skills.start_skill_cooldown(definition.id)
	assert(ui.entries.size() == 2)
	await skills.skill_timer_map[definition.id].timeout
	assert(ui.entries.size() == 1)
	await skills.skill_timer_map[&"dash"].timeout
	assert(not ui.visible and ui.entries.is_empty())
	# 开始信号即可驱动本地计时，即使控制器中的 Timer 被停止也不依赖它。
	skills.start_skill_cooldown(definition.id)
	var local_item = ui.entries[definition.id]
	assert(local_item.timer != skills.skill_timer_map[definition.id])
	skills.skill_timer_map[definition.id].stop()
	await get_tree().create_timer(0.1).timeout
	assert(local_item.progress > 0.0 and local_item.progress < 1.0)
	await local_item.timer.timeout
	assert(not ui.visible and ui.entries.is_empty())
	ResourceManager.SkillConfigCache.erase(definition.id)
	print("SKILL_COOLDOWN_UI_TESTS_PASSED")
	get_tree().quit()
