extends RefCounted

const Book = preload("res://scripts/campaign.gd")
const SPEED := 165.0
const JUMP := 335.0
const HAND_REACH := 41.0
const PULL_TIME := 0.52
const GRAVITY := 990.0
const RADIUS := 8.0
const ROCKER_MAX_SLOPE := .68
const ROCKER_GAP := 74.0
const BODY := 40.0
var room: int
var rides: Array = []
var boar_road := false
var mounted := ""
var active_ride := -1
var platforms: Array = []
var stations: Array = []
var freight: Array = []
var structures: Array = []
var devices: Array = []
var puzzle_wait := 0.0
var puzzle_turn := 0
var ledge := -1
var ledge_face := 1
var hang_time := 0.0
var pull_time := -1.0
var grab_lock := 0.0
var chamber_jump := false
var near_valve := -1
var valve_action := ""
var completed: Array = []
var events: Array = []
var width := 0.0
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var face := 1
var elapsed := 0.0
var time := 0.0
var grounded := -1
var grace := 0.0
var buffer := 0.0
var stride := 0.0
var last_step := 0
var camera := 0.0
var camera_y := 0.0
var section_number := 0
var near_station := -1
var near_crate := false
var held_crate := -1
var hauling_back := false
var death_timer := 0.0
var finish := false
var checkpoint := Vector2(74, 376)
var _x := 0.0
var _y := 376.0
var _key := ""
var restored_at := {}

func _init(index: int, cleared: Array = []) -> void:
	room = index
	completed = cleared.duplicate()
	_y=Book.deck_height(index)
	checkpoint.y=_y
	var exit_height:=Book.deck_height(index+1)
	var tokens:=str(Book.ROOMS[index][1]).split(" ")
	boar_road=tokens.has("ride")
	dock(165)
	for i in tokens.size():
		if i==floori(tokens.size()*.45):
			terrace_to(roundf(lerpf(Book.deck_height(index),exit_height,.55)))
		var raw:=tokens[i]
		var token := String(raw)
		if token.begins_with("@"):
			_key = token.substr(1)
			stations.append({"x":_x+76, "y":_y, "key":_key})
			dock(215)
			if completed.has(_key):
				checkpoint = Vector2(_x-110, _y)
		else:
			build_section(token)
			section_number+=1
	terrace_to(exit_height)
	dock(170)
	width = _x
	if boar_road:
		rides.append({"start":checkpoint.x,"end":width,"type":"ride","position":checkpoint,
			"ground_y":checkpoint.y,"arrived":false})
	spawn()

func platform(x: float, y: float, length: float, style: String, delta := Vector2.ZERO, rate := 0.0) -> void:
	platforms.append({"base":Vector2(x,y), "pos":Vector2(x,y), "old":Vector2(x,y), "w":length, "style":style, "delta":delta, "rate":rate, "key":_key})

func dock(length: float, style := "dock") -> void:
	platform(_x,_y,length,style)
	_x += length

# Long grades have landings for another jump. The outgoing grade remains under
# the next obstacle, and the next room opens at exactly the height of this exit.
func terrace_to(height: float) -> void:
	var start:=_y
	var climbing:=height<start
	var count:=ceili(absf(height-start)/(45.0 if climbing else 59.0))
	for i in count:
		_y=lerpf(start,height,float(i+1)/count)
		dock(91 if climbing else 83,"stone")

# Authored rhythms, selected by the crossing address, repeat exactly on respawn.
const PLANK_RUNS := [4,3,6,4,8,5,3,7,10,5,4]
const FLOAT_RUNS := [2,1,3,2,4,1,3,5,2]
const PLANK_WIDTHS := [71,60,77,64,69,58]
const PLANK_GAPS := [56,66,52,72,61,65]

func plank_run(pattern: int, span_count := 0) -> void:
	dock(68)
	var count:int=PLANK_RUNS[pattern%PLANK_RUNS.size()]
	if span_count>0: count=span_count
	for j in count:
		var beat:=(pattern+j)%PLANK_WIDTHS.size()
		var w:float=PLANK_WIDTHS[beat]
		_x+=float(PLANK_GAPS[beat])
		platform(_x,_y-6*sin(float(j)*1.2),w,"loose")
		platforms.back().timer=-1.0
		_x+=w
	_x+=41
	dock(92)

