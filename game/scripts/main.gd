extends Node2D

const Book = preload("res://scripts/campaign.gd")
const Passage = preload("res://scripts/passage.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Hud = preload("res://scripts/hud.gd")
const Console = preload("res://scripts/console.gd")
const Logbook = preload("res://scripts/logbook.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const SERIF = preload("res://art/fonts/Yrsa-Medium.ttf")
const MONO = preload("res://art/fonts/LiberationMono-Regular.ttf")
var scenery := Scenery.new()
var hud := Hud.new()
var audio := Soundscape.new()
var logbook: Logbook
var route: Passage
var console: Console
var board_specs: Dictionary
var screen := ""
var resume_to := "play"
var settings_return := "menu"
var credits_return := "menu"
var active_station := -1
var fingers := {}
var replay := false
var jump_request := false
var key_grip := false
var mouse_grip := ""
var clock := 0.0
var aim := 0.72
var arrival := 0.0
var horn_count := 0
var ready_game := false
var last_system_back := -1000
var replay_time := 0.0
var chapter_page := 0
const CHAPTERS_PER_PAGE := 9
var practice_pages := {}
var practicing := false
var workshop_return := "menu"

func _ready() -> void:
	add_child(scenery)
	add_child(hud)
	hud.touch_device=OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	add_child(audio)
	board_specs = JSON.parse_string(FileAccess.get_file_as_string("res://art/schematics.json"))
	board_specs.merge(Book.NEW_BOARDS)
	logbook = Logbook.new()
	hud.button_scale=logbook.button_percent/100.0
	audio.set_enabled(logbook.sound)
	update_safe_area()
	get_viewport().size_changed.connect(update_safe_area)
	set_screen("menu")
	audio.surround(0)
	ready_game = true

func update_safe_area() -> void:
	var scale_factor := 1.0
	var offset := Vector2.ZERO
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var transform0 := get_viewport().get_screen_transform().affine_inverse()
		var safe_view := Rect2(transform0*Vector2(safe.position),transform0*Vector2(safe.end)-transform0*Vector2(safe.position))
		safe_view = safe_view.intersection(Rect2(0,0,960,540))
		if safe_view.has_area():
			scale_factor = minf(safe_view.size.x/960,safe_view.size.y/540)
			offset = safe_view.get_center()-Vector2(480,270)*scale_factor
	hud.position = offset
	hud.scale = Vector2.ONE*scale_factor
	if is_instance_valid(console):
		console.position = offset
		console.scale = hud.scale

func clear_input() -> void:
	fingers.clear()
	mouse_grip = ""
	jump_request = false
	key_grip = false
	hud.touched = []

func set_screen(next: String) -> void:
	screen = next
	if next in ["menu","chapters","aim","final"]: audio.accent.stop()
	audio.accent.stream_paused=next!="play"
	if next in ["menu","chapters","aim","final"]: audio.story.stop()
	audio.story.stream_paused=next!="play"
	audio.amb.volume_db=-11 if next in ["pause","settings","console"] else -4
	hud.screen = next
	hud.clear_children()
	hud.queue_redraw()
	clear_input()
	var game_back := route!=null and next in ["play","console","pause","settings","confirm"]
	if next=="aim" or next=="arrival" or next=="final" or (next=="credits" and credits_return=="final"):
		scenery.mode = "ending"
	elif next=="pause" and resume_to=="aim":
		scenery.mode = "ending"
	else:
		scenery.mode = "play" if game_back else "menu"
	if is_instance_valid(console):
		console.visible = next=="console"
		console.set_process(next=="console")
	match next:
		"menu": menu()
		"confirm": confirm_new()
		"pause": pause_menu()
		"settings": settings()
		"chapters": chapters()
		"workshop": workshop()
		"aim": aim_ui()
		"credits": credits()
		"licenses": licenses()
		"final": final_page()

func title(kicker: String, heading: String) -> void:
	hud.label(hud,Rect2(56,42,800,26),kicker,MONO,14,hud.BRASS)
	hud.label(hud,Rect2(54,76,830,65),heading,SERIF,52)

func menu() -> void:
	hud.label(hud,Rect2(52,61,360,43),"THE SIGNAL STATION",MONO,15,hud.BRASS)
	hud.label(hud,Rect2(48,133,480,102),"The Last Ferry",SERIF,77)
	hud.label(hud,Rect2(54,245,360,83),"Three horn blasts. Somewhere beyond the breakwater, a ferry is waiting for your light.",ThemeDB.fallback_font,19,hud.PAPER,true)
	var continuing := logbook.active and not logbook.ended
	hud.button(hud,Rect2(54,358,170,53),"Continue" if continuing else "New game",continue_game if continuing else ask_new,true)
	hud.button(hud,Rect2(237,358,147,53),"Chapters",func(): set_screen("chapters"))
	hud.button(hud,Rect2(397,358,177,53),"Puzzle workshop",open_workshop.bind("menu"))
	if continuing:
		hud.button(hud,Rect2(54,425,108,43),"New game",ask_new)
	hud.button(hud,Rect2(174 if continuing else 54,425,106,43),"Settings",func(): open_settings("menu"))
	hud.button(hud,Rect2(292 if continuing else 173,425,94,43),"Credits",func(): open_credits("menu"))

func ask_new() -> void:
	if logbook.active and not logbook.ended:
		set_screen("confirm")
	else: new_game()

func confirm_new() -> void:
	title("KEEPER'S LOG","Start a new voyage?")
	hud.label(hud,Rect2(56,154,550,67),"Your current checkpoint will be replaced. Unlocked chapters stay in the logbook.",ThemeDB.fallback_font,19,hud.PAPER,true)
	hud.button(hud,Rect2(56,276,170,52),"Start again",new_game,true)
	hud.button(hud,Rect2(240,276,130,52),"Cancel",func(): set_screen("menu"))

func new_game() -> void:
	audio.cooldown=0
	replay = false
	logbook.active = true
	logbook.ended = false
	logbook.played = 0
	logbook.puzzle_wait=0
	logbook.puzzle_turn=0
	horn_count = 0
	enter_room(0,[])

func continue_game() -> void:
	replay = false
	enter_room(logbook.room,logbook.cleared)

func enter_room(index: int, cleared: Array) -> void:
	var walking := {}
	var held_mouse := ""
	if screen=="play":
		for id in fingers:
			if fingers[id] in ["left","right"]: walking[id]=fingers[id]
		if mouse_grip in ["left","right"]: held_mouse=mouse_grip
	dispose_console()
	# Accept only a consecutive prefix of known checkpoint keys.
	var known: Array = []
	for token in str(Book.ROOMS[index][1]).split(" "):
		if token.begins_with("@"):
			var key := token.substr(1)
			if not cleared.has(key): break
			known.append(key)
	var prior:=route
	route = Passage.new(index,known)
	if replay:
		route.puzzle_wait=prior.puzzle_wait if prior else 0.0
		route.puzzle_turn=prior.puzzle_turn if prior else Book.chapter(index)
	else:
		route.puzzle_wait=logbook.puzzle_wait
		route.puzzle_turn=logbook.puzzle_turn
	scenery.route = route
	hud.route = route
	hud.replay = replay
	hud.notice = Book.arrival_text(index)
	hud.fade=.40
	hud.intro = 5.5 if not hud.notice.is_empty() else 0.0
	audio.surround(Book.CHAPTERS[Book.chapter(index)][3])
	audio.play_story(hud.intro)
	if not replay:
		logbook.room = index
		logbook.cleared = route.completed.duplicate()
		logbook.opened = maxi(logbook.opened,Book.chapter(index))
		logbook.store()
	set_screen("play")
	fingers=walking
	mouse_grip=held_mouse

func checkpoint() -> void:
	if not replay and route:
		logbook.puzzle_turn=route.puzzle_turn
		logbook.puzzle_wait=route.puzzle_wait
		logbook.room = route.room
		logbook.cleared = route.completed.duplicate()
		logbook.store()

func pause_game() -> void:
	if screen not in ["play","console","aim"]: return
	if practicing:
		leave_practice()
		return
	resume_to = screen
	checkpoint()
	set_screen("pause")

func pause_menu() -> void:
	title("KEEPER'S LOG   /   PAUSED",Book.ROOMS[route.room][0])
	hud.label(hud,Rect2(56,151,550,35),"Chapter %02d  ·  %s" % [Book.chapter(route.room)+1,Book.chapter_name(Book.chapter(route.room))],SERIF,26,hud.MUTE)
	hud.button(hud,Rect2(56,228,196,52),"Resume",func(): set_screen(resume_to),true)
	hud.button(hud,Rect2(266,228,210,52),"Restart checkpoint",func(): enter_room(route.room,route.completed))
	hud.button(hud,Rect2(56,298,196,49),"Settings",func(): open_settings("pause"))
	hud.button(hud,Rect2(266,298,210,49),"Title screen",leave_voyage)

func leave_voyage() -> void:
	checkpoint()
	dispose_console()
	route = null
	hud.route = null
	scenery.route = null
	replay = false
	audio.surround(0)
	set_screen("menu")

func open_settings(from: String) -> void:
	settings_return=from
	set_screen("settings")

func settings() -> void:
	title("KEEPER'S LOG","Settings")
	hud.label(hud,Rect2(56,167,400,41),"Harbor sounds and music",SERIF,29)
	hud.button(hud,Rect2(490,167,137,46),"Sound on" if logbook.sound else "Sound off",toggle_sound,true)
	hud.label(hud,Rect2(56,232,400,44),"Touch button size",SERIF,29)
	var smaller:=hud.button(hud,Rect2(490,232,60,46),"−",resize_controls.bind(-25))
	smaller.disabled=logbook.button_percent<=75
	hud.label(hud,Rect2(569,232,83,46),"%d%%" % logbook.button_percent,MONO,19)
	var larger:=hud.button(hud,Rect2(650,232,60,46),"+",resize_controls.bind(25))
	larger.disabled=logbook.button_percent>=150
	hud.label(hud,Rect2(56,296,843,53),"Jump toward a ledge to catch it. Hold toward it or tap jump to pull up. Move away to drop. Hold the hand while moving to shift cargo.",ThemeDB.fallback_font,17,hud.MUTE,true)
	hud.label(hud,Rect2(56,344,740,44),"Keyboard    A / D or arrows · Space to jump · E to use · Esc to pause",ThemeDB.fallback_font,16,hud.MUTE,true)
	hud.button(hud,Rect2(56,427,130,47),"Back",func(): set_screen(settings_return))

func resize_controls(change: int) -> void:
	logbook.button_percent=clampi(logbook.button_percent+change,75,150)
	hud.button_scale=logbook.button_percent/100.0
	logbook.store()
	set_screen("settings")

func toggle_sound() -> void:
	logbook.sound = not logbook.sound
	audio.set_enabled(logbook.sound)
	logbook.store()
	set_screen("settings")

func chapters() -> void:
	title("KEEPER'S LOG","Chapters")
	var page_count:=ceili(float(Book.CHAPTERS.size())/CHAPTERS_PER_PAGE)
	var first:=chapter_page*CHAPTERS_PER_PAGE
	for i in range(first,mini(first+CHAPTERS_PER_PAGE,Book.CHAPTERS.size())):
		var cell:=i-first
		var x := 56+(cell%3)*286
		var y := 146+floori(cell/3.0)*65
		var b := hud.button(hud,Rect2(x,y,272,54),"%02d     %s" % [i+1,Book.chapter_name(i)],play_chapter.bind(i))
		b.disabled = i>logbook.opened and not ProjectSettings.get_setting("ferry/testing/open_chapters",false)
		b.tooltip_text="Complete the preceding chapter to unlock." if b.disabled else "Replay from the chapter entrance."
		if b.disabled: b.modulate=Color(.63,.67,.66,.8)
	hud.button(hud,Rect2(56,437,130,47),"Back",func(): set_screen("menu"))
	hud.button(hud,Rect2(210,437,87,47),"Previous",turn_chapter_page.bind(-1)).disabled=chapter_page==0
	hud.label(hud,Rect2(314,437,110,47),"Page %d / %d" % [chapter_page+1,page_count],MONO,15,hud.PAPER)
	hud.button(hud,Rect2(430,437,84,47),"Next",turn_chapter_page.bind(1)).disabled=chapter_page==page_count-1
	hud.button(hud,Rect2(580,437,298,47),"Practice station puzzles",open_workshop.bind("chapters"))

func turn_chapter_page(direction: int) -> void:
	chapter_page+=direction
	set_screen("chapters")

func open_workshop(from: String) -> void:
	workshop_return=from
	set_screen("workshop")

func workshop() -> void:
	title("KEEPER’S LOG","Practice stations")
	for i in Book.FAMILIES.size():
		var family:Array=Book.FAMILIES[i]
		var key:String=family[int(practice_pages.get(i,0))]
		hud.button(hud,Rect2(56+(i%2)*424,149+floori(i/2.0)*62,395,50),Book.BOARD_TITLES[board_specs[key].kind],practice_station.bind(key))
	hud.button(hud,Rect2(56,430,130,47),"Back",func(): set_screen(workshop_return))

func practice_station(key: String) -> void:
	dispose_console()
	practicing=true
	show_board(key,0)
	for i in Book.FAMILIES.size():
		var family:Array=Book.FAMILIES[i]
		var page:=family.find(key)
		if page<0: continue
		practice_pages[i]=page
		console.label(console,Rect2(407,31,158,44),"Layout %d / %d" % [page+1,family.size()],MONO,14,hud.BRASS)
		console.button(console,Rect2(610,31,156,44),"Next layout",practice_station.bind(family[(page+1)%family.size()]))
		break

func play_chapter(index: int) -> void:
	route=null
	replay=true
	replay_time=0
	enter_room(Book.CHAPTER_STARTS[index],[])

func open_credits(from: String) -> void:
	credits_return=from
	set_screen("credits")

func credits() -> void:
	title("THE LAST FERRY","Credits")
	hud.label(hud,Rect2(56,153,790,147),"Harbor paintings created with OpenAI ImageGen. Dog bark recorded by Amada44. Keeper animation, machinery, puzzles and music were made for this voyage.\n\nBuilt with Godot Engine. Typography uses Yrsa and Liberation Mono.",ThemeDB.fallback_font,19,hud.PAPER,true)
	hud.button(hud,Rect2(56,388,140,49),"Back",func(): set_screen(credits_return))
	hud.button(hud,Rect2(212,388,174,49),"Licenses",func(): set_screen("licenses"))

func licenses() -> void:
	title("CREDITS","Licenses")
	var box := TextEdit.new()
	box.editable=false
	box.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	box.position=Vector2(56,145)
	box.size=Vector2(846,252)
	var notices:=PackedStringArray([Engine.get_license_text(),FileAccess.get_file_as_string("res://audio/bark-license.txt"),FileAccess.get_file_as_string("res://audio/splash-license.txt"),FileAccess.get_file_as_string("res://art/fonts/notices.txt")])
	for component in Engine.get_copyright_info():
		notices.append(str(component.name))
		for part in component.parts:
			for owner in part.copyright: notices.append(str(owner))
			notices.append(str(part.license))
	var license_info:=Engine.get_license_info()
	for name0 in license_info:
		notices.append(str(name0)+"\n"+str(license_info[name0]))
	box.text="\n\n".join(notices)
	hud.add_child(box)
	hud.button(hud,Rect2(56,431,125,46),"Back",func(): set_screen("credits"))

func use_nearby() -> void:
	if screen!="play": return
	if route.operate_valve(): return
	open_station()

func open_station() -> void:
	if screen!="play" or route.near_station<0: return
	active_station=route.near_station
	practicing=false
	show_board(Book.board_for(route.puzzle_turn),route.room)

func show_board(key: String,index: int) -> void:
	console=Console.new()
	add_child(console)
	console.setup(board_specs[key],key,index,practicing)
	console.closed.connect(close_console)
	console.restored.connect(solve_console)
	console.mechanical.connect(audio.cue)
	update_safe_area()
	set_screen("console")
	audio.cue("engage")

func dispose_console() -> void:
	if is_instance_valid(console):
		remove_child(console)
		console.queue_free()
		console=null

func close_console() -> void:
	if practicing:
		leave_practice()
		return
	if is_instance_valid(console) and console.model.solved():
		solve_console()
		return
	dispose_console()
	set_screen("play")

func leave_practice() -> void:
	dispose_console()
	practicing=false
	set_screen("workshop")

func solve_console() -> void:
	if practicing:
		for i in Book.FAMILIES.size():
			var family:Array=Book.FAMILIES[i]
			var page:=family.find(console.board_id)
			if page>=0:
				practice_pages[i]=(page+1)%family.size()
				break
		leave_practice()
		return
	route.activate(active_station)
	checkpoint()
	dispose_console()
	set_screen("play")
	hud.notice="The transmission catches. The way is open."
	hud.intro=2.7
	audio.play_story(hud.intro)

func room_finished() -> void:
	checkpoint()
	if route.room==Book.ROOMS.size()-1:
		aim=.20
		scenery.finale_lit=false
		scenery.arrival=0
		set_screen("aim")
	elif replay and Book.CHAPTER_STARTS.has(route.room+1):
		route=null
		scenery.route=null
		hud.route=null
		set_screen("chapters")
	else:
		enter_room(route.room+1,[])

func aim_ui() -> void:
	hud.label(hud,Rect2(51,393,570,55),"Sweep the light onto the ferry, then sound the horn.",ThemeDB.fallback_font,18,hud.PAPER,true)
	hud.button(hud,Rect2(51,456,82,47),"Left",func(): aim=clampf(aim-.045,0,1))
	hud.button(hud,Rect2(144,456,82,47),"Right",func(): aim=clampf(aim+.045,0,1))
	hud.button(hud,Rect2(243,456,177,47),"Sound horn",signal_ferry,true)
	hud.button(hud,Rect2(835,20,90,42),"Pause",pause_game)

func signal_ferry() -> void:
	audio.cue("signal")
	if absf(308+aim*560-663)>31:
		hud.notice="The sound fades into the fog."
		var cue_label := hud.label(hud,Rect2(53,343,465,36),hud.notice,SERIF,24,hud.PAPER)
		get_tree().create_timer(2).timeout.connect(func(): if is_instance_valid(cue_label): cue_label.queue_free())
		return
	arrival=0
	scenery.finale_lit=true
	set_screen("arrival")
	audio.cue("homecoming")
	if not replay:
		logbook.ended=true
		logbook.active=false
		logbook.store()

func final_page() -> void:
	hud.label(hud,Rect2(53,81,400,32),"THE LAST FERRY",MONO,15,hud.BRASS)
	hud.label(hud,Rect2(50,131,550,92),"Home by dawn",SERIF,64)
	hud.label(hud,Rect2(54,230,375,91),"The hull kisses the landing. For the first time since the flood, someone ties a line on the other side.",ThemeDB.fallback_font,19,hud.PAPER,true)
	var duration:=floori(replay_time if replay else logbook.played)
	var time_caption:="Chapter time" if replay else "Voyage time"
	hud.label(hud,Rect2(54,326,407,32),"%s    %02d:%02d:%02d" % [time_caption,floori(duration/3600.0),floori(duration/60.0)%60,duration%60],MONO,15,hud.BRASS)
	hud.button(hud,Rect2(54,374,154,51),"Credits",func(): open_credits("final"),true)
	hud.button(hud,Rect2(222,374,163,51),"Title screen",leave_voyage)

func back() -> void:
	match screen:
		"play","aim": pause_game()
		"console": close_console()
		"pause": set_screen(resume_to)
		"settings": set_screen(settings_return)
		"credits": set_screen(credits_return)
		"licenses": set_screen("credits")
		"workshop": set_screen(workshop_return)
		"chapters","confirm": set_screen("menu")
		"final": leave_voyage()
		"menu":
			if OS.has_feature("android"): get_tree().quit()

func system_back() -> void:
	# Android can deliver both a key event and a platform back callback for one press.
	var now:=Time.get_ticks_msec()
	if now-last_system_back<225: return
	last_system_back=now
	back()

func _notification(what: int) -> void:
	if not ready_game: return
	if what==NOTIFICATION_WM_GO_BACK_REQUEST: system_back()
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		pause_game()

func _input(event: InputEvent) -> void:
	if not ready_game: return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode in [KEY_ESCAPE,KEY_BACK]:
				if event.keycode==KEY_BACK: system_back()
				else: back()
				get_viewport().set_input_as_handled()
			elif screen=="console" and console.keyboard(event.keycode):
				get_viewport().set_input_as_handled()
			elif screen=="play":
				if event.keycode in [KEY_UP,KEY_W,KEY_SPACE]: jump_request=true
				if event.keycode in [KEY_E,KEY_ENTER]:
					key_grip=true
					use_nearby()
				if event.keycode==KEY_P: pause_game()
			elif screen=="aim" and event.keycode in [KEY_E,KEY_ENTER,KEY_SPACE]:
				signal_ferry()
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.keycode in [KEY_E,KEY_ENTER]: key_grip=false
		return
	if screen=="aim" and (event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		if event.position.y>145 and event.position.y<390: aim=clampf((event.position.x-308)/560,0,1)
	if screen!="play": return
	if event is InputEventScreenTouch:
		hud.touch_device=true
		if event.pressed:
			var key := hud.zone_at(hud.get_global_transform().affine_inverse()*event.position)
			fingers[event.index]=key
			trigger_zone(key)
		else: fingers.erase(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var key := hud.zone_at(hud.get_global_transform().affine_inverse()*event.position)
		if fingers.get(event.index,"") in ["left","right",""] and key in ["left","right",""]:
			fingers[event.index]=key
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_grip=hud.zone_at(hud.get_global_transform().affine_inverse()*event.position)
			trigger_zone(mouse_grip)
		else: mouse_grip=""
		get_viewport().set_input_as_handled()

func trigger_zone(key: String) -> void:
	match key:
		"jump": jump_request=true
		"use": use_nearby()
		"pause": pause_game()

func _physics_process(dt: float) -> void:
	if screen!="play": return
	var keys := fingers.values()
	keys.append(mouse_grip)
	hud.touched=keys
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or keys.has("left")
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or keys.has("right")
	route.step(dt,float(right)-float(left),jump_request,key_grip or keys.has("use"))
	jump_request=false
	if route.room==0 and not replay and horn_count<3 and route.elapsed>1.0+horn_count*2.85:
		audio.cue("signal")
		horn_count+=1
	audio.tick(dt)
	for msg in route.events:
		match msg:
			"checkpoint": checkpoint()
			"pursuit","undertow": audio.score(msg)
			_: audio.cue(str(msg))
	route.events.clear()
	if route.finish: room_finished()

func _process(dt: float) -> void:
	clock+=dt
	if not practicing and screen in ["play","console","aim"]:
		if replay: replay_time+=dt
		else: logbook.played+=dt
	if screen=="play":
		hud.intro=maxf(0,hud.intro-dt)
		audio.fade_story(hud.intro)
		hud.fade=maxf(0,hud.fade-dt)
	if screen=="aim":
		aim=clampf(aim+Input.get_axis("ui_left","ui_right")*dt*.33,0,1)
		scenery.finale_aim=aim
	if screen=="arrival":
		if arrival<3.4 and arrival+dt>=3.4: audio.cue("signal")
		arrival+=dt
		scenery.arrival=arrival
		if arrival>=12: set_screen("final")
	if screen not in ["pause","console","settings"]:
		scenery.age=clock
	scenery.position.y=-route.camera_y if scenery.mode=="play" and route else 0.0
	scenery.queue_redraw()
	hud.age=clock
	hud.queue_redraw()
