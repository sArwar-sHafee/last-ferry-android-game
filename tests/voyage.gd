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
	if r.ladder>=0:
		var climbing_up: bool=r.key_gates.is_empty() or r.key_gates[0].key_taken
		return [1 if climbing_up else -1,false,false]
	for gate in r.key_gates:
		if gate.open: continue
		var rungs: Dictionary=r.ladders[0]
		var below:=r.pos.y>=float(rungs.bottom)-3
		if below and not gate.key_taken:
			return [1,false,false]
		if r.nearby_ladder()>=0 and (below or not gate.key_taken):
			r.toggle_ladder()
			return [1 if gate.key_taken else -1,false,false]
		if below and gate.key_taken:
			return [-1,false,false]
		r.use_key_gate()
	if r.key_gates.is_empty() and r.nearby_ladder()>=0 and r.pos.y>float(r.ladders[0].top)+20:
		r.toggle_ladder()
		return [1,false,false]
	if r.ledge>=0: return [float(r.ledge_face),false,false]
	var axis := 1.0
	var jump := false
	var grip := false
	if r.near_valve>=0:
		var device:Dictionary=r.devices[r.near_valve]
		if (r.valve_action=="Fill chamber I" and int(device.mode)==0) or (r.valve_action=="Transfer to II" and int(device.mode)==1):
			game.use_nearby()
	for roof in r.structures:
		var distance:=float(roof.x)-r.pos.x
		if distance>8 and distance<28:
			var ready: bool=roof.cycle>=1.5 and roof.cycle<2.2 if roof.moving else roof.cycle<2.0 or roof.cycle>=3.95
			if not ready: return [0,false,false]
	for device in r.devices:
		if device.type=="spikes" and r.is_grounded() and float(device.x)-r.pos.x>29 and float(device.x)-r.pos.x<56:
			landing=-1
			return [1,true,false]
		if device.type=="cable_drum" and device.mode in [1,2] and device.roll_x>r.pos.x-24:
			var takeoff:=float(device.trigger)+42
			var refuge:=float(device.trigger)+126
			if r.pos.x>=takeoff and r.pos.x<refuge and r.is_grounded() and r.pos.y>float(device.y)-2:
				landing=-1
				return [1,true,false]
			if r.pos.x>=refuge:
				landing=-1
				return [0,false,false]
		if device.type in ["hound","spider"] and device.mode==2 and r.is_grounded():
			var distance:float=(r.pos.x-float(device.dog))*float(device.facing)
			var closing:float=float(device.speed)+r.SPEED if device.facing<0 else float(device.speed)-r.SPEED
			var takeoff:=closing*.31 if device.facing<0 else 25.0+closing*.135
			if distance>0 and distance<takeoff:
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
	if p.style=="rocker" and nxt.style=="skiff":
		var takeoff_time:=maxf(0,(lead-12)/r.SPEED)+(r.SPEED-r.vel.x)/2700.0
		var phase:=r.time-float(r.restored_at.get(nxt.key,0))
		var arriving:=float(nxt.base.x)+float(nxt.delta.x)*(.5-.5*cos((phase+takeoff_time+.57)*float(nxt.rate)))
		if arriving-edge<74:
			return [1,lead<13,false]
		var middle:float=p.pos.x+p.w*.58
		return [clampf((middle-r.pos.x-r.vel.x*.12)/10,-1,1),false,false]
	var jump_lead:=9.0 if gap>=80 or nxt.style=="cargo_net" else 19.0
	if gap>6 and lead<jump_lead:
		# Wait for traveling ferries and lifting hooks before stepping off.
		var safe_gap:=68.0 if p.style=="skiff" else 50.0
		if gap>safe_gap and (p.delta.x!=0 or nxt.delta.x!=0):
			return [0,false,false] if lead>5 else [-.4,false,false]
		jump=true
	elif gap<=6 and drop < -7 and lead<32: jump=true
	return [axis,jump,grip]

func run_room(index: int) -> void:
	# The game itself loads the following room on reaching its exit.
	if not check(game.route!=null and game.route.room==index,"normal room transition "+str(index)): return
	if Book.CHAPTER_STARTS.has(index):
		check(Logbook.new().opened>=Book.chapter(index),"story progress unlocks the chapter when its entrance is reached")
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
		if "splash" in r.events or "impact" in r.events: deaths+=1
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
	game.audio.set_enabled(true)
	game.new_game()
	check(game.hud.intro>0 and game.audio.story.playing,"opening narration starts the story score")
	var before_dialogue:=game.route.pos
	touch(1,game.hud.zones().right,true)
	touch(2,game.hud.zones().jump,true)
	game.back()
	game._physics_process(1.0/60)
	check(game.hud.controls_locked and game.route.pos==before_dialogue and game.screen=="play",
		"movement, jump, and Back stay locked during Mara’s dialogue")
	game.pause_game()
	check(game.audio.story.stream_paused,"story score pauses with the text")
	game.back()
	check(not game.audio.story.stream_paused,"resuming unpauses the story score")
	game._process(game.hud.intro-.5)
	check(game.audio.story.volume_db<-9,"story score fades with the text")
	game._process(.6)
	check(not game.audio.story.playing and not game.hud.controls_locked,"clearing the dialogue stops the story score and unlocks controls")
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
	var fairway:=Book.migrated_room(149)
	game.enter_room(fairway,[])
	game.open_station()
	check(game.screen=="play","distant use cannot open a station")
	var r:=game.route
	var lamp: Dictionary=r.stations[0]
	r.pos=Vector2(lamp.x,lamp.y)
	r.step(1.0/60,0,false,false)
	check(r.near_station<0 and r.completed==["p10"],"ordinary lamp saves automatically before the assigned puzzle")
	game.checkpoint()
	game.continue_game()
	r=game.route
	check(r.completed==["p10"] and r.needs_console(1),"Continue restores the first lamp and keeps the next puzzle available")
	var s: Dictionary=r.stations[1]
	r.pos=Vector2(float(s.x)+84,s.y)
	for j in 35: r.step(1.0/60,1,false,false)
	check(r.pos.x<=float(s.x)+86.1 and not r.finish,"an early approach cannot bypass a closed gate")
	r.pos=Vector2(s.x,s.y)
	r.step(1.0/60,0,false,false)
	game.open_station()
	check(game.console.board_id=="chart2","the fairway checkpoint opens its assigned chart")
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
	check(saved.room==fairway and saved.cleared==["p10","l10"],"on-disk checkpoint records both stations")
	# A fresh launch resumes on the safe side of the solved station.
	var fresh:=Main.new()
	root.add_child(fresh)
	fresh.continue_game()
	check(fresh.route.room==fairway and fresh.route.completed==["p10","l10"] and fresh.route.pos.x>float(s.x),"Continue after a fresh launch restores position and machinery")
	fresh.play_chapter(0)
	fresh.leave_voyage()
	check(Logbook.new().room==fairway and Logbook.new().cleared==["p10","l10"],"chapter replay preserves the story checkpoint")
	fresh.audio.set_enabled(false)
	fresh.queue_free()
	var shutter:=Passage.new(Book.migrated_room(105),["l2","l3"])
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
	old_save.set_value("voyage","room",21)
	old_save.set_value("voyage","cleared",["l2"])
	old_save.save(path)
	var upgraded:=Logbook.new(path)
	check(upgraded.room==Book.legacy_index(21) and upgraded.cleared==["l2"],"version one save maps to the same landmark and checkpoint")
	upgraded.store()
	check(Logbook.new(path).room==upgraded.room,"upgraded room is migrated only once")
	var old_campaign:=ConfigFile.new()
	old_campaign.set_value("voyage","layout",6)
	old_campaign.set_value("voyage","room",38)
	old_campaign.set_value("voyage","opened",8)
	old_campaign.set_value("voyage","cleared",["f2"])
	old_campaign.save(path)
	var retained:=Logbook.new(path)
	check(retained.room==Book.migrated_room(55) and retained.cleared==["f2"] and retained.opened==Book.chapter(retained.room),
		"the old Freightyard keeps its matching checkpoint and unlock")
	old_campaign.set_value("voyage","room",8)
	old_campaign.set_value("voyage","opened",2)
	old_campaign.save(path)
	var retired:=Logbook.new(path)
	check(retired.room==Book.migrated_room(20) and retired.cleared.is_empty(),"retired Customs Reach resumes at the canopy entrance")
	old_campaign.set_value("voyage","room",57)
	old_campaign.set_value("voyage","opened",12)
	old_campaign.save(path)
	var former_ride:=Logbook.new(path)
	check(former_ride.room==Book.migrated_room(88) and not Passage.new(former_ride.room).boar_road,
		"an old Engine Galleries boar save resumes on foot")
	game.new_game()

