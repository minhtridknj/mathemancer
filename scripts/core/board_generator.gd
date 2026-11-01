class_name BoardGenerator
extends RefCounted

## Thuật toán sinh bàn cờ giải đố cho Mathemancer
## Đảm bảo: Sudoku không trùng lặp, Kakuro chính xác, Ordinal Mine Ranking, Ô mỏ neo và Phân tầng Sương mù

const SUITS: Array[String] = ["flame", "frost", "spark", "shadow"]

static func generate_level(grid_size: int, ante: int, seed_val: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_val != -1:
		rng.seed = seed_val
	else:
		rng.randomize()
		
	# 1. Sinh ma trận số Sudoku (Latin Square ngẫu nhiên)
	# Mọi hàng và mọi cột đều có chữ số duy nhất từ 1 đến grid_size
	var base_shift := 1
	if grid_size == 4: base_shift = 1
	var matrix: Array = []
	for r in range(grid_size):
		var row: Array[int] = []
		for c in range(grid_size):
			var val: int = ((r + c * (grid_size - 1)) % grid_size) + 1
			row.append(val)
		matrix.append(row)
		
	# Xáo trộn các hàng và các cột để tạo tính ngẫu nhiên
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
	# Đảm bảo không hàng/cột nào bị ngập toàn mìn (tối thiểu 1 ô an toàn mỗi dòng)
	var target_mines := 3
	if grid_size == 4: target_mines = 3
	elif grid_size == 5: target_mines = 5
	elif grid_size == 6: target_mines = 8
	else: target_mines = int(grid_size * 1.5)
	
	var placed_mines := 0
	var attempts := 0
	while placed_mines < target_mines and attempts < 100:
		attempts += 1
		# Đảm bảo Hàng 0 luôn có 0 mìn để người chơi luôn có xuất phát điểm suy luận 100% chắc chắn
		var mr := rng.randi_range(1, grid_size - 1)
		var mc := rng.randi_range(0, grid_size - 1)
		if not cells[mr][mc].is_mine:
			# Kiểm tra xem hàng/cột này đã quá nhiều mìn chưa
			var r_mines := 0
			for c in range(grid_size):
				if cells[mr][c].is_mine: r_mines += 1
			var c_mines := 0
			for r in range(grid_size):
				if cells[r][mc].is_mine: c_mines += 1
				
			if r_mines < grid_size - 1 and c_mines < grid_size - 1:
				cells[mr][mc].is_mine = true
				placed_mines += 1

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
	# Gom toàn bộ số lượng mìn của các hàng và cột, sắp xếp tăng dần các giá trị duy nhất
	var all_mine_counts: Array[int] = []
	for m in row_mines:
		if not all_mine_counts.has(m): all_mine_counts.append(m)
	for m in col_mines:
		if not all_mine_counts.has(m): all_mine_counts.append(m)
	all_mine_counts.sort()
	
	# Mức thấp nhất được gán Rank 1, mức tiếp theo là Rank 2...
	var rank_map := {}
	for idx in range(all_mine_counts.size()):
		rank_map[all_mine_counts[idx]] = idx + 1
		
	# 6. Phân bổ sương mù theo chặng (Staged Fog of War)
	# Chặng 1: Nửa đầu các hàng và cột mở khóa (Stage 1), giúp suy luận được khu vực đầu
	# Chặng 2: Nửa sau mở khóa sau khi đánh Hand (Stage 2)
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

	# 7. Mở sẵn 2-3 ô mỏ neo ban đầu (Given Numbers)
	# Ưu tiên mở 1 ô ở Hàng 1 để kết hợp với manh mối suy luận
	var row1_safe: Array[Vector2i] = []
	var other_safe: Array[Vector2i] = []
	for r in range(grid_size):
		for c in range(grid_size):
			if not cells[r][c].is_mine:
				if r == 1:
					row1_safe.append(Vector2i(r, c))
				else:
					other_safe.append(Vector2i(r, c))
					
	row1_safe.shuffle()
	other_safe.shuffle()
	
	if not row1_safe.is_empty():
		cells[row1_safe[0].x][row1_safe[0].y].is_given = true
		
	var num_more := 2
	for i in range(mini(num_more, other_safe.size())):
		cells[other_safe[i].x][other_safe[i].y].is_given = true

	return {
		"grid_size": grid_size,
		"ante": ante,
		"cells": cells,
		"row_clues": row_clues,
		"col_clues": col_clues
	}
