--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- file:    localmexes.lua
-- brief:
-- author:  Leonid Krashenko <leonid.krashenko@gmail.com>
--
-- Copyright (C) 2014.
-- Licensed under the terms of the GNU GPL, v2.
--

-- The drawLine function is taken from the Commands FX widget.
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name = "Local Mexes",
		desc = "Watches for the mexes inside the perimeter of the base to be filled with metal extractors",
		author = "jetbird",
		date = "Oct 27, 2014",
		license = "GNU GPL, v2",
		layer = 0,
		enabled = true, --  loaded by default?
		version = "1.2b"
	}
end


local glColor = gl.Color
local glDepthTest = gl.DepthTest
local glBeginEnd = gl.BeginEnd
local glLineWidth = gl.LineWidth
local glShape = gl.Shape
local glDrawGroundCircle = gl.DrawGroundCircle
--local GetUnitDefID = Spring.GetUnitDefID
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitTeam = Spring.GetUnitTeam
local spGetTeamInfo = Spring.GetTeamInfo
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnitMap = Spring.GiveOrderToUnitMap
local spGetGroundInfo = Spring.GetGroundInfo
local spGetGroundHeight = Spring.GetGroundHeight
local spMarkerAddPoint = Spring.MarkerAddPoint
local echo = Spring.Echo

local local_mexes = {} -- array of local mexes
local free_mexes = {} -- {{x1,z1}, {x2,z2} ... {xn,zn}}
local processing_mexes = {} -- {id1, id2, ..., id_n}
local ordered_mexes = {} -- {constructor_id => {x, y}, ...}

local lineWidth = 6

local perimeterDisplayList = 0;
local perimeter = {}
local units = {} -- player's units
local buildings = {} -- player's buildings
local constructors = {} -- {constructor id => true/nil} player's constructors
local metalSpots = {}
local mexDefIDs = {} -- {ud => ud}
local armComUDId = UnitDefNames["armcom"].id
local coreComUDId = UnitDefNames["corcom"].id
local playerAllyTeam = 0

