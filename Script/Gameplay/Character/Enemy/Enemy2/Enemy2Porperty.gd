extends BaseEnemy

var BulletPreload

func _ready() -> void:
	super.beginning()
	BulletPreload = preload(Path.BULLET_SCENE)
