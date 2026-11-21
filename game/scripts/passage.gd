extends RefCounted

const Book = preload("res://scripts/campaign.gd")
const SPEED := 148.2
const AIR_SPEED := 152.88
const RIDE_SPEED := 156.0
const RIDE_CRUISE := .92
const BOAR_SPEED_ADJUSTMENT := .16
const JUMP := 332.0
const HAND_REACH := 41.0
const PULL_TIME := 0.52
const GRAVITY := 990.0
const RADIUS := 8.0
const ROCKER_MAX_SLOPE := .68
const ROCKER_GAP := 74.0
const ROCKER_BALANCE_RADIUS := .5
const BODY := 40.0
const LADDER_SPEED := 100.0
const CULVERT_PERIOD := 4.8
const ACID_STOP := 3.95
# Keep the original sine sweep between stops and halve the time spent at each stop.
const SHUTTER_SWEEP_SPEED := 1.22
const SHUTTER_OPEN_ANGLE := asin(1.0/2.8-.24)
const SHUTTER_CLOSED_ANGLE := asin(-.24)
const SHUTTER_TRAVEL := (SHUTTER_OPEN_ANGLE-SHUTTER_CLOSED_ANGLE)/SHUTTER_SWEEP_SPEED
const SHUTTER_OPEN_PAUSE := (PI-2.0*SHUTTER_OPEN_ANGLE)/(2.0*SHUTTER_SWEEP_SPEED)
const SHUTTER_CLOSED_PAUSE := (PI+2.0*SHUTTER_CLOSED_ANGLE)/(2.0*SHUTTER_SWEEP_SPEED)
const SHUTTER_PERIOD := SHUTTER_OPEN_PAUSE+SHUTTER_CLOSED_PAUSE+2.0*SHUTTER_TRAVEL
const SNAKE_WINDUP := .95
const SNAKE_BITE_TIME := .19
const SNAKE_REST := .48
const SNAKE_RETREAT := .52
const SNAKE_TRIGGER := 106.0
const SNAKE_REACH := 127.0
enum SnakeMode { GUARD, WINDUP, BITE, RECOVER, RETREAT, HIDDEN }
const SPIKE_COUNT := 3
const SPIKE_PITCH := 14.0
const SPIKE_HEIGHT := 24.0
const THROW_WINDUP := .55
const ROCK_GRAVITY := 640.0
const LADDER_ROCK_GRAVITY := 64.0
const LADDER_ROCK_FLIGHT := .90
const ROCK_RADIUS := 5.0
const DRUM_RADIUS := 21.0
const GORILLA_DISPLAY_TIME := .8
const GORILLA_MAX_SPEED := 151.0
const GORILLA_SLAM_TIME := 0.96
const GORILLA_SLAM_IMPACT := 0.34
enum GorillaMode { HIDDEN, ENTERING, DISPLAY, RUNNING, SLAM }
const GROUND_STEPS := ["step_wood","step_grass","step_stone","step","step_clay","step_stone","step_glass","step_soft"]
var room: int
var rides: Array = []
var gorilla: Dictionary = {}
var chase_ropes: Array = []
var boar_road := false
var mounted := ""
var active_ride := -1
var platforms: Array = []
var stations: Array = []
var freight: Array = []
var structures: Array = []
var devices: Array = []
var ladders: Array = []
var key_gates: Array = []
var ladder := -1
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
	var boards: Dictionary=Book.STATION_BOARDS.get(Book.SOURCE_ROOMS[index],{})
	boar_road=tokens.has("ride")
	dock(165)
	for i in tokens.size():
		if i==floori(tokens.size()*.45):
			terrace_to(roundf(lerpf(Book.deck_height(index),exit_height,.55)))
		var raw:=tokens[i]
		var token := String(raw)
		if token.begins_with("@"):
			_key = token.substr(1)
			stations.append({"x":_x+76, "y":_y, "key":_key, "board":boards.get(_key,"")})
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
		var opening:=room==Book.CHAPTER_STARTS[Book.chapter(room)]
		rides.append({"start":196.0 if opening else checkpoint.x,"end":width,"type":"ride",
			"position":checkpoint,"ground_y":Book.deck_height(room),"arrived":false})
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
		var rate:=(1.02+.09*beat)*1.24
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
		"flotilla": moving_decks(3,true,6)
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
		"rocker","rocker_skiff":
			dock(74)
			_x+=ROCKER_GAP
			var span:=174.0
			var center_y:=_y-14.0
			devices.append({"type":"rocker","x":_x+span*.5,"y":center_y,"tilt":0.0,"half_span":span*.5})
			platform(_x,center_y,span,"rocker")
			platforms.back().device=devices.size()-1
			_x+=span
			if token=="rocker_skiff":
				# The skiff is the landing. Board it during its approach to the tilted end.
				var extra_gap:=clampf((Book.chapter(room)-6)*2.0,0,12)
				platform(_x+46+extra_gap,_y+18,91,"skiff",Vector2(141,0),1.03)
				_x+=333+extra_gap
			else:
				_x+=ROCKER_GAP
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
		"cargo_net":
			dock(112)
			_x+=56
			devices.append({"type":token,"x":_x+28,"y":_y,"amount":0.0,"timer":0.0,
				"platform":platforms.size(),"hold_time":1.0 if Book.chapter(room)>=11 else 1.25})
			platform(_x,_y+8,56,token,Vector2(0,102))
			platforms.back().device=devices.size()-1
			_x+=105
			dock(130)
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
		"swarm","swarm_planks":
			var chasing:=token=="swarm_planks"
			var anchor:=_x+42 if chasing else _x
			add_swarm(anchor,152.0 if chasing else 54.0)
			if chasing: plank_run(room+section_number,4 if Book.chapter(room)<12 else 6)
			else: dock(155)
		"gorilla_run","gorilla_continue":
			var opening:=token=="gorilla_run"
			if opening: checkpoint.x=_x+21
			gorilla={"type":"gorilla","x":-68.0,"y":_y,"trigger":checkpoint.x+112,
				"opening":opening,"chase":Vector2(-68,_y),"mode":GorillaMode.HIDDEN,
				"timer":0.0,"rope":-1,"grip":Vector2.ZERO}
			devices.append(gorilla)
			if opening: dock(280)
		"chase_planks":
			var first:=platforms.size()
			plank_run(1,5)
			if not gorilla.is_empty():
				var start:=float(platforms[first].base.x)+float(platforms[first].w)-18
				for i in range(first+2,platforms.size(),2):
					var landing: Dictionary=platforms[i]
					var end:=float(landing.base.x)+float(landing.w)*.5
					add_chase_rope(start,end,_y)
					start=end
				add_chase_rope(start,_x-28,_y)
		"elephant":
			var home:=_x+126
			devices.append({"type":token,"x":home,"y":_y,"foot_x":home,"start":_x+52,
				"end":_x+678,"mode":0,"timer":0.0,"facing":1})
			dock(742)
		"giant_snake":
			devices.append({"type":"snake","x":_x+260,"y":_y,"mode":SnakeMode.GUARD,
				"timer":0.0,"misses":0})
			dock(408,"grass")
		"boar_spikes":
			for i in 5:
				spike_bed(_x+108+i*121,1)
			dock(715,"grass")
		"spikes":
			spike_bed(_x+112)
			dock(224,"stone")
		"monkey":
			add_monkey(_x+255,_y)
			dock(510)
		"monkey_crossfire":
			var rear:=_x+146
			var trigger:=rear+20
			add_monkey(rear,_y,-1,trigger)
			add_monkey(rear+219,_y,-1,trigger)
			dock(535)
		"key_ladder":
			var lower:=_y+130
			dock(112,"catwalk")
			var shaft:=_x+18
			_x+=36
			platform(shaft-42,lower,172,"catwalk")
			add_ladder(shaft,_y,lower,_x+16,shaft+13)
			key_gates.append({"x":shaft+145,"y":_y,"key_pos":Vector2(shaft+87,lower-18),
				"checkpoint":"ladder-exit","key_taken":false,"open":false})
			dock(218,"catwalk")
		"monkey_ladder":
			var lower:=_y
			dock(153,"catwalk")
			var shaft:=_x-17
			platform(_x,lower,155,"catwalk")
			_x+=12
			_y-=126
			add_ladder(shaft,_y,lower,_x+7,shaft+12)
			add_monkey(shaft+114,lower,ladders.size()-1)
			dock(230,"catwalk")
		"cable_drum","rolling_log":
			var later:=Book.chapter(room)>=10
			devices.append({"type":token,"x":_x+355,"y":_y,"trigger":_x+48,"end":_x+23,
				"roll_x":_x+355,"mode":0,"timer":0.0,"warning":.43 if later else .6,
				"speed":255.0 if later else 236.0})
			platform(_x+152,_y-47,49,"stump" if token=="rolling_log" else "bollard")
			dock(450,"grass" if token=="rolling_log" else "rail")
		"boar_hound":
			var kennel:=_x+60
			devices.append({"type":"hound","x":kennel,"y":_y,"limit":kennel,
				"far_post":_x+575,"rear_trigger":kennel+134,"dog":kennel,
				"mode":0,"timer":0.0,"facing":1,"speed":172.0})
			dock(635,"grass")
		"hound","hound_spikes","swarm_hound","spider":
			var start:=_x
			dock(960,"rail")
			if token=="swarm_hound": add_swarm(start+42,153.0,start+925)
			var kennel:=start+408
			devices.append({"type":"spider" if token=="spider" else "hound","x":kennel,"y":_y,"limit":start+45,"far_post":start+925,"dog":kennel,
				"mode":0,"timer":0.0,"facing":-1,"speed":110.0 if token=="spider" else 262.0+9*(room%4)})
			if token=="hound_spikes": spike_bed(start+273)
			dock(75)
		"steam","steam_spikes","vents":
			dock(65)
			var count:=2 if token=="vents" else 1
			for i in count:
				devices.append({"type":"steam","x":_x+79,"y":_y,"phase":i*1.95,"cycle":0.0,"mode":0})
				dock(165,"rail")
			if token=="steam_spikes":
				spike_bed(_x+9)
				dock(66,"rail")
			dock(45)
		"gap":
			dock(54)
			var lip:=_x
			_x += 94 if room==Book.migrated_room(138) else 102
			if not gorilla.is_empty(): add_chase_rope(lip-16,_x+18,_y)
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
		"low","drain","acid_gate":
			_y += 32
			structures.append({"x":_x+36,"w":115.0,"floor":_y,"y":_y-82,"type":token,
				"moving":token!="drain","cycle":0.0,"acid_mode":0})
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
			var gates:=clampi(Book.chapter(room)-9,1,3)
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

