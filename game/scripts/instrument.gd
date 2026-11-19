extends RefCounted

const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var data: Dictionary
var kind: String
var w: int
var h: int
var pieces: Array
var vessels: Array
var boxes: Array
var worker: int
var pipes: Array
var mirrors: Dictionary
var lit: Array
var beam: Array
var reached_exit := false
var tokens: Array = []
var selected := -1
var history: Array = []
var moves := 0

func _init(spec: Dictionary) -> void:
	data = spec.duplicate(true)
	# JSON numbers arrive as floats. Board occupancy uses integer cell identities.
	for key in data:
		if data[key] is Array:
			integer_cells(data[key])
	kind = str(data.kind)
	w = int(data.get("w", 0))
	h = int(data.get("h", 0))
	reset()

func integer_cells(values: Array) -> void:
	for i in values.size():
		if values[i] is float: values[i] = int(values[i])
		elif values[i] is Array: integer_cells(values[i])

func reset() -> void:
	pieces = data.get("pieces", []).duplicate(true)
	vessels = data.get("start", []).duplicate()
	boxes = data.get("boxes", []).duplicate()
	worker = int(data.get("worker", 0))
	pipes = data.get("start", []).duplicate()
	mirrors = {}
	for pair in data.get("mirrors", []):
		mirrors[int(pair[0])] = int(pair[1])
	tokens = []
	if kind == "chart": tokens.append(int(data.port))
	if kind == "relay":
		tokens.resize(w*h)
		tokens.fill(true)
		for cell in data.switches: switch_cross(cell)
	history.clear()
	moves = 0
	selected = -1
	recalculate()

func neighbor(cell: int, dir: int) -> int:
	var x := cell % w + int(DIRS[dir].x)
	var y := floori(float(cell) / w) + int(DIRS[dir].y)
	return x + y * w if x >= 0 and x < w and y >= 0 and y < h else -1

func snapshot() -> Array:
	return [pieces.duplicate(true), vessels.duplicate(), boxes.duplicate(), worker, pipes.duplicate(), mirrors.duplicate(), tokens.duplicate()]

func remember() -> void:
	history.append(snapshot())
	if history.size() > 256:
		history.pop_front()
	moves += 1

func undo() -> void:
	selected = -1
	if history.is_empty():
		return
	var state: Array = history.pop_back()
	pieces = state[0]
	vessels = state[1]
	boxes = state[2]
	worker = state[3]
	pipes = state[4]
	mirrors = state[5]
	tokens = state[6]
	moves -= 1
	recalculate()

func piece_at(cell: int) -> int:
	for i in pieces.size():
		var item: Array = pieces[i]
		var stride := 1 if int(item[1]) == 1 else w
		for j in int(item[2]):
			if cell == int(item[0]) + stride * j:
				return i
	return -1

# Map the free cell at a moving hull's leading edge to its new stern.
func slip_stops(i: int) -> Dictionary:
	var stops := {}
	var item: Array = pieces[i]
	var axis := 1 if int(item[1]) == 1 else 2
	var extent := (int(item[2]) - 1) * (1 if axis == 1 else w)
	for sign_value in [-1, 1]:
		var end := int(item[0]) + (extent if sign_value == 1 else 0)
		var direction := axis if sign_value == 1 else (axis + 2) % 4
		end = neighbor(end, direction)
		while end >= 0 and piece_at(end) < 0:
			stops[end] = end - (extent if sign_value == 1 else 0)
			end = neighbor(end, direction)
	return stops

func switch_cross(cell: int) -> void:
	tokens[cell] = not tokens[cell]
	for d in 4:
		var n := neighbor(cell,d)
		if n>=0: tokens[n] = not tokens[n]

func hanging_mass() -> int:
	var mass := 0
	for cell in tokens: mass+=int(data.weights[cell])
	return mass