func update_checks() -> void:
	# Every workshop variation is solvable using actual taps.
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
	game.open_workshop("menu")
	var before:=Logbook.new()
	game.practice_station("weights2")
	game.console.model.tap(0)
	game.console.model.tap(1)
	game.console.moved(game.console.model.tap(4))
	game.console._process(1)
	var after:=Logbook.new()
	check(game.screen=="workshop" and after.room==before.room and after.cleared==before.cleared,"practice returns without advancing the story")
	game.back()
	check(game.screen=="menu","workshop Back returns to its entrance")
	game.new_game()
	game._process(7.1)
	var r:=game.route
	game.pause_game()
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
	var hound:=Passage.new(Book.migrated_room(6),["4a"])
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
	var steam:=Passage.new(Book.migrated_room(34),["7a"])
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

func hazard_and_storm_checks() -> void:
	var fall:=Passage.new(0)
	fall.pos.y=550
	fall.step(1.0/60,0,false,false)
	check("splash" in fall.events and not "impact" in fall.events,"a fall plays the water splash only")
	var encounter:=Passage.new(Book.migrated_room(6),["4a"])
	for device:Dictionary in encounter.devices:
		if device.type!="hound": continue
		device.mode=2
		encounter.pos=Vector2(device.dog,device.y)
		encounter.step(1.0/60,0,false,false)
		check("impact" in encounter.events and not "splash" in encounter.events,"hound contact plays the dry impact only")
		break
	game.audio.set_enabled(true)
	var splash_voice:AudioStreamPlayer=game.audio.layers[game.audio.cursor]
	game.audio.cue("splash")
	check(splash_voice.volume_db==-10,"the water death cue keeps its volume")
	var impact_voice:AudioStreamPlayer=game.audio.layers[game.audio.cursor]
	game.audio.cue("impact")
	check(is_equal_approx(impact_voice.volume_db,6+linear_to_db(2.0)),"other deaths play at double the previous gain")
	var landing_voice:AudioStreamPlayer=game.audio.layers[game.audio.cursor]
	game.audio.cue("land")
	check(landing_voice.volume_db==-5,"ordinary landings keep their volume")
	game.audio.set_enabled(false)

	var skiffs:=0
	var hoists:=0
	for index in Book.ROOMS.size():
		for platform:Dictionary in Passage.new(index).platforms:
			if platform.style=="skiff":
				skiffs+=1
				check(is_equal_approx(platform.rate,1.03),"skiff has the faster crossing rate")
			elif platform.style=="hoist":
				hoists+=1
				check(is_equal_approx(platform.rate,.76),"freight hoist retains its crossing rate")
	check(skiffs>0 and hoists>0,"skiff and hoist rates are both exercised")

	var boar_chapter:=Book.chapter(Book.migrated_room(68))
	for index in Book.ROOMS.size():
		var boar_scene:=Passage.new(index)
		check(boar_scene.boar_road==(Book.chapter(index)==boar_chapter),"boar stays within Boar Run")
		if boar_scene.boar_road:
			check(boar_scene.rides.size()==1,"one boar crosses each mounted scene")

	var scenery:=game.scenery
	scenery.route=Passage.new(Book.CHAPTER_STARTS[Book.CHAPTERS.size()-1])
	scenery.storm_rng.seed=1193
	scenery.storm_seconds()
	var dark_intervals:={}
	var short_intervals:={}
	var flash_counts:={}
	game.audio.set_enabled(true)
	for i in 30:
		scenery.route.elapsed=scenery.next_strike
		check(scenery.storm_seconds()==0,"a scheduled lightning strike starts")
		var duration: float=scenery.strike_duration()
		var dark: float=scenery.next_strike-scenery.storm_began-duration
		if scenery.strike_count==1:
			check(dark>=.99 and dark<=2.21,"the next flash follows a single flash sooner")
			short_intervals[roundi(dark*10)]=true
		else:
			check(dark>=2.59 and dark<=7.41,"a burst is followed by a longer random dark interval")
			dark_intervals[roundi(dark*10)]=true
		var flashes:=0
		var bright:=false
		for frame in ceili(duration*120):
			var next_bright: bool=scenery.storm_bolt_light(frame/120.0)>.45
			if next_bright and not bright: flashes+=1
			bright=next_bright
		check(flashes==scenery.strike_count,"each scheduled flash has a distinct brightness peak")
		check(duration<.5 if flashes==1 else duration>1.8,"single flashes fade quickly and bursts retain a longer afterglow")
		flash_counts[flashes]=true
		var thunder_voice: AudioStreamPlayer=game.audio.layers[game.audio.cursor]
		var thunder_key:="thunder_distant" if flashes==1 else "thunder"
		scenery.route.elapsed=scenery.thunder_at
		scenery.storm_seconds()
		check(thunder_voice.stream==game.audio.samples[thunder_key],"single flashes and bursts play their matching thunder recordings")
	game.audio.set_enabled(false)
	check(flash_counts.has_all([1,2,3]),"the storm randomly produces singles, doubles, and triples")
	check(short_intervals.size()>1,"the shorter pause also varies")
	check(dark_intervals.size()>6,"dark intervals vary instead of repeating a fixed cycle")
	scenery.route=game.route
	scenery.storm_route=null

