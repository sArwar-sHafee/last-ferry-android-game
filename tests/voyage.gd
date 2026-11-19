extends SceneTree

const Passage = preload("res://scripts/passage.gd")
const Book = preload("res://scripts/campaign.gd")
const Instrument = preload("res://scripts/instrument.gd")
const Logbook = preload("res://scripts/logbook.gd")
const Main = preload("res://scripts/main.gd")
var boards: Dictionary
var bad := 0
var total_steps := 0
var gameplay_seconds := 0.0
var used := {}
var game: Main
var solution_moves := 0
var landing := -1

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,why: String) -> bool:
	if not ok:
		printerr("FAIL  ",why)
		bad+=1
	return ok

func operate(m: Instrument, act: Variant) -> bool:
	match m.kind:
		"slip":
			var i := int(act[0])
			m.tap(int(m.pieces[i][0]))
			for edge in m.slip_stops(i):
				if int(m.slip_stops(i)[edge])==int(act[1]): return m.tap(edge)
			return false
		"sluice":
			m.tap(int(act[0]))
			return m.tap(int(act[1]))
		"freight":
			return m.tap(m.neighbor(m.worker,int(act)))
		_:
			return m.tap(int(act))

func solve(key: String,m: Instrument) -> void:
	check(not m.solved(), key+" starts solved")
	var first = m.data.solution[0]
	var original := m.snapshot()
	check(operate(m,first),key+" first move")
	m.undo()
	check(original==m.snapshot(),key+" undo")
	operate(m,first)
	m.reset()
	check(original==m.snapshot(),key+" reset")
	for act in m.data.solution:
		if m.solved(): break
		if not check(operate(m,act),key+" invalid solution move "+str(act)): break
		solution_moves+=1
	check(m.solved(),key+" unsolved at end")

# Run-length pilot only reads visible geometry and operates the normal player physics.
func pilot(r: Passage) -> Array:
	if r.ledge>=0: return [float(r.ledge_face),false,false]
	var axis := 1.0
	var jump := false
	var grip := false
	if r.near_valve>=0:
		var device:Dictionary=r.devices[r.near_valve]
		if (r.valve_action=="Fill chamber I" and int(device.mode)==0) or (r.valve_action=="Transfer to II" and int(device.mode)==1):
			game.use_nearby()
	for device in r.devices:
		if device.type in ["hound","spider"] and device.mode==2 and r.is_grounded():
			var distance:float=(r.pos.x-float(device.dog))*float(device.facing)
			var closing:float=float(device.speed)+r.SPEED if device.facing<0 else float(device.speed)-r.SPEED
			if distance>0 and distance<closing*.31:
				landing=-1
				return [1,true,false]
		if device.type=="steam" and float(device.x)-r.pos.x>24 and float(device.x)-r.pos.x<54:
			if float(device.cycle)>2.45: return [0,false,false]
		if device.type=="shutter" and float(device.x)-r.pos.x>15 and float(device.x)-r.pos.x<48:
			if float(device.amount)<.9: return [0,false,false]
	if not r.is_grounded():
		# Steer toward the center of the landing, braking before its far edge.
		if landing>=0 and landing<r.platforms.size():
			var target: Dictionary=r.platforms[landing]
			var dx:float=target.pos.x+target.w*.5-r.pos.x
			axis=clampf((dx-r.vel.x*.09)/17,-1,1)
		return [axis,false,false]
	for box in r.freight:
		if absf(float(box.y)-r.pos.y)<2 and r.pos.x<=float(box.x)-12 and float(box.x)-r.pos.x<67:
			if float(box.max)-float(box.x)>1:
				grip=true
			else: jump=true
			landing=-1
			return [axis,jump,grip]
	if r.grounded==-2:
		landing=-1
		return [axis,true,false]
	landing=r.grounded+1
	var p: Dictionary = r.platforms[r.grounded]
	if r.grounded+1>=r.platforms.size(): return [axis,false,false]
	var nxt: Dictionary=r.platforms[r.grounded+1]
	if nxt.style=="chamber" and float(nxt.pos.y)>float(p.pos.y)+24 and r.pos.x>float(p.pos.x)+float(p.w)-30:
		return [0,false,false]
	if nxt.style=="balance" and float(nxt.pos.y)>float(p.pos.y)+21 and r.pos.x>float(p.pos.x)+float(p.w)-25:
		return [0,false,false]
	var near_edge:bool=r.pos.x>float(p.pos.x)+float(p.w)-33
	if near_edge and (nxt.style=="cage" or p.style=="cage") and float(p.pos.y)-float(nxt.pos.y)>19:
		return [0,false,false]
	var drop:float=r.surface_height(nxt,nxt.pos.x)-r.surface_height(p,r.pos.x)
	var edge:float=p.pos.x+p.w
	var lead:float=edge-r.pos.x
	var gap:float=nxt.pos.x-edge
	if gap>6 and lead<19:
		# Wait for traveling ferries and lifting hooks before stepping off.
		if gap>50 and (p.delta.x!=0 or nxt.delta.x!=0):
			return [0,false,false] if lead>5 else [-.4,false,false]
		jump=true
	elif gap<=6 and drop < -7 and lead<32: jump=true
	return [axis,jump,grip]

