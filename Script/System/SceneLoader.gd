extends Node

##加载下一个场景
func load_next_scene(next_scene_path: String) -> void:
    var next_scene: PackedScene = load(next_scene_path)
    var original_scene: Node2D= get_tree().current_scene
    get_tree().change_scene_to_packed(next_scene)
    original_scene.queue_free()