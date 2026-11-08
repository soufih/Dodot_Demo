class_name UIConfig
extends Resource
## SCENE 缓存仍随 owner 离树释放，缓存策略与所属场景独立。
enum Layer { HUD = 10, WINDOW = 20, MODAL = 30, RESULT = 40, LOADING = 50, DEBUG = 60 }
enum Scope { SCENE, GLOBAL }
@export var id: StringName
@export_file("*.tscn") var scene_path: String
@export var layer: Layer = Layer.WINDOW
@export var scope: Scope = Scope.SCENE
@export var keep_alive: bool = true
@export var allow_multiple: bool = false
@export var participates_in_back: bool = true
@export var close_on_cancel: bool = true
@export var modal: bool = false
@export var pause_game: bool = false
@export var block_gameplay: bool = true
@export var block_ui_shortcuts: bool = false
@export var follow_viewport: bool = false
