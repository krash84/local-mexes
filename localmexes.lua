--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    localmexes.lua
--  brief:
--  author:  Leonid Krashenko
--
--  Copyright (C) 2014.
--  Licensed under the terms of the GNU GPL, v3.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Local Mexes",
		desc      = "Watches for the mexes inside the perimeter of the base to be filled with metal extractors",
		author    = "jetbird",
		date      = "Oct 27, 2014",
		license   = "GNU GPL, v3",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end


local glColor = gl.Color
local glDepthTest = gl.DepthTest
local glBeginEnd = gl.BeginEnd
local glLineWidth = gl.LineWidth
local glShape = gl.Shape
local glDrawGroundCircle = gl.DrawGroundCircle
local GetUnitDefID = Spring.GetUnitDefID
local spGetAllUnits = Spring.GetAllUnits
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyPlayerID	= Spring.GetMyPlayerID
local spGetPlayerInfo	= Spring.GetPlayerInfo
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetTeamUnits       = Spring.GetTeamUnits
local spGetUnitDefID       = Spring.GetUnitDefID
local spGiveOrderToUnitMap = Spring.GiveOrderToUnitMap
local spGetGroundInfo   = Spring.GetGroundInfo
local spGetGroundHeight = Spring.GetGroundHeight
local echo			= Spring.Echo

local mexes = {} -- array of mexes {id1:{x1, z1}, id2:{x2, z2}, ... idn:{xn, zn}}
local local_mexes = {} -- array of local mexes
local free_mexes = {}
local perimeter = {}
local units = {} -- player's units
local buildings = {} -- player's buildings
local constructors = {} -- player's constructors
local metalSpots 		= WG.metalSpots