func run_room(index: int) -> void:
	# The game itself loads the following room on reaching its exit.
	if not check(game.route!=null and game.route.room==index,"normal room transition "+str(index)): return
	var r:=game.route
	landing=-1
	var dt:=1.0/60.0
	var deaths:=0
	for tick in 24000:
		if r.near_station>=0:
			game.open_station()
			if not check(game.screen=="console","physical station opens at keeper"): return
			var key := str(r.stations[game.active_station].key)
			used[game.console.board_id]=true
			solve(game.console.board_id,game.console.model)
			game.console.moved(true)
			game.console._process(1)
			if not check(r.completed.has(key),"station completion "+key): break
		var cmd := pilot(r)
		r.step(dt,cmd[0],cmd[1],cmd[2])
		if "splash" in r.events: deaths+=1
		r.events.clear()
		if r.finish:
			print("ROUTE %02d  %s  %.1fs, %d recoveries" % [index+1,Book.ROOMS[index][0],r.elapsed,deaths])
			gameplay_seconds+=r.elapsed
			total_steps+=tick+1
			game.room_finished()
			return
		if deaths>=3: break
	check(false,"room %d %s unreachable at %s ground %d, stations %s, deaths %d" % [index+1,Book.ROOMS[index][0],r.pos,r.grounded,r.completed,deaths])
	if r.grounded>=0:
		print("STUCK ",r.platforms[r.grounded]," NEXT ",r.platforms[mini(r.grounded+1,r.platforms.size()-1)]," CARGO ",r.freight)
	game.enter_room(mini(Book.ROOMS.size()-1,index+1),[])

func touch(index: int,at: Vector2,pressed: bool) -> void:
	var e:=InputEventScreenTouch.new()
	e.index=index
	e.position=at
	e.pressed=pressed
	game._input(e)

func lifecycle_checks() -> void:
	game.new_game()
	for j in 4: game._physics_process(1.0/60)
	touch(1,game.hud.zones().right,true)
	touch(2,game.hud.zones().jump,true)
	game._physics_process(1.0/60)
	check(game.route.vel.x>0 and game.route.vel.y<0,"simultaneous touch movement + jump")
	touch(1,game.hud.zones().right,false)
	touch(2,game.hud.zones().jump,false)
	check(game.fingers.is_empty(),"finger release")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.screen=="pause","two Android callbacks for one Back press open pause once")
	game.back()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.screen=="pause","background pauses game")
	game.back()
	check(game.screen=="play","back resumes paused game")
	game.open_settings("pause")
	var before:=game.logbook.sound
	game.toggle_sound()
	check(Logbook.new().sound!=before and game.audio.enabled!=before,"sound toggle persists")
	game.toggle_sound()
	game.enter_room(Book.legacy_index(1),[])
	var r:=game.route
	r.freight[0].x=r.freight[0].max
	r.pos.y=530
	r.step(1.0/60,0,false,false)
	for j in 45: r.step(1.0/60,0,false,false)
	check(absf(r.pos.x-r.checkpoint.x)<1 and r.freight[0].x==r.freight[0].spawn,"death restores crate and checkpoint")
	game.new_game()

