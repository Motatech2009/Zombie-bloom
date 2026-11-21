extends "res://tests/player16_preview.gd"
var w: Node3D
func visual(kind: int,boss_stage: int) -> Node3D:
	w.restoring_boss_stage = boss_stage
	var actor: Node3D = w.make_enemy(kind,Vector3.ZERO,false,-1)
	w.restoring_boss_stage = 0
	disable(actor)
	var rig: Node3D = actor.rig
	actor.remove_child(rig); actor.get_parent().remove_child(actor); actor.queue_free()
	rig.position = Vector3.ZERO; rig.rotation = Vector3.ZERO
	for mesh in rig.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh is TorusMesh: mesh.get_parent().remove_child(mesh); mesh.free()
	var holder := Node3D.new(); holder.add_child(rig)
	return holder
func run() -> void:
	GameSettings.volume = 0; GameSettings.music_volume = 0
	MobilePlatform.force_touch = false
	out = "res://builds/enemy-references16"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false
	root.add_child(w); current_scene = w; disable(w)
	var records := []
	for kind in range(20):
		if kind==8: continue
		var spec = CampaignData.enemy_spec(kind) if kind<9 else InfectedRoster.extra_spec(kind)
		records.append({"file":"zumbi_%02d" % kind,"title":spec.title,"kind":kind,"stage":0,"group":"zombies"})
	for stage in range(1,8):
		var spec = SectorGenerator.boss_spec(stage)
		records.append({"file":"boss_%02d" % stage,"title":spec.title,"kind":8,"stage":stage,"group":"bosses"})
	records.append({"file":"boss_titan","title":"Titã Enraizado","kind":20,"stage":0,"group":"bosses"})
	var requested_views := ["perspectiva"] if "--overview" in OS.get_cmdline_user_args() else ["frente","perspectiva","costas"]
	var views := {"frente":Vector3(0,1,-6),"perspectiva":Vector3(4,2.3,-6),"costas":Vector3(0,1,6)}
	for item in records:
		var folder: String = out+"/"+item.group+"/"+item.file
		DirAccess.make_dir_recursive_absolute(folder)
		for label in requested_views:
			var model := visual(item.kind,item.stage)
			var picture := await shot(model,1024,views[label])
			assert(picture.save_png(folder+"/"+label+".png")==OK)
		print("REFERENCE ",item.file," ",item.title)
	var manifest := FileAccess.open(out+"/manifest.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"source_commit":OS.get_environment("GITHUB_SHA") if not OS.get_environment("GITHUB_SHA").is_empty() else "working-tree","source":"Godot 4.6.3; actual gameplay rigs and materials","characters":records,"views":requested_views},"  "))
	manifest.close(); await gallery(records,"zombies",5); await gallery(records,"bosses",4); w.queue_free(); await process_frame; await process_frame
	print("REFERENCES COMPLETE: ",records.size()," characters, ",records.size()*requested_views.size()," images"); quit()

func gallery(records: Array,group: String,columns: int) -> void:
	var items := records.filter(func(item): return item.group==group)
	var vp := SubViewport.new(); vp.size = Vector2i(columns*360,ceili(items.size()/float(columns))*420+80); vp.disable_3d = true; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var background := ColorRect.new(); background.color = Color("e8ecec"); background.size = vp.size; vp.add_child(background)
	var heading := Label.new(); heading.text = "ZOMBIE BLOOM · "+("19 INFECTADOS" if group=="zombies" else "7 BOSSES + TITÃ"); heading.position = Vector2(0,16); heading.size = Vector2(vp.size.x,50); heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_theme_color_override("font_color",Color("203739")); heading.add_theme_font_size_override("font_size",30); vp.add_child(heading)
	for i in range(items.size()):
		var x := (i%columns)*360; var y := (i/columns)*420+80
		var im := Image.load_from_file(out+"/"+group+"/"+str(items[i].file)+"/perspectiva.png")
		var pic := TextureRect.new(); pic.texture = ImageTexture.create_from_image(im); pic.position = Vector2(x+10,y); pic.size = Vector2(340,340); pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; vp.add_child(pic); pic.size = Vector2(340,340)
		var label := Label.new(); label.text = items[i].title; label.position = Vector2(x+5,y+350); label.size = Vector2(350,60); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_color_override("font_color",Color("203739")); label.add_theme_font_size_override("font_size",22); vp.add_child(label)
	await process_frame; await RenderingServer.frame_post_draw
	assert(vp.get_texture().get_image().save_png(out+"/galeria_"+group+".png")==OK)
	vp.queue_free(); await process_frame
