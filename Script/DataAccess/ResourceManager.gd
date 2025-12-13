extends Node

var ItemConfigCache: Dictionary = {}
var LoadedScenes: Dictionary = {}        
var loadedTextures: Dictionary = {}

var ReferItemCatalog: ItemCatalog

func load_item_catalog():
	ReferItemCatalog = load("uid://crd3nj0t7e4d6") as ItemCatalog
	if !ReferItemCatalog:
		push_error("ERRO!WHEN LOADING ITEMCATALOG")


func get_item_config(id: int)->ItemConfig:
	if ItemConfigCache.has(id):
		return ItemConfigCache[id]
	
	if ReferItemCatalog:
		for item in ReferItemCatalog.Item:
			if item.ItemID == id:
				ItemConfigCache[id] = item
				return item
	
	return null


func get_item_scene(id: int)->PackedScene:
	if LoadedScenes.has(id):
		return LoadedScenes[id]

	if ReferItemCatalog:
		var Item = get_item_config(id)
		if Item:
			
			if Item.ScenePath:
				LoadedScenes[id] = load(Item.ScenePath) as PackedScene
				return LoadedScenes[id]
	
	return null


func get_item_icon(id: int)->Texture2D:
	if loadedTextures.has(id):
		return loadedTextures[id]
		
	if ReferItemCatalog:
		var item = get_item_config(id)
		if item:
			if item.IconTexture:
				loadedTextures[id] = item.IconTexture
				return loadedTextures[id]
				
	return null


func get_item_item_type(id: int)->Array:
	var Config = get_item_config(id)
	
	if Config:
		if Config.ItemType:
			return Config.ItemType

	return []


func get_item_max_stack(id:int)->int:
	var Config = get_item_config(id)
	if Config:
		if Config.MaxStack:
			return Config.MaxStack

	return -1


func get_item_source(id: int)->Array:
	var Config = get_item_config(id)
	
	if Config:
		if Config.Source:
			return Config.Source

	return []


func get_item_source_discription(id: int)->String:
	var Config = get_item_config(id)

	if Config:
		if Config.SourceDiscription:
			return Config.SourceDiscription

	return ""


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