func spike_bed(x: float,count := SPIKE_COUNT) -> void:
	devices.append({"type":"spikes","x":x,"y":_y,"count":count})

func add_swarm(x: float,speed: float,end := INF) -> void:
	devices.append({"type":"swarm","x":x,"y":_y-36,"flight":Vector2(x-110,_y-64),
		"speed":speed,"end":end,"mode":0})

func add_monkey(x: float,y: float,target_ladder := -1,trigger := -INF) -> void:
	devices.append({"type":"monkey","x":x,"y":y,"target_ladder":target_ladder,
		"mode":0,"timer":0.0,"facing":-1,"rocks":[],"trigger":trigger,"alerted":false})

func add_ladder(x: float,top: float,bottom: float,upper_x: float,lower_x: float) -> void:
	ladders.append({"x":x,"top":top,"bottom":bottom,"upper_landing":Vector2(upper_x,top),
		"lower_landing":Vector2(lower_x,bottom)})

func continue_boar(previous: RefCounted) -> void:
	if not boar_road or not previous.boar_road: return
	var boar:Dictionary=previous.rides[0]
	boar.merge(rides[0],true)
	rides[0]=boar
	vel.x=previous.vel.x
	stride=previous.stride
	last_step=previous.last_step

func spawn() -> void:
	var waiting_boar:=boar_road and checkpoint.x<float(rides[0].start)
	active_ride=0 if boar_road and not waiting_boar else -1
	mounted="ride" if active_ride==0 else ""
	for ride in rides:
		if boar_road:
			ride.position=Vector2(ride.start,ride.ground_y) if waiting_boar else checkpoint
		else:
			ride.arrived=checkpoint.x>=ride.end
			ride.position=Vector2(ride.end if ride.arrived else ride.start,ride.ground_y)
	chamber_jump=false
	pos = checkpoint
	ladder=-1
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
	for gate in key_gates:
		gate.key_taken=false
		gate.open=completed.has(gate.checkpoint)
	for device in devices:
		device.mode=0
		if device.type in ["hound","spider"]:
			device.facing=1 if device.has("rear_trigger") else -1
			device.dog=float(device.x)
			device.timer=0.0
			device.bark_time=0.0
		elif device.type=="swarm":
			device.flight=Vector2(device.x-110,device.y-28)
		elif device.type=="gorilla":
			device.mode=GorillaMode.HIDDEN if device.opening and completed.is_empty() else GorillaMode.RUNNING
			var start:=float(device.x) if device.mode==GorillaMode.HIDDEN else checkpoint.x-220
			device.chase=Vector2(start,device.y)
			device.timer=0.0
			device.rope=-1
		elif device.type=="snake":
			device.mode=SnakeMode.HIDDEN if checkpoint.x>float(device.x) else SnakeMode.GUARD
			device.timer=0.0
			device.misses=0
		elif device.type=="elephant":
			device.foot_x=device.x
			device.facing=1
			device.timer=0.0
		elif device.type=="monkey":
			device.rocks.clear()
			device.facing=-1
			device.timer=0.0
			device.alerted=false
		elif device.type=="cargo_net":
			device.amount=0.0
			device.timer=0.0
		elif device.type in ["cable_drum","rolling_log"]:
			device.roll_x=device.x
			device.timer=0.0
		elif device.type=="rocker":
			device.tilt=0.0
		elif device.type=="lockpair":
			device.first=0.0
			device.second=0.0
		else:
			device.amount=0.0
	near_valve=-1
	valve_action=""
	update_structures()
	update_platforms()
	camera_y=vertical_view()
	camera = clampf(pos.x-275, 0, maxf(0,width-960))