func checkpoint_checks() -> void:
	game.enter_room(Book.legacy_index(2),[])
	game.open_station()
	check(game.screen=="play","distant use cannot open a station")
	var r:=game.route
	var s:Dictionary=r.stations[0]
	r.pos=Vector2(float(s.x)+84,s.y)
	for j in 35: r.step(1.0/60,1,false,false)
	check(r.pos.x<=float(s.x)+86.1 and not r.finish,"an early approach cannot bypass a closed gate")
	r.pos=Vector2(s.x,s.y)
	r.step(1.0/60,0,false,false)
	game.open_station()
	var first=game.console.model.data.solution[0]
	operate(game.console.model,first)
	var partial:=game.console.model.snapshot()
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.screen=="pause" and not game.console.is_processing(),"app background freezes a live instrument")
	game.back()
	check(game.screen=="console" and game.console.model.snapshot()==partial,"resume retains the open instrument")
	game.console.reset_board()
	for act in game.console.model.data.solution:
		if game.console.model.solved(): break
		operate(game.console.model,act)
	game.console.moved(true)
	game.console._process(.7)
	var saved:=Logbook.new()
	check(saved.room==Book.legacy_index(2) and saved.cleared==["s3"],"on-disk checkpoint records the first of two stations")
	# A new scene reads the saved voyage and re-enters from the safe side of the first gate.
	var fresh:=Main.new()
	root.add_child(fresh)
	fresh.continue_game()
	check(fresh.route.room==Book.legacy_index(2) and fresh.route.completed==["s3"] and fresh.route.pos.x>float(s.x),"Continue after a fresh launch restores position and machinery")
	fresh.play_chapter(0)
	fresh.leave_voyage()
	check(Logbook.new().room==Book.legacy_index(2) and Logbook.new().cleared==["s3"],"chapter replay preserves the story checkpoint")
	fresh.audio.set_enabled(false)
	fresh.queue_free()
	var shutter:=Passage.new(Book.legacy_index(22),["l4","l11"])
	for d in shutter.devices:
		if d.type!="shutter": continue
		shutter.pos=Vector2(d.x,d.y)
		shutter.time=3.6
		shutter.step(1.0/60,0,false,false)
		check(shutter.death_timer>0,"closing shutter triggers checkpoint recovery")
		for j in 46: shutter.step(1.0/60,0,false,false)
		check(shutter.pos.distance_to(shutter.checkpoint)<2,"shutter death returns to a safe start")
		break
	var path:="user://recovery-check.cfg"
	var backup:=Logbook.new(path)
	backup.active=true
	backup.room=7
	backup.store()
	backup.room=8
	backup.store()
	var broken:=FileAccess.open(path,FileAccess.WRITE)
	broken.store_string("[voyage]\nroom=99\n=broken")
	broken.close()
	# Simulate loss of the primary file without producing a parser-error test log.
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".interrupted"))
	check(Logbook.new(path).room==7,"previous complete checkpoint backs up an interrupted save")
	var old_save:=ConfigFile.new()
	old_save.set_value("voyage","room",22)
	old_save.set_value("voyage","cleared",["l4"])
	old_save.save(path)
	var upgraded:=Logbook.new(path)
	check(upgraded.room==Book.legacy_index(22) and upgraded.cleared==["l4"],"version one save maps to the same landmark and checkpoint")
	upgraded.store()
	check(Logbook.new(path).room==upgraded.room,"upgraded room is migrated only once")
	game.new_game()

