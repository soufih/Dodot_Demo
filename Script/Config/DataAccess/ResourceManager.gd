extends Node

var ItemConfigCache: Dictionary = {}
var LoadedScenes: Dictionary = {}        
var loadedTextures: Dictionary = {}

var ReferItemCatalog: ItemCatalog

##加载物品配置表
func load_item_catalog():
	ReferItemCatalog = load(Path.ITEM_CATALOG_RESOURCE) as ItemCatalog
	if !ReferItemCatalog:
		push_error("ERRO!WHEN LOADING ITEMCATALOG")

##获取物品配置
func get_item_config(id: int)->ItemConfig:
	if ItemConfigCache.has(id):
		return ItemConfigCache[id]
	
	if ReferItemCatalog:
		for item in ReferItemCatalog.Item:
			if item.ItemID == id:
				ItemConfigCache[id] = item
				return item
	
	return null

##获取物品列表
func get_item_list() ->Array[int]:
	var item_list:Array[int] = []
	
	if ReferItemCatalog:
		for item in ReferItemCatalog.Item:
			item_list.append(item.ItemID)
	
	return item_list

##获取物品名称
func get_item_name(id: int)->String:
	var Config = get_item_config(id)

	if Config:
		if Config.ItemName:
			return Config.ItemName

	return ""

##获取物品描述
func get_item_discription(id: int)->String:
	var Config = get_item_config(id)
	
	if Config:
		if Config.ItemDiscription:
			return Config.ItemDiscription

	return ""

##获取物品主类型
func get_item_main_item_type(id: int)->ENUM.ItemType:
	var Config = get_item_config(id)
	
	if Config:
		if Config.MainItemType:
			return Config.MainItemType

	return ENUM.ItemType.None

##获取物品类型
func get_item_item_type(id: int)->Array:
	var Config = get_item_config(id)
	
	if Config:
		if Config.ItemType:
			return Config.ItemType

	return []

##获取物品图标
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

##获取物品场景
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

##获取物品最大堆叠数
func get_item_max_stack(id:int)->int:
	var Config = get_item_config(id)
	if Config:
		if Config.MaxStack:
			return Config.MaxStack

	return -1

##获取物品高级物品列表
func get_item_products(id: int)->Array:
	var products: Array[int] = []
	for recipe: CraftingRecipe in CraftingManager.list_recipes():
		if recipe.inputs.has(id):
			for output_id: int in recipe.outputs:
				if not products.has(output_id):
					products.append(output_id)
	return products

##获取物品基础物品列表
func get_item_recipe(id: int)->Dictionary:
	# 兼容旧的按产物查询入口；正式合成应使用 recipe_id，以区分同产物的不同配方。
	for recipe: CraftingRecipe in CraftingManager.list_recipes():
		if recipe.outputs.has(id):
			return recipe.inputs.duplicate()
	return {}

##实例化物品场景
func instantiate_item(id: int, parent: Node = null) -> Node:
	var Item = get_item_scene(id)
	if Item:
		var Scene = get_item_scene(id).instantiate()
		if parent:
			parent.add_child(Scene)
		return Scene
	return null

##清除缓存
func clear():
	LoadedScenes.clear()
	loadedTextures.clear()
