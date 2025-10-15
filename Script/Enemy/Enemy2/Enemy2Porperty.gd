extends BaseEnemy

var BulletPreload

func _ready() -> void:
	super.beginning()
	BulletPreload = preload("res://Scene/Bullet/Bullet.tscn")