local function print_array(A, title)
	local s = "";
	if title ~= nil then
		s = s .. title .. ": ";
	end;
	s = s .. "[";

	for k, v in pairs(A) do
		s = s .. tonumber(v - 1)
		if (k ~= #A) then
			s = s .. ", ";
		end;
	end;
	s = s .. "]";
	print(s);
	Spring.Echo(s)
end
local function print_matrix(m, title)
	if title ~= nil then echo(title) end
	for j = 1, #m do
		echo (j.."  "..table.concat(m[j], ", "))
	end
	echo('')
end
local function print_freemexes()
	echo("Free mexes: ")
	for i, mexpos in ipairs(free_mexes) do
		echo("mex "..i.." - "..mexpos[1]..", "..mexpos[2])
	end
	echo('')
end
local function print_map(m, title)
	for k, v in pairs(m) do
		echo (title.."["..k.."]".." = "..v)
	end
end

-- return the convex hull for the set of points
-- @param A Array of
local function grahamscan(A)

	function rotate(A, B, C)
		return (B[1] - A[1]) * (C[2] - B[2]) - (B[2] - A[2]) * (C[1] - B[1])
	end

	local n = #A;
	if (n < 3) then
		return {}
	end

	--print(n)
	local P = {};

	--print_array("grahamscan A", A);

	for i = 1, n do P[i] = i end;
	--print_array(P, "P");

	for i = 1, n do
		if A[P[i]][1] < A[P[1]][1] then
			P[i], P[1] = P[1], P[i];
		end;
	end
	-- print_array(P, "First order sort");

	local j = 0;
	for i = 3, n do
		j = i - 1;
		while j >= 0 and (rotate(A[P[1]], A[P[j]], A[P[j + 1]]) < 0) do
			P[j], P[j + 1] = P[j + 1], P[j];
			j = j - 1;
		end;
	end;
	-- print_array(P, "iSorted P");

	local S = { P[1], P[2] };
	--print_array(S, "Stack");
	for i = 3, n do
		while rotate(A[S[#S - 1]], A[S[#S]], A[P[i]]) < 0 do
			table.remove(S, #S);
		end;
		table.insert(S, P[i]);
	end;

	return S;
end

-- check if the given point {x,z} is located inside the convex hull ({x1,z1}, {x2,z2}, ..., {xn,zn}}
local function pointInConvexhull(A, CH)

	--   http://dic.academic.ru/dic.nsf/ruwiki/209337#sel=27:1,29:14
	--   http://acmp.ru/article.asp?id_text=170
	function testSegmentIntersection(A, B, C, D)
		local v1, v2, v3, v4

		v1 = (D[1] - C[1]) * (A[2] - C[2]) - (D[2] - C[2]) * (A[1] - C[1])
		v2 = (D[1] - C[1]) * (B[2] - C[2]) - (D[2] - C[2]) * (B[1] - C[1])
		v3 = (B[1] - A[1]) * (C[2] - A[2]) - (B[2] - A[2]) * (C[1] - A[1])
		v4 = (B[1] - A[1]) * (D[2] - A[2]) - (B[2] - A[2]) * (D[1] - A[1])

		return (v1 * v2 < 0) and (v3 * v4 < 0)
	end

	local icount = 0
	local B = { CH[1][1], CH[1][2] };
	B[1] = B[1] - 100

	--print_a(A)
	--print_a(B)

	if (testSegmentIntersection(A, B, CH[table.getn(CH)], CH[1])) then
		icount = icount + 1
	end

	for i = 2, table.getn(CH) do
		if (testSegmentIntersection(A, B, CH[i - 1], CH[i])) then
			icount = icount + 1
		end
	end

	return (icount % 2 ~= 0);
end

local function getLocalMexes(mexes, perimeter)
	local_mexes = {}
	if #perimeter == 0 then
		return local_mexes
	end
	for i, pos in pairs(mexes) do
		if pointInConvexhull({ pos.x, pos.z }, perimeter) then
			table.insert(local_mexes, { pos.x, pos.z })
		end
	end
	return local_mexes
end

local function getExtractors()
	local extractors = {}
	for uid, v in pairs(buildings) do
		local udid = spGetUnitDefID(uid)
		local ud = UnitDefs[udid]
		local x, y, z = Spring.GetUnitPosition(uid)
		if ud.isExtractor then
			table.insert(extractors, { x, z })
		end
	end
	return extractors
end

local function getFreeMexes(localMexes)

	local extractors = getExtractors()

	local closedMexes = {} --
	for i, epos in ipairs(extractors) do
		for j, pos in ipairs(localMexes) do
			local dx = epos[1] - pos[1]
			local dz = epos[2] - pos[2]
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist < 75 then
				closedMexes[j] = true
			end
		end
	end

	local freeMexes = {}

	for i, pos in ipairs(localMexes) do
		local isProcessing = false
		for j, pmpos in ipairs(processing_mexes) do
			if pos[1] == pmpos[1] and pos[2] == pmpos[2] then
				isProcessing = true
				break
			end
		end
		
		if closedMexes[i] == nil and (not isProcessing) then
			table.insert(freeMexes, pos)
		end
	end

	return freeMexes
end

local function calcPerimeter()
	local buildingsCoords = {}
	for uid, v in pairs(buildings) do
		local udid = spGetUnitDefID(uid)
		-- local ud = UnitDefs[udid]
		local x, y, z = Spring.GetUnitPosition(uid)

		table.insert(buildingsCoords, { x, z, y })
	end

	local perimeterVertices = grahamscan(buildingsCoords)
	local coords = {}
	for k, i in ipairs(perimeterVertices) do
		table.insert(coords, buildingsCoords[i])
	end

	return coords
end

local function drawLine(x1,y1,z1, x2,y2,z2, width) -- long thin rectangle
    local theta	= (x1~=x2) and math.atan((z2-z1)/(x2-x1)) or math.pi/2
    local zOffset = math.cos(math.pi-theta) * width / 2
    local xOffset = math.sin(math.pi-theta) * width / 2
    
    gl.Vertex(x1+xOffset, y1, z1+zOffset)
    gl.Vertex(x1-xOffset, y1, z1-zOffset)
    
    gl.Vertex(x2-xOffset, y2, z2-zOffset)
    gl.Vertex(x2+xOffset, y2, z2+zOffset)	
end

local function drawPerimeter()
	if #perimeter < 3 then
		return
	end
	
	local p1 = perimeter[1]
	local p2 = {}
	for i = 2, #perimeter do
		p2 = perimeter[i]
		gl.BeginEnd(GL.QUADS, drawLine, p1[1], p1[3], p1[2], p2[1], p2[3], p2[2], lineWidth) 
		p1 = p2
	end
	p1 = perimeter[1]
	gl.BeginEnd(GL.QUADS, drawLine, p1[1], p1[3], p1[2], p2[1], p2[3], p2[2], lineWidth) 
end

--
function widget:DrawWorldPreUnit()
	
	gl.Color(1, 1, 0.7, 0.3)
	--[[
	glLineWidth(3.0)
	glDepthTest(true)
	glColor(1, 0, 0, .2)
	for i, pos in ipairs(perimeter) do
		glDrawGroundCircle(pos[1], 20, pos[2], 50, 16)
	end

--	glColor(0, 1, 0, .3)
--	for i, pos in ipairs(local_mexes) do
--		glDrawGroundCircle(pos[1], 20, pos[2], 50, 16)
--	end
--
--	glColor(0, 0, 1, .3)
--	for i, pos in ipairs(free_mexes) do
--		glDrawGroundCircle(pos[1], 20, pos[2], 50, 16)
--	end
	
	glColor(0, 0, 1, 0.5)
	for consID, orderedMexPos in pairs(ordered_mexes) do
		glDrawGroundCircle(orderedMexPos[1], orderedMexPos[2], orderedMexPos[3], 50, 16)
	end
	--]]
	glDepthTest(false)

	gl.CallList(perimeterDisplayList)
end
--]]

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

local function createMatrix(nrows, ncols, value)
	local M = {}
	for r = 1, nrows do
		M[r] = {}
		for c = 1, ncols do
			M[r][c] = value
		end
	end
	return M
end

local function getBuildingCosts(builderIds, mexPositions)
	local INF = 10000000
	local n = #builderIds
	local m = #mexPositions
	local matrSize = n+1

	if n < m then
		matrSize = m+1
	end

	local costs = createMatrix(matrSize, matrSize, INF)
	--print_matrix(costs, "Initial costs:")

	for j, consId in ipairs(builderIds) do
		for i, mexPos in ipairs(mexPositions) do
			local x, y, z = Spring.GetUnitPosition(consId)
			local dx = mexPos[1] - x
			local dz = mexPos[2] - z
			local dist = math.sqrt(dx*dx + dz*dz)
			costs[j+1][i+1] = dist
		end
	end

	return costs
end

function filterNotOrdered(free_mexes, ordered_mexes)
	local remove = {}
	for i, fmpos in ipairs(free_mexes) do
		for consID, ompos in pairs(ordered_mexes) do
			if fmpos[1] == ompos[1] and fmpos[2] == ompos[3] then
				remove[i] = true;
			end
		end
	end
	for i = #free_mexes, 1, -1 do
		if remove[i] then
			table.remove(free_mexes, i)
		end
	end
	return free_mexes
end

local function buildMexes()
	local freeBuilders = {}
	for consID, v in pairs(constructors) do
		local ordersQueue = Spring.GetUnitCommands(consID, 1)
		if #ordersQueue == 0 then
			table.insert(freeBuilders, consID)
		end
	end

	if #freeBuilders == 0 then
		return
	end

	--print_array(freeBuilders, "free builders");
	free_mexes = filterNotOrdered(free_mexes, ordered_mexes)

	local buildingCosts = getBuildingCosts(freeBuilders, free_mexes);
	--print_matrix(buildingCosts, "Building costs:");

	-- assign mexes to builders
	local builderMexes = lopatin(buildingCosts)
	--print_map(builderMexes, "builder mexes")

	for j, consID in ipairs(freeBuilders) do

		if (builderMexes[j+1]-1 <= #free_mexes) then
			local mexpos = free_mexes[builderMexes[j+1]-1]

			local consDefID = spGetUnitDefID(consID)
			local consDef = UnitDefs[consDefID]

			for i, option in ipairs(consDef.buildOptions) do

				if mexDefIDs[option] then
					local buildable = Spring.TestBuildOrder(option, mexpos[1], 0, mexpos[2], 1)

					if buildable ~= 0 then
						--echo("------    giving order to unit " .. consID .. "[" .. consDef.name .. "] to build "..UnitDefs[option].name .. " at " .. mexpos[1]..", "..mexpos[2])
						Spring.GiveOrderToUnit(consID, -option, { mexpos[1], 0, mexpos[2] }, { "shift" })
						break;
					end
				end
			end
		--else
			--echo ("builderMexes["..j.."+1]-1 ("..(builderMexes[j+1]-1)..") > "..(#free_mexes))
		end
	end
end

local function validConstructor(uid)
	local udid = spGetUnitDefID(uid)
	local ud = UnitDefs[udid]

	-- exclude commanders
	if ud == nil or udid == armComUDId or udid == coreComUDId then
		return false
	end

	if (ud.isBuilder == true and ud.isBuilding == false) then
		return true;
	end

	return false
end

--[[local function notifyNotAlly(unitID)
	echo ("uid: "..unitID)
	local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
	if not ud.isBuilding then
		return
	end
	local x, y, z = Spring.GetUnitPosition(unitID)
	spMarkerAddPoint(x, y, z, "not ally", true)
end--]]


local function dispatchUnit(unitID)
	if not unitID or unitID == false or unitID == true then 
		return 
	end
	
	local unitTeamID = spGetUnitTeam(unitID)
	_,_,_,_,_,unitAllyTeam = spGetTeamInfo(unitTeamID)
	if (unitAllyTeam ~= playerAllyTeam) then
		return
	end
	
	--echo ("dispatched unit: "..unitID)
	local unitDefID = spGetUnitDefID(unitID)
	local ud = UnitDefs[unitDefID]
	if (ud.isBuilding) -- and (ud.onOffable) and (ud.makesMetal > 0) and (ud.energyUpkeep > 0)
	then
		buildings[unitID] = true
	end
	if validConstructor(unitID) then
		constructors[unitID] = true
	end

	units[unitID] = true
end

local function isAllyTeam(teamID)
	local teamIDs = Spring.GetAllyTeamList()
	for _, allyTeamID in ipairs(teamIDs) do
		if allyTeamID == teamID then
			return true
		end
	end
	return false
end


function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local unitTeamID = spGetUnitTeam(unitID)
	_,_,_,_,_,unitAllyTeam = spGetTeamInfo(unitTeamID)
	if (unitAllyTeam ~= playerAllyTeam) then
		return
	end

	-- if we are building the mex
	if mexDefIDs[unitDefID] then
		local x, y, z = Spring.GetUnitPosition(unitID)
		processing_mexes[unitID] = { x, z }
		ordered_mexes[builderID] = nil
	end
end

function widget:GameFrame(frameNum)
	if (frameNum % 128 ) == 0 and #free_mexes > 0 then
		buildMexes()
	end
end

function updateFreeMexes()
	perimeter = calcPerimeter()
	local_mexes = getLocalMexes(metalSpots, perimeter)
	free_mexes = getFreeMexes(local_mexes)
	
	perimeterDisplayList = gl.CreateList(drawPerimeter);
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	local unitTeamID = spGetUnitTeam(unitID)
	_,_,_,_,_,unitAllyTeam = spGetTeamInfo(unitTeamID)
	if (unitAllyTeam ~= playerAllyTeam) then
		return
	end

	if processing_mexes[unitID] then
		processing_mexes[unitID] = nil
	end
	ordered_mexes[unitID] = nil

	dispatchUnit(unitID)

	local ud = UnitDefs[unitDefID]
	if ud.isBuilding then
		updateFreeMexes()
	end
end

function notifyCommand(cmdID, cmdParams, cmdOptions)
	if mexDefIDs[-cmdID] == -cmdID then
		spMarkerAddPoint(cmdOptions[1], cmdOptions[2], cmdOptions[3], "mex", true)
	end
end

function unitHasMexOrder(unitID)
	local queue = Spring.GetCommandQueue(unitID,20)
	for i, cmd in ipairs(queue) do
		for _, mexCmdID in pairs(mexDefIDs) do
			if cmd.id == -mexCmdID then
				return cmd.params
			end
		end
	end
	return false
end

--[[
function unitBuildsMex(unitID)
	local queue = Spring.GetFullBuildQueue (unitID)
	for _, udefCounts in pairs(queue) do
		for __, mexUdid in pairs(mexDefIDs) do
			--echo ("mexUdid: "..mexUdid);
			if (udefCounts[mexUdid] ~= nil) then
				return true
			end
		end
	end
	return false
end
--]]

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	
	local orderedMexPos = unitHasMexOrder(unitID)
	if orderedMexPos ~= false or mexDefIDs[-cmdID] == -cmdID then
		if mexDefIDs[-cmdID] == -cmdID then
			ordered_mexes[unitID] = cmdOptions -- save ordered mex coords
		else
			ordered_mexes[unitID] = orderedMexPos
		end
	else
		ordered_mexes[unitID] = nil -- unit gets other command (or there was no mex ordered ever)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	local unitTeamID = spGetUnitTeam(unitID)
	local _,_,_,_,_,unitAllyTeam = spGetTeamInfo(unitTeamID)
	if (unitAllyTeam ~= playerAllyTeam) then
		return
	end
	
	processing_mexes[unitID] = nil
	ordered_mexes[unitID] = nil

	units[unitID] = nil
	buildings[unitID] = nil
	constructors[unitID] = nil

	local ud = UnitDefs[unitDefID]
	if ud.isBuilding then
		updateFreeMexes()
	end
end


function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widget:UnitDestroyed(unitID, unitDefID)
end


function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitFinished(unitID, unitDefID, unitTeam)
end


function widget:Initialize()
	if not WG.metalSpots then
		echo("<Local Mexes> This widget requires the 'Metalspot Finder' widget to run.")
		widgetHandler:RemoveWidget(self)
		return
	end
	metalSpots = WG.metalSpots

	local playerID = spGetMyPlayerID()
	
	local _,_,spec,_, allyTeam, _, _, _ = spGetPlayerInfo(playerID)
	playerAllyTeam = allyTeam
	
	if spec == true then
		--
		echo("<Local Mexes> Spectator mode. Widget removed")
		widgetHandler:RemoveWidget(self)
		return
		--]]
	end
	
	mexDefIDs[UnitDefNames['armmex'].id] = UnitDefNames['armmex'].id
	mexDefIDs[UnitDefNames['cormex'].id] = UnitDefNames['cormex'].id
	mexDefIDs[UnitDefNames['armuwmex'].id] = UnitDefNames['armuwmex'].id
	mexDefIDs[UnitDefNames['coruwmex'].id] = UnitDefNames['coruwmex'].id

	units = spGetAllUnits()
	for i=1, #units-1 do
		dispatchUnit(units[i])
	end

	updateFreeMexes()
end