func update_devices(dt: float) -> void:
	for d in devices:
		match d.type:
			"swarm":
				if d.mode==2 or pos.x>=float(d.end):
					d.mode=2
					d.flight=Vector2(d.flight).move_toward(Vector2(float(d.end)+90,float(d.y)-140),105*dt)
				elif d.mode==1 or (pos.x>=float(d.x)-70 and pos.x<float(d.x)+75):
					d.mode=1
					d.flight=Vector2(d.flight).move_toward(pos+Vector2(0,-24+6*sin(time*4)),float(d.speed)*dt)
				else: d.mode=0
			"hound","spider":
				update_hound(d,dt)
			"snake":
				update_snake(d,dt)
			"elephant":
				update_elephant(d,dt)
			"gorilla":
				update_gorilla(d,dt)
			"monkey":
				update_monkey(d,dt)
			"cargo_net":
				if d.timer>0:
					d.timer=maxf(0,float(d.timer)-dt)
				elif grounded==int(d.platform):
					if d.amount==0: events.append("crate")
					d.amount=move_toward(float(d.amount),1.0,dt/float(d.hold_time))
					if d.amount==1: d.timer=.9
				else:
					d.amount=move_toward(float(d.amount),0.0,dt*.85)
			"cable_drum","rolling_log":
				update_rolling_hazard(d,dt)
			"rocker":
				var load:=0.0
				if grounded>=0 and platforms[grounded].style=="rocker" and devices[platforms[grounded].device]==d:
					var offset:=pos.x-float(d.x)
					var lever:=smoothstep(ROCKER_BALANCE_RADIUS,float(d.half_span),absf(offset))
					# A sensitive pivot responds visibly to small shifts in weight.
					load=signf(offset)*pow(lever,.25)
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
				d.amount=shutter_opening(time+float(d.offset))