func tap(cell: int) -> bool:
	if kind == "sluice":
		if cell < 0 or cell >= vessels.size():
			return false
		if selected < 0 or cell == selected:
			selected = cell if selected < 0 and int(vessels[cell]) > 0 else -1
			return false
		var amount := mini(int(vessels[selected]), int(data.cap[cell]) - int(vessels[cell]))
		if amount == 0:
			selected = cell if int(vessels[cell]) > 0 else -1
			return false
		remember()
		vessels[selected] = int(vessels[selected]) - amount
		vessels[cell] = int(vessels[cell]) + amount
		selected = -1
		return true
	if cell < 0 or cell >= w*h:
		return false
	match kind:
		"chart":
			if tokens.has(cell) or data.shoals.has(cell): return false
			if cell==int(data.harbor) and tokens.size()+1 != w*h-data.shoals.size(): return false
			for d in 4:
				if neighbor(int(tokens.back()),d)==cell:
					remember()
					tokens.append(cell)
					return true
		"relay":
			remember()
			switch_cross(cell)
			return true
		"weights":
			if not tokens.has(cell) and tokens.size()==int(data.hooks): return false
			remember()
			if tokens.has(cell): tokens.erase(cell)
			else: tokens.append(cell)
			return true
		"slip":
			if selected >= 0:
				var stops := slip_stops(selected)
				if stops.has(cell):
					remember()
					pieces[selected][0] = stops[cell]
					selected = -1
					return true
			selected = piece_at(cell)
		"freight":
			if data.walls.has(cell):
				return false
			for dir in 4:
				if cell == neighbor(worker, dir):
					return walk(dir)
			if boxes.has(cell) or worker == cell:
				return false
			var queue := [worker]
			var seen := {worker:true}
			while not queue.is_empty():
				var current := int(queue.pop_front())
				for dir in 4:
					var n := neighbor(current, dir)
					if n < 0 or seen.has(n) or data.walls.has(n) or boxes.has(n):
						continue
					if n == cell:
						remember()
						worker = cell
						return true
					seen[n] = true
					queue.append(n)
		"pump":
			if data.fixed.has(cell):
				return false
			remember()
			var mask := int(pipes[cell])
			pipes[cell] = ((mask << 1) & 15) | (mask >> 3)
			recalculate()
			return true
		"lens":
			if not mirrors.has(cell):
				return false
			remember()
			mirrors[cell] = 1 - int(mirrors[cell])
			recalculate()
			return true
	return false

func walk(dir: int) -> bool:
	var n := neighbor(worker, dir)
	if n < 0 or data.walls.has(n):
		return false
	if boxes.has(n):
		var target := neighbor(n, dir)
		if target < 0 or data.walls.has(target) or boxes.has(target):
			return false
		remember()
		boxes[boxes.find(n)] = target
	else:
		remember()
	worker = n
	return true

func recalculate() -> void:
	lit = []
	beam = []
	reached_exit = false
	if kind == "pump":
		lit.append(int(data.source))
		var k := 0
		while k < lit.size():
			var cell := int(lit[k])
			k += 1
			for d in 4:
				if (int(pipes[cell]) & (1 << d)) == 0:
					continue
				var n := neighbor(cell, d)
				if n >= 0 and not lit.has(n) and int(pipes[n]) & (1 << ((d + 2) % 4)):
					lit.append(n)
	elif kind == "lens":
		var cell := int(data.entry)
		var dir := 1
		var seen := {}
		while cell >= 0 and not seen.has(cell * 4 + dir):
			seen[cell * 4 + dir] = true
			beam.append(cell)
			if mirrors.has(cell):
				dir = (dir ^ 1) if int(mirrors[cell]) == 0 else (3 - dir)
			var next := neighbor(cell, dir)
			reached_exit = next < 0 and cell == int(data.target) and dir == 1
			cell = next
		beam.append(-2 if reached_exit else -1)

func solved() -> bool:
	match kind:
		"chart": return tokens.back()==int(data.harbor) and tokens.size()==w*h-data.shoals.size()
		"relay": return not tokens.has(false)
		"weights": return tokens.size()==int(data.hooks) and hanging_mass()==int(data.target)
		"slip":
			return int(pieces[0][0]) == 16
		"sluice":
			return vessels == data.goal
		"freight":
			for cell in boxes:
				if not data.targets.has(cell):
					return false
			return true
		"pump":
			return lit.size() == w*h
		"lens":
			if not reached_exit:
				return false
			for relay in data.relays:
				if not beam.has(int(relay)):
					return false
			return true
	return false