func moving_decks(pattern: int, tidal: bool, span_count := 0) -> void:
	dock(60)
	var count:int=FLOAT_RUNS[pattern%FLOAT_RUNS.size()]
	if span_count>0: count=span_count
	for j in count:
		var beat:=(pattern+j)%4
		var w:=61+beat*5 if tidal else 75+beat*3
		_x+=29+beat*4
		var travel:=22+beat*2 if tidal else 33+beat*2
		var rate:=1.02+.09*beat
		var style:="bob" if tidal else "float"
		platform(_x,_y+5-3*(j%2),w,style,Vector2(0,-travel),rate)
		platforms.back().phase=(j%3)*.48
		_x+=w
	_x+=32
	dock(89)

func build_section(token: String) -> void:
	match token:
		"walk": dock(145)
		"shore": dock(195)
		"loose": plank_run(room*7+section_number*3,4 if room==0 else 0)
		"longwreck": plank_run(4,10)
		"short_wreck": plank_run(room*7+section_number*3,3)
		"broken_jetty": plank_run(4,7)
		"single_float": moving_decks(2,false,1)
		"flotilla": moving_decks(3,true,5)
		"viaduct_walk": dock(218,"viaduct")
		"float","tide": moving_decks(room*5+section_number*2,token=="tide")
		"causeway","wide_causeway","spillway":
			# A shallow stair of masonry islands with a broad middle landing.
			dock(60)
			var shape:Array=[0,17,27,12,-9] if token=="spillway" else [-12,-28,-41,-26]
			var wide:=token=="wide_causeway"
			var long_gaps:=[72,82,88,80]
			for i in shape.size():
				_x+=long_gaps[i] if wide else 35+7*(i%3)
				var w:=108 if i==2 else 65+4*i
				platform(_x,_y+float(shape[i]),w,"wide_pier" if wide else "pier")
				_x+=w
			_x+=76 if wide else 32
			dock(95)
		"aqueduct":
			var bank:=_y
			terrace_to(bank-105)
			dock(165,"viaduct")
			_x+=60
			dock(112,"viaduct")
			terrace_to(bank)
		"rocker":
			dock(74)
			_x+=ROCKER_GAP
			var span:=174.0
			var center_y:=_y-14.0
			devices.append({"type":"rocker","x":_x+span*.5,"y":center_y,"tilt":0.0,"half_span":span*.5})
			platform(_x,center_y,span,"rocker")
			platforms.back().device=devices.size()-1
			_x+=span+ROCKER_GAP
			dock(103)
		"gantry":
			# A vertical cage rises to a landing well above normal jump reach.
			dock(85)
			platform(_x+20,_y+6,99,"cage",Vector2(0,-128),1.03)
			_x+=144
			var bank:=_y
			_y-=110
			dock(151,"viaduct")
			terrace_to(bank)
		"ledge":
			dock(96)
			_y-=77
			dock(118,"stone")
			_y+=77
			dock(64)
		"storm_island":
			dock(110,"island")
		"vine":
			dock(55)
			platform(_x+4,_y+4,66,"vine",Vector2(108,-12),1.12)
			_x+=180
			dock(90,"branch")
		"ride","trolley":
			var start:=_x
			dock(135,"rail")
			for k in 3+room%3:
				_x+=43+(room+k)%4*6
				dock(105+((room+k)%3)*13,"rail")
			dock(90)
			if token=="trolley":
				rides.append({"start":start+24,"end":_x-30,"type":token,"position":Vector2(start+24,_y),"ground_y":_y,"arrived":false})
		"barge":
			moving_decks(room,true,2+room%3)
		"piston","wave":
			for k in 1+room%3:
				devices.append({"type":"steam","skin":token,"x":_x+115,"y":_y,"phase":k*1.4,"cycle":0.0,"mode":0})
				dock(230,"stone")
		"branches":
			for k in 5:
				_x+=36+4*(k%3)
				platform(_x,_y-14*sin(k*1.4),75,"branch")
				_x+=75
			_x+=32
			dock(93)
		"swarm":
			devices.append({"type":"swarm","x":_x,"y":_y-36,"flight":Vector2(_x-110,_y-64),"mode":0})
			dock(155)
		"hound","spider":
			var start:=_x
			dock(960,"rail")
			var kennel:=start+408
			devices.append({"type":token,"x":kennel,"y":_y,"limit":start+45,"far_post":start+925,"dog":kennel,
				"mode":0,"timer":0.0,"facing":-1,"speed":110.0 if token=="spider" else 262.0+9*(room%4)})
			dock(75)
		"steam","vents":
			dock(65)
			var count:=2 if token=="vents" else 1
			for i in count:
				devices.append({"type":"steam","x":_x+79,"y":_y,"phase":i*1.95,"cycle":0.0,"mode":0})
				dock(165,"rail")
			dock(45)
		"gap":
			dock(54)
			_x += 102
			dock(122)
		"steps":
			for rise in [26,28,22]:
				_y -= rise
				dock(72,"stone")
			_y += 76
			dock(86)
		"drop":
			_y -= 30
			dock(86,"stone")
			_y -= 26
			dock(82,"stone")
			_x += 72
			_y += 56
			dock(114)
		"crate":
			var begin := _x
			dock(255, "rail")
			freight.append({"x": begin+105, "spawn":begin+105, "y":_y, "min":begin+23, "max":_x-23})
			_y -= 108
			dock(138,"stone")
			_y += 108
			dock(78)
		"skiff", "hoist":
			dock(44)
			var dist := 219.0 if token == "skiff" else 195.0
			var rise := -42.0 if token == "hoist" else -9.0
			var style := "hoist" if _y<310 else token
			var rate := 1.03 if style == "skiff" else .76
			platform(_x+4,_y+8,86,style,Vector2(dist,rise),rate)
			_x += dist + 94
			_y += rise
			dock(93)
			_y -= rise
			dock(58)
		"span":
			dock(45)
			platform(_x+7,_y,178,"span")
			_x += 192
			dock(88)
		"low", "drain":
			structures.append({"x":_x+36,"y":_y-50,"w":115,"type":token,"key":_key})
			_y += 32
			dock(214,"drain")
			_y -= 32
			dock(86,"stone")
		"balance":
			var start := _x
			dock(234,"rail")
			var box_id := freight.size()
			freight.append({"x":start+72,"spawn":start+72,"y":_y,"min":start+23,"max":_x-30})
			devices.append({"type":"balance","x":_x-34,"y":_y,"box":box_id,"amount":0.0,"mode":0})
			platform(_x+18,_y+133,163,"balance",Vector2(0,-137))
			platforms.back().device=devices.size()-1
			_x+=205
			dock(119)
		"lockpair":
			dock(97)
			devices.append({"type":"lockpair","x":_x-33,"y":_y,"mode":0,"first":0.0,"second":0.0})
			for side in 2:
				platform(_x+19+side*140,_y+112,91,"chamber",Vector2(0,-124))
				platforms.back().device=devices.size()-1
				platforms.back().side=side
			_x+=277
			_y-=37
			dock(101,"stone")
			_y+=37
			dock(74)
		"shutters":
			dock(92)
			var gates:=1+(room+section_number)%3
			for gate in gates:
				var offset:=gate*(1.8+.22*(room%3))
				devices.append({"type":"shutter","x":_x+83,"y":_y,"offset":offset,"mode":0,"amount":1.0})
				dock(171,"stone")
			dock(58)
		"ray":
			dock(45)
			var count:=2+(room+section_number)%4
			for j in count:
				var lift:=12+8*(j%3) if room%2==0 else 22-6*(j%3)
				platform(_x+30+j*99,_y-lift,58,"ray")
			_x += count*99+34
			dock(94)
		"summit":
			_y -= 26
			dock(75,"stone")
			_y -= 30
			dock(180,"stone")