func shutter_opening(seconds: float) -> float:
	var phase:=fposmod(seconds,SHUTTER_PERIOD)
	if phase<SHUTTER_OPEN_PAUSE: return 1.0
	var close_time:=phase-SHUTTER_OPEN_PAUSE
	if close_time<SHUTTER_TRAVEL:
		return clampf((sin(SHUTTER_OPEN_ANGLE-close_time*SHUTTER_SWEEP_SPEED)+.24)*2.8,0,1)
	var open_time:=phase-(SHUTTER_PERIOD-SHUTTER_TRAVEL)
	if open_time<=0.0: return 0.0
	return clampf((sin(SHUTTER_CLOSED_ANGLE+open_time*SHUTTER_SWEEP_SPEED)+.24)*2.8,0,1)

func update_structures() -> void:
	for roof in structures:
		var cycle:=fposmod(time,CULVERT_PERIOD)
		roof.cycle=cycle
		if roof.moving:
			var lift:=smoothstep(.85,1.5,cycle)*(1.0-smoothstep(3.10,3.80,cycle))
			roof.y=float(roof.floor)-lerpf(18,92,lift)
		if roof.type!="low":
			var discharge:=acid_release_time(roof)
			var acid_mode:=0
			if cycle>=discharge and cycle<ACID_STOP: acid_mode=2
			elif cycle>=discharge-.55 and cycle<discharge: acid_mode=1
			if acid_mode!=int(roof.acid_mode) and absf(pos.x-float(roof.x))<245:
				if acid_mode==1: events.append("ratchet")
				elif acid_mode==2: events.append("flow")
			roof.acid_mode=acid_mode

func roof_bounds(roof: Dictionary) -> Rect2:
	var top:=float(roof.floor)-118 if roof.moving else float(roof.y)
	return Rect2(roof.x,top,roof.w,float(roof.y)+15-top)

func acid_release_time(roof: Dictionary) -> float:
	return 2.75 if roof.moving else 2.60

func acid_bounds(roof: Dictionary) -> Rect2:
	var outlet:=float(roof.floor)-70
	return Rect2(float(roof.x)+18,outlet,float(roof.w)-36,float(roof.floor)-outlet)

func struck_by_structure() -> bool:
	var keeper:=Rect2(pos-Vector2(RADIUS,BODY),Vector2(2*RADIUS,BODY))
	for roof in structures:
		if roof.moving and keeper.intersects(roof_bounds(roof)): return true
		if roof.acid_mode==2 and keeper.intersects(acid_bounds(roof)): return true
	return false

func update_rolling_hazard(d: Dictionary,dt: float) -> void:
	match int(d.mode):
		0:
			if pos.x>=float(d.trigger) and pos.x<float(d.x) and absf(pos.y-float(d.y))<85:
				d.mode=1
				d.timer=d.warning
				events.append("step_wood" if d.type=="rolling_log" else "ratchet")
		1:
			d.timer-=dt
			if d.timer<=0:
				d.mode=2
				events.append("crate")
		2:
			d.roll_x=move_toward(float(d.roll_x),float(d.end),float(d.speed)*dt)
			if d.roll_x==d.end: d.mode=3

func update_snake(snake: Dictionary,dt: float) -> void:
	snake.timer=maxf(0,float(snake.timer)-dt)
	match int(snake.mode):
		SnakeMode.GUARD:
			var distance:=float(snake.x)-pos.x
			if distance>=0 and distance<=SNAKE_TRIGGER and absf(pos.y-float(snake.y))<86:
				snake.mode=SnakeMode.WINDUP
				snake.timer=SNAKE_WINDUP
				events.append("flow")
		SnakeMode.WINDUP:
			if snake.timer<=0:
				snake.mode=SnakeMode.BITE
				snake.timer=SNAKE_BITE_TIME
				events.append("rock_throw")
		SnakeMode.BITE:
			if snake.timer<=0:
				snake.misses+=1
				snake.mode=SnakeMode.RETREAT if snake.misses>=3 else SnakeMode.RECOVER
				snake.timer=SNAKE_RETREAT if snake.misses>=3 else SNAKE_REST
		SnakeMode.RECOVER:
			if snake.timer<=0: snake.mode=SnakeMode.GUARD
		SnakeMode.RETREAT:
			if snake.timer<=0: snake.mode=SnakeMode.HIDDEN

