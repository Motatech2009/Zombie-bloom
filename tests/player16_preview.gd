extends SceneTree
var out := "res://builds/review16"
func _initialize() -> void: call_deferred("run")
func bounds(node: Node3D,base: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB(); var found := false
	for child in node.get_children():
		if not child is Node3D: continue
		var box := bounds(child,base*child.transform)
		if box.size.length_squared()>0: result = result.merge(box) if found else box; found = true
	if node is MeshInstance3D and node.mesh!=null:
		var box: AABB = base*node.mesh.get_aabb()
		result = result.merge(box) if found else box
	return result
func disable(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	if node is Label3D: node.hide()
	for child in node.get_children(): disable(child)
func shot(object: Node3D,pixels: int = 768,view: Vector3 = Vector3(4,2.8,-6)) -> Image:
	var vp := SubViewport.new(); vp.size = Vector2i(pixels,pixels); vp.own_world_3d = true; vp.transparent_bg = false; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var stage := Node3D.new(); vp.add_child(stage); stage.add_child(object); disable(object)
	var world_env := WorldEnvironment.new(); world_env.environment = Environment.new(); world_env.environment.background_mode = Environment.BG_COLOR; world_env.environment.background_color = Color("e8ecec"); world_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; world_env.environment.ambient_light_color = Color.WHITE; world_env.environment.ambient_light_energy = .72; stage.add_child(world_env)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-38,-28,0); light.light_energy = 1.25; stage.add_child(light)
	var box := bounds(object); var center := box.get_center(); var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = box.size.length()*1.05; camera.position = center+view.normalized()*maxf(5,box.size.length()*2); camera.far = 200; stage.add_child(camera); camera.look_at(center); camera.current = true
	await process_frame; await RenderingServer.frame_post_draw
	var result := vp.get_texture().get_image(); vp.queue_free(); await process_frame; return result
func make_player(outfit: Dictionary,pose: String) -> Node3D:
	var actor := Node3D.new(); root.add_child(actor)
	var rig := VisualFactory.human(actor,Color("81946e"),true); Cosmetics16.decorate(rig,outfit)
	VisualFactory.animate_human(rig,.14,1 if pose=="walk" else 0,0,true)
	if pose=="reload": rig.get_node("ArmL").rotation = Vector3(.5,0,.65); rig.get_node("Gun").rotation.z = -.4
	if pose=="empty": rig.get_node("Gun").hide()
	rig.sync_pose(); actor.remove_child(rig); actor.queue_free(); return rig
func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	var tag := "mobile" if MobilePlatform.enabled() else "desktop"
	DirAccess.make_dir_recursive_absolute(out)
	var outfits := [{},{"head":"COS-ENG-01","outfit":"COS-ENG-04","backpack":"COS-ENG-05"},{"head":"COS-BAT-01","outfit":"COS-BAT-03","backpack":"COS-BAT-05"},{"head":"COS-TITAN-01"}]
	var image := Image.create(2560,1280,false,Image.FORMAT_RGB8)
	for row in range(2):
		for col in range(4):
			var rig := make_player(outfits[col],["empty","walk","reload","walk"][col])
			var picture := await shot(rig,640,Vector3(3,1.8,-6) if row==0 else Vector3(-3,1.8,6)); picture.convert(Image.FORMAT_RGB8)
			image.blit_rect(picture,Rect2i(0,0,640,640),Vector2i(col*640,row*640))
	assert(image.save_png(out+"/"+tag+"-player-models.png")==OK)
	var scene := Node3D.new(); var stall: Node3D = load("res://assets/scenery/tripo16/vendedor/stall.tscn").instantiate(); scene.add_child(stall)
	var person := Node3D.new(); stall.add_child(person); person.position = Vector3(0,0,-.45); person.rotation.y = PI; VisualFactory.human(person,Color("a5966b"),false)
	var picture := await shot(scene,1024,Vector3(4,2.8,6)); assert(picture.save_png(out+"/"+tag+"-vendor-model.png")==OK)
	print("PLAYER PREVIEW ",tag," complete"); quit()
