extends RefCounted
## Shared, offline-prepared models supplied by the creator. Gameplay remains on the actor.
static var scenes: Dictionary[String, PackedScene] = {}
static var lean_materials: Dictionary = {}
static var rendered_modes: Dictionary = {}

static func source_id_for(id: String) -> String:
	return "hound" if id == "parasite" else id

static func model_scene(id: String, boss: bool) -> PackedScene:
	var kit := "bosses" if boss else "zombies"
	var path := "res://assets/enemies/tripo16/%s/%s.tscn" % [kit, source_id_for(id)]
	if not scenes.has(path):
		scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return scenes[path]

static func prepare() -> void:
	for kind in range(8):
		model_scene(CampaignData.enemy_spec(kind).id, false)
	for entry in InfectedRoster.EXTRA:
		model_scene(entry[0], false)
	for id in SectorGenerator.BOSS_IDS:
		model_scene(id, true)
	model_scene("titan16", true)

static func warm_render(world: Node3D) -> void:
	if DisplayServer.get_name() == "headless": return
	var mode := Vector2i(int(MobilePlatform.lightweight()), int(world.sunlight.shadow_enabled))
	if rendered_modes.has(mode) or world.has_node("EnemyRenderWarmup"): return

	# Submit the real skinned draw calls in the gameplay viewport, below the
	# arena floor. This also warms the lightweight viewport's shader variants.
	var stage := Node3D.new()
	stage.name = "EnemyRenderWarmup"
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(stage)
	stage.global_position = world.player.global_position - Vector3.UP * 1.25
	var index := 0
	for scene in scenes.values():
		if scene == null: continue
		var rig: Node3D = scene.instantiate()
		apply_quality(rig)
		rig.scale = Vector3.ONE * .15
		rig.position = Vector3(float(index % 6) * .33 - .83, 0, floorf(index / 6.0) * .33 - .66)
		stage.add_child(rig)
		index += 1

	await RenderingServer.frame_post_draw
	if is_instance_valid(stage):
		rendered_modes[mode] = true
		stage.queue_free()

static func apply_quality(rig: Node3D) -> void:
	if not MobilePlatform.lightweight(): return
	var mesh: MeshInstance3D = rig.get_node("Skeleton3D/Character")
	var original: StandardMaterial3D = mesh.get_surface_override_material(0)
	if not lean_materials.has(original):
		var lean: StandardMaterial3D = original.duplicate()
		lean.normal_enabled = false
		lean_materials[original] = lean
	mesh.set_surface_override_material(0, lean_materials[original])

static func create(actor: Node3D, factor: float) -> Node3D:
	var id: String = actor.spec.id
	var scene := model_scene(id, actor.is_boss)
	if scene == null: return null
	var rig: Node3D = scene.instantiate()
	apply_quality(rig)
	var profile: String = rig.get_meta("profile16", "human")
	rig.set_meta("source_model_id16", source_id_for(id))
	rig.set_meta("model_id16", id)
	rig.scale = Vector3.ONE * (factor if actor.is_boss or profile == "human" else .45 if id == "parasite" else 1.0)
	if id == "parasite": rig.set_meta("parasite16", true)
	actor.add_child(rig)
	actor.wings.clear()
	for name in (["WingL","WingR"] if profile == "flyer" else ["LegFL","LegFR","LegBL","LegBR"] if profile == "dog" else []):
		actor.wings.append(rig.get_node(name))
	return rig