func bridge_checks() -> void:
	var standard_count:=0
	var wide_count:=0
	var bridge_count:=0
	for room in Book.ROOMS.size():
		var tokens:=str(Book.ROOMS[room][1]).split(" ")
		standard_count+=tokens.count("causeway")
		wide_count+=tokens.count("wide_causeway")
		var layout:=Passage.new(room)
		for i in range(1,layout.platforms.size()-1):
			var bridge:Dictionary=layout.platforms[i]
			if bridge.style=="wide_pier" and layout.platforms[i+1].style=="wide_pier":
				var gap:float=layout.platforms[i+1].pos.x-bridge.pos.x-bridge.w
				check(gap>=72 and gap<=88,"wide causeway places long gaps in room "+str(room))
			if bridge.style!="rocker": continue
			bridge_count+=1
			var left:Dictionary=layout.platforms[i-1]
			var right:Dictionary=layout.platforms[i+1]
			var exit_gap:float=right.pos.x-bridge.pos.x-bridge.w
			var safe_exit:=exit_gap>=46 and exit_gap<=58 if right.style=="skiff" else exit_gap==74
			check(bridge.pos.x-left.pos.x-left.w==74 and safe_exit,
				"tilting bridge has gaps on both sides in room "+str(room))
			for direction in [-1,1]:
				var keys:=layout.stations.map(func(station): return station.key)
				var ride:=Passage.new(room,keys)
				var beam:Dictionary=ride.platforms[i]
				var device:Dictionary=ride.devices[beam.device]
				ride.pos=beam.pos+Vector2(beam.w*(.5+direction*.30),0)
				ride.grounded=i
				var start:=ride.pos.x
				for frame in 60: ride.step(1.0/60,0,false,false)
				check(device.tilt*direction>.35 and (ride.pos.x-start)*direction>15,
					"unbraced keeper slides down the steep bridge in room "+str(room))
				for frame in 160:
					ride.step(1.0/60,0,false,false)
					if ride.death_timer>0: break
				if right.style!="skiff":
					check(ride.death_timer>0,"keeper falls without jumping off the bridge in room "+str(room))
	check(bridge_count==4 and standard_count==1 and wide_count==3,"solo bridge and both causeway variants are placed")

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
	check(locks==2,"one teaching lock and one later two-chamber transfer")
	check(planks.has(3) and planks.has(4) and planks.has(7),"plank crossings grow from three to seven boards")
	check(lifts.size()>=2,"moving crossings have distinct lengths")
	check(lowest-highest>650,"surveyed campaign includes waterfront and upper galleries")
	print("Terrain: %d manual locks, plank runs %s, moving deck runs %s." % [locks,planks.keys(),lifts.keys()])

	var encounter:=Passage.new(Book.migrated_room(6),["4a"])
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
	game.enter_room(Book.migrated_room(54),["3a"])
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

	# A normal approach can grab the block, but the same pose on either ride cannot.
	for source in [54,68]:
		var layout:=Passage.new(Book.migrated_room(source))
		var ride:Dictionary=layout.rides[0]
		var deck:Dictionary=layout.platforms[0]
		layout.pos=deck.pos+Vector2(-8,24)
		layout.grounded=-1
		layout.active_ride=0
		layout.mounted=ride.type
		layout.catch_ledge(1)
		check(layout.ledge<0,"ledge grab is disabled while mounted on "+str(ride.type))
		layout.active_ride=-1
		layout.mounted=""
		layout.catch_ledge(1)
		check(layout.ledge==0,"ledge grab still works on foot")

	var opening:=Book.migrated_room(68)
	game.enter_room(opening,[])
	var road:=game.route
	var boar:Dictionary=road.rides[0]
	check(road.rides.size()==1 and road.active_ride<0 and float(boar.position.x)>road.pos.x,
		"the keeper starts on foot beside a waiting boar")
	for frame in 12: road.step(1.0/60,0,false,false)
	check(road.active_ride<0 and not road.events.has("boar_call"),"the boar waits for the keeper to approach")
	for frame in 65:
		road.step(1.0/60,1,false,false)
		if road.active_ride>=0: break
	check(road.active_ride==0 and road.mounted=="ride" and road.events.count("boar_call")==1,
		"approaching the tether starts the ride with one boar call")
	for frame in 12: game._physics_process(1.0/60)
	var cruise:=road.vel.x
	touch(6,game.hud.zones().left,true)
	for frame in 12: game._physics_process(1.0/60)
	check(road.vel.x>0 and road.vel.x<cruise-24.0,"left touch brakes the boar while it keeps moving forward")
	touch(6,game.hud.zones().left,false)
	touch(7,game.hud.zones().right,true)
	for frame in 12: game._physics_process(1.0/60)
	check(road.vel.x>cruise+24.0,"right touch speeds up the boar")
	touch(7,game.hud.zones().right,false)
	for frame in 12: game._physics_process(1.0/60)
	check(is_equal_approx(road.vel.x,cruise),"releasing the controls restores cruising speed")
	var station:Dictionary=road.stations[0]
	road.pos=Vector2(station.x,station.y)
	road.step(1.0/60,0,false,false)
	check(road.active_ride==0 and road.near_station<0 and road.completed.size()==1,
		"boar checkpoint advances without a dismount or puzzle")
	road.spawn()
	check(road.active_ride==0 and road.pos==road.checkpoint and is_same(boar,road.rides[0]),"checkpoint recovery keeps the boar")
	road.finish=true
	road.vel.x=150
	game.room_finished()
	check(game.route.room==opening+1 and game.route.active_ride==0 and is_same(boar,game.route.rides[0]) and game.route.vel.x==150,
		"the same boar carries its momentum into the next scene")
	game.enter_room(Book.migrated_room(71),[])
	game.route.finish=true
	game.room_finished()
	check(game.route.room==Book.migrated_room(88) and game.route.active_ride<0 and game.route.rides.is_empty(),
		"the keeper enters the Engine Galleries on foot")

func boar_speed_crossing_checks() -> void:
	var chapter:=Book.chapter(Book.migrated_room(68))
	for direction in [-1,0,1]:
		for room in range(Book.CHAPTER_STARTS[chapter],Book.CHAPTER_STARTS[chapter+1]):
			var ride:=Passage.new(room)
			landing=-1
			for frame in 1800:
				var jump: bool=pilot(ride)[1]
				if ride.grounded>=0 and ride.grounded+1<ride.platforms.size():
					var deck: Dictionary=ride.platforms[ride.grounded]
					var next: Dictionary=ride.platforms[ride.grounded+1]
					var edge: float=deck.pos.x+deck.w
					# A faster approach jumps earlier. At the slow pace, use more of the deck.
					if next.pos.x-edge>6: jump=edge-ride.pos.x<19+direction*11
				ride.step(1.0/60,1 if ride.active_ride<0 else direction,jump,false)
				if ride.finish or ride.death_timer>0: break
			check(ride.finish and ride.death_timer==0,"mounted scene clears at speed input %d" % direction)

