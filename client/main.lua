players = {}
entities = {}
objects = {}
ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

if Config.NotHealthRecharge then
	SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
end

if Config.MuteAmbience then
	StartAudioScene('CHARACTER_CHANGE_IN_SKY_SCENE')
end

SetBlackout(Config.Blackout)

RegisterNetEvent("esx_zombiesystem:playerupdate")
AddEventHandler("esx_zombiesystem:playerupdate", function(mPlayers)
	players = mPlayers
end)

TriggerServerEvent("esx_zombiesystem:RegisterNewZombie")
TriggerServerEvent("esx_zombiesystem:newplayer", PlayerId())

RegisterNetEvent("esx_zombiesystem:ZombieSync")
AddEventHandler("esx_zombiesystem:ZombieSync", function()
	AddRelationshipGroup("zombie")
	SetRelationshipBetweenGroups(0, `zombie`, `PLAYER`)
	SetRelationshipBetweenGroups(2, `PLAYER`, `zombie`)

	while true do
		Citizen.Wait(1)

		if #entities < Config.SpawnZombie then
			x, y, z = table.unpack(GetEntityCoords(PlayerPedId(), true))
			entityModel = Config.Models[math.random(1, #Config.Models)]

			ESX.Streaming.RequestModel(entityModel)

			local posX = x
			local posY = y
			local posZ = z + 999.0

			repeat
				Citizen.Wait(1)

				posX = x + math.random(-Config.MaxSpawnDistance, Config.MaxSpawnDistance)
				posY = y + math.random(-Config.MaxSpawnDistance, Config.MaxSpawnDistance)
				_, posZ = GetGroundZFor_3dCoord(posX + .0, posY + .0, z, 1)

				for _, player in pairs(players) do
					Citizen.Wait(1)

					playerX, playerY = table.unpack(GetEntityCoords(GetPlayerPed(player), true))

					if posX > playerX - Config.MinSpawnDistance and posX < playerX + Config.MinSpawnDistance or posY > playerY - Config.MinSpawnDistance and posY < playerY + Config.MinSpawnDistance then
						canSpawn = false
						break
					else
						canSpawn = true
					end
				end
			until canSpawn

			entity = CreatePed(4, entityModel, posX, posY, posZ, 0.0, true, false)
			walk = Config.Walks[math.random(1, #Config.Walks)]

			ESX.Streaming.RequestAnimDict(walk)

			SetPedMovementClipset(entity, walk, 1.0)
			TaskWanderStandard(entity, 1.0, 10)
			SetCanAttackFriendly(entity, true, true)
			SetPedCanEvasiveDive(entity, false)
			SetPedRelationshipGroupHash(entity, `zombie`)
			SetPedCombatAbility(entity, 0)
			SetPedCombatRange(entity,0)
			SetPedCombatMovement(entity, 0)
			SetPedAlertness(entity,0)
			SetPedIsDrunk(entity, true)
			SetPedConfigFlag(entity, 100, 1)
			ApplyPedDamagePack(entity, "BigHitByVehicle", 0.0, 9.0)
			ApplyPedDamagePack(entity, "SCR_Dumpster", 0.0, 9.0)
			ApplyPedDamagePack(entity, "SCR_Torture", 0.0, 9.0)
			DisablePedPainAudio(entity, true)
			StopPedSpeaking(entity, true)
			SetEntityAsMissionEntity(entity, true, true)

			if not NetworkGetEntityIsNetworked(entity) then
				NetworkRegisterEntityAsNetworked(entity)
			end

			table.insert(entities, entity)
		end

		for i, entity in pairs(entities) do
			if not DoesEntityExist(entity) then
				SetEntityAsNoLongerNeeded(entity)

				table.remove(entities, i)
			else
				local playerX, playerY, playerZ = table.unpack(GetEntityCoords(PlayerPedId(), true))
				local pedX, pedY, pedZ = table.unpack(GetEntityCoords(entity, true))

				if pedX < playerX - Config.DespawnDistance or pedX > playerX + Config.DespawnDistance or pedY < playerY - Config.DespawnDistance or pedY > playerY + Config.DespawnDistance then
					local model = GetEntityModel(entity)

					SetEntityAsNoLongerNeeded(entity)
					SetModelAsNoLongerNeeded(model)

					table.remove(entities, i)
				end
			end

			if IsEntityInWater(entity) then
				local model = GetEntityModel(entity)

				SetEntityAsNoLongerNeeded(entity)
				SetModelAsNoLongerNeeded(model)
				DeleteEntity(entity)

				table.remove(entities,i)
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1000)

		for i, entity in pairs(entities) do
			for j, player in pairs(players) do
				local playerX, playerY, playerZ = table.unpack(GetEntityCoords(GetPlayerPed(player), true))
				local distance = GetDistanceBetweenCoords(GetEntityCoords(GetPlayerPed(player)), GetEntityCoords(entity), true)

				if distance <= 25.0 then
					TaskGoToEntity(entity, GetPlayerPed(player), -1, 0.0, 1.0, 1073741824, 0)
				end
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)

		for i, entity in pairs(entities) do
			playerX, playerY, playerZ = table.unpack(GetEntityCoords(PlayerPedId(), true))
			pedX, pedY, pedZ = table.unpack(GetEntityCoords(entity, true))

			if IsPedDeadOrDying(entity, 1) ~= 1 then
				if Vdist(playerX, playerY, playerZ, pedX, pedY, pedZ) < 0.6 then
					if IsPedRagdoll(entity, 1) ~= 1 then
						if not IsPedGettingUp(entity) then
							ESX.Streaming.RequestAnimDict("misscarsteal4@actor")

							TaskPlayAnim(entity, "misscarsteal4@actor", "stumble", 1.0, 1.0, 500, 9, 1.0, 0, 0, 0)

							local playerPed = PlayerPedId()
							local maxHealth = GetEntityMaxHealth(playerPed)
							local health = GetEntityHealth(playerPed)
							local newHealth = math.min(maxHealth, math.floor(health - maxHealth / 8))

							SetEntityHealth(playerPed, newHealth)

							Citizen.Wait(2000)

							TaskGoToEntity(entity, PlayerPedId(), -1, 0.0, 1.0, 1073741824, 0)
						end
					end
				end
			end
		end
	end
end)

if Config.ZombieDropLoot then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(1)

			for i, entity in pairs(entities) do
				playerX, playerY, playerZ = table.unpack(GetEntityCoords(PlayerPedId(), true))
				pedX, pedY, pedZ = table.unpack(GetEntityCoords(entity, true))

				if DoesEntityExist(entity) == false then
					table.remove(entities, i)
				end

				if IsPedDeadOrDying(entity, 1) == 1 then
					if GetPedSourceOfDeath(entity) == PlayerPedId() then
						playerX, playerY, playerZ = table.unpack(GetEntityCoords(PlayerPedId(), true))
						pedX, pedY, pedZ = table.unpack(GetEntityCoords(entity, true))

						if not IsPedInAnyVehicle(PlayerPedId(), false) then
							if Vdist(playerX, playerY, playerZ, pedX, pedY, pedZ) < 1.5 then
								ESX.Game.Utils.DrawText3D({x = pedX, y = pedY, z = pedZ + 0.2}, '~c~PRESS ~b~[E]~c~ TO SEARCH', 0.8, 4)

								if IsControlJustReleased(1, 51) then
									if DoesEntityExist(PlayerPedId()) then
										ESX.Streaming.RequestAnimDict("random@domestic")

										TaskPlayAnim(PlayerPedId(), "random@domestic", "pickup_low", 8.0, -8, 2000, 2, 0, 0, 0, 0)

										Citizen.Wait(2000)

										randomChance = math.random(1, 100)
										randomWeapon = Config.WeaponLoot[math.random(1, #Config.WeaponLoot)]
										randomItem = Config.ItemLoot[math.random(1, #Config.ItemLoot)]

										if randomChance > 0 and randomChance < Config.ProbabilityWeaponLoot then
											local randomAmmo = math.random(1, 30)

											GiveWeaponToPed(PlayerPedId(), randomWeapon, randomAmmo, true, false)

											ESX.ShowNotification('You found ' .. randomWeapon)
										elseif randomChance >= Config.ProbabilityWeaponLoot and randomChance < Config.ProbabilityMoneyLoot then
											TriggerServerEvent('esx_zombiesystem:moneyloot')
										elseif randomChance >= Config.ProbabilityMoneyLoot and randomChance < Config.ProbabilityItemLoot then
											TriggerServerEvent('esx_zombiesystem:itemloot', randomItem)
										elseif randomChance >= Config.ProbabilityItemLoot and randomChance < 100 then
											ESX.ShowNotification('You not found nothing')
										end

										ClearPedSecondaryTask(PlayerPedId())

										local model = GetEntityModel(entity)

										SetEntityAsNoLongerNeeded(entity)
										SetModelAsNoLongerNeeded(model)

										table.remove(entities, i)
									end
								end
							end
						end
					end
				end
			end
		end
	end)
end

if Config.SafeZoneRadioBlip then
	for k, v in pairs(Config.SafeZoneCoords) do
		blip = AddBlipForRadius(v.x, v.y, v.z, v.radio)

		SetBlipHighDetail(blip, true)
		SetBlipColour(blip, 2)
		SetBlipAlpha(blip, 128)
	end
end

if Config.SafeZone then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(1)

			for k, v in pairs(Config.SafeZoneCoords) do
				for i, entity in pairs(entities) do
					pedX, pedY, pedZ = table.unpack(GetEntityCoords(entity, true))

					if Vdist(pedX, pedY, pedZ, v.x, v.y, v.z) < v.radio then
						SetEntityHealth(entity, 0)
						SetEntityAsNoLongerNeeded(entity)
						DeleteEntity(entity)

						table.remove(entities, i)
					end
				end
			end
		end
	end)
end

RegisterNetEvent('esx_zombiesystem:clear')
AddEventHandler('esx_zombiesystem:clear', function()
	for i, entity in pairs(entities) do
		local model = GetEntityModel(entity)

		SetEntityAsNoLongerNeeded(entity)
		SetModelAsNoLongerNeeded(model)

		table.remove(entities, i)
	end
end)

if Config.Debug then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(1)

			for i, entity in pairs(entities) do
				local playerX, playerY, playerZ = table.unpack(GetEntityCoords(PlayerPedId(), true))
				local pedX, pedY, pedZ = table.unpack(GetEntityCoords(entity, false))

				DrawLine(playerX, playerY, playerZ, pedX, pedY, pedZ, 250,0,0,250)
			end
		end
	end)
end

if Config.NoPeds then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(1)

			SetVehicleDensityMultiplierThisFrame(0.0)
			SetPedDensityMultiplierThisFrame(0.0)
			SetRandomVehicleDensityMultiplierThisFrame(0.0)
			SetParkedVehicleDensityMultiplierThisFrame(0.0)
			SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)

			local playerPed = PlayerPedId()
			local playerCoords = GetEntityCoords(playerPed)

			RemoveVehiclesFromGeneratorsInArea(playerCoords.x - 500.0, playerCoords.y - 500.0, playerCoords.z - 500.0, playerCoords.x + 500.0, playerCoords.y + 500.0, playerCoords.z + 500.0)
			SetGarbageTrucks(0)
			SetRandomBoats(0)
		end
	end)
end

if Config.ObjectDropLoot then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0)

			for k, v in pairs(Config.ObjectsLoot) do
				local playerPed = PlayerPedId()
				local playerCoords = GetEntityCoords(playerPed)
				local distanceobject = 2.2
				local obj = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, distanceobject, v, false, true ,true)
				local distance = GetDistanceBetweenCoords(playerCoords, GetEntityCoords(obj), true)

				if distance <= distanceobject then
					local objectCoords = GetEntityCoords(obj)

					if not objects[obj] then
						ESX.Game.Utils.DrawText3D(objectCoords + vector3(0.0, 0.0, 0.5), '~c~PRESS ~b~[E]~c~ TO SEARCH', 1, 4)
					end

					if IsControlJustReleased(0, 38) then
						if not objects[obj] then
							SetCurrentPedWeapon(PlayerPedId(), 0xA2719263, true)

							ESX.Streaming.RequestAnimDict("anim@amb@clubhouse@tutorial@bkr_tut_ig3@")

							TaskPlayAnim(playerPed, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 2.0, 2.0, 4000, 30, 0, 0, 0, 0)

							Citizen.Wait(4000)

							randomChance = math.random(1, 100)
							randomWeapon = Config.WeaponLootObject[math.random(1, #Config.WeaponLootObject)]
							randomItem = Config.ItemLootObject[math.random(1, #Config.ItemLootObject)]

							if randomChance > 0 and randomChance < Config.ProbabilityWeaponLootObject then
								local randomAmmo = math.random(1, 30)

								GiveWeaponToPed(playerPed, randomWeapon, randomAmmo, true, false)

								ESX.ShowNotification('You found ' .. randomWeapon)
							elseif randomChance >= Config.ProbabilityWeaponLootObject and randomChance < Config.ProbabilityMoneyLootObject then
								TriggerServerEvent('esx_zombiesystem:moneyloot')
							elseif randomChance >= Config.ProbabilityMoneyLootObject and randomChance < Config.ProbabilityItemLootObject then
								TriggerServerEvent('esx_zombiesystem:itemloot', randomItem)
							elseif randomChance >= Config.ProbabilityItemLootObject and randomChance < 100 then
								ESX.ShowNotification('You not found nothing')
							end

							objects[obj] = true
					   	end
					end
				end
			end
		end
	end)
end
