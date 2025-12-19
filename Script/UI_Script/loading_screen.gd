extends BaseUI

func _ready() -> void:
	begin()
	#ResourceLoader.load_threaded_request()
#加载资源

func _process(_delta: float) -> void:
	var progress = []
	#ResourceLoader.load_threaded_get_status()
	$ProgressBar.value = progress[0] * 100
	$progress_number_Lb.text = str(progress[0] * 100)+"%"
	
	#if progress[0] == 1:
		#var packed_scene = ResourceLoader.load_threaded_get()
		#get_tree().change_scene_to_packed(packed_scene)
#	加载完成后跳转下一个界面
	
