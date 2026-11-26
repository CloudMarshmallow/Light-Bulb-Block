class_name PuzzleEngine
extends RefCounted
## N×N 灯泡方块：GF(2) 求解（最小重量）与反向生成。
## 规则：按下格 c 翻转「自身 + 上下左右四邻」；目标全亮。
## locked 位掩码中的格子不可按（冰封），但仍会被相邻格翻转。

static var _mask_cache: Dictionary = {}
static var _row_cache: Dictionary = {}


static func all_on(n: int) -> int:
	return (1 << (n * n)) - 1


static func popcount(x: int) -> int:
	var c: int = 0
	var v: int = x
	while v != 0:
		v &= v - 1
		c += 1
	return c


static func highest_bit(x: int) -> int:
	var c: int = -1
	var v: int = x
	while v > 0:
		v = v >> 1
		c += 1
	return c


static func press_masks(n: int) -> Array:
	var cached: Variant = _mask_cache.get(n)
	if cached != null:
		return cached
	var masks: Array = []
	masks.resize(n * n)
	for r in range(n):
		for c in range(n):
			var idx: int = r * n + c
			var m: int = 1 << idx
			if r > 0:
				m |= 1 << (idx - n)
			if r < n - 1:
				m |= 1 << (idx + n)
			if c > 0:
				m |= 1 << (idx - 1)
			if c < n - 1:
				m |= 1 << (idx + 1)
			masks[idx] = m
	_mask_cache[n] = masks
	return masks


static func apply_press(state: int, cell: int, n: int) -> int:
	var masks: Array = press_masks(n)
	return state ^ (masks[cell] as int)


static func apply_presses(state: int, presses: int, n: int) -> int:
	var result: int = state
	var masks: Array = press_masks(n)
	for cell in range(n * n):
		if (presses >> cell) & 1:
			result ^= masks[cell] as int
	return result


static func _equations(n: int, locked: int = 0) -> Array:
	var key: String = "%d_%d" % [n, locked]
	var cached: Variant = _row_cache.get(key)
	if cached != null:
		return cached
	var nn: int = n * n
	var masks: Array = press_masks(n)
	var rows: Array = []
	rows.resize(nn)
	for i in range(nn):
		rows[i] = 0
	for cell in range(nn):
		if ((locked >> cell) & 1) != 0:
			continue
		var m: int = masks[cell] as int
		for lamp in range(nn):
			if ((m >> lamp) & 1) != 0:
				rows[lamp] = (rows[lamp] as int) | (1 << cell)
	_row_cache[key] = rows
	return rows


static func solve(state: int, n: int, locked: int = 0) -> Dictionary:
	## 返回 {"ok": bool, "optimal": int, "presses": int}
	var nn: int = n * n
	var rows: Array = _equations(n, locked)
	var rhs: int = state ^ all_on(n)
	var pivots: Dictionary = {}
	for i in range(nn):
		var cur: int = rows[i] as int
		var b: int = (rhs >> i) & 1
		while cur != 0:
			var c: int = highest_bit(cur)
			if pivots.has(c):
				cur ^= pivots[c][0] as int
				b ^= pivots[c][1] as int
			else:
				pivots[c] = [cur, b]
				break
		if cur == 0 and b == 1:
			return {"ok": false, "optimal": -1, "presses": 0}

	var x: int = 0
	var cols: Array = pivots.keys()
	cols.sort()
	for c in cols:
		var pr: int = pivots[c][0] as int
		var pb: int = pivots[c][1] as int
		var val: int = pb ^ (popcount(pr & x) & 1)
		if val == 1:
			x |= 1 << (c as int)

	var basis: Array = []
	for f in range(nn):
		if pivots.has(f):
			continue
		var vec: int = 1 << f
		for c in cols:
			var pr2: int = pivots[c][0] as int
			if (popcount(pr2 & vec) & 1) != 0:
				vec ^= 1 << (c as int)
		basis.append(vec)

	var best: int = x
	var best_w: int = popcount(x)
	var total: int = 1 << basis.size()
	for mask in range(1, total):
		var cand: int = x
		for i in range(basis.size()):
			if ((mask >> i) & 1) != 0:
				cand ^= basis[i] as int
		var w: int = popcount(cand)
		if w < best_w:
			best = cand
			best_w = w
	return {"ok": true, "optimal": best_w, "presses": best}


static func generate(rng: RandomNumberGenerator, n: int, target: int, locked: int = 0) -> Dictionary:
	## 反向生成：随机按法 P（重量 = target）→ state = ALL_ON ⊕ A·P，
	## 要求真最优 == target（避免线性折叠导致白给），否则重试。
	var nn: int = n * n
	target = max(1, min(target, nn))
	var allowed: Array = []
	for i in range(nn):
		if ((locked >> i) & 1) == 0:
			allowed.append(i)
	if allowed.size() < 2:
		return {"n": n, "state": all_on(n), "optimal": 0, "locked": locked}
	target = min(target, allowed.size() - 1)
	var fallback: Dictionary = {}
	for _attempt in range(400):
		var pool: Array = allowed.duplicate()
		var pressed: int = 0
		var picked: int = 0
		while picked < target:
			var idx: int = rng.randi_range(0, pool.size() - 1)
			pressed |= 1 << (pool[idx] as int)
			pool.remove_at(idx)
			picked += 1
		var start: int = apply_presses(all_on(n), pressed, n)
		if start == all_on(n):
			continue
		var res: Dictionary = solve(start, n, locked)
		if not (res["ok"] as bool) or (res["optimal"] as int) <= 0:
			continue
		var data: Dictionary = {"n": n, "state": start, "optimal": res["optimal"], "locked": locked}
		if (res["optimal"] as int) == target:
			return data
		if (res["optimal"] as int) >= max(2, target - 1):
			fallback = data
	if fallback.size() > 0:
		return fallback
	push_error("生成失败：连续 400 次未找到合适谜题")
	return {"n": n, "state": all_on(n), "optimal": 0, "locked": locked}