func chamber_transfer_checks() -> void:
	var hand:Vector2=game.hud.zones().use
	for room in Book.ROOMS.size():
		var layout:=Passage.new(room)
		var cleared:Array=layout.stations.map(func(station): return station.key)
		for i in layout.platforms.size():
			var platform:Dictionary=layout.platforms[i]
			if platform.style!="chamber" or platform.side!=0: continue
			for fill in [0.72,1.0]:
				game.enter_room(room,cleared)
				var r:=game.route
				var first:Dictionary=r.platforms[i]
				var second:Dictionary=r.platforms[i+1]
				var lock:Dictionary=r.devices[first.device]
				lock.mode=1
				lock.first=fill
				r.update_platforms()
				r.pos=first.pos+Vector2(first.w*.84,0)
				r.grounded=i
				r.step(1.0/60,0,false,false)
				check(r.valve_action=="Transfer to II","chamber I offers transfer in room "+str(room))
				var start_x:=r.pos.x
				var first_before:Vector2=first.pos
				var second_before:Vector2=second.pos
				for press in 2:
					touch(press,hand,true)
					touch(press,hand,false)
				for frame in 18: r.step(1.0/60,0,false,false)
				check(lock.mode==2 and r.grounded==i and is_equal_approx(r.pos.x,start_x)
					and first.pos.x==first_before.x and first.pos.y>first_before.y
					and second.pos.x==second_before.x and second.pos.y<second_before.y and r.chamber_jump,
					"the two floats move vertically without carrying the keeper sideways in room "+str(room))
				r.step(1.0/60,1,true,false)
				check(r.grounded<0,"keeper jumps off chamber I in room "+str(room))
				for frame in 65:
					r.step(1.0/60,1,false,false)
					if r.grounded==i+1 or r.death_timer>0: break
				check(r.grounded==i+1 and r.death_timer==0,"jump lands on the rising second float in room "+str(room))

func menu_button(caption: String) -> Button:
	for node in game.hud.get_children():
		if node is Button and node.text==caption: return node
	return null

func chapter_progress_checks() -> void:
	if check(menu_button("Support")!=null,"Support appears on the title screen"):
		menu_button("Support").pressed.emit()
		check(game.screen=="support" and menu_button("Star on GitHub")!=null,"Support opens GitHub support options")
		game.back()
	game.open_credits("menu")
	check(game.hud.get_children().any(func(node): return node is Label and "GPT 6.2 Astra" in node.text),
		"the credits name the development model")
	game.set_screen("chapters")
	check(game.hud.get_children().filter(func(node): return node is Button).size()==3,
		"only chapter one and the navigation actions appear on a fresh install")
	game.play_chapter(1)
	check(game.screen=="chapters" and game.route==null,"locked chapters cannot be opened directly")
	game.play_chapter(0)
	game.enter_room(Book.CHAPTER_STARTS[1]-1,[])
	game.room_finished()
	var saved:=Logbook.new()
	check(game.screen=="chapters" and saved.opened==1 and not saved.active,
		"completing the first chapter from the picker unlocks chapter two independently of the story checkpoint")

func developer_name_checks() -> void:
	game.open_settings("menu")
	var name_input:LineEdit=game.hud.get_children().filter(func(node): return node is LineEdit)[0]
	for value in ["sha2027","SHA2027 "," SHA2027","SHA2027X"]:
		name_input.text_changed.emit(value)
		check(not game.hud.scene_skip_enabled,"developer mode requires an exact name match")
	name_input.text_changed.emit("SHA2027")
	check(game.hud.scene_skip_enabled,"the exact keeper name activates developer mode")
	game.back()
	check(Logbook.new().keeper_name=="SHA2027","leaving settings saves the keeper name")
	var fresh:=Main.new()
	root.add_child(fresh)
	check(fresh.hud.scene_skip_enabled,"developer mode is restored with the keeper name")
	fresh.queue_free()

func debug_skip_checks() -> void:
	var last_in_chapter:int=Book.CHAPTER_STARTS[1]-1
	game.enter_room(last_in_chapter,[])
	var saved:=Logbook.new()
	var key:=InputEventKey.new()
	key.keycode=KEY_R
	key.pressed=true
	game._input(key)
	check(game.screen=="play" and game.route.room==last_in_chapter+1 and game.replay,
		"R opens the next scene across a chapter boundary")
	var skip_button:=game.hud.SKIP_SCENE_RECT.get_center()
	touch(0,skip_button,true)
	touch(0,skip_button,false)
	check(game.route.room==last_in_chapter+1,"a repeated skip input in the same frame is ignored")
	game.last_skip_frame=-1
	touch(0,skip_button,true)
	touch(0,skip_button,false)
	check(game.route.room==last_in_chapter+2,"the skip icon advances the scene")
	var after:=Logbook.new()
	check(after.room==saved.room and after.cleared==saved.cleared and after.opened==saved.opened,
		"debug skips leave the main voyage save intact")
	game.last_skip_frame=-1
	game.enter_room(Book.ROOMS.size()-1,[])
	game._input(key)
	check(game.screen=="aim","skipping the last scene opens the final beacon")
	game.new_game()
	game._process(7.1)
	game.last_skip_frame=-1
	game._input(key)
	var lamp: Dictionary=game.route.stations[0]
	game.route.pos=Vector2(lamp.x,lamp.y)
	game.route.step(1.0/60,0,false,false)
	game.open_station()
	check(game.route.room==1 and game.screen=="play" and game.route.completed==["0a"],
		"skipping the landing leaves the chart behind and the Ropewalk lamp saves automatically")
	game.play_chapter(1)
	var relay: Dictionary=game.route.stations[0]
	game.route.pos=Vector2(relay.x,relay.y)
	game.route.step(1.0/60,0,false,false)
	game.open_station()
	check(game.screen=="console" and game.console.board_id=="relay1","Chapter 2 replay opens its own relay")
	game.close_console()

func puzzle_skip_checks() -> void:
	for index in range(Book.CHAPTER_STARTS[10],Book.CHAPTER_STARTS[11]):
		check(Passage.new(index).stations.all(func(station): return station.board.is_empty()),
			"the gorilla chapter uses automatic checkpoints")
	var index:=Book.migrated_room(135)
	game.enter_room(index,[])
	var lamp: Dictionary=game.route.stations[0]
	check(lamp.board=="s2","Storm Glass hosts the relocated skiff puzzle")
	game.route.pos=Vector2(lamp.x,lamp.y)
	game.route.step(1.0/60,0,false,false)
	game.open_station()
	var skip:=game.console.get_children().filter(func(node): return node is Button and node.text=="Skip puzzle")
	if check(skip.size()==1,"the developer sees a Skip puzzle button"):
		check(not game.console.model.solved(),"the board starts unsolved")
		skip[0].pressed.emit()
		check(game.screen=="play" and game.route.completed==["p9"],"the skipped campaign board unlocks the route")
	game.open_workshop("menu")
	game.practice_station("chart1")
	var practice_skip:=game.console.get_children().filter(func(node): return node is Button and node.text=="Skip puzzle")
	if check(practice_skip.size()==1,"the developer can skip in the workshop"):
		practice_skip[0].pressed.emit()
		check(game.screen=="workshop","skipping a practice puzzle returns to the workshop")
	game.update_keeper_name("")
	game.practice_station("chart1")
	check(not game.console.get_children().any(func(node): return node is Button and node.text=="Skip puzzle"),
		"regular players have no skip button")
	game.skip_puzzle()
	check(game.screen=="console","regular players cannot bypass a board")
	game.leave_practice()
	game.update_keeper_name("SHA2027")

