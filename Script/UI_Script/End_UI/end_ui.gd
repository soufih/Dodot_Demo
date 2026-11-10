extends BaseUI

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

@export_file("*.tscn") var return_scene_path: String = SceneLoading.HOME_SCENE_PATH

@onready var level_label: Label = %LevelName
@onready var prompt_label: Label = %Prompt
@onready var return_button: Button = %ReturnButton
@onready var materials_content: VBoxContainer = %MaterialsContent
@onready var statistics_label: Label = %StatisticsValues

var _returning := false


func _ready() -> void:
	begin()
	SignalBus.level_statistics_updated.connect(_show_statistics)
	var info := CurrentLevel.get_level_info()
	level_label.text = info.levelName if not info.levelName.is_empty() else "关卡 %d" % (info.level + 1)


func on_open(_payload: Dictionary) -> bool:
	_show_statistics({})
	SignalBus.level_completed.emit()
	SignalBus.level_statistics_requested.emit()
	return true


func _show_statistics(statistics: Dictionary) -> void:
	var seconds := maxi(int(statistics.get("elapsed_seconds", 0.0)), 0)
	var duration := "%02d:%02d" % [seconds / 60, seconds % 60]
	if seconds >= 3600:
		duration = "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	statistics_label.text = "击败敌人：%d\n\n首领：%d\n\n造成伤害：%.1f\n\n承受伤害：%.1f\n\n通关耗时：%s" % [
		statistics.get("enemies_defeated", 0), statistics.get("bosses_defeated", 0),
		statistics.get("damage_dealt", 0.0), statistics.get("damage_taken", 0.0), duration]
	for child in materials_content.get_children():
		materials_content.remove_child(child)
		child.queue_free()
	var items: Dictionary = statistics.get("items_collected", {})
	if items.is_empty():
		var empty := Label.new()
		empty.text = "本关未拾取战利品"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		materials_content.add_child(empty)
		return
	var item_ids := items.keys()
	item_ids.sort()
	for config_id: int in item_ids:
		_add_item_row(config_id, int(items[config_id]))


func _add_item_row(config_id: int, quantity: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	materials_content.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ResourceManager.get_item_icon(config_id)
	row.add_child(icon)
	var item_name := Label.new()
	item_name.text = ResourceManager.get_item_name(config_id)
	if item_name.text.is_empty():
		item_name.text = "物品 %d" % config_id
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(item_name)
	var amount := Label.new()
	amount.text = "× %d" % quantity
	row.add_child(amount)


func _on_return_pressed() -> void:
	if _returning:
		return
	_returning = true
	return_button.disabled = true
	var error := SceneLoading.load_next_scene(return_scene_path, false)
	if error != OK:
		_on_return_failed()
		return
	var loading_ui = UIManager.get_ui(UIId.LOADING)
	loading_ui.loading_failed.connect(_on_return_failed, CONNECT_ONE_SHOT)


func _on_return_failed() -> void:
	_returning = false
	return_button.disabled = false
	prompt_label.text = "返回城镇失败，请重试。"
	var loading_ui = UIManager.get_ui(UIId.LOADING)
	if loading_ui != null and loading_ui._failed:
		UIManager.close(UIId.LOADING)