func update_checks() -> void:
	# Families cycle without repeats, and every variation is solvable using actual taps.
	var kinds:Dictionary={}
	var variants:Dictionary={}
	for family in Book.FAMILIES:
		for key in family:
			var model:=Instrument.new(game.board_specs[key])
			solve(key,model)
			variants[key]=true
		var first:=Instrument.new(game.board_specs[family[0]])
		kinds[first.kind]=true
	check(kinds.size()==8 and variants.size()==game.board_specs.size(),"eight complete, playable families")
	for turn in 32:
		check(game.board_specs[Book.board_for(turn)].kind==game.board_specs[Book.board_for(turn+8)].kind,"family rotation repeats only after eight")
	game.open_workshop("menu")
	var before:=Logbook.new()
	game.practice_station("weights2")
	game.console.model.tap(0)
	game.console.model.tap(1)
	game.console.moved(game.console.model.tap(4))
	game.console._process(1)
	check(game.screen=="workshop" and Logbook.new().puzzle_turn==before.puzzle_turn,"practice returns without advancing the story")
	game.back()
	check(game.screen=="menu","workshop Back returns to its entrance")
	game.new_game()
	var r:=game.route
	var marker:Dictionary=r.stations[0]
	r.pos=Vector2(marker.x,marker.y)
	r.step(1.0/60,0,false,false)
	game.open_station()
	check(game.console.board_id==Book.board_for(0),"fresh voyage begins with the chart")
	for act in game.console.model.data.solution: operate(game.console.model,act)
	game.console.moved(true)
	game.console._process(1)
	check(r.puzzle_turn==1 and r.puzzle_wait==420.0,"solving starts seven minutes of exploration")
	game.pause_game()
	game._physics_process(75)
	check(r.puzzle_wait==420.0,"paused time does not advance the next puzzle")
	game.back()
	game.enter_room(Book.legacy_index(2),[])
	r=game.route
	marker=r.stations[0]
	r.pos=Vector2(marker.x,marker.y)
	r.step(1.0/60,0,false,false)
	check(r.near_station==-1 and r.completed==["s3"],"ordinary marker activates without a puzzle")
	game.checkpoint()
	game.continue_game()
	r=game.route
	check(r.puzzle_turn==1 and r.puzzle_wait>419 and r.completed==["s3"],"pacing and automatic checkpoint survive Continue")
	for frame in 25198: r.step(1.0/60,0,false,false)
	check(not r.needs_console(1),"next station stays open before seven minutes")
	for frame in 3: r.step(1.0/60,0,false,false)
	check(r.needs_console(1),"next unresolved station becomes eligible after seven minutes")
	marker=r.stations[1]
	r.pos=Vector2(marker.x,marker.y)
	r.step(1.0/60,0,false,false)
	game.open_station()
	check(game.console.model.kind=="relay","second scheduled encounter uses a new mechanic")
	game.close_console()
	game.open_settings("pause")
	for change in [25,25,25]:
		game.resize_controls(change)
	check(Logbook.new().button_percent==150 and game.hud.button_scale==1.5,"large controls persist at upper bound")
	for change in [-25,-25,-25,-25]:
		game.resize_controls(change)
	check(Logbook.new().button_percent==75,"small control bound")
	for value in [.75,1.0,1.25,1.5]:
		game.hud.button_scale=value
		for key in game.hud.zones():
			var c:Vector2=game.hud.zones()[key]
			var radius:float=value*(44 if key=="jump" else 40)
			check(game.hud.zone_at(c+Vector2(radius-1,0))==key and game.hud.zone_at(c-Vector2(radius-1,0))==key,"scaled button target matches "+key)
			check(Rect2(0,0,960,540).encloses(Rect2(c-Vector2.ONE*radius,Vector2.ONE*radius*2)),"touch bounds inside viewport")
	game.resize_controls(25)
	game.new_game()
	r=game.route
	for frame in 180:
		var cmd:=pilot(r)
		r.step(1.0/60,cmd[0],cmd[1],cmd[2])
		if r.ledge>=0: break
	if check(r.ledge>=0,"short jump catches first quay"):
		var edge:=r.ledge_anchor()
		var old_ledge:=r.ledge
		for frame in 20: r.step(1.0/60,0,false,false)
		check(r.ledge==old_ledge and r.pull_time<0 and r.pos.y>edge.y+30,"neutral input holds the edge")
		r.step(1.0/60,-1,false,false)
		check(r.ledge<0 and r.grab_lock>0,"away releases the edge")
		r.spawn()
		landing=-1
		for frame in 240:
			var cmd:=pilot(r)
			r.step(1.0/60,cmd[0],cmd[1],cmd[2])
			if r.ledge>=0: break
		r.step(1.0/60,0,true,false)
		for frame in 14: r.step(1.0/60,0,false,false)
		check(r.pull_time>0 and r.pos.y>edge.y and r.pos.y<edge.y+38,"pull-up has intermediate poses")
		for frame in 24: r.step(1.0/60,0,false,false)
		check(r.ledge<0 and r.grounded==old_ledge and absf(r.pos.y-edge.y)<1,"pull-up lands on top")
	var hound:=Passage.new(Book.legacy_index(1),["s2"])
	for d in hound.devices:
		if d.type!="hound": continue
		hound.pos=Vector2(d.x-295,d.y)
		hound.step(1.0/60,0,false,false)
		check(d.mode==1 and d.dog>hound.pos.x and "bark" in hound.events and "pursuit" in hound.events,"hound warns before pursuit")
		for frame in 140:
			hound.step(1.0/60,0,false,false)
			if hound.death_timer>0: break
		check(hound.death_timer>0,"hound catches a stationary keeper")
		for frame in 45: hound.step(1.0/60,0,false,false)
		check(d.mode==0 and absf(hound.pos.x-hound.checkpoint.x)<1,"chase resets safely")
	var steam:=Passage.new(Book.legacy_index(2),["s3"])
	for d in steam.devices:
		if d.type!="steam": continue
		steam.time=2.6
		steam.pos=Vector2(d.x,d.y)
		steam.step(.016,0,false,false)
		check(d.mode==1 and steam.death_timer==0,"vent warns harmlessly")
		steam.time=3.5
		steam.step(.016,0,false,false)
		check(steam.death_timer>0,"live steam is hazardous")
	var loose:=Passage.new(0,["s1"])
	for i in loose.platforms.size():
		var plank:Dictionary=loose.platforms[i]
		if plank.style!="loose": continue
		loose.pos=Vector2(plank.pos)+Vector2(30,0)
		loose.grounded=i
		for frame in 48: loose.step(1.0/60,0,false,false)
		check(not loose.is_solid(plank) and loose.grounded!=i,"loose deck gives way underfoot")
		loose.spawn()
		check(loose.is_solid(plank),"loose deck restores at checkpoint")
		break
	game.audio.set_enabled(true)
	game.audio.cooldown=0
	game.audio.score("pursuit")
	var first_stream:=game.audio.accent.stream
	check(first_stream.get_length()>=5 and first_stream.get_length()<=10,"short original encounter score")
	game.audio.score("undertow")
	check(game.audio.accent.stream==first_stream and game.audio.cooldown>60,"threats cannot stack or immediately repeat cues")
	game.audio.set_enabled(false)
	check(not game.audio.accent.playing,"sound off stops the score")
	game.new_game()
	landing=-1