func debug_chapter_checks() -> void:
	check(Book.CHAPTERS.size()==13 and Book.CHAPTER_STARTS.back()==Book.ROOMS.size(),"13 chapters cover every scene")
	var backgrounds:={}
	var saved:=Logbook.new()
	game.chapter_page=0
	game.set_screen("chapters")
	for i in Book.CHAPTERS.size():
		var count:=Book.CHAPTER_STARTS[i+1]-Book.CHAPTER_STARTS[i]
		check(count>=2 and count<=5,"short chapter "+str(i+1))
		var backdrop:Texture2D=Book.CHAPTERS[i][2]
		check(not backgrounds.has(backdrop.resource_path.get_file()),"distinct backdrop for chapter "+str(i+1))
		backgrounds[backdrop.resource_path.get_file()]=true
		check(ResourceLoader.exists("res://audio/reach%02d.ogg" % Book.CHAPTERS[i][3]),"chapter ambience is packaged")
		var buttons:=game.hud.get_children().filter(func(node): return node is Button)
		if i>0 and i%game.CHAPTERS_PER_PAGE==0:
			var next:Button=buttons.filter(func(button): return button.text=="Next")[0]
			check(not next.disabled,"can open the next chapter page")
			next.pressed.emit()
			buttons=game.hud.get_children().filter(func(node): return node is Button)
		var entry:Button=buttons[i%game.CHAPTERS_PER_PAGE]
		check(not entry.disabled and Book.chapter_name(i) in entry.text,"unlocked chapter "+str(i+1))
		entry.pressed.emit()
		check(game.replay and game.route.room==Book.CHAPTER_STARTS[i],"correct replay entrance")
		game.enter_room(Book.CHAPTER_STARTS[i+1]-1,[])
		game.room_finished()
		if i==Book.CHAPTERS.size()-1:
			check(game.screen=="aim","last chapter reaches the beacon")
		else:
			check(game.screen=="chapters","returns to picker at chapter boundary")
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

func disable_developer_checks() -> void:
	game.chapter_page=2
	game.open_settings("menu")
	var name_input:LineEdit=game.hud.get_children().filter(func(node): return node is LineEdit)[0]
	name_input.text_changed.emit("Keeper")
	game.back()
	game.set_screen("chapters")
	var last_earned_page:=floori(float(game.logbook.opened)/game.CHAPTERS_PER_PAGE)
	check(game.chapter_page==last_earned_page and Logbook.new().keeper_name=="Keeper","renaming restores the earned chapter list")
	game.new_game()
	var key:=InputEventKey.new()
	key.keycode=KEY_R
	key.pressed=true
	game._input(key)
	var skip_target:=game.hud.SKIP_SCENE_RECT.get_center()
	check(game.hud.zone_at(skip_target).is_empty(),"the skip icon is hidden for a regular keeper name")
	touch(0,skip_target,true)
	touch(0,skip_target,false)
	check(game.route.room==0 and not game.replay,"skip taps and shortcuts cannot advance a regular voyage")

func component_section(token: String) -> Passage:
	var r:=Passage.new(0)
	for station in r.stations: r.completed.append(station.key)
	r.checkpoint=Vector2(r.width+26,r._y)
	r.build_section(token)
	r.dock(180)
	r.width=r._x
	r.spawn()
	return r

func unplaced_component_checks() -> void:
	const DT:=1.0/60.0
	var r:=component_section("elephant")
	var elephant:Dictionary=r.devices.back()
	for frame in 90:
		r.step(DT,1,false,false)
		if r.pos.x>=float(elephant.x)+20: break
	check(r.pos.x>=float(elephant.x)+20 and elephant.mode==0 and elephant.foot_x==elephant.x,"elephant grazes while the keeper approaches")
	for frame in 75: r.step(DT,1,false,false)
	check(elephant.mode==2 and elephant.foot_x>elephant.x,"elephant runs after a keeper who has passed")
	for frame in 150:
		r.step(DT,0,false,false)
		if r.death_timer>0: break
	check(r.death_timer>0 and r.events.has("impact"),"elephant catches a keeper who stops")
	for frame in 42: r.step(DT,0,false,false)
	check(elephant.mode==0 and elephant.foot_x==elephant.x,"checkpoint restores grazing elephant")
	for frame in 400:
		r.step(DT,1,false,false)
		if r.death_timer>0 or r.finish: break
	check(r.finish,"keeper can outrun the elephant to safety")

	r=component_section("spikes")
	var spikes:Dictionary=r.devices.back()
	for frame in 90:
		r.step(DT,1,false,false)
		if r.death_timer>0: break
	check(r.death_timer>0 and r.events.has("impact"),"walking into spikes triggers impact")
	r.spawn()
	for frame in 160:
		r.step(DT,1,r.is_grounded() and r.pos.x>float(spikes.x)-55 and r.pos.x<float(spikes.x),false)
		if r.death_timer>0 or r.finish: break
	check(r.finish,"keeper can clear all spike tips in one jump")

	r=component_section("monkey")
	var monkey:Dictionary=r.devices.back()
	for direction in [-1,1]:
		r.spawn()
		r.pos=Vector2(monkey.x+145*direction,monkey.y)
		r.step(DT,0,false,false)
		check(monkey.mode==1 and monkey.rocks.is_empty(),"monkey raises a stone before throwing")
		for frame in 36: r.step(DT,0,false,false)
		if check(monkey.rocks.size()==1,"monkey releases one rock"):
			check(signf(monkey.rocks[0].velocity.x)==direction,"rock aims toward the keeper on either side")
		for frame in 90:
			r.step(DT,0,false,false)
			if r.death_timer>0: break
		check(r.death_timer>0 and r.events.has("impact"),"aimed rock hits a stationary keeper")
	r.spawn()
	check(monkey.rocks.is_empty(),"checkpoint clears thrown rocks")
	for frame in 310:
		r.step(DT,1,false,false)
		if r.death_timer>0 or r.finish: break
	check(r.finish and monkey.rocks.is_empty(),"moving keeper dodges the rocks and missed throws expire")

func cargo_hazard_checks() -> void:
	const DT:=1.0/60.0
	var r:=component_section("cargo_net")
	var net:Dictionary=r.devices.back()
	var sling:Dictionary=r.platforms[net.platform]
	var edge:=float(sling.base.x)-56
	for frame in 140:
		r.step(DT,1,r.is_grounded() and r.pos.x>=edge-13 and r.pos.x<edge,false)
		if r.grounded==net.platform or r.death_timer>0: break
	check(r.grounded==net.platform,"running jump catches the hanging cargo net")
	for frame in 18: r.step(DT,0,false,false)
	check(r.grounded==net.platform and r.pos.y>float(sling.base.y),"the keeper's weight lowers the net")
	for frame in 90:
		r.step(DT,0,false,false)
		if r.death_timer>0: break
	check(r.death_timer>0 and not r.is_solid(sling),"waiting on the net drops the keeper")
	r.spawn()
	check(sling.pos==sling.base and net.timer==0,"checkpoint resets the cargo net")
	for frame in 300:
		var leap: bool=(r.is_grounded() and r.pos.x>=edge-13 and r.pos.x<edge) or r.grounded==net.platform
		r.step(DT,1,leap,false)
		if r.death_timer>0 or r.finish: break
	check(r.finish and sling.pos==sling.base,"jumping off in time clears the gap and the net returns")

	r=component_section("cable_drum")
	var drum:Dictionary=r.devices.back()
	check(drum.mode==0 and drum.roll_x==drum.x,"wooden chock initially holds the drum")
	for frame in 70:
		r.step(DT,1,false,false)
		if drum.mode==1: break
	check(drum.mode==1 and drum.roll_x==drum.x,"approach shakes the chock before the drum moves")
	for frame in 150:
		r.step(DT,0,false,false)
		if r.death_timer>0: break
	check(r.death_timer>0 and r.events.has("impact"),"the rolling drum hits a keeper at deck level")
	r.spawn()
	check(drum.mode==0 and drum.roll_x==drum.x,"checkpoint resets the cable drum and chock")
	var takeoff:=float(drum.trigger)+42
	var refuge:=float(drum.trigger)+126
	for frame in 150:
		var advance:=r.pos.x<refuge
		r.step(DT,1 if advance else 0,r.is_grounded() and r.pos.x>=takeoff and r.pos.x<takeoff+4,false)
		if r.death_timer>0 or (drum.mode==2 and drum.roll_x<r.pos.x-24): break
	check(r.death_timer==0 and r.grounded>=0 and r.platforms[r.grounded].style=="bollard" and drum.roll_x<r.pos.x-24,
		"keeper can jump onto the bollard and let the drum roll underneath")
	for frame in 300:
		r.step(DT,1,false,false)
		if r.death_timer>0 or r.finish: break
	check(r.finish and drum.mode==3,"keeper can continue after the drum passes")

