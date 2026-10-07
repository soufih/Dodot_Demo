class_name Path
extends RefCounted

# 统一管理资源路径，仅保存字符串，避免预加载依赖循环。
# Godot 序列化配置和继承声明保留原生资源路径。

# 资源目录与关卡配置
const LEVEL_CATALOG_RESOURCE = "res://Rescource/Data/Catalog/LevelCatalog.tres"
const ENEMY_PORPERTY_CATALOG_RESOURCE = "res://Rescource/Data/Catalog/EnemyPorpertyCatalog.tres"
const ITEM_CATALOG_RESOURCE = "res://Rescource/Data/Catalog/ItemCatalog.tres"
const SKILL_CATALOG_RESOURCE = "res://Rescource/Data/Catalog/SkillCatalog.tres"
const WEAPON_PORPERTY_CATALOG_RESOURCE = "res://Rescource/Data/Catalog/WeaponPorpertyCatalog.tres"

# 场景
const ENEMY_HEALTH_BAR_SCENE = "res://UI/EnemyUI/EnemyHealthBar.tscn"
const AIR_WALL_SCENE = "res://Scene/Map/MapComponent/AirWall.tscn"
const BASE_ROOM_SCENE = "res://Scene/Map/Room/BaseRoom.tscn"
const BULLET_SCENE = "res://Scene/Bullet/Bullet.tscn"
const C1_SCENE = "res://Scene/Map/Room/Corridor/C1.tscn"
const C2_SCENE = "res://Scene/Map/Room/Corridor/C2.tscn"
const C3_SCENE = "res://Scene/Map/Room/Corridor/C3.tscn"
const CAMERA_BOUNDARY_SCENE = "res://Scene/Map/MapComponent/CameraBoundary.tscn"
const DEATH_UI_SCENE = "res://UI/Death_UI/death_ui.tscn"
const DEBUG_CONSOLE_UI_SCENE = "res://UI/Debug_UI/debug_console_ui.tscn"
const DROPPED_ITEM_SCENE = "res://Scene/DroppedItem/DroppedItem.tscn"
const E1_SCENE = "res://Scene/Map/Room/End/E1.tscn"
const END_UI_SCENE = "res://UI/End_UI/end_ui.tscn"
const ENEMY1_SCENE = "res://Scene/Enemy/Enemy1.tscn"
const ENEMY2_SCENE = "res://Scene/Enemy/Enemy2.tscn"
const EQUIPMENT_ENHANCEMENT_UI_SCENE = "res://UI/Equipment_Enhancement_UI/equipment_enhancement_ui.tscn"
const EQUIPMENT_SLOT_SCENE = "res://UI/Bag_UI/equipment_slot.tscn"
const EXIT_POINT_SCENE = "res://Scene/Map/MapComponent/ExitPoint.tscn"
const FLOATING_PICKUP_MENTION_UI_SCENE = "res://UI/Floating_Pickup_Mention_UI/floating_pickup_mention_ui.tscn"
const HERO_SCENE = "res://Scene/Hero/Hero.tscn"
const HOME_SCENE = "res://Scene/Map/Home/Home.tscn"
const INVENTORY_UI_SCENE = "res://UI/Bag_UI/inventory_ui.tscn"
const ITEM_LIST_SLOT_SCENE = "res://UI/Component_UI/Item_List_UI/item_list_slot.tscn"
const LADDER_SCENE = "res://Scene/Map/MapComponent/ladder.tscn"
const LEVEL_SCENE = "res://Scene/Map/Level/LevelScene.tscn"
const LOADING_SCREEN_SCENE = "res://UI/Loading_screen/loading_screen.tscn"
const MAP_DIRECTORY = "res://Scene/Map/"
const MAP_SCENE = "res://UI/Map_UI/map.tscn"
const MENU_UI_SCENE = "res://UI/Menu_ui/menu_ui.tscn"
const R4_SCENE = "res://Scene/Map/Room/Room/R4.tscn"
const R5_SCENE = "res://Scene/Map/Room/Room/R5.tscn"
const R6_SCENE = "res://Scene/Map/Room/Room/R6.tscn"
const S1_SCENE = "res://Scene/Map/Room/Start/S1.tscn"
const SETTING_PANEL_SCENE = "res://UI/MainScene_UI/setting_panel.tscn"
const SLOPE_SCENE = "res://Scene/Map/MapComponent/Slope.tscn"
const SLOT_SCENE = "res://UI/Bag_UI/slot.tscn"
const ROOM_SCENE_PATTERN = "res://Scene/Map/Room/%s.tscn"
const TEMPLATE_EDITOR_SCENE = "res://Scene/Util/TemplateEditor.tscn"
const TMP_SLOT_SCENE = "res://UI/Bag_UI/TmpSlot.tscn"
const WAREHOUSE_UI_SCENE = "res://UI/Warehouse_UI/warehouse_ui.tscn"

