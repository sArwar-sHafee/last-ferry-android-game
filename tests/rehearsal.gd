extends "voyage.gd"
# Rehearse the public controls at game speed. Build scripts run the faster deterministic audit.
var down := {}
var clock_start := 0
var last_room := -1
var strokes := 0

func finger(index: int, zone: String, pressed: bool) -> void:
	var ev:=InputEventScreenTouch.new()
	ev.index=index
	ev.position=game.hud.zones()[zone]
	ev.pressed=pressed
	root.push_input(ev,true)

func controls(left: bool,right: bool,grasp: bool,jump: bool) -> void:
	var states:=[left,right,grasp,jump]
	for i in 4:
		if bool(down.get(i,false))!=bool(states[i]):
			finger(i,["left","right","use","jump"][i],states[i])
			down[i]=states[i]

func click(at: Vector2) -> void:
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=at
		e.global_position=at
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=pressed
		root.push_input(e,true)

func tile_at(panel,cell: int) -> Vector2:
	if panel.model.kind=="sluice": return panel.origin+Vector2(cell+.5,1.5)*panel.tile
	return panel.center(cell)

func run() -> void:
	game=Main.new()
	root.add_child(game)
	if "--continue" not in OS.get_cmdline_user_args(): game.logbook.active=false
	game.logbook.sound=false
	game.audio.set_enabled(false)
	game.set_screen("menu")
	await process_frame
	click(Vector2(130,384))
	if not check(game.screen=="play","start or Continue button"): quit(1);return
	clock_start=Time.get_ticks_msec()
	var ticks:=0
	var room_start:=0.0
	while game.screen not in ["final","credits"] and ticks<60*10800:
		await physics_frame
		ticks+=1
		if game.screen=="play":
			var r:=game.route
			if last_room!=r.room:
				last_room=r.room
				room_start=game.logbook.played
				landing=-1
				print("REHEARSAL  room %02d  elapsed %.1fs" % [r.room+1,game.logbook.played])
			if game.logbook.played-room_start>180:
				printerr("Pilot stalled in ",r.room," at ",r.pos," g",r.grounded," touch",game.fingers," down",down)
				quit(1);return
			if game.hud.controls_locked:
				controls(false,false,false,false)
			elif r.near_station>=0:
				controls(false,false,false,false)
				finger(8,"use",true)
				finger(8,"use",false)
			else:
				var move:=pilot(r)
				controls(float(move[0])<-.13,float(move[0])>.13,move[2],move[1])
		elif game.screen=="console":
			down.clear()
			var panel=game.console
			var m:Instrument=panel.model
			for act in m.data.solution:
				if m.solved(): break
				var cells:=[]
				match m.kind:
					"slip":
						var piece:=int(act[0])
						cells.append(int(m.pieces[piece][0]))
						var stops:=m.slip_stops(piece)
						for edge in stops:
							if int(stops[edge])==int(act[1]): cells.append(edge);break
					"sluice": cells=[act[0],act[1]]
					"freight": cells=[m.neighbor(m.worker,int(act))]
					_: cells=[int(act)]
				for cell in cells:
					click(tile_at(panel,int(cell)))
					strokes+=1
					await create_timer(.25).timeout
			if not check(m.solved(),"pointer solution "+panel.board_id): quit(1);return
			while game.screen=="console": await physics_frame
		elif game.screen=="aim":
			controls(false,false,false,false)
			# The tarnished handwheel advances a fixed angle for each press.
			while absf(308+game.aim*560-663)>31: click(Vector2(186,477))
			click(Vector2(320,477))
		elif game.screen=="pause":
			printerr("Unexpected pause during rehearsal");quit(1);return
		if ticks%3600==0: print("REHEARSAL  still moving  ",game.route.pos)
	if not check(game.screen=="final","rehearsal reached the ending"): quit(1);return
	click(Vector2(132,399))
	check(game.screen=="credits","Credits button")
	print("REHEARSAL COMPLETE: %.1f active game seconds, %.1f wall seconds, %d station pointer presses" % [game.logbook.played,(Time.get_ticks_msec()-clock_start)/1000.0,strokes])
	game.queue_free()
	await process_frame
	quit(1 if bad else 0)
