if not ESX then
	SetTimeout(3000, function() print('[^3WARNING^7] Unable to start NUI Doorlock - ensure you are using ESX Legacy') end)
else
	RegisterServerEvent('nui_doorlock:updateState')
	AddEventHandler('nui_doorlock:updateState', function(doorID, locked, src, usedLockpick)
		local playerId = source
		local xPlayer = ESX.GetPlayerFromId(playerId)

		if type(doorID) ~= 'number' then
			print(('nui_doorlock: %s (%s) didn\'t send a number! (Sent %s)'):format(xPlayer.name, xPlayer.identifier, doorID))
			return
		end

		if type(locked) ~= 'boolean' then
			print(('nui_doorlock: %s (%s) attempted to update invalid state! (Sent %s)'):format(xPlayer.name, xPlayer.identifier, locked))
			return
		end

		if not Config.DoorList[doorID] then
			print(('nui_doorlock: %s (%s) attempted to update invalid door! (Sent %s)'):format(xPlayer.name, xPlayer.identifier, doorID))
			return
		end
		
		if not IsAuthorized(xPlayer, Config.DoorList[doorID], usedLockpick) then
			return
		end

		Config.DoorList[doorID].locked = locked
		if not src then TriggerClientEvent('nui_doorlock:setState', -1, playerId, doorID, locked)
		else TriggerClientEvent('nui_doorlock:setState', -1, playerId, doorID, locked, src) end

		if Config.DoorList[doorID].autoLock then
			SetTimeout(Config.DoorList[doorID].autoLock, function()
				if Config.DoorList[doorID].locked == true then return end
				Config.DoorList[doorID].locked = true
				TriggerClientEvent('nui_doorlock:setState', -1, -1, doorID, true)
			end)
		end
	end)

	ESX.RegisterServerCallback('nui_doorlock:getDoorList', function(source, cb)
		cb(Config.DoorList)
	end)

	function IsAuthorized(xPlayer, doorID, usedLockpick)
		local jobName, grade = {}, {}
		jobName[1] = xPlayer.job.name
		grade[1] = xPlayer.job.grade
		if xPlayer.job2 then
			jobName[2] = xPlayer.job2.name
			grade[2] = xPlayer.job2.grade
		end
		
		if doorID.lockpick and usedLockpick then
			local count = xPlayer.getInventoryItem('lockpick').count
			if count and count >= 1 then return true end
		end

		if doorID.authorizedJobs then
			for job,rank in pairs(doorID.authorizedJobs) do
				if (job == jobName[1] and rank <= grade[1]) or (jobName[2] and job == jobName[2] and rank <= grade[2]) then
					return true
				end
			end
		end

		if doorID.items then
			for k, v in pairs(doorID.items) do
				local item = xPlayer.getInventoryItem(v)
				if item and item.count > 0 then
					local consumables = {'ticket'} -- Add items you would like to be removed after use to this table
					if locked and consumables[v] then
						xPlayer.removeInventoryItem(v, 1)
					end
					return true
				end
			end
		end

		if Config.AdminAccess and IsPlayerAceAllowed(xPlayer.source, 'command.newdoor') then
			print(xPlayer.group..' '..xPlayer.name..' opened a door using admin privileges')
			return true
		end
		return false
	end

	RegisterCommand('newdoor', function(playerId, args, rawCommand)
		TriggerClientEvent('nui_doorlock:newDoorSetup', playerId, args)
	end, true)

	RegisterServerEvent('nui_doorlock:newDoorCreate')
	AddEventHandler('nui_doorlock:newDoorCreate', function(config, model, heading, coords, jobs, item, doorLocked, maxDistance, slides, garage, doubleDoor, doorname)
		xPlayer = ESX.GetPlayerFromId(source)
		if not IsPlayerAceAllowed(source, 'command.newdoor') then print(xPlayer.name.. 'attempted to create a new door but does not have permission') return end
		doorLocked = tostring(doorLocked)
		slides = tostring(slides)
		garage = tostring(garage)
		local newDoor = {}
		if jobs[1] then auth = tostring("['"..jobs[1].."']=0") end
		if jobs[2] then auth = auth..', '..tostring("['"..jobs[2].."']=0") end
		if jobs[3] then auth = auth..', '..tostring("['"..jobs[3].."']=0") end
		if jobs[4] then auth = auth..', '..tostring("['"..jobs[4].."']=0") end

		if auth then newDoor.authorizedJobs = { auth } end
		if item then newDoor.items = { item } end
		newDoor.locked = doorLocked
		newDoor.maxDistance = maxDistance
		newDoor.slides = slides
		if not doubleDoor then
			newDoor.garage = garage
			newDoor.objHash = model
			newDoor.objHeading = heading
			newDoor.objCoords = coords
			newDoor.fixText = false
		else
			newDoor.doors = {
				{objHash = model[1], objHeading = heading[1], objCoords = coords[1]},
				{objHash = model[2], objHeading = heading[2], objCoords = coords[2]}
			}
		end
			newDoor.audioRemote = false
			newDoor.lockpick = false
		local path = GetResourcePath(GetCurrentResourceName())
		
		if config ~= '' then
			path = path:gsub('//', '/')..'/configs/'..string.gsub(config, ".lua", "")..'.lua'
		else
			path = path:gsub('//', '/')..'/config.lua'
		end


		file = io.open(path, 'a+')
		if not doorname then label = '\n\n-- UNNAMED DOOR CREATED BY '..xPlayer.name..'\ntable.insert(Config.DoorList, {'
		else
			label = '\n\n-- '..doorname.. '\ntable.insert(Config.DoorList, {'
		end
		file:write(label)
		for k,v in pairs(newDoor) do
			if k == 'authorizedJobs' then
				local str =  ('\n	%s = { %s },'):format(k, auth)
				file:write(str)
			elseif k == 'doors' then
				local doorStr = {}
				for i=1, 2 do
					table.insert(doorStr, ('	{objHash = %s, objHeading = %s, objCoords = %s}'):format(model[i], heading[i], coords[i]))
				end
				local str = ('\n	%s = {\n	%s,\n	%s\n },'):format(k, doorStr[1], doorStr[2])
				file:write(str)
			elseif k == 'items' then
				local str = ('\n	%s = { \'%s\' },'):format(k, item)
				file:write(str)
			else
				local str = ('\n	%s = %s,'):format(k, v)
				file:write(str)
			end
		end
		file:write([[
			
		-- oldMethod = true,
		-- audioLock = {['file'] = 'metal-locker.ogg', ['volume'] = 0.6},
		-- audioUnlock = {['file'] = 'metallic-creak.ogg', ['volume'] = 0.7},
		-- autoLock = 1000]])
		file:write('\n})')
		file:close()
		local doorID = #Config.DoorList + 1
		
		if jobs[4] then newDoor.authorizedJobs = { [jobs[1]] = 0, [jobs[2]] = 0, [jobs[3]] = 0, [jobs[4]] = 0 }
		elseif jobs[3] then newDoor.authorizedJobs = { [jobs[1]] = 0, [jobs[2]] = 0, [jobs[3]] = 0 }
		elseif jobs[2] then newDoor.authorizedJobs = { [jobs[1]] = 0, [jobs[2]] = 0 }
		elseif jobs[1] then newDoor.authorizedJobs = { [jobs[1]] = 0 } end
		if item then newDoor.Items = { item } end

		Config.DoorList[doorID] = newDoor
		Config.DoorList[doorID].locked = doorLocked 
		TriggerClientEvent('nui_doorlock:newDoorAdded', -1, newDoor, doorID, doorLocked)
	end)



	-- Test command that causes all doors to change state
	--[[RegisterCommand('testdoors', function(playerId, args, rawCommand)
		for k, v in pairs(doorStates) do
			if v == true then lock = false else lock = true end
			Config.DoorList[k] = lock
			TriggerClientEvent('nui_doorlock:setState', -1, k, lock)
		end
	end, true)
	--]]


	if Config.CheckVersion then
		Citizen.CreateThread(function()
			local resource = GetCurrentResourceName()
			local version, latest = GetResourceMetadata(resource, 'version')
			local outdated = '^3[version]^7 You can upgrade to ^2v%s^7 (currently using ^1v%s^7 - refresh after updating)'
			Citizen.Wait(2000)

			PerformHttpRequest(GetResourceMetadata(resource, 'versioncheck'), function (errorCode, resultData, resultHeaders)
				if errorCode ~= 200 then print("Returned error code:" .. tostring(errorCode)) else
					local data, version = tostring(resultData)
					for line in data:gmatch("([^\n]*)\n?") do
						if line:find('^version ') then version = line:sub(10, (line:len(line) - 2)) break end
					end		 
					latest = version
				end
			end)
			if latest then 
				if version ~= latest then
					print(outdated:format(latest, version))
				end
			end
		end)
	end
end
