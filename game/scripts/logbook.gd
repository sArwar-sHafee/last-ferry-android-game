extends RefCounted

const Book = preload("res://scripts/campaign.gd")

var path := "user://harbor.cfg"
var active := false
var room := 0
var opened := 0
var ended := false
var cleared: Array = []
var sound := true
var button_percent := 100
var keeper_name := ""
var puzzle_wait := 0.0
var puzzle_turn := 0
var played := 0.0

func _init(file := "user://harbor.cfg") -> void:
	path = file
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK and cfg.load(path+".bak") != OK: return
	active = bool(cfg.get_value("voyage","active",false))
	room = int(cfg.get_value("voyage","room",0))
	if int(cfg.get_value("voyage","layout",1))<2:
		room=Book.legacy_index(clampi(room,0,Book.LANDMARKS.size()-1))
	elif int(cfg.get_value("voyage","layout",1))<4:
		room=Book.migrated_room(room)
	room=clampi(room,0,Book.ROOMS.size()-1)
	opened=int(cfg.get_value("voyage","opened",0))
	if int(cfg.get_value("voyage","layout",1))<3:
		opened=Book.chapter(Book.migrated_room(clampi(opened,0,5)*Book.ROOMS_PER_DISTRICT))
	elif int(cfg.get_value("voyage","layout",1))==3:
		var starts:=[0,9,19,30,39,49,60,68,80,91,101,111,121,131,138]
		opened=Book.chapter(Book.migrated_room(starts[clampi(opened,0,14)]))
	elif int(cfg.get_value("voyage","layout",1))==4:
		opened=Book.chapter(Book.REGION_STARTS[clampi(opened,0,Book.ENVIRONMENTS.size()-1)])
	elif int(cfg.get_value("voyage","layout",1))==5:
		var starts:=[0,5,9,12,16,21,23,27,32,35,39,43,47,52,55,59,63,65,70,75,79,82,85,87,89]
		opened=Book.chapter(starts[clampi(opened,0,starts.size()-1)])
	opened=clampi(maxi(opened,Book.chapter(room)),0,Book.CHAPTERS.size()-1)
	ended = bool(cfg.get_value("voyage","ended",false))
	played = maxf(0,float(cfg.get_value("voyage","played",0)))
	var saved = cfg.get_value("voyage","cleared",[])
	var layout:=int(cfg.get_value("voyage","layout",1))
	var source:=int(cfg.get_value("voyage","room",0))
	if layout==1: source=149 if source==29 else source*5
	if saved is Array and (layout>=4 or source==Book.SOURCE_ROOMS[room]): cleared=saved
	puzzle_wait=clampf(float(cfg.get_value("voyage","puzzle_wait",0)),0,600)
	puzzle_turn=maxi(0,int(cfg.get_value("voyage","puzzle_turn",0)))
	button_percent=clampi(roundi(float(cfg.get_value("settings","button_percent",100))/25)*25,75,150)
	sound = bool(cfg.get_value("settings","sound",true))
	keeper_name = str(cfg.get_value("settings","keeper_name",""))

func store() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("voyage","active",active)
	cfg.set_value("voyage","layout",6)
	cfg.set_value("voyage","room",room)
	cfg.set_value("voyage","opened",opened)
	cfg.set_value("voyage","ended",ended)
	cfg.set_value("voyage","played",played)
	cfg.set_value("voyage","cleared",cleared)
	cfg.set_value("settings","sound",sound)
	cfg.set_value("settings","button_percent",button_percent)
	cfg.set_value("settings","keeper_name",keeper_name)
	cfg.set_value("voyage","puzzle_wait",puzzle_wait)
	cfg.set_value("voyage","puzzle_turn",puzzle_turn)
	var tmp := path+".new"
	if cfg.save(tmp)!=OK:
		push_error("Could not write the harbor logbook.")
		return
	var dst := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(dst,dst+".bak")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),dst)!=OK:
		push_error("Could not replace the harbor logbook.")
