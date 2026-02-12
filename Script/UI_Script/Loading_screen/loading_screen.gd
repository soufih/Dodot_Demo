extends BaseUI
class_name LoadingScreenUI

@onready var Bar = $ProgressBar
@onready var progress_number_Lb = $progress_number_Lb

var next_scene:String


func _ready() -> void:
	print("loading......")
	ResourceLoader.load_threaded_request(next_scene, '', true)


func _process(_delta: float) -> void:
	#获取加载进度
	var progress = []
	ResourceLoader.load_threaded_get_status(next_scene,progress)

	#更新进度条
	Bar.value = progress[0] * 100
	progress_number_Lb.text = str(Bar.value)+"%"

	#加载完成后跳转下一个界面
	if progress[0] == 1:
		var original_scene= get_tree().current_scene
		var packed_scene = ResourceLoader.load_threaded_get(next_scene)
		get_tree().change_scene_to_packed(packed_scene)
		original_scene.queue_free()


func set_next_scene(scene_path:String) -> void:
	next_scene = scene_path