func continue_boar(previous: RefCounted) -> void:
	if not boar_road or not previous.boar_road: return
	var boar:Dictionary=previous.rides[0]
	boar.merge(rides[0],true)
	rides[0]=boar
	vel.x=previous.vel.x
	stride=previous.stride
	last_step=previous.last_step

func spawn() -> void:
	active_ride=0 if boar_road else -1
	mounted="ride" if boar_road else ""
	for ride in rides:
		if boar_road:
			ride.position=checkpoint
		else:
			ride.arrived=checkpoint.x>=ride.end
			ride.position=Vector2(ride.end if ride.arrived else ride.start,ride.ground_y)
	chamber_jump=false
	pos = checkpoint
	ledge=-1
	pull_time=-1
	grab_lock=0
	vel = Vector2.ZERO
	grounded = -1
	grace = 0.10
	buffer = 0
	near_station = -1
	near_crate = false
	held_crate=-1
	hauling_back=false
	death_timer = 0
	time = 0
	restored_at.clear()
	for p in platforms:
		if p.style=="loose": p.timer=-1.0
	for item in freight:
		item.x = item.spawn
	for device in devices:
		device.mode=0
		if device.type in ["hound","spider"]:
			device.facing=-1
			device.dog=float(device.x)
			device.timer=0.0
		elif device.type=="swarm":
			device.flight=Vector2(device.x-110,device.y-28)
		elif device.type=="rocker":
			device.tilt=0.0
		elif device.type=="lockpair":
			device.first=0.0
			device.second=0.0
		else:
			device.amount=0.0
	near_valve=-1
	valve_action=""
	update_platforms()
	camera_y=vertical_view()
	camera = clampf(pos.x-275, 0, maxf(0,width-960))