func terrain_checks() -> void:
	var locks:=0
	var planks:Dictionary={}
	var lifts:Dictionary={}
	var lowest:float=-INF
	var highest:float=INF
	for i in Book.ROOMS.size():
		var r:=Passage.new(i)
		lowest=maxf(lowest,r.checkpoint.y)
		highest=minf(highest,r.checkpoint.y)
		check(is_equal_approx(float(r.platforms.back().pos.y),Book.deck_height(i+1)),"continuous elevation at "+str(i))
		check(r.pos.y-r.camera_y>=205 and r.pos.y-r.camera_y<=420,"visible entrance at "+str(i))
		for d in r.devices:
			if d.type=="lockpair": locks+=1
		var run_length:=0
		var lift_length:=0
		for p in r.platforms:
			if p.style=="loose": run_length+=1
			elif run_length:
				planks[run_length]=true
				run_length=0
			if p.style in ["float","bob"]: lift_length+=1
			elif lift_length:
				lifts[lift_length]=true
				lift_length=0
	check(locks==7,"manual lock transfers are distributed over seven locations")
	check(planks.has(4) and planks.has(10) and planks.size()>=6,"distinct short and long plank runs")
	check(lifts.has(1) and lifts.has(2) and lifts.has(5),"single pontoons and longer moving crossings")
	check(lowest-highest>650,"surveyed campaign includes waterfront and upper galleries")
	print("Terrain: %d manual locks, plank runs %s, moving deck runs %s." % [locks,planks.keys(),lifts.keys()])

	var encounter:=Passage.new(Book.legacy_index(1),["s2"])
	for d in encounter.devices:
		if d.type!="hound": continue
		encounter.pos=Vector2(d.x-355,d.y)
		var jumped:=false
		var passed:=false
		for tick in 240:
			var separation:float=d.dog-encounter.pos.x
			var jump:bool=not jumped and d.mode==2 and separation<110
			if jump: jumped=true
			encounter.step(1.0/60,1,jump,false)
			if encounter.death_timer>0: break
			if jumped and d.mode==2 and d.dog+27<encounter.pos.x and encounter.pos.y<d.y-27: passed=true
			if passed and encounter.is_grounded(): break
		check(jumped and passed and encounter.is_grounded() and encounter.death_timer==0,"keeper clears the oncoming hound with one running jump")
		var turned:=false
		for frame in 360:
			encounter.step(1.0/60,0,false,false)
			if d.mode==2 and d.facing==1: turned=true
			if encounter.death_timer>0: break
		check(turned and encounter.death_timer>0,"hound catches the keeper on its return run")
		break

