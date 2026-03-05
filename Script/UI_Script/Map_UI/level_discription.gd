extends BaseUI


func _ready() -> void:
	begin()
	hide()

func _on_button_button_down() -> void:
	UIManager.ui_close_all()

	var tmpRoot: CanvasLayer = CanvasLayer.new()
	tmpRoot.name = "tmpRoot"
	tmpRoot.layer = 100

	get_tree().root.get_node("Home").add_child(tmpRoot)
	var loading_scene = load("res://UI/Loading_screen/loading_screen.tscn").instantiate()
	loading_scene.set_next_scene("res://Scene/Map/Level/LevelScene.tscn") #加载关卡
	tmpRoot.add_child(loading_scene)
