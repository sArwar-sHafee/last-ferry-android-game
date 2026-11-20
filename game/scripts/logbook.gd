extends RefCounted

const Book = preload("res://scripts/campaign.gd")
const EXPANDED_ROOMS := [
	0,1,2,4,5,6,7,8,9,10,12,17,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,
	35,37,39,40,42,44,47,51,53,54,55,57,59,60,61,62,64,66,67,68,69,70,71,72,73,
	74,75,76,77,78,79,88,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,
	107,108,109,110,114,118,129,131,132,133,134,135,136,137,144,147,148,149,
]
const CHAPTER_STARTS_BY_LAYOUT := {
	3:[0,9,19,30,39,49,60,68,80,91,101,111,121,131,138],
	4:[0,12,23,35,47,59,70,82],
	5:[0,5,9,12,16,21,23,27,32,35,39,43,47,52,55,59,63,65,70,75,79,82,85,87,89],
	6:[0,4,8,13,18,23,28,33,37,42,47,52,57,62,67,72,77,82,85,87,89],
}

var path := "user://harbor.cfg"
var active := false
var room := 0
var opened := 0
var ended := false
var cleared: Array = []
var sound := true
var button_percent := 100
var keeper_name := ""
var played := 0.0

func _init(file := "user://harbor.cfg") -> void:
	path = file
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK and cfg.load(path+".bak") != OK: return
	active = bool(cfg.get_value("voyage","active",false))
	var layout:=int(cfg.get_value("voyage","layout",1))
	var source:=int(cfg.get_value("voyage","room",0))
	if layout<2:
		source=149 if source>=29 else maxi(0,source)*5
	elif layout in [4,5,6]:
		source=EXPANDED_ROOMS[clampi(source,0,EXPANDED_ROOMS.size()-1)]
	room=Book.migrated_room(source)
	var opened_source:=int(cfg.get_value("voyage","opened",0))
	if layout<3:
		opened_source=clampi(opened_source,0,5)*25
	elif CHAPTER_STARTS_BY_LAYOUT.has(layout):
		var starts: Array=CHAPTER_STARTS_BY_LAYOUT[layout]
		opened_source=starts[clampi(opened_source,0,starts.size()-1)]
		if layout>=4: opened_source=EXPANDED_ROOMS[opened_source]
	opened=maxi(Book.chapter(Book.migrated_room(opened_source)),Book.chapter(room))
	ended = bool(cfg.get_value("voyage","ended",false))
	played = maxf(0,float(cfg.get_value("voyage","played",0)))
	var saved = cfg.get_value("voyage","cleared",[])
	if saved is Array and source==Book.SOURCE_ROOMS[room]: cleared=saved
	button_percent=clampi(roundi(float(cfg.get_value("settings","button_percent",100))/25)*25,75,150)
	sound = bool(cfg.get_value("settings","sound",true))
	keeper_name = str(cfg.get_value("settings","keeper_name",""))

func store() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("voyage","active",active)
	cfg.set_value("voyage","layout",7)
	cfg.set_value("voyage","room",Book.SOURCE_ROOMS[room])
	cfg.set_value("voyage","opened",Book.SOURCE_ROOMS[Book.CHAPTER_STARTS[opened]])
	cfg.set_value("voyage","ended",ended)
	cfg.set_value("voyage","played",played)
	cfg.set_value("voyage","cleared",cleared)
	cfg.set_value("settings","sound",sound)
	cfg.set_value("settings","button_percent",button_percent)
	cfg.set_value("settings","keeper_name",keeper_name)
	var tmp := path+".new"
	if cfg.save(tmp)!=OK:
		push_error("Could not write the harbor logbook.")
		return
	var dst := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(dst,dst+".bak")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),dst)!=OK:
		push_error("Could not replace the harbor logbook.")