func snake_hint() -> String:
	for snake in devices:
		if snake.type!="snake" or snake.mode>=SnakeMode.RETREAT or absf(pos.x-float(snake.x))>215: continue
		if snake.mode==SnakeMode.WINDUP: return "Back away before the bite"
		return "Bait three bites · %d/3 missed" % int(snake.misses)
	return ""

func update_elephant(d: Dictionary,dt: float) -> void:
	match int(d.mode):
		1: # Lift its head before charging.
			d.timer-=dt
			if d.timer<=0: d.mode=2
		2:
			var target:=clampf(pos.x,float(d.start),float(d.end))
			if target!=d.foot_x: d.facing=signf(target-float(d.foot_x))
			d.foot_x=move_toward(float(d.foot_x),target,168.0*dt)
			if d.foot_x==target and pos.x!=target: d.mode=3
		3: # The keeper has escaped. Walk back to the grass.
			d.facing=signf(float(d.x)-float(d.foot_x))
			d.foot_x=move_toward(float(d.foot_x),float(d.x),84.0*dt)
			if is_equal_approx(float(d.foot_x),float(d.x)):
				d.mode=0
				d.facing=1

func add_chase_rope(start: float,end: float,deck_y: float) -> void:
	var reach:=(end-start)*.5
	var drop:=reach*.6+66
	chase_ropes.append({"start":start,"end":end,"deck_y":deck_y,
		"anchor":Vector2(start+reach,deck_y-drop-85),"length":Vector2(reach,drop).length()})

func continue_gorilla(previous: RefCounted) -> void:
	var lead:=maxf(70,previous.pos.x-float(previous.gorilla.chase.x))
	gorilla.chase.x=pos.x-lead

func update_gorilla(d: Dictionary,dt: float) -> void:
	match int(d.mode):
		GorillaMode.HIDDEN:
			if pos.x>=float(d.trigger):
				d.chase.x=camera-68
				d.mode=GorillaMode.ENTERING
			return
		GorillaMode.ENTERING:
			var mark:=maxf(0,camera)+62
			d.chase.x=move_toward(float(d.chase.x),mark,150.0*dt)
			if d.chase.x>=mark:
				d.mode=GorillaMode.DISPLAY
				d.timer=GORILLA_DISPLAY_TIME
				events.append("gorilla_intro")
			return
		GorillaMode.DISPLAY:
			d.timer-=dt
			if d.timer<=0:
				d.mode=GorillaMode.RUNNING
			return
	var lead:=pos.x-float(d.chase.x)
	var pace:=clampf(124.0+(lead-44.0)*.20,124.0,GORILLA_MAX_SPEED)
	d.chase.x=minf(pos.x,float(d.chase.x)+pace*dt)
	if not swing_gorilla(d):
		var surface:=float(d.y)
		for p in platforms:
			if p.style in ["loose","bollard"] or not is_solid(p): continue
			if float(p.pos.x)<=float(d.chase.x): surface=float(p.pos.y)
		d.chase.y=move_toward(float(d.chase.y),surface,340*dt)

func swing_gorilla(d: Dictionary) -> bool:
	d.rope=-1
	var x:=float(d.chase.x)
	for i in chase_ropes.size():
		var rope: Dictionary=chase_ropes[i]
		var start:=float(rope.start)
		if x<start-24 or x>=float(rope.end): continue
		if x<start:
			var lift:=smoothstep(start-24,start,x)
			d.chase.y=float(rope.deck_y)-29*lift
			return true
		var dx:=x-float(rope.anchor.x)
		var drop:=sqrt(maxf(0,pow(float(rope.length),2)-dx*dx))
		d.grip=Vector2(x,float(rope.anchor.y)+drop)
		d.rope=i
		d.chase.y=float(d.grip.y)+56
		return true
	return false

func swarm_distance() -> float:
	var distance:=INF
	if death_timer>0 or finish: return distance
	for d in devices:
		if d.type=="swarm" and d.mode==1:
			distance=minf(distance,Vector2(d.flight).distance_to(pos-Vector2(0,22)))
	return distance

func gorilla_intro_active() -> bool:
	return not gorilla.is_empty() and gorilla.mode in [GorillaMode.ENTERING,GorillaMode.DISPLAY]

func hits_gorilla(d: Dictionary) -> bool:
	var feet:=Vector2(d.chase)
	return d.mode==GorillaMode.RUNNING and absf(pos.x-feet.x)<40 and pos.y>feet.y-70 and pos.y-BODY<feet.y

