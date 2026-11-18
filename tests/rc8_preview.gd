extends "res://tests/player16_preview.gd"
func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	var tag := "mobile" if MobilePlatform.enabled() else "desktop"
	DirAccess.make_dir_recursive_absolute(out)
	var image := Image.create(2560,1024,false,Image.FORMAT_RGB8)
	for row in range(2):
		for col in range(5):
			var tier := row*5+col+1
			var rig := make_player({},"walk"); rig.set_rank16(tier); Cosmetics16.decorate(rig,{})
			preload("res://scripts/presentation/rank_cosmetics16.gd").decorate(rig,tier); rig.sync_pose()
			var picture := await shot(rig,512,Vector3(3,1.8,-6) if tier<=3 else Vector3(-3,1.8,6)); picture.convert(Image.FORMAT_RGB8)
			image.blit_rect(picture,Rect2i(0,0,512,512),Vector2i(col*512,row*512))
	assert(image.save_png(out+"/"+tag+"-rank-models.png")==OK)
	print("RC8 PREVIEW ",tag," complete"); quit()