func vehicle_checks() -> void:
	for source in [61,68]:
		game.enter_room(Book.migrated_room(source),[])
		var r:=game.route
		var vehicle:Dictionary=r.rides[0]
		var height:=float(vehicle.ground_y)
		r.pos=Vector2(vehicle.start-10,height)
		r.step(1.0/60,0,false,false)
		check(r.active_ride==-1 and vehicle.position==Vector2(vehicle.start,height),"ride waits at its boarding point")
		r.pos.x=vehicle.start
		r.step(1.0/60,0,false,false)
		check(r.active_ride==0 and vehicle.position==r.pos,"boarding moves the existing ride")
		game.pause_game()
		var stopped:Vector2=vehicle.position
		game._physics_process(.5)
		check(game.scenery.mode=="play" and vehicle.position==stopped and r.active_ride==0,"pause keeps the mounted ride in the world")
		game.set_screen("play")
		r.pos=Vector2(vehicle.end-1,height)
		r.vel.x=r.SPEED
		r.step(1.0/60,1,false,false)
		for frame in 10: r.step(1.0/60,1,false,false)
		check(r.active_ride==-1 and vehicle.arrived and vehicle.position==Vector2(vehicle.end,height),"dismount leaves the ride at the terminus")

func stationary_transfer_check() -> void:
	game.enter_room(Book.migrated_room(25),["w3"])
	var r:=game.route
	for i in r.platforms.size():
		var p:Dictionary=r.platforms[i]
		if p.style!="chamber" or p.side!=0: continue
		var lock:Dictionary=r.devices[p.device]
		lock.mode=1
		lock.first=1.0
		r.update_platforms()
		r.pos=p.pos+Vector2(p.w*.84,0)
		r.grounded=i
		r.step(1.0/60,0,false,false)
		var hand:Vector2=game.hud.zones().use
		touch(0,hand,true)
		touch(0,hand,false)
		for frame in 105: r.step(1.0/60,0,false,false)
		check(lock.mode==2 and r.grounded==i+1 and r.death_timer==0,"one hand tap carries stationary keeper onto chamber II")
		break

