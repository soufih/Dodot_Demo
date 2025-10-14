extends Control


func _ready() -> void:
	ResourceLoader.load_threaded_request(SceneLoader.next_scene)


func _process(delta: float) -> void:
	var progress = []
	ResourceLoader.load_threaded_get_status(SceneLoader.next_scene,progress)
	$ProgressBar.value = progress[0] * 100
	$progress_number_Lb.text = str(progress[0] * 100)+"%"
	
	if progress[0] == 1:
		var packed_scene = ResourceLoader.load_threaded_get(SceneLoader.next_scene)
		get_tree().change_scene_to_packed(packed_scene)
	
	