func update_devices(dt: float) -> void:
	for d in devices:
		match d.type:
			"swarm":
				if d.mode==1 or (pos.x>=float(d.x)-70 and pos.x<float(d.x)+75):
					d.mode=1
					d.flight=Vector2(d.flight).move_toward(pos+Vector2(0,-24+6*sin(time*4)),42*dt)
				else: d.mode=0
			"hound","spider":
				update_hound(d,dt)
			"rocker":
				var load:=0.0
				if grounded>=0 and platforms[grounded].style=="rocker" and devices[platforms[grounded].device]==d:
					load=clampf((pos.x-float(d.x))/float(d.half_span),-1,1)
				d.tilt=move_toward(float(d.tilt),load*ROCKER_MAX_SLOPE,dt*1.12)
			"steam":
				d.cycle=fposmod(time+float(d.phase),4.8)
				var next_mode:=2 if float(d.cycle)>=3.35 else (1 if float(d.cycle)>=2.45 else 0)
				if next_mode==1 and int(d.mode)!=1 and absf(pos.x-float(d.x))<240:
					events.append("undertow")
				d.mode=next_mode
			"balance":
				var crate: Dictionary=freight[d.box]
				var loaded := absf(float(crate.x)-float(d.x))<23
				if loaded and int(d.mode)==0: events.append("engage")
				d.mode=int(loaded)
				d.amount=move_toward(float(d.amount),float(d.mode),dt*.85)
			"lockpair":
				var feeding_second:bool=d.mode==2
				d.first=move_toward(float(d.first),1.0 if d.mode==1 else 0.0,dt*(.42 if feeding_second else .53))
				d.second=move_toward(float(d.second),1.0 if feeding_second else 0.0,dt*.95)
			"shutter":
				d.amount=clampf((sin((time+float(d.offset))*1.22)+.24)*2.8,0,1)

func update_hound(d: Dictionary,dt: float) -> void:
	# A sentry works the stretch between two posts. At either end it plants
	# its feet before reversing. Once the yard is empty it trots home.
	match int(d.mode):
		0:
			var distance:=float(d.x)-pos.x
			if distance>0 and distance<=335 and absf(pos.y-float(d.y))<78:
				d.mode=1
				d.timer=.58
				events.append("bark" if d.type=="hound" else "ratchet")
				events.append("pursuit")
		1,3:
			d.timer-=dt
			if float(d.timer)<=0:
				if int(d.mode)==3:
					if pos.x<float(d.limit)-25 or (d.facing>0 and pos.x>=float(d.far_post)-25):
						d.mode=4
						d.facing=signi(roundi(float(d.x)-float(d.dog)))
						return
					d.facing=-int(d.facing)
					events.append("bark" if d.type=="hound" else "ratchet")
				d.mode=2
		2:
			var end:float=d.limit if d.facing<0 else d.far_post
			var speed:float=d.speed
			d.dog=move_toward(float(d.dog),end,speed*dt)
			if is_equal_approx(float(d.dog),end):
				d.mode=3
				d.timer=.35 if d.facing<0 else .72
		4:
			d.dog=move_toward(float(d.dog),float(d.x),122*dt)
			if is_equal_approx(float(d.dog),float(d.x)):
				d.mode=0
				d.facing=-1

func operate_valve() -> bool:
	if near_valve<0 or death_timer>0: return false
	var lock:Dictionary=devices[near_valve]
	lock.mode=2 if valve_action=="Transfer to II" else 1
	# Clear the prompt immediately so an emulated click cannot use it again.
	near_valve=-1
	valve_action=""
	events.append("flow")
	return true

