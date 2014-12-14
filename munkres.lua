--
-- Created by IntelliJ IDEA.
-- User: jetbird
-- Date: 13.12.14
-- Time: 22:40
--



function munkres(C)
	local nrow = #C
	local ncol = #(C[1]) -- TODO проверка на существование C[1]
	local rowCover = {}
	local colCover = {}
	local step = 1
	local done = false
	local path_row_0
	local path_col_0
	local path_count

	local function createZeroMatrix(nrows, ncols)
		local M = {}
		for r = 1, nrows do
			M[r] = {}
			for c = 1, ncols do
				M[r][c] = 0
			end
		end
		return M
	end
	local M = createZeroMatrix(nrow, ncol)
	local path = createZeroMatrix(nrow, ncol)

	function showMatrix(M, name)
		if name then print("Matrix "..name..": ") end
		for r = 1, nrow do
			print(table.concat(M[r], ', '))
		end
	end

	-- For each row of the matrix, find the smallest element and subtract it from
	-- every element in its row.  Go to Step 2.
	function step_1()

		local min_in_row;
		for r = 1, nrow do
			min_in_row = C[r][1]
			for c = 1, ncol do
				if C[r][c] < min_in_row then
					min_in_row = C[r][c]
				end
			end

			for c = 1, ncol do
				C[r][c] = C[r][c] - min_in_row
			end
		end

		step = 2
	end

	-- Find a zero (Z) in the resulting matrix.  If there is no starred zero in
	-- its row or column, star Z. Repeat for each element in the matrix.
	-- Go to Step 3.
	function step_2()
		for r = 1, nrow do
			for c = 1, ncol do
				if C[r][c] == 0 and rowCover[r] ~= 1 and colCover[c] ~= 1 then
					M[r][c] = 1
					rowCover[r] = 1
					colCover[c] = 1
				end
			end
		end

		for i = 1, nrow do
			rowCover[i] = 0
		end

		for i = 1, ncol do
			colCover[i] = 0
		end

		step = 3
	end

	-- Cover each column containing a starred zero.  If K columns are covered,
	-- the starred zeros describe a complete set of unique assignments.
	-- In this case, Go to DONE, otherwise, Go to Step 4.
	function step_3()
		for r = 1, nrow do
			for c = 1, ncol do
				if M[r][c] == 1 then
					colCover[c] = 1
				end
			end
		end

		local colcount = 0;
		for c = 1, ncol do
			if colCover[c] == 1 then
				colcount = colcount + 1
			end
		end
		if colcount >= ncol or colcount >= nrow then
			step = 7
		else
			step = 4
		end
	end

	local function find_a_zero(row, col)
		local r = 1 -- 0
		local c
		local done = false
		row = -1
		col = -1

		while done ~= true do
			c = 1 -- 0
			while true do
				if C[r][c] and rowCover[r] == 0 and colCover[c] == 0 then
					row = r
					col = c
					done = true
				end
				c = c + 1
				if c > ncol or done then -- >=
					break
				end
			end
			r = r + 1
			if r > nrow then -- >=
				done = true
			end
		end

		return row, col
	end

	local function star_in_row(row)
		local tmp = false
		for c = 1, ncol do
			if M[row][c] == 1 then
				tmp = true
				-- TODO possible return tmp here
			end
		end
		return tmp
	end

	local function find_star_in_row(row, col)
		col = -1
		for c = 1, ncol do
			if M[row][c] == 1 then
				col = c
			end
		end
		return col
	end


	-- Find a noncovered zero and prime it.  If there is no starred zero in the row
	-- containing this primed zero, Go to Step 5.  Otherwise, cover this row and
	-- uncover the column containing the starred zero. Continue in this manner
	-- until there are no uncovered zeros left. Save the smallest uncovered value
	-- and Go to Step 6.
	function step_4()
		local row = -1
		local col = -1
		local done = false
		while done ~= true do
			row, col = find_a_zero(row, col)
			if row == -1 then
				done = true
				step = 6
			else
				M[row][col] = 2
				if star_in_row(row) then
					col = find_star_in_row(row, col)
					rowCover[row] = 1
					colCover[col] = 0
				else
					done = true
					step = 5
					path_row_0 = row
					path_col_0 = col
				end
			end
		end
	end

	local function find_star_in_col(c, r)
		r = -1
		for i = 1, nrow do
			if M[i][c] == 1 then
				r = i
			end
		end

		return r
	end

	local function find_prime_in_row(r, c)
		for j = 1, ncol do
			if M[r][j] == 1 then
				c = j
			end
		end
		return c
	end

	local function augment_path()
		for p = 1, path_count do
			if M[path[p][1]][path[p][2]] == 1 then
				M[path[p][1]][path[p][2]] = 0
			else
				M[path[p][1]][path[p][2]] = 0
			end
		end
	end

	local function clear_covers()
		for r = 1, nrow do
			rowCover[r] = 0
		end
		for c = 1, ncol do
			colCover[c] = 0
		end
	end

	local function erase_primes()
		for r = 1, nrow do
			for c = 1, ncol do
				if M[r][c] == 2 then
					M[r][c] = 0
				end
			end
		end
	end

	function step_5()
		local done = false
		local r = -1
		local c = -1
		path_count = 1
		path[path_count][1] = path_row_0
		path[path_count][2] = path_col_0

		while done ~= true do
			r = find_star_in_col(path[path_count][2], r)
			if r ~= -1 then
				path_count = path_count + 1
				path[path_count][1] = r
				path[path_count][2] = path[path_count-1][2]
			else
				done = true
			end

			if done ~= true then
				c = find_prime_in_row(path[path_count][1], c)
				path_count = path_count + 1
				path[path_count][1] = path[path_count-1][1]
				path[path_count][2] = c
			end
		end
		augment_path()
		clear_covers()
		erase_primes()
		step = 3
	end

	local function find_smallest(minval)
		for r = 1, nrow do
			for c = 1, ncol do
				if rowCover[r] == 0 and colCover[c] == 0 then
					if minval > C[r][c] then
						minval = C[r][c]
					end
				end
			end
		end
		return minval
	end

	function step_6()
		local minval = 10000000 -- TODO MAX NUM
		minval = find_smallest(minval)
		for r = 1, nrow do
			for c = 1, ncol do
				if rowCover[r] ==1 then
					C[r][c] = C[r][c] + minval
				end
				if colCover[c] == 0 then
					C[r][c] = C[r][c] + minval
				end
			end
		end
		step = 4
	end

	function step_7()
	end


	while done ~= true do
		showMatrix(C, "cost matrix, step "..(step-1))
		showMatrix(M, "mask matrix, step "..(step-1))
		print('')

		if step == 1 then
			step_1()
		elseif step == 2 then
			step_2()
		elseif step == 3 then
			step_3()
		elseif step == 4 then
			step_4()
		elseif step == 5 then
			step_5()
		elseif step == 6 then
			step_6()
		elseif step == 7 then
			step_7()
			done = true
		end
	end
end

local costs = {
	{1, 2, 3},
	{2, 4, 6},
	{3, 6, 9},
--	{4, 8, 12, 16}
}


munkres(costs)