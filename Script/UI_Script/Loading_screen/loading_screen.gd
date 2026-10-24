extends BaseUI
class_name LoadingScreenUI
signal loading_failed

@export var wait_for_input: bool = true

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

@onready var Bar = $ProgressBar
@onready var progress_number_Lb = $progress_number_Lb

var next_scene:String
var _packed_scene: PackedScene
var _preloader: LevelGenerator
var _progress: float = 0.0
var _ready_to_continue := false
var _failed := false
var _switching := false
var _level_info: Dictionary
var _previous_ui_ban := false


func _ready() -> void:
	_level_info = CurrentLevel.get_level_info()
	_previous_ui_ban = UIManager.is_banned
	UIManager.ban_ui_input()
	var paths: Array[String] = [next_scene]
	if next_scene.is_empty() or not await SceneLoading.prepare_scenes(paths, get_tree(), _on_scene_progress):
		_fail("无法加载目标场景：%s" % next_scene)
		return
	_packed_scene = SceneLoading.get_scene(next_scene)
	if next_scene == SceneLoading.LEVEL_SCENE_PATH:
		_preloader = LevelGenerator.new()
		_preloader.auto_generate = false
		add_child(_preloader)
		if not await _preloader.prepare_level_async(_level_info.level):
			_fail("关卡资源或配置加载失败。")
			return
	elif next_scene == SceneLoading.HOME_SCENE_PATH:
		var home_paths: Array[String] = [SceneLoading.HERO_SCENE_PATH,
			Path.MENU_UI_SCENE,
			Path.EQUIPMENT_ENHANCEMENT_UI_SCENE, Path.MAP_SCENE]
		if not await SceneLoading.prepare_scenes(home_paths, get_tree(), _on_dependency_progress):
			_fail("家园资源加载失败。")
			return
	_progress = 1.0
	_ready_to_continue = true
	$progress_titiel_Lb.show()
	if not wait_for_input:
		_switch_scene.call_deferred()


func _process(_delta: float) -> void:
	if is_instance_valid(_preloader) and not _ready_to_continue:
		_progress = 0.2 + _preloader.loading_progress * 0.8
	Bar.value = maxf(_progress * 100.0, Bar.value)
	progress_number_Lb.text = "%d%%" % roundi(Bar.value)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _switching:
		return
	if _failed:
		get_viewport().set_input_as_handled()
		# 新的加载入口有独立覆盖层；原入口的 UI 也可直接关闭。
		if get_parent().name == "SceneLoadingLayer":
			get_parent().queue_free()
		else:
			queue_free()
	elif _ready_to_continue:
		get_viewport().set_input_as_handled()
		_switch_scene()


func _switch_scene() -> void:
	if _switching or not _ready_to_continue:
		return
	_switching = true
	if next_scene == SceneLoading.LEVEL_SCENE_PATH:
		CurrentLevel.set_level_info(_level_info.level, _level_info.levelName)
	var error := get_tree().change_scene_to_packed(_packed_scene)
	if error != OK:
		_switching = false
		_fail("场景切换失败：%s" % error_string(error))


func _on_scene_progress(value: float) -> void:
	_progress = value * 0.2


func _on_dependency_progress(value: float) -> void:
	_progress = 0.2 + value * 0.8


func _fail(message: String) -> void:
	push_error(message)
	_failed = true
	_ready_to_continue = false
	$progress_titiel_Lb.text = "加载失败，任意键返回"
	$progress_titiel_Lb.show()
	set_process(false)
	loading_failed.emit()


func _exit_tree() -> void:
	UIManager.is_banned = _previous_ui_ban


func set_next_scene(scene_path:String) -> void:
	next_scene = scene_path
