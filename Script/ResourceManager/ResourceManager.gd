extends Node

var ItemConfigCache: Dictionary = {}
var LoadedScenes: Dictionary = {}        
var loadedTextures: Dictionary = {}

var InforItemCatalog: ItemCatalog

func load_item_catalog():
	InforItemCatalog = load("uid://crd3nj0t7e4d6") as ItemCatalog
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
	push_error("ID", id, "NOT FOUND")
	
	return null
	
func get_item_scene(id: int)->PackedScene:
	if LoadedScenes.has(id):
		return LoadedScenes[id]
	
	if InforItemCatalog:
		var item = get_item_config(id)
		if item:
			if item.ScenePath:
				LoadedScenes[id] = load(item.ScenePath) as PackedScene
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
	if get_item_scene(id):
		var Scene = get_item_scene(id).instantiate()
		if parent:
			parent.add_child(Scene)
		return Scene
	return null
	
func clear():
	LoadedScenes.clear()
	loadedTextures.clear()