local function print_array(A, title)
  local s = "";
  if title ~= nil then
    s = s .. title .. ": ";
  end;
  s = s .. "[";

  for k, v in pairs(A) do
    s = s..tonumber(v-1)
    if (k ~= #A) then
      s = s..", ";
    end;
  end;
  s = s.."]";
  print(s);
  Spring.Echo(s)
end;

-- return the convex hull for the set of points
-- @param A Array of 
local function grahamscan (A)

  function rotate (A, B, C)
    return (B[1]-A[1])*(C[2]-B[2])-(B[2]-A[2])*(C[1]-B[1])
  end;


  local n = #A;
  --print(n)
  local P = {};

  --print_array("grahamscan A", A);

  for i = 1,n do P[i]=i end;
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
    while j >= 0 and (rotate(A[P[1]], A[P[j]], A[P[j+1]]) < 0) do
      P[j], P[j+1] = P[j+1], P[j];
      j = j - 1;
    end;
  end;
  -- print_array(P, "iSorted P");

  local S = {P[1], P[2]};
  --print_array(S, "Stack");
  for i = 3, n do
    while rotate(A[S[#S-1]],A[S[#S]],A[P[i]])<0 do
      table.remove(S, #S);
    end;
    table.insert(S, P[i]);
  end;

  return S;
end;

local function pointInConvexhull(A, CH)

  --   http://dic.academic.ru/dic.nsf/ruwiki/209337#sel=27:1,29:14
  --   http://acmp.ru/article.asp?id_text=170
  function testSegmentIntersection(A, B, C, D)
    local v1, v2, v3, v4

    v1 = (D[1]-C[1])*(A[2]-C[2])-(D[2]-C[2])*(A[1]-C[1])
    v2 = (D[1]-C[1])*(B[2]-C[2])-(D[2]-C[2])*(B[1]-C[1])
    v3 = (B[1]-A[1])*(C[2]-A[2])-(B[2]-A[2])*(C[1]-A[1])
    v4 = (B[1]-A[1])*(D[2]-A[2])-(B[2]-A[2])*(D[1]-A[1])

    return (v1*v2<0) and (v3*v4<0)
  end

  local icount = 0
  local B = {CH[1][1], CH[1][2]};
  B[1] = B[1]-100

  --print_a(A)
  --print_a(B)

  if (testSegmentIntersection(A, B, CH[table.getn(CH)], CH[1])) then
    icount = icount+1
  end

  for i=2,table.getn(CH) do
    if (testSegmentIntersection(A, B, CH[i-1], CH[i])) then
      icount = icount+1
    end
  end

  return (icount%2 ~= 0);
end

local function getLocalMexes(mexes, perimeter)
  local_mexes = {}
  if #perimeter == 0 then 
    return local_mexes
  end
  for i, pos in pairs(metalSpots) do
    if pointInConvexhull({pos.x, pos.z}, perimeter) then
      table.insert(local_mexes, {pos.x, pos.z})
    end
  end 
  return local_mexes
end

local function getBuilders()
	local builders = {}
	echo ("units num: "..#units)
	for uid, v in pairs(units) do
		--echo ("testing unit uid")
		local udid = spGetUnitDefID(uid)
		local ud = UnitDefs[udid]
		if ud == nil then
			echo ("null Unit Def for unit "..uid) 
			break;
		end
		--local x, y, z = Spring.GetUnitPosition(uid)
		if ud.isBuilder and (ud.name == 'armck' or ud.name == 'corck') then
			builders[uid] = true
			--table.insert(builders, uid)
		end
	end
	return builders
end

local function getFreeBuilder()
	echo ("Looking for the free builder...")
	for uid, v in pairs(constructors) do
		local ordersQueue = Spring.GetUnitCommands(uid)
		echo ("Getting unit commands: "..#ordersQueue)
		if #ordersQueue == 0 then
			return uid
		end
	end
	return nil
end

local function getExtractors()
	local extractors = {}
	for uid, v in pairs(buildings) do
		local udid = spGetUnitDefID(uid)
		local ud = UnitDefs[udid]
		local x, y, z = Spring.GetUnitPosition(uid)
		if ud.isExtractor then
			table.insert(extractors, {x, z})
		end
	end
	return extractors
end

local function getFreeMexes(localMexes)
	local extractors = getExtractors()

	local closedMexes = {} -- 
	for i, epos in ipairs(extractors) do
		for j, pos in ipairs(localMexes) do
			--echo("Pos: " .. pos[1]..','..pos[2])
			--echo("EPos: " .. epos[1]..','..epos[2])
			local dx = epos[1] - pos[1]
			local dz = epos[2] - pos[2]
			local dist = math.sqrt(dx*dx + dz*dz) 
			if dist < 75 then
				closedMexes[j] = true
			end
		end
	end
	
	local freeMexes = {}
	for i, pos in ipairs(localMexes) do
		if closedMexes[i] == nil then
			table.insert(freeMexes, pos) 
		end
	end
	
	return freeMexes
	
end

local function calcPerimeter()
	local tmpcoords = {}
	for uid, v in pairs(buildings) do
		local udid = spGetUnitDefID(uid)
		-- local ud = UnitDefs[udid]
		local x, y, z = Spring.GetUnitPosition(uid)

		table.insert(tmpcoords, {x, z})
	end

	local pnumbers = grahamscan(tmpcoords)
	local coords = {}
	for k, i in ipairs(pnumbers) do
		table.insert(coords, tmpcoords[i])
	end

	return coords
end

function widget:DrawWorldPreUnit()
	glLineWidth(3.0)
	glDepthTest(true)
	glColor(1, 0, 0, .4)
	for i, pos in ipairs(perimeter) do
		glDrawGroundCircle(pos[1], 20, pos[2], 100, 100)
	end

	glColor(0, 1, 0, .4)
	for i, pos in ipairs(local_mexes) do
		glDrawGroundCircle(pos[1], 20, pos[2], 100, 100)
	end
	
	glColor(0, 0, 1, 0.5)
	for i, pos in ipairs(free_mexes) do
		glDrawGroundCircle(pos[1], 20, pos[2], 100, 100)
	end

	glDepthTest(false)
end

function widget:Update(deltaTime)
end

local function buildMexes()
	echo ("Building mexes....");
	if #free_mexes > 0 then 
		local mexpos = free_mexes[1]
		echo ("    mex pos .. "..mexpos[1]..", ".. mexpos[2])
		local buildable = Spring.TestBuildOrder(UnitDefNames['armmex'].id,mexpos[1],0,mexpos[2],1)
		if buildable ~= 0 then
			
			local id = getFreeBuilder()
			if id ~= nil then
			
				local udid = spGetUnitDefID(id)
				local ud = UnitDefs[udid]
			
				echo("    giving order to unit " .. id .. "[" .. ud.name .. "] to build armmex with UD = "..UnitDefNames['armmex'].id) 
				Spring.GiveOrderToUnit(id, -UnitDefNames['armmex'].id, {mexpos[1],0,mexpos[2]}, {"shift"})
			else 
				echo("    no free constructors found!")
			end
		else
			echo ("Mex is not buildable")
		end
	end	
end

local function validConstructor(uid)
	local udid = spGetUnitDefID(uid)
	local ud = UnitDefs[udid]
	
	if ud == nil then
		return false 
	end
	
	if (ud.isBuilder == true and ud.isBuilding == false) then
		return true;
	end
	
	return false
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitTeam ~= spGetMyTeamID()) then
		return
	end
	local ud = UnitDefs[unitDefID]
	if (ud.isBuilding) --and (ud.onOffable) and (ud.makesMetal > 0) and (ud.energyUpkeep > 0)
	then
		echo("Added building: "..unitID)
		buildings[unitID] = true
	end
	
	if validConstructor(unitID) then
		constructors[unitID] = true
	end
	units[unitID] = true
	echo ("Unit finished! .. " .. unitID);

	perimeter = calcPerimeter()
	local_mexes = getLocalMexes(mexes, perimeter)
	free_mexes = getFreeMexes(local_mexes)
	
	if #free_mexes > 0 then 
		buildMexes()
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	units[unitID] = nil
	buildings[unitID] = nil
	constructors[unitID] = nil

	perimeter = calcPerimeter()
	local_mexes = getLocalMexes(mexes, perimeter)
	free_mexes = getFreeMexes(local_mexes)
	
	if #free_mexes > 0 then
		buildMexes()
	end
end


function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widget:UnitDestroyed(unitID, unitDefID)
end


function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitFinished(unitID, unitDefID, unitTeam)
end


function widget:Initialize()

	units = spGetTeamUnits(spGetMyTeamID())
	for _,uid in ipairs(units) do
		local udid = spGetUnitDefID(uid)
		local ud = UnitDefs[udid]
		if (ud.isBuilding) -- and (ud.onOffable) and (ud.makesMetal > 0) and (ud.energyUpkeep > 0)
		then
			buildings[uid] = true
			echo("Added building: "..uid)
		end
		if validConstructor(uid) then
			constructors[uid] = true
			echo("Found constructor: "..uid)
		end
		
		units[uid] = true
	end

	perimeter = calcPerimeter()
	local_mexes = getLocalMexes(mexes, perimeter)
	free_mexes = getFreeMexes(local_mexes)
	
end