func culvert_checks() -> void:
	const DT:=1.0/60.0
	var r:=Passage.new(Book.migrated_room(91),["12a"])
	var roof: Dictionary=r.structures[0]
	var approach:=Vector2(float(roof.x)-r.RADIUS-1,float(roof.floor))
	r.pos=approach
	for frame in 25: r.step(DT,1,false,false)
	check(r.pos.x<=float(roof.x)-r.RADIUS and r.death_timer==0,"the closed roof blocks entry")
	r.time=1.5
	for frame in 56: r.step(DT,1,false,false)
	check(r.pos.x>float(roof.x)+float(roof.w)+r.RADIUS and r.death_timer==0,"a running keeper clears the open roof")
	r.spawn()
	r.pos=Vector2(float(roof.x)+float(roof.w)*.5,float(roof.floor))
	r.time=1.5
	for frame in 150:
		r.step(DT,0,false,false)
		if r.death_timer>0: break
	check(r.death_timer>0 and "impact" in r.events,"the descending roof crushes a keeper who waits underneath")

	r=Passage.new(Book.migrated_room(31),["4a"])
	var drain: Dictionary=r.structures[0]
	r.pos=Vector2(float(drain.x)+float(drain.w)*.5,float(drain.floor))
	r.time=2.12
	r.step(DT,0,false,false)
	check(drain.acid_mode==1 and r.death_timer==0,"drain warns before acid flows")
	for frame in 60:
		r.step(DT,0,false,false)
		if r.death_timer>0: break
	check(drain.acid_mode==2 and r.death_timer>0,"acid contact kills even after the checkpoint is cleared")
	for frame in 43: r.step(DT,0,false,false)
	check(drain.acid_mode==0 and r.pos==r.checkpoint,"drain resets on checkpoint recovery")
	r.time=4.0
	r.pos=Vector2(float(drain.x)+float(drain.w)*.5,float(drain.floor))
	r.step(DT,0,false,false)
	check(r.death_timer==0 and drain.acid_mode==0,"the area is safe once the discharge stops")

	r=Passage.new(Book.migrated_room(137),["9a"])
	var gate: Dictionary=r.structures[0]
	r.time=2.78
	r.pos=Vector2(float(gate.x)+float(gate.w)*.5,float(gate.floor))
	r.step(DT,0,false,false)
	check(r.roof_bounds(gate).end.y<r.pos.y-r.BODY and gate.acid_mode==2 and r.death_timer>0,
		"the acid gate is hazardous even while its roof is open")

func swarm_hound_checks() -> void:
	const DT:=1.0/60.0
	var r:=Passage.new(Book.migrated_room(136),["8a"])
	var swarm: Dictionary=r.devices[0]
	var hound: Dictionary=r.devices[1]
	var overlap:=false
	landing=-1
	for frame in 1500:
		var move:=pilot(r)
		r.step(DT,move[0],move[1],move[2])
		if swarm.mode==1 and hound.mode==2 and float(swarm.flight.x)<r.pos.x and float(hound.dog)>r.pos.x:
			overlap=true
		if r.finish or r.death_timer>0: break
	check(overlap and r.finish,"keeper can clear the hound with the swarm chasing from behind")
	r=Passage.new(Book.migrated_room(136),["8a"])
	swarm=r.devices[0]
	hound=r.devices[1]
	r.pos=Vector2(float(swarm.x)-20,float(hound.y))
	for frame in 100:
		r.step(DT,0,false,false)
		if r.death_timer>0: break
	check(r.death_timer>0 and swarm.mode==1 and hound.mode==0,"waiting at the start lets the swarm catch up before the hound charges")

func ladder_checks() -> void:
	const DT:=1.0/60.0
	game.enter_room(Book.migrated_room(131),["4a"])
	var r:=game.route
	var gate: Dictionary=r.key_gates[0]
	var rungs: Dictionary=r.ladders[0]
	r.pos=Vector2(float(gate.x)-24,gate.y)
	game.use_nearby()
	for frame in 30: r.step(DT,1,false,false)
	check(not gate.open and r.pos.x<=float(gate.x)-r.RADIUS,"the locked door blocks the route until the key is found")

	var hand: Vector2=game.hud.zones().use
	var down: Vector2=game.hud.zones().left
	var up: Vector2=game.hud.zones().right
	r.pos=Vector2(float(rungs.x)-26,rungs.top)
	touch(5,hand,true)
	var emulated:=InputEventMouseButton.new()
	emulated.device=InputEvent.DEVICE_ID_EMULATION
	emulated.button_index=MOUSE_BUTTON_LEFT
	emulated.position=hand
	emulated.pressed=true
	game._input(emulated)
	touch(5,hand,false)
	check(r.ladder==0,"a touch grabs the ladder once even if it also generates a mouse event")
	touch(6,down,true)
	for frame in 90:
		game._physics_process(DT)
		if r.ladder<0: break
	touch(6,down,false)
	check(r.pos==rungs.lower_landing and r.ladder<0,"the down control reaches the lower landing")
	for frame in 45:
		r.step(DT,1,false,false)
		if gate.key_taken: break
	check(gate.key_taken,"walking to the key collects it")
	for frame in 60:
		r.step(DT,-1,false,false)
		if r.nearby_ladder()>=0: break
	touch(5,hand,true)
	touch(5,hand,false)
	touch(6,up,true)
	for frame in 90:
		game._physics_process(DT)
		if r.ladder<0: break
	touch(6,up,false)
	check(r.pos==rungs.upper_landing and r.ladder<0,"the up control returns to the upper catwalk")
	for frame in 80:
		r.step(DT,1,false,false)
		if r.nearby_key_gate()>=0: break
	touch(5,hand,true)
	touch(5,hand,false)
	check(gate.open,"the hand control opens the door with the collected key")
	touch(6,up,true)
	for frame in 160:
		game.jump_request=pilot(r)[1]
		game._physics_process(DT)
		if r.completed.has("ladder-exit"): break
	touch(6,up,false)
	game.continue_game()
	check(game.route.completed.has("ladder-exit") and game.route.key_gates[0].open,
		"Continue beyond the door restores it open")

	for source in [134,148]:
		var room:=Book.migrated_room(source)
		var cleared:=["7a"] if source==134 else ["18a"]
		var launch_velocity:=Vector2.ZERO
		for from_top in [false,true]:
			r=Passage.new(room,cleared)
			rungs=r.ladders[0]
			r.pos=rungs.upper_landing if from_top else rungs.lower_landing
			var monkey: Dictionary=r.devices.back()
			r.step(DT,0,false,false)
			check(monkey.rocks.is_empty(),"the ladder guard waits until the keeper grabs the ladder")
			check(r.toggle_ladder(),"the guarded ladder can be grabbed from either end")
			if not check(monkey.rocks.size()==1 and r.events.has("rock_throw"),"the guard throws on the grab"):
				continue
			var rock: Dictionary=monkey.rocks[0]
			var start_y:=float(rock.pos.y)
			if from_top:
				check(rock.velocity.is_equal_approx(launch_velocity),"both ends trigger the same fixed trajectory")
			else:
				launch_velocity=rock.velocity
			for frame in roundi(Passage.LADDER_ROCK_FLIGHT/DT): r.step(DT,0,false,false)
			var midpoint:=Vector2(rungs.x,(float(rungs.top)+float(rungs.bottom))*.5)
			check(rock.pos.distance_to(midpoint)<.02 and start_y<rock.pos.y and launch_velocity.y>=0,
				"the rock travels down through the ladder midpoint without rising")
			check(r.death_timer==0,"waiting at either end avoids the throw")
			if from_top:
				for frame in 8: r.step(DT,0,false,false)
				for frame in 90:
					r.step(DT,-1,false,false)
					if r.ladder<0: break
				check(r.death_timer==0 and r.pos==rungs.lower_landing,"the keeper can descend after the first stone passes")

		r=Passage.new(room,cleared)
		rungs=r.ladders[0]
		r.pos=Vector2(float(rungs.x)-14,(float(rungs.top)+float(rungs.bottom))*.5+20)
		r.toggle_ladder()
		for frame in 60:
			r.step(DT,0,false,false)
			if r.death_timer>0: break
		check(r.death_timer>0 and r.ladder<0,"the fixed throw still knocks the keeper off at the midpoint")

