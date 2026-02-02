extends Node
class_name WeaponComponent

##伤害模块
func damage_module(Hitbox:Area2D, Movement:int, Porperty:WeaponPorperty, EquipmentOwner:BaseCharacter) -> void:
    for body in Hitbox.get_overlapping_bodies():
        if body.is_in_group("Enemy"):
            var Damage:DamagePorperty = Porperty.BaseDamage.duplicate(true)
            Damage.Damage = Damage.Damage * Porperty.DamageMultipler[Movement]
            DamageSystem.damage_assess(EquipmentOwner,body, Damage)

##生成弹幕模块
func spawn_bullet(BulletScene:PackedScene, SpawnPosition:Vector2, Direction:Vector2, Speed:float, Porperty:WeaponPorperty, EquipmentOwner:BaseCharacter) -> void:
    var bullet_instance = BulletScene.instantiate()
    bullet_instance.position = SpawnPosition
    bullet_instance.direction = Direction.normalized()
    bullet_instance.speed = Speed
    bullet_instance.Porperty = Porperty
    bullet_instance.EquipmentOwner = EquipmentOwner
    get_tree().current_scene.add_child(bullet_instance)