func update_monkey(d: Dictionary,dt: float) -> void:
	for i in range(d.rocks.size()-1,-1,-1):
		var rock:Dictionary=d.rocks[i]
		var gravity:=float(rock.get("gravity",ROCK_GRAVITY))
		rock.pos+=rock.velocity*dt+Vector2.DOWN*(.5*gravity*dt*dt)
		rock.velocity.y+=gravity*dt
		if rock.pos.y>=float(d.y)-ROCK_RADIUS: d.rocks.remove_at(i)
	d.timer=maxf(0,float(d.timer)-dt)
	if int(d.target_ladder)>=0:
		if ladder==int(d.target_ladder) and d.timer<=0:
			throw_ladder_rock(d,ladders[ladder])
		return
	if not d.alerted:
		if pos.x<float(d.trigger): return
		d.alerted=true
	if absf(pos.x-float(d.x))>235 or absf(pos.y-float(d.y))>125:
		d.mode=0
		return
	d.facing=1 if pos.x>=float(d.x) else -1
	if d.timer>0: return
	if d.mode==0:
		d.mode=1
		d.timer=THROW_WINDUP
		events.append("monkey_call")
	else:
		var hand:=Vector2(float(d.x)+d.facing*15,float(d.y)-93)
		var flight_time:=.68+absf(pos.x-hand.x)*.001
		var target:=pos-Vector2(0,BODY*.5)
		var velocity:=(target-hand)/flight_time-Vector2.DOWN*(.5*ROCK_GRAVITY*flight_time)
		d.rocks.append({"pos":hand,"velocity":velocity})
		events.append("rock_throw")
		d.mode=0
		d.timer=1.3

func throw_ladder_rock(monkey: Dictionary,rungs: Dictionary) -> void:
	var midpoint:=Vector2(rungs.x,(float(rungs.top)+float(rungs.bottom))*.5)
	monkey.facing=1 if midpoint.x>=float(monkey.x) else -1
	var hand:=Vector2(float(monkey.x)+monkey.facing*15,float(monkey.y)-93)
	var velocity:=(midpoint-hand)/LADDER_ROCK_FLIGHT
	velocity.y-=.5*LADDER_ROCK_GRAVITY*LADDER_ROCK_FLIGHT
	monkey.rocks.append({"pos":hand,"velocity":velocity,"gravity":LADDER_ROCK_GRAVITY})
	monkey.timer=1.55
	events.append("rock_throw")

func hits_spikes(d: Dictionary) -> bool:
	if pos.y-BODY>=float(d.y): return false
	var count:=int(d.count)
	for tooth in count:
		var tip_x:=float(d.x)+(tooth-(count-1)*.5)*SPIKE_PITCH
		var gap:=maxf(0,absf(pos.x-tip_x)-RADIUS)
		if gap<SPIKE_PITCH*.5 and pos.y>float(d.y)-SPIKE_HEIGHT*(1.0-2*gap/SPIKE_PITCH):
			return true
	return false

func update_hound(d: Dictionary,dt: float) -> void:
	d.bark_time=maxf(0.0,float(d.bark_time)-dt)
	if d.has("rear_trigger"):
		match int(d.mode):
			0:
				if pos.x>=float(d.rear_trigger):
					d.mode=1
					d.timer=.39
					hound_call(d)
					events.append("pursuit")
			1:
				d.timer-=dt
				if d.timer<=0: d.mode=2
			2:
				d.dog=move_toward(float(d.dog),float(d.far_post),float(d.speed)*dt)
				if pos.x>=float(d.far_post) or d.dog>=float(d.far_post): d.mode=4
			4:
				d.facing=-1
				d.dog=move_toward(float(d.dog),float(d.x),122*dt)
				if d.dog==d.x: d.mode=5
		return
	# A sentry works the stretch between two posts. At either end it plants
	# its feet before reversing. Once the yard is empty it trots home.
	match int(d.mode):
		0:
			var distance:=float(d.x)-pos.x
			if distance>0 and distance<=335 and absf(pos.y-float(d.y))<78:
				d.mode=1
				d.timer=.58
				hound_call(d)
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
					hound_call(d)
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

func hound_call(d: Dictionary) -> void:
	if d.type=="hound":
		d.bark_time=.27
		events.append("bark")
	else:
		events.append("ratchet")

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
			elif p.style=="cargo_net":
				weight = float(d.amount)*float(d.amount)
			else: weight = d.amount
		p.pos = Vector2(p.base) + Vector2(p.delta)*weight

func surface_height(p: Dictionary,x: float) -> float:
	if p.style=="rocker":
		var beam:Dictionary=devices[p.device]
		return float(beam.y)+clampf(x-float(beam.x),-p.w*.5,p.w*.5)*float(beam.tilt)
	return float(p.pos.y)

func is_solid(p: Dictionary) -> bool:
	if p.style=="loose": return float(p.timer)<.74
	if p.style=="cargo_net": return float(devices[p.device].amount)<1
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
			if landing_box.intersects(roof_bounds(roof)): blocked=true
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
		events.append(footstep())

func needs_console(index: int) -> bool:
	return index==completed.size() and index<stations.size() and not str(stations[index].board).is_empty()

