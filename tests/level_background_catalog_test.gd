extends SceneTree

class TestGenerator extends Node:
	signal level_generated
	signal level_clearing
	var generation_succeeded := false
	var generated_level := 0

func _initialize() -> void:
	call_deferred("run_test")

func solid_texture(color: Color, dimensions: Vector2i) -> ImageTexture:
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func run_test() -> void:
	root.size = Vector2i(960, 540)
	var level := Node2D.new()
	var generator := TestGenerator.new()
	generator.name = "LevelGenerator"
	level.add_child(generator)
	var camera := Camera2D.new()
	level.add_child(camera)
	var background: CanvasLayer = load(Path.LEVEL_BACKGROUND_SCRIPT).new()
	level.add_child(background)
	root.add_child(level)
	await process_frame
	var original_catalog: LevelCatalog = background.level_catalog
	var catalog := LevelCatalog.new()
	var first := Level.new()
	first.LevelInfor = LevelInformation.new()
	for index in 6:
		first.LevelInfor.Background.append(original_catalog.Log[0].LevelInfor.Background[index % 4])
	var second := Level.new()
	second.LevelInfor = LevelInformation.new()
	second.LevelInfor.Background.append(first.LevelInfor.Background[1])
	catalog.Log.assign([first, second])
	background.level_catalog = catalog
	generator.level_generated.emit()
	assert(background.get_node("BackgroundLayer0").material.get_shader_parameter("background_texture") == first.LevelInfor.Background[0])
	assert(background.get_node("BackgroundLayer5").material.get_shader_parameter("background_texture") == first.LevelInfor.Background[5])
	assert(background.get_node("BackgroundLayer0").get_index() > background.get_node("BackgroundLayer5").get_index())
	assert(background.get_node("BackgroundLayer0").material.get_shader_parameter("layer_depth") > background.get_node("BackgroundLayer5").material.get_shader_parameter("layer_depth"))
	generator.generated_level = 1
	generator.level_generated.emit()
	assert(background.has_node("BackgroundLayer0") and not background.has_node("BackgroundLayer1"))
	assert(background.get_node("BackgroundLayer0").material.get_shader_parameter("background_texture") == second.LevelInfor.Background[0])
	background.set_background_level(99)
	assert(not background.has_node("BackgroundLayer0"))
	background.set_background_level(-1)
	assert(not background.has_node("BackgroundLayer0"))
	second.LevelInfor.Background.clear()
	background.set_background_level(1)
	assert(not background.has_node("BackgroundLayer0"))
	var near := solid_texture(Color(1, 0, 0, 0.5), Vector2i(64, 32))
	var far := solid_texture(Color.GREEN, Vector2i(128, 64))
	var textures: Array[Texture2D] = [near, far]
	background.set_background_textures(textures)
	background.fog_strength = 0.0
	background.get_node("OutsideRoomMask").hide()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var pixel := root.get_texture().get_image().get_pixel(480, 270)
		assert(absf(pixel.r - 0.5) < 0.02 and absf(pixel.g - 0.5) < 0.02 and pixel.b < 0.02)
	level.queue_free()
	await process_frame
	print("PASS: catalog selection, near-to-far ordering, six layers, empty/invalid levels, alpha composition")
	quit()