func debug_chapter_checks() -> void:
	check(Book.CHAPTERS.size()==8 and Book.CHAPTER_STARTS.back()==Book.ROOMS.size(),"eight variable-length chapters")
	var saved:=Logbook.new()
	for i in Book.CHAPTERS.size():
		game.set_screen("chapters")
		var buttons:=game.hud.get_children().filter(func(node): return node is Button)
		var entry:Button=buttons[i]
		check(not entry.disabled and Book.CHAPTERS[i] in entry.text,"unlocked chapter "+str(i+1))
		entry.pressed.emit()
		check(game.replay and game.route.room==Book.CHAPTER_STARTS[i],"correct replay entrance")
		game.enter_room(Book.CHAPTER_STARTS[i+1]-1,[])
		game.room_finished()
		check(game.screen==("aim" if i==7 else "chapters"),"chapter boundary")
	check(Logbook.new().room==saved.room and Logbook.new().opened==saved.opened,"debug replays preserve earned story progress")
	game.new_game()
	var r:=Passage.new(Book.legacy_index(1))
	var crate:Dictionary=r.freight[0]
	r.pos=Vector2(crate.x-31,crate.y)
	r.step(1.0/60,0,false,false)
	var start:=float(crate.x)
	for frame in 10: r.step(1.0/60,1,false,true)
	check(r.held_crate==0 and not r.hauling_back and r.face==1 and crate.x>start,"pushing leans toward cargo")
	for frame in 20: r.step(1.0/60,-1,false,true)
	check(r.held_crate==0 and r.hauling_back and r.face==1 and crate.x<start,"pulling steps backwards facing cargo")
	r.step(1.0/60,0,false,false)
	check(r.held_crate<0,"release returns to walking pose")

func run() -> void:
	game=Main.new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	lifecycle_checks()
	checkpoint_checks()
	boards=game.board_specs
	update_checks()
	terrain_checks()
	vehicle_checks()
	stationary_transfer_check()
	debug_chapter_checks()
	for index in Book.ROOMS.size():
		run_room(index)
	check(gameplay_seconds>=3600,"full voyage contains at least one hour of tested traversal")
	check(used.size()>=8 and used.size()<=1+floori(gameplay_seconds/420),"all eight families fit the required puzzle pacing")
	if check(game.screen=="aim","final lens reached"):
		game.aim=0
		game.signal_ferry()
		check(game.screen=="aim","off-target signal can be retried")
		game.aim=(663.0-308.0)/560.0
		game.signal_ferry()
		check(game.screen=="arrival" and Logbook.new().ended,"final beacon and persistent completion")
		game._process(12.1)
		check(game.screen=="final","homecoming ending")
		game.open_credits("final")
		check(game.screen=="credits","credits reached from ending")
	print("Checked %d rooms, %d scheduled puzzles, %d solution inputs, %.1f seconds of solved traversal. Failures: %d" % [Book.ROOMS.size(),used.size(),solution_moves,gameplay_seconds,bad])
	game.audio.set_enabled(false)
	await create_timer(.35).timeout
	game.queue_free()
	await process_frame
	quit(1 if bad else 0)
