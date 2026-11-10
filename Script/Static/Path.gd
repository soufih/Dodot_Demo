class_name Path
extends RefCounted

# 统一管理资源UID与少量动态路径，仅保存字符串，避免预加载依赖循环。
# Godot 序列化配置和继承声明保留原生资源路径。

# 资源目录与关卡配置
const LEVEL_CATALOG_RESOURCE = "uid://bkk6fhvj5tx87"
const ENEMY_PORPERTY_CATALOG_RESOURCE = "uid://2srf8bdj186"
const ITEM_CATALOG_RESOURCE = "uid://crd3nj0t7e4d6"
const SKILL_CATALOG_RESOURCE = "res://Rescource/Data/Catalog/SkillCatalog.tres"
const WEAPON_PORPERTY_CATALOG_RESOURCE = "uid://btq5vs0iwj7jm"

# 场景
const ENEMY_HEALTH_BAR_SCENE = "uid://yiyrqpaw408l"
const AIR_WALL_SCENE = "res://Scene/Map/MapComponent/AirWall.tscn"
const BASE_ROOM_SCENE = "uid://b1icj01t6yj82"
const BULLET_SCENE = "uid://cmuk84c173g6p"
const C1_SCENE = "uid://dyyqa2sadbnbi"
const C2_SCENE = "uid://dfkfn5qrvbp80"
const C3_SCENE = "uid://bx6og5tjba7lp"
const CAMERA_BOUNDARY_SCENE = "res://Scene/Map/MapComponent/CameraBoundary.tscn"
const DEATH_UI_SCENE = "uid://46ii0cldw2i6"
const DEBUG_CONSOLE_UI_SCENE = "uid://bg27y24o5vgsg"
const DROPPED_ITEM_SCENE = "uid://brjmaexsiviws"
const E1_SCENE = "uid://cu8d1yqpj64mu"
const END_UI_SCENE = "uid://bycq6aswbilkt"
const ENEMY1_SCENE = "uid://dapiqis2bgofl"
const ENEMY2_SCENE = "uid://debrsbk4rnn23"
const CRAFTING_UI_SCENE = "res://UI/Crafting/crafting_window.tscn"
const EXIT_POINT_SCENE = "uid://b4juvpm2bu5i8"
const HERO_SCENE = "uid://dsspae73jd8a6"
const HOME_SCENE = "uid://5x746yhfjp3c"
const ITEM_LIST_SLOT_SCENE = "uid://bmtyh6pxk6pjt"
const LADDER_SCENE = "uid://x1dfb4rvq5v"
const LEVEL_SCENE = "uid://dn6etfky2c7oa"
const LOADING_SCREEN_SCENE = "uid://dwe0xfiykgcu0"
const MAP_DIRECTORY = "res://Scene/Map/"
const MAP_SCENE = "uid://baysbd0v7e3fm"
const MENU_UI_SCENE = "uid://cyy1mus77qou1"
const R4_SCENE = "uid://umasvyl80cyn"
const R5_SCENE = "uid://st38toceke0r"
const R6_SCENE = "uid://3gkycdqer3c4"
const S1_SCENE = "uid://wfy85603mfji"
const SETTING_PANEL_SCENE = "uid://di38xxftqwhae"
const SLOPE_SCENE = "res://Scene/Map/MapComponent/Slope.tscn"
const ROOM_SCENE_PATTERN = "res://Scene/Map/Room/%s.tscn"
const TEMPLATE_EDITOR_SCENE = "uid://c5btmj4x5ov78"

# 脚本
const LEVEL_BACKGROUND_SCRIPT = "uid://cx5rqs341ykbv"
const LEVEL_GENERATOR_V1_SCRIPT = "uid://bp2w26nctj7d6"
const LEVEL_GENERATOR_V2_SCRIPT = "uid://beae4cu52t85w"
const LEVEL_OUTSIDE_MASK_SCRIPT = "uid://ckfc4f77cvvr1"
const MAIN_CAMERA_SCRIPT = "uid://fe5kru1uiwtf"
const SCENE_LOADER_SCRIPT = "uid://5u5vpp5025u1"
const SKILL_COOLDOWN_ITEM_SCRIPT = "uid://dvwljupmcw17q"

# 纹理、着色器与资源文件
const BACKGROUND1_TEXTURE = "uid://d0sggcuateqqq"
const BACKGROUND2_TEXTURE = "uid://duyrtxyknc2s2"
const BACKGROUND3_TEXTURE = "uid://bnkas8f1buei8"
const BACKGROUND4A_TEXTURE = "uid://blvsm0bh58dxs"
const FIRE_BALL_RESOURCE = "uid://butaa0i8k8mts"
const LEVEL_BACKGROUND_SHADER = "uid://d2r21xmv748b6"
const LEVEL_TILE_SET_RESOURCE = "uid://d0ka4oj0qnxtl"
const PURPLE_WAVE_RESOURCE = "uid://bbdlp3w7oyci1"

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
