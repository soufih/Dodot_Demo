class_name BulletContext
extends RefCounted

var Valid: bool = true
var Target: String = "Enemy"
var HitBody: Node2D

##弹幕节点
var BulletNode: Node2D

##弹幕
var Bullet: ElementaryBullet

##动画
var Ani: AnimationPlayer

##碰撞箱
var Hitbox: Area2D

##弹幕生成者
var Attacker: BaseCharacter


func _init(
	node: Node2D,
	bullet: ElementaryBullet,
	ani: AnimationPlayer,
	hitbox: Area2D,
	attacker: BaseCharacter
):
	BulletNode = node
	Bullet = bullet
	Ani = ani
	Hitbox = hitbox
	Attacker = attacker
