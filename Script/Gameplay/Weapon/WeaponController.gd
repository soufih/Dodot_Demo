extends Node2D

@export var Ani: AnimationPlayer
@export var PlayerAni: AnimationPlayer
@export var Owner:CharacterBody2D
@export var WeaponNode:Node2D
@export var Hitbox:Area2D
@export var WeaponTexture:Sprite2D
@export var ComboAnimations: Array[StringName] = [&"Attack", &"Attack2", &"Attack3", &"Attack4"]
@export var equipment: PlayerEquipmentComponent

var Weapon: WeaponPorperty
var Context:WeaponContext
var ComboCount:int
var _attack_generation: int = 0
const Type:Dictionary[int, String] = {
	ENUM.WeaponType.Sword : "Sword",
	ENUM.WeaponType.Blade : 'Blade',
	ENUM.WeaponType.Staff : 'Staff',
	ENUM.WeaponType.Bow : 'Bow'
}


## 监听本角色的装备适配器，使用现有动画和武器属性驱动战斗。
func _ready() -> void:
	if equipment != null:
		equipment.weapon_changed.connect(_on_current_weapon_changed)
	get_weapon()
	Ani.play("Reset")


## 解除角色订阅，切关后旧控制器不会继续接收装备变化。
func _exit_tree() -> void:
	if is_instance_valid(equipment) and equipment.weapon_changed.is_connected(_on_current_weapon_changed):
		equipment.weapon_changed.disconnect(_on_current_weapon_changed)


## 换装或切换使用武器时结束旧攻击上下文，避免继续执行旧武器动作。
func _on_current_weapon_changed():
	_attack_generation += 1
	Context = null
	ComboCount = 0
	Ani.play("Reset")
	Ani.advance(0.0)
	get_weapon()

## 按正式物品名称查询现有武器属性，空手时清空图标和攻击能力。
func get_weapon()->bool:
	var WeaponId = equipment.get_current_weapon() if equipment != null else -1
	var WeaponName = ResourceManager.get_item_name(WeaponId)
	Weapon = WeaponManager.get_weapon_porperty(WeaponName)
	WeaponTexture.texture = ResourceManager.get_item_icon(WeaponId)
	if Weapon == null:
		Context = null
		ComboCount = 0
		Ani.play("Reset")
		Ani.advance(0.0)
		return false
	return true

func _on_hero_on_attack(CCount:int) -> void:
	if Weapon == null && !get_weapon():
		return
	ComboCount = CCount % Weapon.MaxCombo
	Context = create_context()
	before_attack()

##结束攻击后复位
func _on_hero_end_attack() -> void:
	if Weapon == null:
		return
	Ani.play("Reset")


func _on_hero_breaked() -> void:
	Ani.play("Reset")


func before_attack():
	if Weapon == null:
		return
	var generation := _attack_generation
	for action:WeaponAction in Weapon.BeforeAttack:
		await action.execute(Context)
		if Weapon == null or generation != _attack_generation:
			return
	
	PlayerAni.speed_scale = Weapon.AttackSpeed
	Ani.speed_scale = Weapon.AttackSpeed
	
	var AniName:String = Type[Weapon.Type]+ComboAnimations[ComboCount]
	if PlayerAni && PlayerAni.has_animation(AniName):
		PlayerAni.play(AniName)
	if Ani && Ani.has_animation(AniName):
		Ani.play(AniName)


func during_attack():
	if Weapon == null:
		return
	var generation := _attack_generation
	for action:WeaponAction in Weapon.DuringAttack:
		await action.execute(Context)
		if Weapon == null or generation != _attack_generation:
			return


func after_attack():
	if Weapon == null:
		return
	var generation := _attack_generation
	for action:WeaponAction in Weapon.AfterAttack:
		await action.execute(Context)
		if Weapon == null or generation != _attack_generation:
			return


##创建上下文供每个攻击动作使用
func create_context():
	return WeaponContext.new(
		Weapon,
		Owner,
		WeaponNode,
		Hitbox,
		ComboCount
	)
