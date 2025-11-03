extends Node

var ItemConfigCache: Dictionary = {}
var LoadedScenes: Dictionary = {}        
var loadedTextures: Dictionary = {}

var InforItemCatalog: ItemCatalog

func _ready() -> void:
	load_item_catalog()
	
func load_item_catalog():
	InforItemCatalog = load("res://Rescource/ItemCatalog.tres") as ItemCatalog
	if !InforItemCatalog:
		push_error("ERRO!WHEN LOADING ITEMCATALOG")

func get_item_config(id: int)->ItemConfig:
	
	if ItemConfigCache.has(id):
		return ItemConfigCache[id]
	
	if InforItemCatalog:
		for item in InforItemCatalog.Item:
			
			if item.ItemID == id:
				ItemConfigCache[id] = item
				
				return item
	
	return null
	
func get_item_scene(id: int)->PackedScene:
	if LoadedScenes.has(id):
		return LoadedScenes[id]

	if InforItemCatalog:
		var Item = get_item_config(id)
		if Item:
			
			if Item.ScenePath:
				LoadedScenes[id] = load(Item.ScenePath) as PackedScene
				return LoadedScenes[id]
	
	return null
	
func get_item_icon(id: int)->Texture2D:
	if loadedTextures[id]:
		return loadedTextures[id]
		
	if InforItemCatalog:
		var item = get_item_config(id)
		if item:
			if item.IconTexture:
				loadedTextures[id] = item.IconTexture
				return loadedTextures[id]
				
	return null
	
func instantiate_item(id: int, parent: Node = null) -> Node:
	var Item = get_item_scene(id)
	if Item:
		var Scene = get_item_scene(id).instantiate()
		if parent:
			parent.add_child(Scene)
		return Scene
	return null
	
func clear():
	LoadedScenes.clear()
	loadedTextures.clear()
