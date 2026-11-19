extends SceneTree
# Save only the game's viewport to the designated preview directory.
const Main = preload("res://scripts/main.gd")
var game: Main
var dest := ""
func _initialize() -> void:
	call_deferred("run")

func capture(name0: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(dest+"/"+name0+".png")

func run() -> void:
	dest=OS.get_environment("FERRY_PREVIEWS")
	if dest.is_empty(): quit(1);return
	DirAccess.make_dir_recursive_absolute(dest)
	game=Main.new()
	root.add_child(game)
	game.logbook.active=false
	game.set_screen("menu")
	await capture("title")
	game.set_screen("chapters")
	await capture("chapters")
	for page in [1,2]:
		game.turn_chapter_page(1)
		await capture("chapters-"+str(page+1))
	game.new_game()
	game.set_physics_process(false)
	game.hud.fade=0
	await capture("landing")
	var r:=game.route
	for i in r.platforms.size():
		var p:Dictionary=r.platforms[i]
		if p.style!="stone": continue
		r.pos=Vector2(p.pos)+Vector2(-r.RADIUS,32)
		r.catch_ledge(1)
		r.camera=clampf(r.pos.x-350,0,maxf(0,r.width-960))
		game.hud.intro=0
		await capture("ledge")
		r.climb_step(.24,1,true)
		await capture("mantle")
		break
	game.enter_room(game.Book.legacy_index(1),["s2"])
	r=game.route
	for d in r.devices:
		if d.type!="hound": continue
		r.pos=Vector2(d.x-355,d.y)
		var jumped:=false
		for frame in 230:
			var gap:float=d.dog-r.pos.x
			var leap:bool=not jumped and d.mode==2 and gap<110
			jumped=jumped or leap
			r.step(1.0/60,1,leap,false)
			if jumped and d.dog-r.pos.x<14: break
		game.hud.fade=0
		game.hud.intro=0
		await capture("hound")
		break
	# Reverse the same grip without moving the camera to compare the two poses.
	var box:Dictionary=r.freight[0]
	r.spawn()
	r.pos=Vector2(box.x-35,box.y)
	r.step(1.0/60,0,false,false)
	for direction in [1,-1]:
		for frame in 9: r.step(1.0/60,direction,false,true)
		r.camera=maxf(0,r.pos.x-385)
		await capture("crate-push" if direction==1 else "crate-pull")
	game.enter_room(game.Book.legacy_index(11),["f2"])
	r=game.route
	for deck in r.platforms:
		if deck.style!="hoist": continue
		r.camera=deck.base.x-245
		r.camera_y=minf(0,deck.base.y-350)
		game.hud.fade=0
		game.hud.intro=0
		for phase in [0.0,PI]:
			r.time=phase/deck.rate
			r.update_platforms()
			r.pos=Vector2(deck.pos)+Vector2(deck.w*.5,0)
			await capture("hoist-left" if phase==0 else "hoist-right")
		break
	game.enter_room(game.Book.legacy_index(2),["s3"])
	r=game.route
	for d in r.devices:
		if d.type!="steam": continue
		r.pos=Vector2(d.x-85,d.y)
		r.camera=maxf(0,r.pos.x-420)
		r.time=3.6
		r.update_devices(0)
		game.hud.button_scale=1.5
		game.hud.fade=0
		await capture("vent")
		break
	for index in [25,148]:
		game.enter_room(game.Book.migrated_room(index),[])
		r=game.route
		var deck:Dictionary=r.platforms[1]
		r.pos=Vector2(deck.pos)+Vector2(deck.w*.5,0)
		r.camera=maxf(0,r.pos.x-385)
		r.camera_y=r.vertical_view()
		game.hud.intro=0
		game.hud.fade=0
		game.hud.button_scale=1
		await capture("low-water" if index==25 else "upper-tower")
	for shot in [["canopy",21,.46],["boar",68,.18],["cave",94,.50],["lightning",144,.30],["storm-afterglow",144,.30],["storm-dark",144,.30]]:
		game.enter_room(game.Book.migrated_room(shot[1]),[])
		r=game.route
		var target:float=r.width*shot[2]
		for deck in r.platforms:
			if deck.pos.x<target: continue
			r.pos=deck.pos+Vector2(deck.w*.5,0)
			break
		r.camera=clampf(r.pos.x-385,0,maxf(0,r.width-960))
		r.camera_y=r.vertical_view()
		r.time={"lightning":2.45,"storm-afterglow":2.94,"storm-dark":3.85}.get(shot[0],.3)
		for ride in r.rides:
			if r.pos.x>=ride.start and r.pos.x<ride.end:
				r.mounted=ride.type
				r.active_ride=r.rides.find(ride)
				ride.position=r.pos
		game.hud.intro=0
		game.hud.fade=0
		await capture(shot[0])
	for i in game.Book.CHAPTERS.size():
		game.enter_room(game.Book.CHAPTER_STARTS[i],[])
		game.hud.intro=0
		game.hud.fade=0
		await capture("chapter-material-"+str(i+1))
	game.leave_voyage()
	game.open_workshop("menu")
	for family in game.Book.FAMILIES:
		game.practice_station(family[0])
		await capture("board-"+str(family[0]))
		game.close_console()
	game.enter_room(game.Book.ROOMS.size()-1,[])
	game.room_finished()
	await capture("beacon")
	game.queue_free()
	await process_frame
	quit()
