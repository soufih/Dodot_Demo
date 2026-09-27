class_name ElementaryBullet
extends Resource

@export var AniTres: SpriteFrames
@export var CollisionShape: Resource
@export var Porperty: DamagePorperty
@export var Lifecycle: float

@export var Spawned: Array[BulletAction]
@export var Moving: Array[BulletAction]
@export var Death: Array[BulletAction]
@export var Hit: Array[BulletAction]

var attacker: String
var target: String


##设置攻击发出方
func set_attacker(atkr: String):
	attacker = atkr

##设置敌对阵营
func set_target(tgt: String):
	target = tgt