# 脚本
const LEVEL_BACKGROUND_SCRIPT = "res://Script/Gameplay/Map/LevelBackground.gd"
const LEVEL_GENERATOR_V1_SCRIPT = "res://Script/Gameplay/Map/LevelGenerator v1.gd"
const LEVEL_GENERATOR_V2_SCRIPT = "res://Script/Gameplay/Map/Test/LevelGenerator v2.gd"
const LEVEL_OUTSIDE_MASK_SCRIPT = "res://Script/Gameplay/Map/LevelOutsideMask.gd"
const MAIN_CAMERA_SCRIPT = "res://Script/Gameplay/Character/Hero/MainCamera.gd"
const MOTION_UTIL_SCRIPT = "res://Script/Gameplay/Util/MotionUtil.gd"
const SCENE_LOADER_SCRIPT = "res://Script/Gameplay/System/SceneLoader.gd"
const SKILL_COOLDOWN_ITEM_SCRIPT = "res://Script/UI_Script/Player_UI/SkillCooldown/skill_cooldown_item.gd"

# 纹理、着色器与资源文件
const BACKGROUND1_TEXTURE = "res://Rescource/Static/Background/background1.png"
const BACKGROUND2_TEXTURE = "res://Rescource/Static/Background/background2.png"
const BACKGROUND3_TEXTURE = "res://Rescource/Static/Background/background3.png"
const BACKGROUND4A_TEXTURE = "res://Rescource/Static/Background/background4a.png"
const FIRE_BALL_RESOURCE = "res://Rescource/Data/Bullet/ElementaryBullet/FireBall.tres"
const LEVEL_BACKGROUND_SHADER = "res://Shader/level_background.gdshader"
const LEVEL_TILE_SET_RESOURCE = "res://Rescource/Static/TileSet/LevelTileSet.tres"
const PURPLE_WAVE_RESOURCE = "res://Rescource/Data/Bullet/ElementaryBullet/PurpleWave.tres"

# 目录、模板与工具数据
const LEVEL2_TEMPLATE = "res://Rescource/Data/Level/LevelTemplate/Level2"
const LEVEL_TEMPLATE_DIRECTORY = "res://Rescource/Data/Level/LevelTemplate/"
const RESOURCE_ROOT = "res://"
const TILEMAP_SIZES_JSON = "res://Script/Gameplay/Map/Test/tilemap_sizes.json"

# 测试资源与生成文件
const CAMERA_BOUNDARY_GENERATOR_FIXTURE_SCRIPT = "res://tests/camera_boundary_generator_fixture.gd"
const COOLDOWN_UI_PREVIEW_TEXTURE = "res://tests/cooldown_ui_preview.png"
const DEATH_UI_PREVIEW_TEXTURE = "res://tests/death_ui_preview.png"
const END_UI_PREVIEW_TEXTURE = "res://tests/end_ui_preview.png"
const LEVEL_BACKGROUND_INGAME_TEXTURE = "res://tests/level_background_ingame.png"
const LEVEL_BACKGROUND_PREVIEW_TEXTURE = "res://tests/level_background_preview.png"
const LEVEL_OUTSIDE_MASK_PREVIEW_TEXTURE = "res://tests/level_outside_mask_preview.png"
const LEVEL_TILESET_BASELINE_FILE = "res://tests/level_tileset_baseline.json"
const MINIMAP_PREVIEW_TEXTURE = "res://tests/minimap_preview.png"
# 此文件故意不存在，用于验证场景加载失败时的处理。
const MISSING_HOME_SCENE = "res://tests/missing_home.tscn"
const TEMPLATE_ROUNDTRIP_TMP_FILE = "res://tests/template_roundtrip.tmp.json"
