if not ESX then
	SetTimeout(3000, function() print('[^3WARNING^7] Unable to start NUI Doorlock - ensure you are using ESX Legacy') end)
else
	local Config = Config

	local isCuffed, playerCoords, doorCount = false
	local nearbyDoors, closestDoor = {}, {}

	local round = function(num, decimal)
		local mult = 10^(decimal)
		return math.floor(num * mult + 0.5) / mult
	end

	local SetTextCoords = function(data)
		local minDimension, maxDimension = GetModelDimensions(data.objHash)
		local dimensions = maxDimension - minDimension
		local dx, dy = tonumber(dimensions.x), tonumber(dimensions.y)
		if dy <= -1 or dy >= 1 then dx = dy end
		if data.fixText then
			return GetOffsetFromEntityInWorldCoords(data.object, dx/2, 0, 0)
		else
			return GetOffsetFromEntityInWorldCoords(data.object, -dx/2, 0, 0)
		end
	end

	local UpdateDoors = function(specificDoor)
		playerCoords = GetEntityCoords(ESX.PlayerData.ped)
		for doorID, data in pairs(Config.DoorList) do
			if (not specificDoor or doorID == specificDoor) then
				if data.doors then
					for k,v in pairs(data.doors) do
						if #(playerCoords - v.objCoords) < 30 then Citizen.Wait(1)
							v.object = GetClosestObjectOfType(v.objCoords, 1.0, v.objHash, false, false, false)
							if data.delete then
								SetEntityAsMissionEntity(v.object, 1, 1)
								DeleteObject(v.object)
								v.object = nil
							end
							if v.object then
								v.doorHash = 'l_'..doorID..'_'..k
								if not IsDoorRegisteredWithSystem(v.doorHash) then
									AddDoorToSystem(v.doorHash, v.objHash, v.objCoords, false, false, false)
									nearbyDoors[doorID] = true
									if data.locked then
										DoorSystemSetDoorState(v.doorHash, 4, false, false) DoorSystemSetDoorState(v.doorHash, 1, false, false)
									else
										DoorSystemSetDoorState(v.doorHash, 0, false, false) if data.oldMethod then FreezeEntityPosition(v.object, false) end
									end
								end
							end
						elseif v.object then RemoveDoorFromSystem(v.doorHash) nearbyDoors[doorID] = nil end
					end
				elseif not data.doors then
					if #(playerCoords - data.objCoords) < 30 then Citizen.Wait(2)
						if data.slides then data.object = GetClosestObjectOfType(data.objCoords, 5.0, data.objHash, false, false, false) else
							data.object = GetClosestObjectOfType(data.objCoords, 1.0, data.objHash, false, false, false)
						end
						if data.delete then
							SetEntityAsMissionEntity(data.object, 1, 1)
							DeleteObject(data.object)
							data.object = nil
						end
						if data.object then
							data.doorHash = 'l_'..doorID
							if not IsDoorRegisteredWithSystem(data.doorHash) then
								AddDoorToSystem(data.doorHash, data.objHash, data.objCoords, false, false, false)
								nearbyDoors[doorID] = true
								if data.locked then
									DoorSystemSetDoorState(data.doorHash, 4, false, false) DoorSystemSetDoorState(data.doorHash, 1, false, false)
								else
									DoorSystemSetDoorState(data.doorHash, 0, false, false) if data.oldMethod then FreezeEntityPosition(data.object, false) end
								end
							end
						end
					elseif data.object then RemoveDoorFromSystem(data.doorHash) nearbyDoors[doorID] = false end
				end
				-- set text coords
				if not data.setText and data.doors then
					for k,v in pairs(data.doors) do
						if k == 1 and DoesEntityExist(v.object) then
							data.textCoords = v.objCoords
						elseif k == 2 and DoesEntityExist(v.object) and data.textCoords then
							local textDistance = data.textCoords - v.objCoords
							data.textCoords = (data.textCoords - (textDistance / 2))
							data.setText = true
						end
						if k == 2 and data.textCoords and data.slides then
							if GetEntityHeightAboveGround(v.object) < 1 then
								data.textCoords = vector3(data.textCoords.x, data.textCoords.y, data.textCoords.z+1.2)
							end
						end
					end
				elseif not data.setText and not data.doors and DoesEntityExist(data.object) then
					if data.garage == true then
						data.textCoords = data.objCoords
						data.setText = true
					else
						data.textCoords = SetTextCoords(data)
						data.setText = true
					end
					if data.slides then
						if GetEntityHeightAboveGround(data.object) < 1 then
							data.textCoords = vector3(data.textCoords.x, data.textCoords.y, data.textCoords.z+1.6)
						end
					end
				end
			end
		end
		doorCount = DoorSystemGetSize()
		lastCoords = playerCoords
	end

	local paused, last_x, last_y, lasttext = false
	local Draw3dNUI = function(coords, text)
		local _, x, y = GetScreenCoordFromWorldCoord(coords.x,coords.y,coords.z)
		if x ~= last_x or y ~= last_y or text ~= lasttext then
			isDrawing = true
			SendNUIMessage({type = "display", x = x, y = y, text = text})
			last_x, last_y, lasttext = x, y, text
			Citizen.Wait(0)
		end
	end

	local DoorLoop = function()
		ESX.TriggerServerCallback('nui_doorlock:getDoorList', function(doorList)
			Config.DoorList = doorList
			UpdateDoors()
			while ESX.PlayerLoaded do
				playerCoords = GetEntityCoords(ESX.PlayerData.ped)
				local doorSleep = 1000
				if not closestDoor.id then
					local distance = #(playerCoords - lastCoords)
					if distance > 30 then
						UpdateDoors()
					else
						closestDoor.distance = 30
						for k in pairs(nearbyDoors) do
							local door = Config.DoorList[k]
							if door.setText and door.textCoords then
								distance = #(door.textCoords - playerCoords)
								if distance < closestDoor.distance or 10 then
									if distance < door.maxDistance then
										closestDoor = {distance = distance, id = k, data = door}
										doorSleep = 0
									end
								end
							end
							Citizen.Wait(5)
						end
					end
				end
				if closestDoor.id then
					while true do
						if not paused and IsPauseMenuActive() then SendNUIMessage ({type = "hide"}) paused = true 
						elseif paused then Citizen.Wait(20)
							if not IsPauseMenuActive() then lasttext, paused = '', false end
						else
							playerCoords = GetEntityCoords(ESX.PlayerData.ped)
							closestDoor.distance = #(closestDoor.data.textCoords - playerCoords)
							if closestDoor.distance < closestDoor.data.maxDistance then
								if not closestDoor.data.doors then
									local doorState = DoorSystemGetDoorState(closestDoor.data.doorHash)
									if closestDoor.data.locked and doorState ~= 1 then
										Draw3dNUI(closestDoor.data.textCoords, 'Locking')
									elseif not closestDoor.data.locked then
										if Config.ShowUnlockedText then Draw3dNUI(closestDoor.data.textCoords, 'Unlocked') else if isDrawing then SendNUIMessage ({type = "hide"}) isDrawing = false end end
									else
										Draw3dNUI(closestDoor.data.textCoords, 'Locked')
									end
								else
									local door = {}
									local state = {}
									door[1] = closestDoor.data.doors[1]
									door[2] = closestDoor.data.doors[2]
									state[1] = DoorSystemGetDoorState(door[1].doorHash)
									state[2] = DoorSystemGetDoorState(door[2].doorHash)
									
									if closestDoor.data.locked and (state[1] ~= 1 or state[2] ~= 1) then
										Draw3dNUI(closestDoor.data.textCoords, 'Locking')
									elseif not closestDoor.data.locked then
										if Config.ShowUnlockedText then Draw3dNUI(closestDoor.data.textCoords, 'Unlocked') else if isDrawing then SendNUIMessage ({type = "hide"}) isDrawing = false end end
									else
										Draw3dNUI(closestDoor.data.textCoords, 'Locked')
									end
								end
							else
								if closestDoor.distance > closestDoor.data.maxDistance and isDrawing then
									SendNUIMessage ({type = "hide"}) isDrawing = false
								end
								break
							end
							Citizen.Wait(5)
						end
					end
					closestDoor = {}
					doorSleep = 5
				end
				Citizen.Wait(doorSleep)
			end
		end)
	end

	local PlaySound = function(door, src)
		local origin
		if src and src ~= ESX.PlayerData.ped then src = NetworkGetEntityFromNetworkId(src) end
		if not src then origin = door.textCoords elseif src == ESX.PlayerData.ped then origin = playerCoords else origin = NetworkGetPlayerCoords(src) end
		local distance = #(playerCoords - origin)
		if distance < 10 then
			if not door.audioLock then
				if door.audioRemote then
					door.audioLock = {['file'] = 'button-remote.ogg', ['volume'] = 0.08}
					door.audioUnlock = {['file'] = 'button-remote.ogg', ['volume'] = 0.08}
				else
					door.audioLock = {['file'] = 'door-bolt-4.ogg', ['volume'] = 0.1}
					door.audioUnlock = {['file'] = 'door-bolt-4.ogg', ['volume'] = 0.1}
				end
			end
			local sfx_level = GetProfileSetting(300)
			if door.locked then SendNUIMessage ({type = 'audio', audio = door.audioLock, distance = distance, sfx = sfx_level})
			else SendNUIMessage ({type = 'audio', audio = door.audioUnlock, distance = distance, sfx = sfx_level}) end
		end
	end

	RegisterNetEvent('nui_doorlock:setState')
	AddEventHandler('nui_doorlock:setState', function(sid, doorID, locked, src)
		local serverid = GetPlayerServerId(PlayerId())
		if sid == serverid then dooranim() end
		if Config.DoorList[doorID] then
			Config.DoorList[doorID].locked = locked
			UpdateDoors(doorID)
			while true do
				Citizen.Wait(5)
				if Config.DoorList[doorID].doors then
					for k, v in pairs(Config.DoorList[doorID].doors) do
						if not IsDoorRegisteredWithSystem(v.doorHash) then return end -- If door is not registered end the loop
						v.currentHeading = GetEntityHeading(v.object)
						v.doorState = DoorSystemGetDoorState(v.doorHash)
						if Config.DoorList[doorID].slides then
							if Config.DoorList[doorID].locked then
								DoorSystemSetDoorState(v.doorHash, 1, false, false) -- Set to locked
								DoorSystemSetAutomaticDistance(v.doorHash, 0.0, false, false)
								if k == 2 then PlaySound(Config.DoorList[doorID], src) return end -- End the loop
							else
								DoorSystemSetDoorState(v.doorHash, 0, false, false) -- Set to unlocked
								DoorSystemSetAutomaticDistance(v.doorHash, 30.0, false, false)
								if k == 2 then PlaySound(Config.DoorList[doorID], src) return end -- End the loop
							end
						elseif Config.DoorList[doorID].locked and (v.doorState == 4) then
							if Config.DoorList[doorID].oldMethod then FreezeEntityPosition(v.object, true) end
							DoorSystemSetDoorState(v.doorHash, 1, false, false) -- Set to locked
							if Config.DoorList[doorID].doors[1].doorState == Config.DoorList[doorID].doors[2].doorState then PlaySound(Config.DoorList[doorID], src) return end -- End the loop
						elseif not Config.DoorList[doorID].locked then
							if Config.DoorList[doorID].oldMethod then FreezeEntityPosition(v.object, false) end
							DoorSystemSetDoorState(v.doorHash, 0, false, false) -- Set to unlocked
							if Config.DoorList[doorID].doors[1].doorState == Config.DoorList[doorID].doors[2].doorState then PlaySound(Config.DoorList[doorID], src) return end -- End the loop
						else
							if round(v.currentHeading, 0) == round(v.objHeading, 0) then
								DoorSystemSetDoorState(v.doorHash, 4, false, false) -- Force to close
							end
						end
					end
				else
					if not IsDoorRegisteredWithSystem(Config.DoorList[doorID].doorHash) then return end -- If door is not registered end the loop
					Config.DoorList[doorID].currentHeading = GetEntityHeading(Config.DoorList[doorID].object)
					Config.DoorList[doorID].doorState = DoorSystemGetDoorState(Config.DoorList[doorID].doorHash)
					if Config.DoorList[doorID].slides then
						if Config.DoorList[doorID].locked then
							DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 1, false, false) -- Set to locked
							DoorSystemSetAutomaticDistance(Config.DoorList[doorID].doorHash, 0.0, false, false)
							PlaySound(Config.DoorList[doorID], src)
							return -- End the loop
						else
							DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 0, false, false) -- Set to unlocked
							DoorSystemSetAutomaticDistance(Config.DoorList[doorID].doorHash, 30.0, false, false)
							PlaySound(Config.DoorList[doorID], src)
							return -- End the loop
						end
					elseif Config.DoorList[doorID].locked and (Config.DoorList[doorID].doorState == 4) then
						if Config.DoorList[doorID].oldMethod then FreezeEntityPosition(Config.DoorList[doorID].object, true) end
						DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 1, false, false) -- Set to locked
						PlaySound(Config.DoorList[doorID], src)
						return -- End the loop
					elseif not Config.DoorList[doorID].locked then
						if Config.DoorList[doorID].oldMethod then FreezeEntityPosition(Config.DoorList[doorID].object, false) end
						DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 0, false, false) -- Set to unlocked
						PlaySound(Config.DoorList[doorID], src)
						return -- End the loop
					else
						if round(Config.DoorList [doorID].currentHeading, 0) == round(Config.DoorList[doorID].objHeading, 0) then
							DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 4, false, false) -- Force to close
						end
					end
				end
			end
		end
	end)

	function loadAnimDict(dict)
		while (not HasAnimDictLoaded(dict)) do
			RequestAnimDict(dict)
			Citizen.Wait(5)
		end
	end

	function dooranim()
		Citizen.CreateThread(function()
			loadAnimDict("anim@heists@keycard@") 
			TaskPlayAnim(ESX.PlayerData.ped, "anim@heists@keycard@", "exit", 8.0, 1.0, -1, 16, 0, 0, 0, 0)
			Citizen.Wait(550)
			ClearPedTasks(ESX.PlayerData.ped)
		end)
	end

	function debug(doorID, data)
		if GetDistanceBetweenCoords(playerCoords, data.textCoords) < 3 then
			for k,v in pairs(data) do
				print(  ('%s = %s'):format(k, v) )
			end
			if data.doors then
				for k, v in pairs(data.doors) do
					print('\nCurrent Heading '..k..': '..GetEntityHeading(v.object))
					print('Current Coords '..k..': '..GetEntityCoords(v.object))
				end
			else
				print('\nCurrent Heading: '..GetEntityHeading(data.object))
				print('Current Coords: '..GetEntityCoords(data.object))
			end
		end
	end

	RegisterNetEvent('esx_policejob:handcuff')
	AddEventHandler('esx_policejob:handcuff', function()
		isCuffed = not isCuffed
	end)

	RegisterNetEvent('esx_policejob:unrestrain')
	AddEventHandler('esx_policejob:unrestrain', function()
		isCuffed = false
	end)

	RegisterCommand('doorlock', function()
		if closestDoor.id and not ESX.PlayerData.dead and not isCuffed then
			local veh = GetVehiclePedIsIn(ESX.PlayerData.ped)
			if veh then
				Citizen.CreateThread(function()
					local counter = 0
					local siren = IsVehicleSirenOn(veh)
					repeat
						DisableControlAction(0, 86, true)
						SetHornEnabled(veh, false)
						if not siren then SetVehicleSiren(veh, false) end
						counter = counter + 1
						Citizen.Wait(0)
					until (counter == 100)
					SetHornEnabled(veh, true)
				end)
			end
			local locked = not closestDoor.data.locked
			if closestDoor.data.audioRemote then src = NetworkGetNetworkIdFromEntity(ESX.PlayerData.ped) else src = nil end
			TriggerServerEvent('nui_doorlock:updateState', closestDoor.id, locked, src) -- Broadcast new state of the door to everyone
		end
	end)
	TriggerEvent("chat:removeSuggestion", "/doorlock")
	RegisterKeyMapping('doorlock', '[Doorlock] Interact with doorlock~', 'keyboard', 'e')


	--[[RegisterNetEvent('nui_doorlock:lockpick') -- Set up your own lockpick event here
	AddEventHandler('nui_doorlock:lockpick', function(data)
		local locked = not closestDoor.data.locked
		TriggerServerEvent('nui_doorlock:updateState', closestDoor.id, locked, nil, true) -- Broadcast new state of the door to everyone
	end)]]

	function closeNUI()
		SetNuiFocus(false, false)
		SendNUIMessage({type = "newDoorSetup", enable = false})
		receivedDoorData = nil
	end

	RegisterNUICallback('newDoor', function(data, cb)
		receivedDoorData = true
		arg = data
		closeNUI()
	end)

	RegisterNUICallback('close', function(data, cb)
		closeNUI()
	end)

	RegisterCommand('-nui', function(playerId, args, rawCommand)
		closeNUI()
	end, false)

	local Raycast = function()
		local offset = GetOffsetFromEntityInWorldCoords(GetCurrentPedWeaponEntityIndex(ESX.PlayerData.ped), 0, 0, -0.01)
		local direction = GetGameplayCamRot()
		direction = vector2(direction.x * math.pi / 180.0, direction.z * math.pi / 180.0)
		local num = math.abs(math.cos(direction.x))
		direction = vector3((-math.sin(direction.y) * num), (math.cos(direction.y) * num), math.sin(direction.x))
		local destination = vector3(offset.x + direction.x * 30, offset.y + direction.y * 30, offset.z + direction.z * 30)
		local rayHandle, result, hit, endCoords, surfaceNormal, entityHit = StartShapeTestLosProbe(offset, destination, -1, ESX.PlayerData.ped, 0)
		repeat
			result, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
			Citizen.Wait(0)
		until result ~= 1
		if GetEntityType(entityHit) == 3 then return hit, entityHit else return false end
	end

	RegisterNetEvent('nui_doorlock:newDoorSetup')
	AddEventHandler('nui_doorlock:newDoorSetup', function(args)
		if not args[1] then
			receivedDoorData = false
			SetNuiFocus(true, true)
			SendNUIMessage({type = "newDoorSetup", enable = true})
			while receivedDoorData == false do Citizen.Wait(5) DisableAllControlActions(0) end
		end
		--if not args[1] then print('/newdoor [doortype] [locked] [jobs]\nDoortypes: door, sliding, garage, double, doublesliding\nLocked: true or false\nJobs: Up to four can be added with the command') return end
		if arg then doorType = arg.doortype else doorType = args[1] end
		if arg then doorLocked = arg.doorlocked else doorLocked = not not args[1] end
		local validTypes = {['door']=true, ['sliding']=true, ['garage']=true, ['double']=true, ['doublesliding']=true}
		if not validTypes[doorType] then print(doorType.. ' is not a valid doortype') return end
		if arg and arg.item == '' and arg.job1 == '' then print('You must enter either a job or item for lock authorisation') return end
		if args[7] then print('You can only set four authorised jobs - if you want more, add them to the config later') return end
		if doorType == 'door' or doorType == 'sliding' or doorType == 'garage' then
			local entity, coords, heading, model = nil, nil, nil, nil
			local result = false
			print('Aim at your desired door and press left mouse button')
			while true do
				if IsPlayerFreeAiming(PlayerId()) then
					local result, object = Raycast()
					if result and object ~= entity then
						SetEntityDrawOutline(entity, false)
						SetEntityDrawOutline(object, true)
						entity = object
						coords = GetEntityCoords(entity)
						model = GetEntityModel(entity)
						heading = GetEntityHeading(entity)
					end
				else Citizen.Wait(0) end
				if result then DrawInfos("Coordinates: " .. coords .. "\nHeading: " .. heading .. "\nHash: " .. model)
			else DrawInfos("Aim at your desired door and shoot") end
				if entity and IsControlPressed(0, 24) then break end
			end
			SetEntityDrawOutline(entity, false)
			if not model or model == 0 then print('Did not receive a model hash\nIf the door is transparent, make sure you aim at the frame') return end
			local result, door = DoorSystemFindExistingDoor(coords.x, coords.y, coords.z, model)
			if result then return print('This door is already registered') end
			local jobs = {}
			if args[3] then
				jobs[1] = args[3]
				jobs[2] = args[4]
				jobs[3] = args[5]
				jobs[4] = args[6]
			else
				if arg.job1 ~= '' then jobs[1] = arg.job1 end
				if arg.job2 ~= '' then jobs[2] = arg.job2 end
				if arg.job3 ~= '' then jobs[3] = arg.job3 end
				if arg.job4 ~= '' then jobs[4] = arg.job4 end
				if arg.item ~= '' then item = arg.item end
			end
			local maxDistance, slides, garage = 2.0, false, false
			if doorType == 'sliding' then slides = true
			elseif doorType == 'garage' then maxDistance, slides, garage = 6.0, true, true end
			if slides then maxDistance = 6.0 end
			local doorHash = 'l_'..#Config.DoorList + 1
			AddDoorToSystem(doorHash, model, coords, false, false, false)
			DoorSystemSetDoorState(doorHash, 4, false, false)
			coords = GetEntityCoords(entity)
			heading = GetEntityHeading(entity)
			RemoveDoorFromSystem(doorHash)
			if arg then doorname = arg.doorname end
			TriggerServerEvent('nui_doorlock:newDoorCreate', arg.configname, model, heading, coords, jobs, item, doorLocked, maxDistance, slides, garage, false, doorname)
			print('Successfully sent door data to the server')
		elseif doorType == 'double' or doorType == 'doublesliding' then
			local entity, coords, heading, model = {}, {}, {}, {}
			local result = false
			print('Aim at each desired door and press left mouse button')
			for i=1, 2 do
				while true do
					if IsPlayerFreeAiming(PlayerId()) then
						local result, object = Raycast()
						if result and object ~= entity[i] then
							SetEntityDrawOutline(entity[i], false)
							SetEntityDrawOutline(object, true)
							entity[i] = object
							coords[i] = GetEntityCoords(object)
							model[i] = GetEntityModel(object)
							heading[i] = GetEntityHeading(object)
						end
					else Citizen.Wait(0) end
					if result then DrawInfos("Coordinates: " .. coords[i] .. "\nHeading: " .. heading[i] .. "\nHash: " .. model[i])
				else DrawInfos("Aim at your desired door and shoot") end
					if entity[i] and IsControlPressed(0, 24) then break end
				end
				Citizen.Wait(200)
			end
			SetEntityDrawOutline(entity[1], false)
			SetEntityDrawOutline(entity[2], false)
			if not model[1] or model[1] == 0 or not model[2] or model[2] == 0 then print('Did not receive a model hash\nIf the door is transparent, make sure you aim at the frame') return end
			if entity[1] == entity[2] then print('Can not add double door if entities are the same') return end
			for i=1, 2 do
				local result, door = DoorSystemFindExistingDoor(coords[i].x, coords[i].y, coords[i].z, model[i])
				if result then return print('This door is already registered') end
			end
			local jobs = {}
			if args[3] then
				jobs[1] = args[3]
				jobs[2] = args[4]
				jobs[3] = args[5]
				jobs[4] = args[6]
			else
				if arg.job1 ~= '' then jobs[1] = arg.job1 end
				if arg.job2 ~= '' then jobs[2] = arg.job2 end
				if arg.job3 ~= '' then jobs[3] = arg.job3 end
				if arg.job4 ~= '' then jobs[4] = arg.job4 end
				if arg.item ~= '' then item = arg.item end
			end
			local maxDistance, slides, garage = 2.5, false, false
			if doorType == 'sliding' or doorType == 'doublesliding' then slides = true end
			if slides then maxDistance = 6.0 end

			local doors = #Config.DoorList + 1
			local doorHash = {}
			doorHash[1] = 'l_'..doors..'_'..'1'
			doorHash[2] = 'l_'..doors..'_'..'2'
			for i=1, #doorHash do
				AddDoorToSystem(doorHash[i], model[i], coords[i], false, false, false)
				DoorSystemSetDoorState(doorHash[i], 4, false, false)
				coords[i] = GetEntityCoords(entity[i])
				heading[i] = GetEntityHeading(entity[i])
				RemoveDoorFromSystem(doorHash[i])
			end
			if arg then doorname = arg.doorname end
			TriggerServerEvent('nui_doorlock:newDoorCreate', arg.configname, model, heading, coords, jobs, item, doorLocked, maxDistance, slides, garage, true, doorname)
			print('Successfully sent door data to the server')
			arg = nil
		end
	end)

	function DrawInfos(text)
		SetTextColour(255, 255, 255, 255)   -- Color
		SetTextFont(4)					  -- Font
		SetTextScale(0.4, 0.4)			  -- Scale
		SetTextWrap(0.0, 1.0)			   -- Wrap the text
		SetTextCentre(false)				-- Align to center(?)
		SetTextDropshadow(0, 0, 0, 0, 255)  -- Shadow. Distance, R, G, B, Alpha.
		SetTextEdge(50, 0, 0, 0, 255)	   -- Edge. Width, R, G, B, Alpha.
		SetTextOutline()					-- Necessary to give it an outline.
		SetTextEntry("STRING")
		AddTextComponentString(text)
		DrawText(0.015, 0.71)			   -- Position
	end

	RegisterNetEvent('nui_doorlock:newDoorAdded')
	AddEventHandler('nui_doorlock:newDoorAdded', function(newDoor, doorID, locked)
		Config.DoorList[doorID] = newDoor
		UpdateDoors()
		TriggerEvent('nui_doorlock:setState', GetPlayerServerId(PlayerId()), doorID, locked)
	end)

	RegisterNetEvent('esx:playerLoaded')
	AddEventHandler('esx:playerLoaded', function(playerData)
		ESX.PlayerLoaded = true
		ESX.PlayerData = playerData
		Citizen.CreateThread(DoorLoop)
	end)

	RegisterNetEvent('esx:onPlayerLogout')
	AddEventHandler('esx:onPlayerLogout', function(playerData)
		ESX.PlayerLoaded = false
		ESX.PlayerData = {}
	end)

	if ESX.PlayerLoaded then Citizen.CreateThread(DoorLoop) end
end