func progression_checks() -> void:
	var pairs:={
		"rocker_skiff":["rocker","skiff"],
		"hound_spikes":["hound","spikes"],
		"swarm_planks":["swarm","short_wreck"],
		"steam_spikes":["steam","spikes"],
		"swarm_hound":["swarm","hound"],
		"acid_gate":["drain","low"],
		"monkey_ladder":["monkey","key_ladder"],
		"monkey_crossfire":["monkey"],
	}
	var introduced:={}
	var played_pairs:={}
	var duplicate_sections:={}
	var current_chapter:=-1
	for room in Book.ROOMS.size():
		var chapter:=Book.chapter(room)
		if chapter!=current_chapter:
			current_chapter=chapter
			duplicate_sections.clear()
		var layout:=Passage.new(room)
		for token in str(Book.ROOMS[room][1]).split(" "):
			if token.begins_with("@"): continue
			check(not duplicate_sections.has(token) or token=="ride","each obstacle section is used once per chapter")
			duplicate_sections[token]=true
			if pairs.has(token):
				for solo in pairs[token]:
					check(introduced.has(solo) and introduced[solo]<chapter,"solo "+solo+" precedes "+token+" by a chapter")
				played_pairs[token]=true
			if not introduced.has(token): introduced[token]=chapter
		if not layout.freight.is_empty():
			check(layout.freight.size()==1 and not duplicate_sections.has("freight"),"at most one crate in a chapter")
			duplicate_sections["freight"]=true
		for shape in layout.structures:
			check(not duplicate_sections.has("roof"),"at most one roof section in a chapter")
			duplicate_sections["roof"]=true
	check(played_pairs.size()==pairs.size(),"all paired encounters are live")
	for token in ["elephant","monkey","spikes","cargo_net","cable_drum"]:
		check(introduced.has(token),"new component is placed: "+token)

func finale_rehearsal_checks() -> void:
	var finale:=Book.CHAPTERS.size()-1
	var prior_counts:={}
	for room in Book.ROOMS.size():
		var tokens:=str(Book.ROOMS[room][1]).split(" ")
		for token in tokens:
			if token.begins_with("@"): continue
			if Book.chapter(room)<finale:
				prior_counts[token]=int(prior_counts.get(token,0))+1
			else:
				var count:=int(prior_counts.get(token,0))
				check(count>=1 and count<=2,"finale section has one or two earlier appearances: "+token)
				check(token!="monkey_crossfire","the monkey crossfire stays outside the finale")
		if Book.chapter(room)==finale:
			check(not Passage.new(room).devices.any(func(device): return device.type=="gorilla"),
				"the final chapter has no gorilla")

func monkey_crossfire_checks() -> void:
	const DT:=1.0/60.0
	var r:=Passage.new(Book.migrated_room(136),["8a"])
	var monkeys:=r.devices.filter(func(device): return device.type=="monkey")
	check(monkeys.size()==2 and Book.chapter(r.room)==11,"two monkeys guard the Chapter 12 ambush")
	var rear: Dictionary=monkeys[0]
	var front: Dictionary=monkeys[1]
	r.pos=Vector2(float(rear.x)-25,rear.y)
	for frame in 45: r.step(DT,0,false,false)
	check(not rear.alerted and not front.alerted and rear.rocks.is_empty() and front.rocks.is_empty(),
		"the monkeys wait until the keeper has passed the first perch")
	r.pos.x=(float(rear.x)+float(front.x))*.5
	for frame in 38: r.step(DT,0,false,false)
	if check(rear.rocks.size()==1 and front.rocks.size()==1,"both monkeys throw during the same volley"):
		check(rear.rocks[0].velocity.x>0 and front.rocks[0].velocity.x<0,"the rocks come from behind and ahead")
	for frame in 100:
		r.step(DT,0,false,false)
		if r.death_timer>0: break
	check(r.death_timer>0,"standing in the crossfire gets the keeper hit")
	for frame in 43: r.step(DT,0,false,false)
	check(not rear.alerted and not front.alerted and rear.rocks.is_empty() and front.rocks.is_empty(),
		"checkpoint recovery resets both monkeys and their projectiles")

