extends Node

func _ready() -> void:
	EnemyManager.load_enemy()
	UIManager.configure_scene(self, [UIId.PAUSE, UIId.SETTINGS, UIId.INVENTORY, UIId.DEATH, UIId.END])

func _exit_tree() -> void:
	DataLoader.set_hero(null)
