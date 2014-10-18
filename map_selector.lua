local	NUMBERBLOCKED = 20
local	KEYWORDS = {"small", "medium", "big"}
local	PLAYERLIMIT = {12, 20}		--[[
										[0-12] Small	First keyword
										[13-20] Medium	Second keyword
										[20-inf] Big	Third keyword
									--]]

local	oldTime = -1
									
function	getElapsedTime(time1, time2)
	return math.abs(time1 - time2)
end

function	getVar(varName)
	local	value = et.trap_Cvar_Get(varName)
	
	if (varName == "nextmap" and value ~= nil) then
		value = string.sub(value, 5)
	end
	return value
end

function	setVar(varName, value)
	if (varName == "nextmap") then
		value = "map " .. value
	end
	et.trap_Cvar_Set(varName, value)
end

function	xwrite(toWho, sentence)
	et.trap_SendServerCommand(toWho, sentence)
end

function	getFileContent(filename)
	local	file = io.open(filename, "r")
	local	content

	if (file == nil) then
		return nil
	end
	content = file:read("*all")
	file:close();
	return content
end

function	skip_carac(str, spe, i)
	while (string.sub(str, i, i) == sep) do
		i = i + 1
	end
	return 	i
end

function	explode(str, sep)
	local	tab = {}
	local	len = string.len(str)
	local	wend = 1
	local	y = 1
	
	wend = skip_carac(str, sep, wend)
	wstart = wend
	while (wend <= len) do
		local carac = string.sub(str, wend, wend)
		
		if (wend == len and carac ~= sep) then
			tab[y] = string.sub(str, wstart, wend)
		elseif (carac == sep or wend == len) then
			tab[y] = string.sub(str, wstart, wend - 1)
			y = y + 1
			wend = skip_carac(str, sep, wend)
			wstart = wend + 1
		end
		wend = wend + 1
	end
	return	tab
end

function	findElem(elem, list)
	for idx, value in ipairs(list) do
		if (elem == value) then
			return idx
		end
	end
	return -1
end

function	writeList(list, filename)
	local	file = io.open(filename, "w")

	if (file == nil) then
		xwrite(-1, "cpm \"^3Warning Failed to open file: "..filename.."\"")
		return false
	end
	for _, line in ipairs(list) do
		file:write(line.."\n")
	end
	file:close()
	return true
end

function	countInGamePlayers()
	local	num_player = 0
	local	maxclients = tonumber(getVar("sv_maxClients")) - 1
	
	for i = 0, maxclients do
		local clientteam = tonumber(et.gentity_get(i, "sess.sessionTeam"))

		if (clientteam == 1 or clientteam == 2) then -- Axis or Allied
			num_player = num_player + 1
		end
	end
	return num_player
end

function	countPlayers()
	local	num_player = 0
	local	maxclients = tonumber(getVar("sv_maxClients")) - 1
	
	for i = 0, maxclients do
		local clientteam = tonumber(et.gentity_get(i, "sess.sessionTeam"))

		if (clientteam == 1 or clientteam == 2 or clientteam == 3) then -- Axis or Allied
			num_player = num_player + 1
		end
	end
	return num_player
end

function	parseContent(content)
	local	tab = explode(content, "\n")
	local	matrice = {}
	local	idx = -1
	local	isSep = false

	for init = 1, 3 do matrice[init] = {} end
	for i, name in ipairs(tab) do
		name = tostring(name)
		name = string.sub(name, 1, -2)
		if (name ~= nil and name ~= "") then
			for j, key in ipairs(KEYWORDS) do
				if (string.lower(name) == string.lower(key)) then
					idx = j
					isSep = true
					break
				end
			end
			if (isSep == false) then
				if (idx == -1) then
					xwrite(-1, "cpm \"maplist.txt: Bad file format\"")
					return nil
				end
				table.insert(matrice[idx], name)
			end
			isSep = false
		end
	end
	return matrice
end

function	getListIdx()
	local	totalPlayers = countPlayers()
	local	inGamePlayers = countInGamePlayers()
	
	totalPlayers = inGamePlayers + (totalPlayers - inGamePlayers) / 2
	for idx = 1, table.getn(PLAYERLIMIT) do
		if (totalPlayers <= PLAYERLIMIT[idx]) then
			return idx
		end
	end
	return -1
end

function	saveCurrentMap(map, blockedList)
	local	idx

	if (table.getn(blockedList) + 1 >= NUMBERBLOCKED) then
		table.remove(blockedList, 1)
	end
	idx = findElem(map, blockedList)
	if (idx ~= -1) then
		table.remove(blockedList, idx)
	end
	table.insert(blockedList, map)
	writeList(blockedList, "blockedmap.txt") 
end

function	findLastBlocked(mapList, blockedList)
	for i = 1, table.getn(blockedList) do
		if (findElem(blockedList[i], mapList) ~= -1) then
			return blockedList[i]
		end
	end
	xwrite(-1, "cpm \"Couldn't find any map to load, error will occur\"")
	return nil
end

function	buildMapList(mapList, blockedList)
	local	list = {}

	for _, map in ipairs(mapList) do
		if (findElem(map, blockedList) == -1) then
			table.insert(list, map)
		end
	end
	if (table.getn(list) == 0) then
		xwrite(-1, "cpm \"^3Warning: ^7All maps were blocked\"")
		list[1] = findLastBlocked(mapList, blockedList)
	end
	return list
end

function	getMapFromList(mapList)
	local	pos = math.random(1, table.getn(mapList))
	
	return mapList[pos]
end

function	chooseNewMap(currentMap)
	local	fileContent = getFileContent("maplist.txt")
	if (fileContent == nil) then return -1 end
	local	blockedList = getFileContent("blockedmap.txt")
	if (blockedList == nil) then blockedList = {} else blockedList = explode(blockedList, "\n") end
	local	filetab = parseContent(fileContent)
	local	listIdx = getListIdx()
	local	mapList
	local	nextMap = nil
	
	if (listIdx == -1) then
		xwrite(-1, "cpm \"Not a list associated to the number of player\"")
		return -1
	end
	saveCurrentMap(currentMap, blockedList)
	mapList = buildMapList(filetab[listIdx], blockedList)
	nextmap = getMapFromList(mapList)
	setVar("nextmap", nextmap)
	return 0
end

function	et_RunFrame(levelTime)
	if (getElapsedTime(oldTime, levelTime) > 1000) then	-- check every second instead of every frame
		local	mapname = getVar("mapname")
		local	nextmap = getVar("nextmap")

		oldTime = levelTime
		if (nextmap == nil or mapname == nextmap or nextmap == "" or string.find(nextmap, "restart") ~= nil) then
			if (chooseNewMap(mapname) == -1) then
				xwrite(-1, "cpm \"Failed to choose a new map\"")
			end
		end
	end
end