func nearby_ladder() -> int:
	if death_timer>0 or active_ride>=0 or ledge>=0: return -1
	for i in ladders.size():
		var rungs: Dictionary=ladders[i]
		if absf(pos.x-float(rungs.x))<=36 and pos.y>=float(rungs.top)-12 and pos.y<=float(rungs.bottom)+10:
			return i
	return -1

func toggle_ladder() -> bool:
	if death_timer>0: return false
	if ladder>=0:
		ladder=-1
		return true
	ladder=nearby_ladder()
	if ladder<0: return false
	var rungs: Dictionary=ladders[ladder]
	pos=Vector2(rungs.x,clampf(pos.y,float(rungs.top),float(rungs.bottom)))
	vel=Vector2.ZERO
	grounded=-1
	grace=0.0
	buffer=0.0
	for monkey in devices:
		if monkey.type=="monkey" and int(monkey.target_ladder)==ladder:
			events.append("monkey_call")
			throw_ladder_rock(monkey,rungs)
	return true

func ladder_step(dt: float,axis: float) -> void:
	var rungs: Dictionary=ladders[ladder]
	pos.y=clampf(pos.y-axis*LADDER_SPEED*dt,float(rungs.top),float(rungs.bottom))
	if axis>0 and pos.y==float(rungs.top):
		pos=rungs.upper_landing
		ladder=-1
	elif axis<0 and pos.y==float(rungs.bottom):
		pos=rungs.lower_landing
		ladder=-1

func nearby_key_gate() -> int:
	if death_timer>0 or ladder>=0: return -1
	for i in key_gates.size():
		var gate: Dictionary=key_gates[i]
		if not gate.open and absf(pos.x-float(gate.x))<=36 and absf(pos.y-float(gate.y))<42:
			return i
	return -1

func use_key_gate() -> bool:
	var index:=nearby_key_gate()
	if index<0: return false
	var gate: Dictionary=key_gates[index]
	if gate.key_taken:
		gate.open=true
		events.append("engage")
	return true

func struck_by_rock() -> bool:
	var body:=Rect2(pos-Vector2(RADIUS,BODY),Vector2(RADIUS*2,BODY)).grow(ROCK_RADIUS)
	for d in devices:
		if d.type!="monkey": continue
		for rock in d.rocks:
			if body.has_point(rock.pos): return true
	return false

func vertical_view() -> float:
	return minf(0.0,pos.y-272)

func track_keeper(dt: float) -> void:
	var horizontal:=clampf(pos.x-320,0,maxf(0,width-960))
	if not gorilla.is_empty() and gorilla.mode in [GorillaMode.HIDDEN,GorillaMode.ENTERING,GorillaMode.DISPLAY]:
		horizontal=0.0
	camera=lerpf(camera,horizontal,1-exp(-dt*5))
	var target:=minf(0,clampf(camera_y,pos.y-320,pos.y-223))
	camera_y=lerpf(camera_y,target,1-exp(-dt*4))