func update_planks(dt: float) -> void:
	for i in platforms.size():
		var p:Dictionary=platforms[i]
		if p.style!="loose": continue
		if grounded==i and float(p.timer)<0:
			p.timer=0.0
			events.append("crate")
		if float(p.timer)>=0:
			p.timer+=dt
			if float(p.timer)>=3.2: p.timer=-1.0
			elif float(p.timer)>=.74 and grounded==i: grounded=-1

func update_platforms() -> void:
	for p in platforms:
		p.old = p.pos
		var active: bool = str(p.key).is_empty() or completed.has(p.key) or p.style == "bob"
		var weight := 0.0
		if active and float(p.rate)>0:
			var phase := maxf(0,time-float(restored_at.get(p.key,0)))+float(p.get("phase",0))
			weight = (1.0-cos(phase*float(p.rate)))*0.5
		if p.has("device") and p.style!="rocker":
			var d: Dictionary = devices[p.device]
			if p.style=="chamber":
				weight = d.first if int(p.side)==0 else d.second
			else: weight = d.amount
		p.pos = Vector2(p.base) + Vector2(p.delta)*weight

func surface_height(p: Dictionary,x: float) -> float:
	if p.style=="rocker":
		var beam:Dictionary=devices[p.device]
		return float(beam.y)+clampf(x-float(beam.x),-p.w*.5,p.w*.5)*float(beam.tilt)
	return float(p.pos.y)

func is_solid(p: Dictionary) -> bool:
	if p.style=="loose": return float(p.timer)<.74
	return not (p.style in ["span","ray"] and not completed.has(p.key))

func collide_side(left: float, right: float, top: float, previous: float, dir: int) -> void:
	if pos.y <= top+0.5 or pos.y-BODY >= 700:
		return
	var hits_left:=dir>0 and previous+RADIUS<=left+.5 and pos.x+RADIUS>left
	var hits_right:=dir<0 and previous-RADIUS>=right-.5 and pos.x-RADIUS<right
	if not (hits_left or hits_right): return
	if is_grounded() and pos.y-top<=8:
		pos.y=top
	elif hits_left: pos.x=minf(pos.x,left-RADIUS)
	else: pos.x=maxf(pos.x,right+RADIUS)

func ledge_anchor() -> Vector2:
	var p:Dictionary=platforms[ledge]
	return Vector2(p.pos)+Vector2(float(p.w) if ledge_face<0 else 0.0,0)

func catch_ledge(axis: float) -> void:
	if active_ride>=0 or is_grounded() or grab_lock>0 or absf(axis)<.15: return
	var side:=1 if axis>0 else -1
	for i in platforms.size():
		var p:Dictionary=platforms[i]
		if p.style not in ["stone","dock","rail","drain","viaduct","pier","wide_pier"]: continue
		var edge:=Vector2(p.pos)+Vector2(float(p.w) if side<0 else 0.0,0)
		var reach:float=(edge.x-pos.x)*side
		var below:=pos.y-edge.y
		if reach<1 or reach>RADIUS+5 or below<10 or below>HAND_REACH: continue
		if vel.y<0 and vel.y*vel.y/(2*GRAVITY)>below+5: continue
		# Low culvert roofs need room for both the hanging and standing poses.
		var landing_box:=Rect2(edge-Vector2(RADIUS,BODY),Vector2(RADIUS*2,BODY))
		var blocked:=false
		for roof in structures:
			if landing_box.intersects(Rect2(roof.x,roof.y,roof.w,15)): blocked=true
		if blocked: continue
		ledge=i
		ledge_face=side
		face=side
		hang_time=0
		pull_time=-1
		grace=0
		buffer=0
		vel=Vector2.ZERO
		pos=edge+Vector2(-side*RADIUS,HAND_REACH)
		events.append("land")
		return

func climb_step(dt: float,axis: float,jump: bool) -> void:
	hang_time+=dt
	if pull_time<0:
		if axis*ledge_face<-.25:
			ledge=-1
			grab_lock=.28
			return
		if jump or (hang_time>=.20 and axis*ledge_face>.2):
			pull_time=0
		else: return
	pull_time=minf(PULL_TIME,pull_time+dt)
	var progress:=pull_time/PULL_TIME
	var rise:=smoothstep(0,.82,progress)
	var over:=smoothstep(.44,1,progress)
	pos=ledge_anchor()+Vector2(ledge_face*lerpf(-RADIUS,RADIUS+5,over),lerpf(HAND_REACH,0,rise))
	if progress>=1:
		grounded=ledge
		ledge=-1
		grace=.11
		pull_time=-1
		events.append("step")

