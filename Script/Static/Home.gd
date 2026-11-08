extends Node

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

@onready var startpoint:Marker2D = $Startpoint
#玩家
var hero: HeroProperty


func _ready() -> void:
	UIManager.configure_scene(self, [UIId.PAUSE, UIId.SETTINGS, UIId.MAP, UIId.EQUIPMENT, UIId.INVENTORY, UIId.DEATH, UIId.END])
	hero = SceneLoading.get_scene(SceneLoading.HERO_SCENE_PATH).instantiate()
	DataLoader.set_hero(hero)
	startpoint.add_child(hero)

func _exit_tree() -> void:
	DataLoader.set_hero(null)
