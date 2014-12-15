-- based on Andrew Lopatin's C++ implementation of "hungarian" algorithm
-- for the assignment problem: http://e-maxx.ru/algo/assignment_hungary

local function lopatin(a)
	local n = #a
	local m = #a[1] -- TODO !! if 0
	local INF = 100000000
	
	local function vec(size, val)
		local v = {}
		for i = 1, size do v[i] = val end
		return v  
	end
	
	local u = vec(n+1,0)
	local v = vec(m+1,0)
	local p = vec(m+1,1)
	local way = vec(m+1,0)
	
	for i = 1, n do
		p[1] = i
		local j0 = 1
		local minv = vec(m+1, INF)
		local used = vec(m+1, false)
		
		repeat
			used[j0] = true
			local i0 = p[j0]
			local delta = INF
			local j1
			for j = 2, m do
				if used[j] ~= true then
					local cur = a[i0][j]-u[i0]-v[j]
					if cur < minv[j] then
						minv[j] = cur
						way[j] = j0
					end
					if minv[j] < delta then
						delta = minv[j]
						j1 = j
					end	
				end
			end
			for j = 1, m do
				if used[j] == true then
					u[p[j]] = u[p[j]] + delta
					v[j] = v[j] - delta 
				else
					minv[j] = minv[j] - delta
				end 
				j0=j1
			end
		until p[j0] == 1
		
		repeat 
			local j1 = way[j0]
			p[j0] = p[j1]
			j0 = j1
		until j0 == 1  
	end
	
	local ans = {}
	for j=2, m do
		ans[p[j]] = j
	end
	return ans
end

local a = {
	{0,  0,  0,  0,  0,  0},
	{0, 15, 16, 17, 18, 19}, 
	{0,  1,  1,  3,  1,  16}, 
	{0,  2,  8,  8,  6,  17},
	{0,  2,  2,  2,  8,  18},
	{0,  4,  6,  7,  8,  19}
}

--local i = 0
--repeat
--	i = i + 1
--	print (i)
--until i == 10

local ans = lopatin(a)
local cost = 0

for row, col in pairs(ans) do
	print("for row "..(row-1).." col is "..(col-1))
	cost = cost + a[row][col]
end
print("total cost = "..cost)