func step(dt: float, axis: float, jump: bool, grip: bool) -> void:
	if finish:
		return
	elapsed += dt
	if death_timer > 0:
		var impact_at:=GORILLA_SLAM_TIME-GORILLA_SLAM_IMPACT
		if not gorilla.is_empty() and gorilla.mode==GorillaMode.SLAM and death_timer>impact_at and death_timer-dt<=impact_at:
			events.append("impact")
		death_timer -= dt
		if death_timer <= 0:
			spawn()
		return
	if active_ride<0 and ledge<0:
		for i in rides.size():
			var vehicle:Dictionary=rides[i]
			var approach:=22.0 if vehicle.type=="ride" else 0.0
			if not vehicle.arrived and pos.x>=vehicle.start-approach and pos.x<vehicle.start+30 and absf(pos.y-float(vehicle.ground_y))<48:
				active_ride=i
				mounted=vehicle.type
				if mounted=="ride": events.append("boar_call")
				break
	if active_ride>=0:
		var adjustment:=BOAR_SPEED_ADJUSTMENT if mounted=="ride" else .08
		axis=RIDE_CRUISE+axis*adjustment
	grab_lock=maxf(0,grab_lock-dt)
	time += dt
	var was_in_gorilla_intro:=gorilla_intro_active()
	update_devices(dt)
	if was_in_gorilla_intro or gorilla_intro_active():
		vel=Vector2.ZERO
		buffer=0.0
		track_keeper(dt)
		return
	update_structures()
	update_planks(dt)
	update_platforms()
	if ladder>=0:
		ladder_step(dt,axis)
		if not gorilla.is_empty() and hits_gorilla(gorilla): fail_crossing(true,true)
		elif struck_by_rock(): fail_crossing(true)
		track_keeper(dt)
		return
	if ledge>=0:
		climb_step(dt,axis,jump)
		var grabbed:=not gorilla.is_empty() and hits_gorilla(gorilla)
		if grabbed or struck_by_structure() or struck_by_rock():
			fail_crossing(true,grabbed)
			return
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
	var pace:=RIDE_SPEED if active_ride>=0 else (SPEED if is_grounded() else AIR_SPEED)
	vel.x = move_toward(vel.x, axis*pace+slide_speed, dt*(1250 if is_grounded() else 760))
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
	for gate in key_gates:
		if gate.open: continue
		var door_x:=float(gate.x)
		pos.x=minf(pos.x,door_x-RADIUS) if old_x<door_x else maxf(pos.x,door_x+RADIUS)
	var dir := signi(roundi(signf(vel.x)))
	for p in platforms:
		if is_solid(p) and p.style in ["dock","rail","stone","drain","viaduct","pier","wide_pier"]:
			collide_side(p.pos.x, p.pos.x+p.w, p.pos.y, old_x, dir)
	for box in freight:
		collide_side(box.x-21,box.x+21,box.y-45,old_x,dir)
	for roof in structures:
		var bounds:=roof_bounds(roof)
		var left:=bounds.position.x
		var right:=bounds.end.x
		if old_y-BODY<bounds.end.y and old_y>bounds.position.y:
			if old_x+RADIUS<=left and pos.x+RADIUS>left: pos.x=left-RADIUS
			if old_x-RADIUS>=right and pos.x-RADIUS<right: pos.x=right+RADIUS
	for snake in devices:
		if snake.type=="snake" and snake.mode!=SnakeMode.HIDDEN and old_x<float(snake.x):
			pos.x=minf(pos.x,float(snake.x)-34)
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
			var bottom:=roof_bounds(roof).end.y
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
			events.append(footstep())
	else:
		grace = maxf(0,grace-dt)
	near_valve=-1
	valve_action=""
	chamber_jump=false
	var submerged := false
	for gate in key_gates:
		if not gate.open and not gate.key_taken and Vector2(gate.key_pos).distance_to(pos-Vector2(0,18))<25:
			gate.key_taken=true
			events.append("engage")
	var struck := struck_by_structure() or struck_by_rock()
	var grabbed:=not gorilla.is_empty() and hits_gorilla(gorilla)
	struck=struck or grabbed
	for i in devices.size():
		var d: Dictionary = devices[i]
		if d.type=="elephant":
			var pass_x:=float(d.x)+58
			if d.mode==0 and old_x<=pass_x and pos.x>pass_x:
				d.mode=1
				d.timer=.48
				events.append("elephant_call")
				events.append("pursuit")
			if d.mode==2 and absf(pos.x-float(d.foot_x))<46 and pos.y>float(d.y)-64 and pos.y-BODY<float(d.y):
				struck=true
		elif d.type=="snake" and d.mode==SnakeMode.BITE:
			var reach:=float(d.x)-pos.x
			if reach>=0 and reach<SNAKE_REACH+RADIUS and pos.y>float(d.y)-89: struck=true
		elif d.type=="spikes" and hits_spikes(d):
			struck=true
		elif d.type in ["cable_drum","rolling_log"] and d.mode==2:
			var center:=Vector2(d.roll_x,float(d.y)-DRUM_RADIUS)
			var closest:=center.clamp(pos-Vector2(RADIUS,BODY),pos+Vector2(RADIUS,0))
			if center.distance_squared_to(closest)<DRUM_RADIUS*DRUM_RADIUS:
				struck=true
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
		fail_crossing(struck,grabbed)
		return
	near_station = -1
	var next:=completed.size()
	if next<stations.size():
		var s:Dictionary=stations[next]
		if needs_console(next):
			if absf(pos.x-float(s.x))<78 and absf(pos.y-float(s.y))<45: near_station=next
		elif pos.x>=float(s.x):
			activate(next)
	if pos.x >= width-56 and completed.size() == stations.size():
		finish = true
	track_keeper(dt)

func fail_crossing(struck: bool, by_gorilla := false) -> void:
	if by_gorilla:
		death_timer=GORILLA_SLAM_TIME
		gorilla.mode=GorillaMode.SLAM
		if int(gorilla.rope)>=0:
			gorilla.chase.y=chase_ropes[gorilla.rope].deck_y
			gorilla.rope=-1
	else:
		death_timer=0.68
		events.append("splash" if not struck and grounded==-1 else "impact")
	ledge=-1
	ladder=-1

func is_grounded() -> bool:
	return grounded != -1

func footstep() -> String:
	if mounted=="ride": return "step_clay"
	if grounded<0: return "step_wood"
	match str(platforms[grounded].style):
		"rail","catwalk","span","hoist","cage": return "step"
		"grass": return "step_grass"
		"stump": return "step_wood"
		"stone","pier","wide_pier","viaduct","drain","bollard": return "step_stone"
		"loose","branch","vine","rocker","skiff","float","bob","chamber","balance": return "step_wood"
		"ray": return "step_glass"
		"island","cargo_net": return "step_soft"
	return GROUND_STEPS[Book.region(room)]

func activate(index: int) -> void:
	var s: Dictionary = stations[index]
	if completed.has(s.key):
		return
	completed.append(s.key)
	restored_at[s.key]=time
	checkpoint = Vector2(s.x+26,s.y)
	near_station = -1
	events.append("checkpoint" if str(s.board).is_empty() else "save")
