class_name BulletContext
extends RefCounted

##弹幕节点
var BulletNode: Node2D

##弹幕
var Bullet: SeniorBullet

##动画
var Ani: AnimationPlayer

##碰撞箱
var Hitbox: Area2D

##弹幕生成者
var Attacker: BaseCharacter


func _init(
	node: Node2D,
	bullet: SeniorBullet,
	ani: AnimationPlayer,
	hitbox: Area2D,
	attacker: BaseCharacter
):
	BulletNode = node
	Bullet = bullet
	Ani = ani
	Hitbox = hitbox
	Attacker = attacker
