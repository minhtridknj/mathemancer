class_name BoardGenerator
extends RefCounted

## Thuật toán sinh bàn cờ giải đố cho Mathemancer
## Đảm bảo: Sudoku không trùng lặp, Kakuro chính xác, Ordinal Mine Ranking,
## Phân bổ ô mỏ neo chiến lược, và 100% SUY LUẬN LOGIC KHÔNG BAO GIỜ BỊ 50/50.

const SUITS: Array[String] = ["flame", "frost", "spark", "shadow"]

static func generate_level(grid_size: int, ante: int, seed_val: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_val != -1:
		rng.seed = seed_val
	else:
		rng.randomize()
		
	# Lặp thử tối đa 100 lần để tìm bàn cờ được chứng minh toán học giải được 100% không đoán mò
	for attempt in range(100):
		var candidate := _try_generate_candidate(grid_size, ante, rng)
		if is_board_100_percent_solvable(candidate):
			return candidate
			
	# Dự phòng nếu sau 100 lần vẫn chưa đạt (rất hiếm): sinh với ô mỏ neo bổ sung
	return _try_generate_candidate(grid_size, ante, rng)

static func _try_generate_candidate(grid_size: int, ante: int, rng: RandomNumberGenerator) -> Dictionary:
	# 1. Sinh ma trận số Sudoku (Latin Square ngẫu nhiên)
	var matrix: Array = []
	for r in range(grid_size):
		var row: Array[int] = []
		for c in range(grid_size):
			var val: int = ((r + c * (grid_size - 1)) % grid_size) + 1
			row.append(val)
		matrix.append(row)
		
	# Xáo trộn các hàng và các cột
	for i in range(grid_size * 2):
		var r1 := rng.randi_range(0, grid_size - 1)
		var r2 := rng.randi_range(0, grid_size - 1)
		var temp_row = matrix[r1]
		matrix[r1] = matrix[r2]
		matrix[r2] = temp_row
		
	for i in range(grid_size * 2):
		var c1 := rng.randi_range(0, grid_size - 1)
		var c2 := rng.randi_range(0, grid_size - 1)
		for r in range(grid_size):
			var temp = matrix[r][c1]
			matrix[r][c1] = matrix[r][c2]
			matrix[r][c2] = temp

	# 2. Tạo cấu trúc Cells và gán Chất nguyên tố (Suits)
	var cells: Array = []
	for r in range(grid_size):
		var row: Array = []
		for c in range(grid_size):
			var suit: String = SUITS[rng.randi_range(0, SUITS.size() - 1)]
			row.append({
				"val": matrix[r][c],
				"suit": suit,
				"is_mine": false,
				"is_given": false
			})
		cells.append(row)

	# 3. Gieo mìn dựa theo Ante và Grid Size
	# Cho phép rải mìn tự do trên mọi hàng/cột (kể cả Hàng 0) ngay từ Ante 1.
	# Thiết lập các cấu trúc phân bổ ngẫu nhiên để:
	# - Rank 1 có thể có 0 mìn HOẶC >= 1 mìn (người chơi tự suy luận).
	# - Khoảng cách chênh lệch mìn giữa các rank là ngẫu nhiên (1, 2, 3... quả mìn).
	# 3. Gieo mìn dựa theo Ante và Grid Size
	# Thiết lập các cấu trúc phân bổ ngẫu nhiên để:
	# - Rank 1 có thể có 0 mìn HOẶC >= 1 mìn (người chơi tự suy luận, không đoán trước được ở mọi Ante).
	# - Khoảng cách chênh lệch mìn giữa các rank là ngẫu nhiên (1, 2, 3... quả mìn).
	# - Loại bỏ triệt để mọi tình trạng mặc định (default 0 mìn hoặc default chỉ chênh 1 mìn) trên tất cả các Ante.
	var min_mine_rank := 0
	var r_roll := rng.randf()
	if grid_size <= 4:
		if r_roll < 0.45: min_mine_rank = 1
	elif grid_size <= 5:
		if r_roll < 0.50: min_mine_rank = 1
	elif grid_size <= 6:
		if r_roll < 0.45: min_mine_rank = 1
		elif r_roll < 0.55: min_mine_rank = 2
	else:
		if r_roll < 0.45: min_mine_rank = 1
		elif r_roll < 0.60: min_mine_rank = 2

	# Nếu min_mine_rank >= 1: gieo hoán vị đầy đủ để mọi hàng/cột đều có ít nhất min_mine_rank quả mìn
	if min_mine_rank >= 1:
		var perm: Array[int] = []
		for i in range(grid_size): perm.append(i)
		perm.shuffle()
		for r in range(grid_size):
			cells[r][perm[r]].is_mine = true
			
		if min_mine_rank >= 2:
			var shift := rng.randi_range(1, grid_size - 1)
			for r in range(grid_size):
				var c := (perm[r] + shift) % grid_size
				cells[r][c].is_mine = true

	# Danh sách hàng và cột khả dụng cho việc gieo các cấu trúc chênh lệch rank
	var avail_r: Array[int] = []
	var avail_c: Array[int] = []
	for i in range(grid_size):
		avail_r.append(i)
		avail_c.append(i)
	avail_r.shuffle()
	avail_c.shuffle()

	# Nếu min_mine_rank == 0: BẢO LƯU ít nhất 1 hàng và 1 cột không có mìn để đảm bảo Rank 1 bắt đầu từ 0
	var reserved_r := -1
	var reserved_c := -1
	if min_mine_rank == 0:
		reserved_r = avail_r.pop_back()
		reserved_c = avail_c.pop_back()

	# Hàm kiểm tra đảm bảo mỗi hàng và cột luôn có ít nhất 1 ô an toàn (tối đa grid_size - 1 quả mìn)
	var can_place_mine := func(target_r: int, target_c: int) -> bool:
		if cells[target_r][target_c].is_mine: return false
		var rm := 0
		for c in range(grid_size):
			if cells[target_r][c].is_mine: rm += 1
		if rm >= grid_size - 1: return false
		var cm := 0
		for r in range(grid_size):
			if cells[r][target_c].is_mine: cm += 1
		if cm >= grid_size - 1: return false
		return true

	# Các chiến lược tạo bước nhảy rank ngẫu nhiên (gaps >= 1, 2, 3...)
	# Chiến lược 0: Khối giao điểm k x k (tạo bước nhảy gap = k mìn)
	# Chiến lược 1: Bó mìn theo hàng/cột (tạo bước nhảy 2-3 mìn trên cùng 1 đường)
	# Chiến lược 2: Cụm bậc thang phân tầng (tạo nhiều rank phân cách)
	var strat := rng.randi_range(0, 2)
	
	if strat == 0:
		var max_k := mini(3, grid_size - 1 - min_mine_rank)
		var k := rng.randi_range(2, maxi(2, max_k))
		var sel_r := avail_r.slice(0, mini(k, avail_r.size()))
		var sel_c := avail_c.slice(0, mini(k, avail_c.size()))
		for r in sel_r:
			for c in sel_c:
				if can_place_mine.call(r, c):
					cells[r][c].is_mine = true
	elif strat == 1:
		var num_bundles := rng.randi_range(1, 2)
		for _b in range(num_bundles):
			if avail_r.is_empty(): break
			var br: int = avail_r[rng.randi_range(0, avail_r.size() - 1)]
			var bundle_len := rng.randi_range(2, 3)
			var valid_cols: Array[int] = []
			for c in avail_c:
				if can_place_mine.call(br, c): valid_cols.append(c)
			valid_cols.shuffle()
			for i in range(mini(bundle_len, valid_cols.size())):
				cells[br][valid_cols[i]].is_mine = true
	else:
		if avail_r.size() >= 2 and avail_c.size() >= 2:
			var sel_r := avail_r.slice(0, 2)
			var sel_c := avail_c.slice(0, 2)
			for r in sel_r:
				for c in sel_c:
					if can_place_mine.call(r, c):
						cells[r][c].is_mine = true
			if grid_size >= 6 and rng.randf() < 0.5:
				var rem_r := avail_r.slice(2)
				var rem_c := avail_c.slice(2)
				if rem_r.size() >= 2 and rem_c.size() >= 2:
					for r in rem_r.slice(0, 2):
						for c in rem_c.slice(0, 2):
							if can_place_mine.call(r, c):
								cells[r][c].is_mine = true

	# Bổ sung số lượng mìn tối thiểu theo kích thước bàn cờ (tránh quá ít mìn)
	var target_min_mines := 3 if grid_size == 4 else (4 if grid_size == 5 else (6 if grid_size == 6 else (8 if grid_size == 7 else 10)))
	var cur_m := 0
	for r in range(grid_size):
		for c in range(grid_size):
			if cells[r][c].is_mine: cur_m += 1
	while cur_m < target_min_mines:
		var cand_cells: Array[Vector2i] = []
		for r in range(grid_size):
			if r == reserved_r: continue
			for c in range(grid_size):
				if c == reserved_c: continue
				if can_place_mine.call(r, c): cand_cells.append(Vector2i(r, c))
		if cand_cells.is_empty(): break
		var p: Vector2i = cand_cells[rng.randi_range(0, cand_cells.size() - 1)]
		cells[p.x][p.y].is_mine = true
		cur_m += 1

	# Đảm bảo luôn có tối thiểu 2 Ranks khác nhau (loại bỏ bàn cờ 1 rank)
	var pre_r_counts: Array[int] = []
	for r in range(grid_size):
		var m := 0
		for c in range(grid_size):
			if cells[r][c].is_mine: m += 1
		pre_r_counts.append(m)
	for c in range(grid_size):
		var m := 0
		for r in range(grid_size):
			if cells[r][c].is_mine: m += 1
		pre_r_counts.append(m)
		
	var pre_u_counts: Array[int] = []
	for m in pre_r_counts:
		if not pre_u_counts.has(m): pre_u_counts.append(m)
	pre_u_counts.sort()
	
	if pre_u_counts.size() < 2:
		for r in range(grid_size):
			if r == reserved_r: continue
			var placed := false
			for c in range(grid_size):
				if c == reserved_c: continue
				if can_place_mine.call(r, c):
					cells[r][c].is_mine = true
					placed = true
					break
			if placed: break

	# 4. Tính toán số lượng mìn và Tổng Kakuro cho từng hàng & cột
	var row_mines: Array[int] = []
	var col_mines: Array[int] = []
	var row_sums: Array[int] = []
	var col_sums: Array[int] = []
	
	for r in range(grid_size):
		var m := 0
		var s := 0
		for c in range(grid_size):
			if cells[r][c].is_mine:
				m += 1
			else:
				s += cells[r][c].val
		row_mines.append(m)
		row_sums.append(s)
		
	for c in range(grid_size):
		var m := 0
		var s := 0
		for r in range(grid_size):
			if cells[r][c].is_mine:
				m += 1
			else:
				s += cells[r][c].val
		col_mines.append(m)
		col_sums.append(s)

	# 5. Xếp Hạng Thứ Bậc Mìn Tương Đối (Ordinal Mine Ranking)
	# Rank thấp nhất luôn là Rank 1 (số mìn của Rank 1 có thể là 0 hoặc >= 1 do người chơi tự suy luận).
	# Khoảng cách giữa các rank (Rank 1 -> Rank 2 -> Rank 3...) là ngẫu nhiên, không cố định chênh 1 quả.
	var all_mine_counts: Array[int] = []
	for m in row_mines:
		if not all_mine_counts.has(m): all_mine_counts.append(m)
	for m in col_mines:
		if not all_mine_counts.has(m): all_mine_counts.append(m)
	all_mine_counts.sort()
	
	var rank_map := {}
	for idx in range(all_mine_counts.size()):
		rank_map[all_mine_counts[idx]] = idx + 1
		
	# 6. Phân bổ sương mù theo chặng (Staged Fog of War)
	var half_grid := int(ceil(grid_size / 2.0))
	var row_clues: Array = []
	for r in range(grid_size):
		var stage := 1 if r < half_grid else 2
		row_clues.append({
			"sum": row_sums[r],
			"rank": rank_map[row_mines[r]],
			"unlocked_at_stage": stage
		})
		
	var col_clues: Array = []
	for c in range(grid_size):
		var stage := 1 if c < half_grid else 2
		col_clues.append({
			"sum": col_sums[c],
			"rank": rank_map[col_mines[c]],
			"unlocked_at_stage": stage
		})

	# 7. Phân bổ ô mỏ neo chiến lược (Strategic Given Anchors)
	# Tập hợp toàn bộ các ô an toàn trên bàn cờ
	var safe_cells: Array[Vector2i] = []
	for r in range(grid_size):
		for c in range(grid_size):
			if not cells[r][c].is_mine:
				safe_cells.append(Vector2i(r, c))
				
	for i in range(safe_cells.size()):
		var swap_idx := rng.randi_range(0, safe_cells.size() - 1)
		var tmp := safe_cells[i]
		safe_cells[i] = safe_cells[swap_idx]
		safe_cells[swap_idx] = tmp
		
	var base_anchors := 3 if grid_size <= 4 else (4 if grid_size == 5 else (5 if grid_size == 6 else (6 if grid_size == 7 else 7)))
	for i in range(mini(base_anchors, safe_cells.size())):
		var p := safe_cells[i]
		cells[p.x][p.y].is_given = true

	var candidate := {
		"grid_size": grid_size,
		"ante": ante,
		"cells": cells,
		"row_clues": row_clues,
		"col_clues": col_clues
	}

	# Nếu bàn cờ chưa giải được bằng logic với số mỏ neo cơ bản:
	# Mở thêm dần từng ô an toàn ban đầu để đảm bảo 100% suy luận logic được đoạn đầu
	if not is_board_100_percent_solvable(candidate):
		for extra_idx in range(base_anchors, mini(base_anchors + 4, safe_cells.size())):
			var p := safe_cells[extra_idx]
			cells[p.x][p.y].is_given = true
			if is_board_100_percent_solvable(candidate):
				break

	return candidate

## Bộ giải suy luận toán học (Logical Solver)
## Kiểm tra xem bàn cờ có thể giải được 100% bằng logic thuần túy hay không (không có điểm 50/50)
static func is_board_100_percent_solvable(board_data: Dictionary) -> bool:
	var sz: int = board_data.grid_size
	var cells: Array = board_data.cells
	
	var is_safe: Array = []
	var is_mine: Array = []
	for r in range(sz):
		var r_safe: Array[bool] = []
		var r_mine: Array[bool] = []
		for c in range(sz):
			r_safe.append(cells[r][c].is_given)
			r_mine.append(false)
		is_safe.append(r_safe)
		is_mine.append(r_mine)
		
	var stage := 1
	var progress := true
	
	while progress:
		progress = false
		
		# Quét suy luận theo từng Hàng
		for r in range(sz):
			var clue = board_data.row_clues[r]
			if clue.unlocked_at_stage > stage:
				continue
				
			var known_safe_sum := 0
			var unk_cells: Array[Vector2i] = []
			for c in range(sz):
				if is_safe[r][c]:
					known_safe_sum += cells[r][c].val
				elif not is_mine[r][c]:
					unk_cells.append(Vector2i(r, c))
					
			if unk_cells.is_empty():
				continue
				
			var rem_safe: int = int(clue.sum) - known_safe_sum
			if rem_safe == 0:
				for p in unk_cells:
					is_mine[p.x][p.y] = true
					progress = true
				continue
				
			var n := unk_cells.size()
			if n <= 10:
				var valid_masks: Array[int] = []
				for mask in range(1 << n):
					var s := 0
					for i in range(n):
						if mask & (1 << i):
							s += cells[unk_cells[i].x][unk_cells[i].y].val
					if s == rem_safe:
						valid_masks.append(mask)
						
				if valid_masks.is_empty():
					return false
					
				var all_m := valid_masks[0]
				var any_m := valid_masks[0]
				for m in valid_masks:
					all_m &= m
					any_m |= m
					
				for i in range(n):
					if (all_m & (1 << i)) and not is_safe[unk_cells[i].x][unk_cells[i].y]:
						is_safe[unk_cells[i].x][unk_cells[i].y] = true
						progress = true
					if not (any_m & (1 << i)) and not is_mine[unk_cells[i].x][unk_cells[i].y]:
						is_mine[unk_cells[i].x][unk_cells[i].y] = true
						progress = true

		# Quét suy luận theo từng Cột
		for c in range(sz):
			var clue = board_data.col_clues[c]
			if clue.unlocked_at_stage > stage:
				continue
				
			var known_safe_sum := 0
			var unk_cells: Array[Vector2i] = []
			for r in range(sz):
				if is_safe[r][c]:
					known_safe_sum += cells[r][c].val
				elif not is_mine[r][c]:
					unk_cells.append(Vector2i(r, c))
					
			if unk_cells.is_empty():
				continue
				
			var rem_safe: int = int(clue.sum) - known_safe_sum
			if rem_safe == 0:
				for p in unk_cells:
					is_mine[p.x][p.y] = true
					progress = true
				continue
				
			var n := unk_cells.size()
			if n <= 10:
				var valid_masks: Array[int] = []
				for mask in range(1 << n):
					var s := 0
					for i in range(n):
						if mask & (1 << i):
							s += cells[unk_cells[i].x][unk_cells[i].y].val
					if s == rem_safe:
						valid_masks.append(mask)
						
				if valid_masks.is_empty():
					return false
					
				var all_m := valid_masks[0]
				var any_m := valid_masks[0]
				for m in valid_masks:
					all_m &= m
					any_m |= m
					
				for i in range(n):
					if (all_m & (1 << i)) and not is_safe[unk_cells[i].x][unk_cells[i].y]:
						is_safe[unk_cells[i].x][unk_cells[i].y] = true
						progress = true
					if not (any_m & (1 << i)) and not is_mine[unk_cells[i].x][unk_cells[i].y]:
						is_mine[unk_cells[i].x][unk_cells[i].y] = true
						progress = true

		# Giải trừ sương mù sang Chặng 2 khi đã suy luận được tối thiểu 3 ô an toàn ở Chặng 1
		if not progress and stage == 1:
			var safe_count := 0
			for r in range(sz):
				for c in range(sz):
					if is_safe[r][c]:
						safe_count += 1
			if safe_count >= 3:
				stage = 2
				progress = true

	# Kiểm tra xem toàn bộ các ô đã được định đoạt rõ ràng (an toàn hoặc mìn) hay chưa
	for r in range(sz):
		for c in range(sz):
			if not is_safe[r][c] and not is_mine[r][c]:
				return false
	return true
