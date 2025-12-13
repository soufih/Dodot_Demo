extends BaseUI

func _ready() -> void:
	begin()
	ResourceLoader.load_threaded_request(SceneLoader.next_scene)
#加载资源

func _process(delta: float) -> void:
	var progress = []
	ResourceLoader.load_threaded_get_status(SceneLoader.next_scene,progress)
	$ProgressBar.value = progress[0] * 100
	$progress_number_Lb.text = str(progress[0] * 100)+"%"
	
	if progress[0] == 1:
		var packed_scene = ResourceLoader.load_threaded_get(SceneLoader.next_scene)
		get_tree().change_scene_to_packed(packed_scene)
#	加载完成后跳转下一个界面
	