func gameplay_sound_checks() -> void:
	const DT:=1.0/60.0
	for sample in ["step_wood","step_grass","step_stone","step_clay","step_glass","step_soft",
			"monkey_call","rock_throw","gorilla_call","gorilla_intro","boar_call"]:
		check(game.audio.samples[sample] is AudioStreamOggVorbis,"playable sound for "+sample)
	for sample in [[0,"step_wood"],[20,"step_grass"],[68,"step_clay"],[103,"step_glass"],[138,"step_soft"]]:
		var crossing:=Passage.new(Book.migrated_room(sample[0]))
		for frame in 26: crossing.step(DT,1,false,false)
		check(sample[1] in crossing.events,"walk emits "+sample[1])
	var mixed:=Passage.new(Book.migrated_room(131))
	for style in [["stone","step_stone"],["catwalk","step"]]:
		for i in mixed.platforms.size():
			if mixed.platforms[i].style==style[0]:
				mixed.grounded=i
				check(mixed.footstep()==style[1],"platform overrides the chapter ground for "+style[0])
				break

	game.enter_room(Book.migrated_room(21),["16a"])
	game.audio.set_enabled(true)
	var r:=game.route
	var swarm: Dictionary=r.devices[0]
	check(not game.audio.swarm_buzz.playing,"insects are quiet before pursuit")
	r.pos=Vector2(float(swarm.x)-52,float(swarm.y)+36)
	game._physics_process(DT)
	check(swarm.mode==1 and game.audio.swarm_buzz.playing and game.audio.swarm_buzz.stream.loop,
		"the live chase starts a looping buzz")
	game.pause_game()
	check(not game.audio.swarm_buzz.playing,"the loop stops when paused")
	game.back()
	game._physics_process(DT)
	check(game.audio.swarm_buzz.playing,"resuming restores the chase buzz")
	game.enter_room(0,[])
	check(not game.audio.swarm_buzz.playing,"the loop does not leak into the next scene")
	game.audio.update_swarm(24)
	var near_volume:=game.audio.swarm_buzz.volume_db
	game.audio.update_swarm(230)
	check(near_volume>-3 and game.audio.swarm_buzz.volume_db>=-16 and game.audio.swarm_buzz.volume_db<near_volume,
		"the buzz is prominent up close and audible at chase distance")
	var voice: AudioStreamPlayer=game.audio.layers[game.audio.cursor]
	game.audio.cue("monkey_call")
	check(voice.volume_db==2,"the monkey call plays at the raised volume")
	game.audio.set_enabled(false)

	var monkey_run:=Passage.new(Book.migrated_room(23),["18a"])
	var monkey: Dictionary=monkey_run.devices[0]
	monkey_run.pos=Vector2(float(monkey.x)-168,monkey.y)
	monkey_run.step(DT,0,false,false)
	check("monkey_call" in monkey_run.events and not "rock_throw" in monkey_run.events,
		"the monkey calls before throwing")
	for frame in 38: monkey_run.step(DT,0,false,false)
	check("rock_throw" in monkey_run.events and monkey.rocks.size()==1,"the rock release plays its own cue")

func gorilla_checks() -> void:
	const DT:=1.0/60.0
	var index:=Book.migrated_room(133)
	var r:=Passage.new(index)
	var ape: Dictionary=r.devices[0]
	for frame in 90: r.step(DT,0,false,false)
	check(ape.mode==Passage.GorillaMode.HIDDEN and not r.events.has("gorilla_intro") and r.death_timer==0,
		"the gorilla stays hidden before the keeper starts walking")
	for frame in 90:
		r.step(DT,1,false,false)
		if ape.mode==Passage.GorillaMode.ENTERING: break
	check(ape.mode==Passage.GorillaMode.ENTERING and ape.chase.x<r.camera-40 and not r.events.has("gorilla_intro"),
		"the keeper triggers the gorilla's entrance beyond the left edge")
	for frame in 90:
		r.step(DT,0,false,false)
		if ape.mode==Passage.GorillaMode.DISPLAY: break
	check(ape.chase.x>r.camera and ape.mode==Passage.GorillaMode.DISPLAY and "gorilla_intro" in r.events,
		"the gorilla walks into view before its chest-beat introduction")
	var reveal: Vector2=ape.chase
	var keeper: Vector2=r.pos
	for frame in 38: r.step(DT,1,true,true)
	check(ape.mode==Passage.GorillaMode.DISPLAY and ape.chase==reveal and r.pos==keeper and r.death_timer==0,
		"the keeper stays still through the gorilla's display despite movement and jump input")
	var max_pace:=0.0
	for frame in 120:
		var previous_x:=float(ape.chase.x)
		r.step(DT,0,false,false)
		max_pace=maxf(max_pace,(float(ape.chase.x)-previous_x)/DT)
		if r.death_timer>0: break
	check(r.death_timer==Passage.GORILLA_SLAM_TIME and ape.mode==Passage.GorillaMode.SLAM and max_pace<=Passage.GORILLA_MAX_SPEED+.1,
		"catching a stationary keeper starts the two-handed slam")
	check(not r.events.has("impact"),"ground impact waits for the fists")
	for frame in 22: r.step(DT,0,false,false)
	check(r.events.count("impact")==1,"the slam plays one impact when both fists hit")
	for frame in 39: r.step(DT,0,false,false)
	check(r.pos.distance_to(r.checkpoint)<3 and ape.mode==Passage.GorillaMode.HIDDEN,"respawn resets the gorilla introduction")
	r=Passage.new(index)
	ape=r.devices[0]
	var stayed_behind:=true
	var swung_from_ropes:=false
	landing=-1
	for frame in 1900:
		var move:=pilot(r)
		r.step(DT,move[0],move[1],move[2])
		if ape.mode==Passage.GorillaMode.RUNNING:
			stayed_behind=stayed_behind and float(ape.chase.x)<r.pos.x
		if ape.rope>=0:
			swung_from_ropes=true
		if r.finish or r.death_timer>0: break
	check(r.finish and stayed_behind and swung_from_ropes and ape.mode==Passage.GorillaMode.RUNNING,
		"the gorilla swings across the planks and pursues past the checkpoint to the exit")
	game.enter_room(index,[])
	game.route.finish=true
	game.route.pos.x=game.route.width-28
	game.route.gorilla.chase.x=game.route.pos.x-193
	game.enter_room(index+1,[])
	check(game.route.gorilla.mode==Passage.GorillaMode.RUNNING and is_equal_approx(game.route.pos.x-game.route.gorilla.chase.x,193),
		"the running gorilla keeps its lead distance into The Gull Roost")
	for item in [[index,"6a"],[index+1,"7a"]]:
		var resumed:=Passage.new(item[0],[item[1]])
		check(resumed.gorilla.mode==Passage.GorillaMode.RUNNING and resumed.gorilla.chase.x<resumed.pos.x,
			"resuming from a Chapter 11 checkpoint preserves the chase")

func run() -> void:
	game=Main.new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	chapter_progress_checks()
	game.leave_voyage()
	lifecycle_checks()
	checkpoint_checks()
	progression_checks()
	finale_rehearsal_checks()
	boards=game.board_specs
	update_checks()
	hazard_and_storm_checks()
	gameplay_sound_checks()
	unplaced_component_checks()
	cargo_hazard_checks()
	culvert_checks()
	swarm_hound_checks()
	ladder_checks()
	gorilla_checks()
	monkey_crossfire_checks()
	bridge_checks()
	terrain_checks()
	vehicle_checks()
	boar_speed_crossing_checks()
	chamber_transfer_checks()
	developer_name_checks()
	debug_skip_checks()
	puzzle_skip_checks()
	debug_chapter_checks()
	disable_developer_checks()
	game._process(7.1)
	for index in Book.ROOMS.size():
		run_room(index)
	check(gameplay_seconds<1800,"compact voyage takes less than 30 minutes of uninterrupted traversal")
	var campaign_kinds:={}
	for key in used: campaign_kinds[boards[key].kind]=true
	check(used.size()==9 and campaign_kinds.size()==8,"the voyage reaches all nine assigned boards across eight families")
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