func needs_console(index: int) -> bool:
	return not boar_road and index==completed.size() and puzzle_wait<=0.0

func vertical_view() -> float:
	return minf(0.0,pos.y-272)

func track_keeper(dt: float) -> void:
	camera=lerpf(camera,clampf(pos.x-320,0,maxf(0,width-960)),1-exp(-dt*5))
	var target:=minf(0,clampf(camera_y,pos.y-320,pos.y-223))
	camera_y=lerpf(camera_y,target,1-exp(-dt*4))

func step(dt: float, axis: float, jump: bool, grip: bool) -> void:
	if finish:
		return
	elapsed += dt
	if death_timer > 0:
		death_timer -= dt
		if death_timer <= 0:
			spawn()
		return
	if active_ride<0 and ledge<0:
		for i in rides.size():
			var vehicle:Dictionary=rides[i]
			if not vehicle.arrived and pos.x>=vehicle.start and pos.x<vehicle.start+30 and absf(pos.y-float(vehicle.ground_y))<48:
				active_ride=i
				mounted=vehicle.type
				break
	if active_ride>=0: axis=.92+axis*.08
	puzzle_wait=maxf(0,puzzle_wait-dt)
	grab_lock=maxf(0,grab_lock-dt)
	time += dt
	update_devices(dt)
	update_planks(dt)
	update_platforms()
	if ledge>=0:
		climb_step(dt,axis,jump)
		track_keeper(dt)
		return
	if grounded >= 0:
		pos += Vector2(platforms[grounded].pos)-Vector2(platforms[grounded].old)
	var old_x := pos.x
	var old_y := pos.y
	var slide_speed:=0.0
	if grounded>=0 and platforms[grounded].style=="rocker":
		var slope:=float(devices[platforms[grounded].device].tilt)
		slide_speed=signf(slope)*maxf(0.0,absf(slope)-.24)*170.0
	vel.x = move_toward(vel.x, axis*SPEED+slide_speed, dt*(1250 if is_grounded() else 760))
	if absf(axis)>0.01:
		face = 1 if axis>0 else -1
	near_crate=false
	held_crate=-1
	for i in freight.size():
		var box:Dictionary=freight[i]
		if absf(pos.x-float(box.x))>43 or absf(pos.y-float(box.y))>=6: continue
		near_crate=true
		if grip and is_grounded() and not jump:
			held_crate=i
			face=1 if float(box.x)>pos.x else -1
			if absf(axis)>.01: hauling_back=axis*face<0
			var next_x:=clampf(float(box.x)+axis*91*dt,float(box.min),float(box.max))
			vel.x=(next_x-float(box.x))/dt
			box.x=next_x
			break
	pos.x = clampf(pos.x+vel.x*dt, RADIUS+1, width-25)
	var dir := signi(roundi(signf(vel.x)))
	for p in platforms:
		if is_solid(p) and p.style in ["dock","rail","stone","drain","viaduct","pier","wide_pier"]:
			collide_side(p.pos.x, p.pos.x+p.w, p.pos.y, old_x, dir)
	for box in freight:
		collide_side(box.x-21,box.x+21,box.y-45,old_x,dir)
	for roof in structures:
		var left:=float(roof.x)
		var right:=left+float(roof.w)
		var top:=float(roof.y)
		if old_y-BODY<top+15 and old_y>top:
			if old_x+RADIUS<=left and pos.x+RADIUS>left: pos.x=left-RADIUS
			if old_x-RADIUS>=right and pos.x-RADIUS<right: pos.x=right+RADIUS
	for s in stations:
		if not completed.has(s.key):
			pos.x = minf(pos.x,float(s.x)+94-RADIUS)
			break
	old_y=minf(old_y,pos.y)
	if jump:
		buffer = 0.14
	else:
		buffer = maxf(0,buffer-dt)
	if buffer > 0 and grace > 0:
		vel.y = -JUMP
		grounded = -1
		grace = 0
		buffer = 0
	vel.y += GRAVITY * dt
	pos.y += vel.y*dt
	if vel.y<0:
		for roof in structures:
			var bottom:=float(roof.y)+15
			if pos.x+RADIUS>float(roof.x) and pos.x-RADIUS<float(roof.x)+float(roof.w) and old_y-BODY>=bottom and pos.y-BODY<bottom:
				pos.y=bottom+BODY
				vel.y=0
	var support:=grounded
	var was_grounded := is_grounded()
	grounded = -1
	if vel.y >= 0:
		for i in platforms.size():
			var p: Dictionary = platforms[i]
			if is_solid(p) and pos.x+RADIUS-2 > p.pos.x and pos.x-RADIUS+2 < p.pos.x+p.w:
				var top:=surface_height(p,pos.x)
				var riding_beam:bool=i==support and p.style=="rocker"
				if riding_beam or (old_y<=top+maxf(1.8,absf(float(p.pos.y)-float(p.old.y))) and pos.y>=top):
					pos.y = top
					vel.y = 0
					grounded = i
		for box in freight:
			if absf(pos.x-float(box.x)) < 26 and old_y<=float(box.y)-44.5 and pos.y >= float(box.y)-45:
				pos.y = float(box.y)-45
				vel.y = 0
				grounded = -2
	catch_ledge(axis)
	if active_ride>=0:
		var vehicle:Dictionary=rides[active_ride]
		vehicle.position=pos
		if pos.x>=vehicle.end:
			vehicle.position=Vector2(vehicle.end,vehicle.ground_y)
			vehicle.arrived=true
			active_ride=-1
			mounted=""
	if not is_grounded(): held_crate=-1
	if is_grounded():
		grace = 0.11
		if grounded>=0 and platforms[grounded].style=="island":
			var island:Dictionary=platforms[grounded]
			checkpoint=Vector2(island.base)+Vector2(island.w*.5,0)
		if not was_grounded and old_y < pos.y-1.0:
			events.append("land")
		stride += absf(pos.x-old_x)*0.083
		if int(stride/PI) != last_step:
			last_step = int(stride/PI)
			events.append("step")
	else:
		grace = maxf(0,grace-dt)
	near_valve=-1
	valve_action=""
	chamber_jump=false
	var submerged := false
	var struck := false
	for i in devices.size():
		var d: Dictionary = devices[i]
		if d.type in ["hound","spider"] and int(d.mode)==2 and absf(pos.x-float(d.dog))<25 and pos.y>float(d.y)-27 and pos.y-BODY<float(d.y):
			struck=true
		if d.type=="swarm" and d.mode==1 and Vector2(d.flight).distance_to(pos+Vector2(0,-24))<7: struck=true
		if d.type=="steam" and int(d.mode)==2 and absf(pos.x-float(d.x))<21 and pos.y>float(d.y)-85:
			struck=true
		if d.type=="shutter" and absf(pos.x-float(d.x))<14 and float(d.amount)<.54:
			if old_x<float(d.x)-9: pos.x=float(d.x)-15
			elif old_x>float(d.x)+9: pos.x=float(d.x)+15
			else: struck=true
		if d.type=="lockpair":
			if pos.x>float(d.x)+34 and pos.x<float(d.x)+303 and pos.y>float(d.y)+84: submerged=true
			if absf(pos.x-float(d.x))<42 and absf(pos.y-float(d.y))<40:
				near_valve=i
				valve_action="Fill chamber I"
			elif grounded>=0 and platforms[grounded].style=="chamber" and platforms[grounded].device==i and platforms[grounded].side==0:
				if d.mode==1:
					near_valve=i
					valve_action="Transfer to II"
				elif d.mode==2:
					chamber_jump=true
	if pos.y > minf(496,camera_y+570) or submerged or struck:
		death_timer = 0.68
		events.append("splash" if not struck and grounded==-1 else "impact")
		ledge=-1
		return
	near_station = -1
	var next:=completed.size()
	if next<stations.size():
		var s:Dictionary=stations[next]
		if needs_console(next):
			if absf(pos.x-float(s.x))<78 and absf(pos.y-float(s.y))<45: near_station=next
		elif pos.x>=float(s.x):
			activate(next,false)
	if pos.x >= width-56 and completed.size() == stations.size():
		finish = true
	track_keeper(dt)

func is_grounded() -> bool:
	return grounded != -1

func activate(index: int,puzzle := true) -> void:
	var s: Dictionary = stations[index]
	if completed.has(s.key):
		return
	completed.append(s.key)
	restored_at[s.key]=time
	checkpoint = Vector2(s.x+26,s.y)
	near_station = -1
	if puzzle:
		s.was_console=true
		puzzle_turn+=1
		puzzle_wait=Book.PUZZLE_INTERVAL
		events.append("save")
	else:
		events.append("checkpoint")
