extends HBoxContainer

const Item = preload(Path.SKILL_COOLDOWN_ITEM_SCRIPT)

@export var hero: HeroProperty
var entries: Dictionary[StringName, Control] = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SignalBus.skill_cooldown_started.connect(_on_started)
	SignalBus.skill_cooldown_finished.connect(_on_finished)
	# 仅初始化时读取一次快照，重新挂载后从剩余时间启动本地计时器。
	var controller: SkillController = hero.get_node("SkillController")
	for id in controller.skill_timer_map:
		var timer := controller.skill_timer_map[id]
		if not timer.is_stopped():
			_show_cooldown(id, timer.wait_time, timer.time_left)
	visible = not entries.is_empty()

func _on_started(target: HeroProperty, id: StringName, duration: float) -> void:
	if target != hero or duration <= 0.0:
		return
	_show_cooldown(id, duration, duration)

func _show_cooldown(id: StringName, duration: float, seconds_left: float) -> void:
	var definition := ResourceManager.get_skill_config(id)
	if definition == null:
		return
	if not entries.has(id):
		var item := Item.new()
		item.skill_id = id
		item.icon = definition.icon
		entries[id] = item
		item.cooldown_finished.connect(_on_finished.bind(hero, id))
		add_child(item)
	entries[id].start_cooldown(duration, seconds_left)
	show()

func _on_finished(target: HeroProperty, id: StringName) -> void:
	if target != hero or not entries.has(id):
		return
	var item := entries[id]
	entries.erase(id)
	remove_child(item)
	item.queue_free()
	visible = not entries.is_empty()

func _exit_tree() -> void:
	if SignalBus.skill_cooldown_started.is_connected(_on_started):
		SignalBus.skill_cooldown_started.disconnect(_on_started)
	if SignalBus.skill_cooldown_finished.is_connected(_on_finished):
		SignalBus.skill_cooldown_finished.disconnect(_on_finished)
