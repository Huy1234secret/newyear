--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TeamsService = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")


-- === PVP Apocalypse Debug Helper ===
local function pvpDebug(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	if ok then
		print("[PVP][Apocalypse] " .. msg)
	else
		print("[PVP][Apocalypse] " .. tostring(fmt))
	end
end
-- === End Debug Helper ===



local function getOrCreateTeam(name: string, color: Color3, autoAssignable: boolean): Team
	local team = TeamsService:FindFirstChild(name) :: Team?
	if not team then
		team = Instance.new("Team")
		team.Name = name
		team.Parent = TeamsService
	end

	team.TeamColor = BrickColor.new(color)
	team.AutoAssignable = autoAssignable

	return team
end

local spectateTeam = getOrCreateTeam("Spectate", Color3.fromRGB(85, 170, 255), true)

spectateTeam.AutoAssignable = true

local survivalTeam = TeamsService:FindFirstChild("Survivor")
if not survivalTeam or not survivalTeam:IsA("Team") then
	survivalTeam = TeamsService:FindFirstChild("Survival")
end
if not survivalTeam or not survivalTeam:IsA("Team") then
	survivalTeam = getOrCreateTeam("Survivor", Color3.fromRGB(255, 170, 0), false)
end
survivalTeam.AutoAssignable = false

local ghostTeam = getOrCreateTeam("Ghost", Color3.fromRGB(170, 170, 170), false)
ghostTeam.AutoAssignable = false

-- Cache the latest PirateApocalypse state so other systems (respawn handler) can see hearts/ghost flags
local LATEST_APOCALYPSE_STATE = nil


do
	local PIRATE_APOCALYPSE_WAVES = {
		{musicId = "114905649764615", spawns = {{name = "Zombie", count = 6, interval = 0.5}}},
		{spawns = {{name = "Zombie", count = 10, interval = 0.25}}},
		{spawns = {{name = "SpeedZombie", count = 5, interval = 0.5}}},
		{spawns = {{name = "Zombie", count = 5, interval = 0.5}, {name = "SpeedZombie", count = 5, interval = 0.3}}},
		{spawns = {{name = "Zombie", count = 20, interval = 0.5}}},
		{spawns = {{name = "Zombie", count = 5, interval = 1}, {name = "SpeedZombie", count = 20, interval = 0.5}}},
		{spawns = {{name = "FireZombie", count = 3, interval = 3}, {name = "Zombie", count = 15, interval = 0.5}}},
		{spawns = {{name = "FireZombie", count = 10, interval = 1}}},
		{spawns = {{name = "Zombie", count = 20, interval = 1}, {name = "SpeedZombie", count = 20, interval = 0.5}, {name = "FireZombie", count = 10, interval = 1}}},
		{musicId = "123764887251796", spawns = {{name = "KingZombie", count = 1, interval = 2}}},
		{spawns = {{name = "Zombie", count = 15, interval = 0.5}, {name = "FireZombie", count = 10, interval = 0.5}, {name = "DemonZombie", count = 2, interval = 1}}},
		{spawns = {{name = "FireZombie", count = 20, interval = 0.25}, {name = "SpeedZombie", count = 20, interval = 0.25}}},
		{spawns = {{name = "HazmatZombie", count = 5, interval = 1}, {name = "FireZombie", count = 10, interval = 1}, {name = "DemonZombie", count = 5, interval = 1}}},
		{spawns = {{name = "HazmatZombie", count = 10, interval = 0.5}}},
		{spawns = {{name = "Zombie", count = 50, interval = 0.1}, {name = "KingZombie", count = 1, interval = 2}}},
		{spawns = {{name = "SpeedZombie", count = 50, interval = 0.25}}},
		{spawns = {{name = "FireZombie", count = 25, interval = 1}}},
		{spawns = {{name = "DemonZombie", count = 20, interval = 1}}},
		{spawns = {{name = "HazmatZombie", count = 20, interval = 1}}},
		{musicId = "78606778500481", spawns = {{name = "DiamondZombie", count = 5, interval = 1},{name = "KingZombie", count = 1, interval = 2}}},
		{spawns = {{name = "ShadowZombie", count = 5, interval = 0.25}, {name = "SpeedZombie", count = 15, interval = 0.1}, {name = "HazmatZombie", count = 5, interval = 0.1}, {name = "DemonZombie", count = 5, interval = 0.1}, {name = "FireZombie", count = 5, interval = 3}}},
		{spawns = {{name = "GiantZombie", count = 1, interval = 1},{name = "KingZombie", count = 1, interval = 2}, {name = "FireZombie", count = 20, interval = 1}, {name = "SpeedZombie", count = 15, interval = 0.5}}},
		{spawns = {{name = "ShadowZombie", count = 10, interval = 0.5}, {name = "GiantZombie", count = 3, interval = 1}}},
		{spawns = {{name = "GiantSpeedZombie", count = 1, interval = 1},{name = "KingZombie", count = 1, interval = 2}, {name = "GiantZombie", count = 10, interval = 1}}},
		{spawns = {{name = "HazmatZombie", count = 5, interval = 0.2}, {name = "DemonZombie", count = 5, interval = 0.2}, {name = "FireZombie", count = 5, interval = 0.2}, {name = "ShadowZombie", count = 5, interval = 0.2}, {name = "GiantZombie", count = 5, interval = 1}, {name = "GiantSpeedZombie", count = 2, interval = 1}, {name = "Zombie", count = 25, interval = 1}, {name = "SpeedZombie", count = 20, interval = 1}}},
		{spawns = {{name = "CrystalZombie", count = 3, interval = 1},{name = "KingZombie", count = 1, interval = 2}, {name = "SpeedZombie", count = 15, interval = 0.1}}},
		{spawns = {{name = "GiantZombie", count = 20, interval = 2}, {name = "Zombie", count = 25, interval = 0.1}}},
		{spawns = {{name = "CrystalZombie", count = 5, interval = 0.25}, {name = "SpeedZombie", count = 20, interval = 0.1}, {name = "GiantSpeedZombie", count = 5, interval = 0.5}}},
		{spawns = {{name = "HazmatZombie", count = 5, interval = 1}, {name = "GiantZombie", count = 10, interval = 1}, {name = "CrystalZombie", count = 3, interval = 1}, {name = "ShadowZombie", count = 10, interval = 1}}},
		{musicId = "78708644418174", spawns = {{name = "ShadowBoss", count = 1, interval = 1},{name = "KingZombie", count = 3, interval = 2},{name = "DiamondZombie", count = 5, interval = 1}}},
		{spawns = {{name = "LightningZombie", count = 3, interval = 1}, {name = "DiamondZombie", count = 2, interval = 1}, {name = "GiantZombie", count = 5, interval = 1}}},
		{spawns = {{name = "DemonZombie", count = 10, interval = 0.2}, {name = "HazmatZombie", count = 10, interval = 0.2}, {name = "GiantSpeedZombie", count = 10, interval = 0.2}}},
		{spawns = {{name = "DiamondZombie", count = 10, interval = 1}, {name = "SpeedZombie", count = 50, interval = 0.1}}},
		{spawns = {{name = "FireZombie", count = 25, interval = 0.25}, {name = "LightningZombie", count = 10, interval = 0.5}}},
		{spawns = {{name = "CrystalZombie", count = 25, interval = 1}, {name = "LightningZombie", count = 10, interval = 1}, {name = "DemonZombie", count = 25, interval = 1}}},
		{spawns = {{name = "AngelZombie", count = 3, interval = 1}, {name = "DiamondZombie", count = 10, interval = 1}}},
		{spawns = {{name = "AngelZombie", count = 5, interval = 1},{name = "ShadowZombie", count = 25, interval = 0.5}, {name = "DemonZombie", count = 25, interval = 0.5}, {name = "LightningZombie", count = 10, interval = 1}}},
		{spawns = {{name = "AngelZombie", count = 5, interval = 1},{name = "RedValkZombie", count = 1, interval = 1}, {name = "DiamondZombie", count = 20, interval = 1}}},
		{spawns = {{name = "AngelZombie", count = 5, interval = 1},{name = "RedValkZombie", count = 5, interval = 0.5}, {name = "AngelZombie", count = 10, interval = 0.5}}},
		{musicId = "106663800872288", spawns = {{name = "AngelZombie", count = 5, interval = 1},{name = "NormalZombie", count = 10, interval = 0.1}, {name = "SpeedZombie", count = 10, interval = 0.1}, {name = "GiantZombie", count = 10, interval = 0.1}, {name = "GiantSpeedZombie", count = 10, interval = 0.1}, {name = "DemonZombie", count = 10, interval = 0.1}, {name = "FireZombie", count = 10, interval = 0.1}, {name = "HazmatZombie", count = 10, interval = 0.1}, {name = "CrystalZombie", count = 10, interval = 0.1}, {name = "ShadowZombie", count = 10, interval = 0.1}, {name = "DiamondZombie", count = 10, interval = 0.1}, {name = "LightningZombie", count = 10, interval = 0.1}, {name = "RedValkZombie", count = 5, interval = 1}, {name = "FrostBossZombie", count = 1, interval = 1}}},
	}

	local PIRATE_APOCALYPSE_GEAR_REWARDS = {
		[0] = {"Pistol", "Assault Rifle"},
		[10] = {"Tommy Gun"},
		[20] = {"Shotgun"},
		[30] = {"HexSpitter"},
	}

	local PIRATE_APOCALYPSE_HEART_RESTORE_INTERVAL = 5

	local function pirateApocalypseNormalizeName(name: string): string
		local lowered = string.lower(name)
		return lowered:gsub("%s+", "")
	end

	local function pirateApocalypseGetTemplate(cache: {[string]: Instance?}, folder: Instance?, name: string): Instance?
		if not folder then
			return nil
		end

		local normalized = pirateApocalypseNormalizeName(name)
		if cache[normalized] ~= nil then
			return cache[normalized]
		end

		local matched: Instance? = nil
		for _, child in folder:GetChildren() do
			if child:GetAttribute("PVPGenerated") == true then
				continue
			end

			if child:IsA("Tool") or child:IsA("Model") then
				local candidate = pirateApocalypseNormalizeName(child.Name)
				if candidate == normalized then
					matched = child
					break
				end
			end
		end


		-- Fallback synonym mapping (normalized)
		if not matched then
			local syn = {
				zombie = {"normalzombie"},
				speedzombie = {"fastzombie","runnerzombie"},
				firezombie = {"flamezombie"},
				hazmatzombie = {"toxiczombie"},
				giantzombie = {"bigzombie","tankzombie"},
				giantspeedzombie = {"giantfastzombie"},
				shadowzombie = {"darkzombie"},
				demonzombie = {"hellzombie"},
				crystalzombie = {"icezombie"},
				diamondzombie = {"gemzombie"},
				lightningzombie = {"electriczombie"},
				angelzombie = {"holyzombie"},
				normalzombie = {"zombie"},
			}
			local list = syn[normalized]
			if list then
				for _, alt in ipairs(list) do
					for _, child in folder:GetChildren() do
						if child:GetAttribute("PVPGenerated") == true then
							continue
						end
						if child:IsA("Tool") or child:IsA("Model") then
							local cand = pirateApocalypseNormalizeName(child.Name)
							if cand == alt then
								matched = child
								break
							end
						end
					end
					if matched then break end
				end
			end
		end
		cache[normalized] = matched
		return matched
	end

	local TARGET_ZOMBIE_SPAWN_MODEL_NAME = "ZombieSpawn"
	local TARGET_ZOMBIE_SPAWN_PART_NAMES = {
		Part = true,
		SpawnLocation = true,
	}

	local function pirateApocalypseCollectSpawnPoints(container: Instance?, onlyTargetParts: boolean?): {BasePart}
		local points: {BasePart} = {}
		if not container then
			return points
		end

		local function consider(instance: Instance)
			if not instance:IsA("BasePart") then
				return
			end

			if onlyTargetParts and not TARGET_ZOMBIE_SPAWN_PART_NAMES[instance.Name] then
				return
			end

			table.insert(points, instance)
		end

		consider(container)

		for _, child in container:GetDescendants() do
			consider(child)
		end

		return points
	end

	local ZOMBIE_SPAWN_CONTAINER_NAMES = {"ZombieSpawn", "ZombieSpawns", "ZombieSpawnPoints"}

	local function pirateApocalypseResolveSpawnPoints(mapModel: Model?): {BasePart}
		local resolved: {BasePart} = {}
		local seen: {[BasePart]: boolean} = {}

		if not mapModel then
			return resolved
		end

		local function addFrom(instance: Instance?, onlyTargetParts: boolean?)
			if not instance then
				return
			end

			for _, part in ipairs(pirateApocalypseCollectSpawnPoints(instance, onlyTargetParts)) do
				if not seen[part] then
					seen[part] = true
					table.insert(resolved, part)
				end
			end
		end

		local zombieSpawnModel = mapModel:FindFirstChild(TARGET_ZOMBIE_SPAWN_MODEL_NAME)
		if (not zombieSpawnModel or not zombieSpawnModel:IsA("Model")) then
			zombieSpawnModel = mapModel:FindFirstChild(TARGET_ZOMBIE_SPAWN_MODEL_NAME, true)
		end

		if zombieSpawnModel and zombieSpawnModel:IsA("Model") then
			addFrom(zombieSpawnModel, false)
		end

		for _, containerName in ipairs(ZOMBIE_SPAWN_CONTAINER_NAMES) do
			local container = mapModel:FindFirstChild(containerName)
			if not container then
				container = mapModel:FindFirstChild(containerName, true)
			end
			local onlyTargetParts = containerName ~= TARGET_ZOMBIE_SPAWN_MODEL_NAME
			addFrom(container, onlyTargetParts)
		end

		if #resolved == 0 then
			for _, descendant in mapModel:GetDescendants() do
				if descendant:IsA("BasePart") then
					local loweredName = string.lower(descendant.Name)
					if string.find(loweredName, "zombie") and string.find(loweredName, "spawn") then
						local onlyTargetParts = descendant.Parent and descendant.Parent:IsA("Model") and descendant.Parent.Name == TARGET_ZOMBIE_SPAWN_MODEL_NAME
						addFrom(descendant, onlyTargetParts)
					end
				end
			end
		end

		return resolved
	end


	-- Movement limiter for PirateBay survivors
	local function _applySurvivorNoJump(char: Model?)
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		-- Zero out jump; support both JumpPower and JumpHeight
		pcall(function() hum.UseJumpPower = true end)
		hum.Jump = false
		hum.JumpPower = 0
		pcall(function() hum.JumpHeight = 0 end)
	end

	local function _bindNoJumpOnSpawn(player: Player)
		if not player then return end
		-- Apply immediately if character exists
		if player.Character then _applySurvivorNoJump(player.Character) end
		-- And on future spawns
		player.CharacterAdded:Connect(function(char)
			_applySurvivorNoJump(char)
		end)
	end

	function pirateApocalypseAssignTeam(player: Player, team: Team?)
		if not player then
			return
		end

		player.Team = team
		player.Neutral = team == nil
		-- If assigning to Survival during PirateBay Apocalypse, disable jumping
		if team == survivalTeam then _bindNoJumpOnSpawn(player) end
	end


	-- Clean apocalypse status senders
	local function pirateApocalypseSendStatus(payload: {[string]: any})
		payload.action = "ApocalypseStatus"
		local remotes = ReplicatedStorage:FindFirstChild("PVPRemotes")
		if remotes and remotes:IsA("Folder") then
			local ev = remotes:FindFirstChild("StatusUpdate")
			if ev and ev:IsA("RemoteEvent") then
				ev:FireAllClients(payload)
				return
			end
		end
		-- If StatusUpdate RemoteEvent is unavailable, do nothing
	end

	local function pirateApocalypseSendPersonal(player: Player, payload: {[string]: any})
		if not player then return end
		payload.action = "ApocalypseStatus"
		local remotes = ReplicatedStorage:FindFirstChild("PVPRemotes")
		if remotes and remotes:IsA("Folder") then
			local ev = remotes:FindFirstChild("StatusUpdate")
			if ev and ev:IsA("RemoteEvent") then
				ev:FireClient(player, payload)
				return
			end
		end
		-- If StatusUpdate RemoteEvent is unavailable, do nothing
	end

	local function pirateApocalypseDisconnectConnections(connections: {RBXScriptConnection}?)
		if not connections then
			return
		end

		for index, conn in ipairs(connections) do
			if conn.Connected then
				conn:Disconnect()
			end
			connections[index] = nil
		end
	end

	local PIRATE_APOCALYPSE_ZOMBIE_FOLDER_NAME = "PirateApocalypseZombies"

	local function pirateApocalypseResolveZombieFolder(): Folder?
		local folder = ReplicatedStorage:FindFirstChild("Zombies")
		if not folder then
			local ok, result = pcall(function()
				return ReplicatedStorage:WaitForChild("Zombies", 5)
			end)
			if ok then
				folder = result
			end
		end

		if folder and folder:IsA("Folder") then
			return folder
		end

		return nil
	end

	local function pirateApocalypseEnsureZombieParentFolder(state: {[string]: any}): Folder
		local folder = state.zombieParentFolder
		if folder and folder.Parent then
			return folder
		end

		local existing = Workspace:FindFirstChild(PIRATE_APOCALYPSE_ZOMBIE_FOLDER_NAME)
		if not existing or not existing:IsA("Folder") then
			existing = Instance.new("Folder")
			existing.Name = PIRATE_APOCALYPSE_ZOMBIE_FOLDER_NAME
			existing.Parent = Workspace
		end

		state.zombieParentFolder = existing
		return existing
	end

	function pirateApocalypseEnsureState(context: SpecialEventContext, mapModel: Model?): {[string]: any}
		local state = context.state.PirateApocalypse
		local spawnPoints = pirateApocalypseResolveSpawnPoints(mapModel)
		if state then
			if mapModel then
				state.spawnPoints = spawnPoints
			end

			if not state.zombieFolder or not state.zombieFolder.Parent then
				state.zombieFolder = pirateApocalypseResolveZombieFolder()
			end

			if not state.gearFolder or not state.gearFolder.Parent then
				state.gearFolder = ReplicatedStorage:FindFirstChild("SurvivalGear")
			end

			pirateApocalypseEnsureZombieParentFolder(state)

			return state
		end

		state = {
			roundId = context.roundId,
			hearts = {},
			ghostPlayers = {},
			playerStatus = {},
			unlockedGear = {},
			gearCache = {},
			zombieCache = {},
			activeZombies = {},
			pendingSpawns = 0,
			running = false,
			completed = false,
			currentWave = 0,
			spawnPoints = spawnPoints,
			zombieFolder = pirateApocalypseResolveZombieFolder(),
			gearFolder = ReplicatedStorage:FindFirstChild("SurvivalGear"),
			zombieParentFolder = nil,
			zombieConnections = {},
			random = Random.new(),
		}

		pirateApocalypseEnsureZombieParentFolder(state)

		context.state.PirateApocalypse = state
		LATEST_APOCALYPSE_STATE = state
		return state
	end

	function pirateApocalypseUnlockRewards(state: {[string]: any}, waveNumber: number)
		local rewards = PIRATE_APOCALYPSE_GEAR_REWARDS[waveNumber]
		if not rewards then
			return
		end

		for _, gearName in ipairs(rewards) do
			local normalized = pirateApocalypseNormalizeName(gearName)
			state.unlockedGear[normalized] = gearName
		end
	end

	local function pirateApocalypseFindTool(player: Player, toolName: string): Tool?
		local normalized = pirateApocalypseNormalizeName(toolName)

		local function matchTool(container: Instance?): Tool?
			if not container then
				return nil
			end

			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					local candidate = pirateApocalypseNormalizeName(child.Name)
					if candidate == normalized then
						return child
					end
				end
			end

			return nil
		end

		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		local starter = player:FindFirstChild("StarterGear")

		return matchTool(character) or matchTool(backpack) or matchTool(starter)
	end

	local function pirateApocalypseGiveTool(player: Player, template: Instance, toolName: string)
		if not player or not template then
			return
		end

		local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
		local starter = player:FindFirstChild("StarterGear")

		if backpack and template:IsA("Tool") then
			local toolClone = template:Clone()
			toolClone.Name = template.Name
			toolClone:SetAttribute("PVPGenerated", true)
			toolClone.Parent = backpack
		end

		if starter and template:IsA("Tool") then
			local starterClone = template:Clone()
			starterClone.Name = template.Name
			starterClone:SetAttribute("PVPGenerated", true)
			starterClone.Parent = starter
		end
	end

	function pirateApocalypseProvideGear(state: {[string]: any}, record: ParticipantRecord)
		local player = record.player
		if not player then
			return
		end

		local gearFolder = state.gearFolder
		if not gearFolder then
			return
		end

		if state.ghostPlayers[player] then
			return
		end

		for normalized, originalName in pairs(state.unlockedGear) do
			if not pirateApocalypseFindTool(player, originalName) then
				local template = pirateApocalypseGetTemplate(state.gearCache, gearFolder, originalName)
				if template and template:IsA("Tool") then
					pirateApocalypseGiveTool(player, template, originalName)
				end
			end
		end
	end

	local function pirateApocalypseAdjustCharacterCollision(character: Model?, enabled: boolean)
		if not character then
			return
		end

		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") then
				if descendant:GetAttribute("OrigCollide") == nil then
					descendant:SetAttribute("OrigCollide", descendant.CanCollide)
				end
				if descendant:GetAttribute("OrigCanQuery") == nil then
					descendant:SetAttribute("OrigCanQuery", descendant.CanQuery)
				end
				if descendant:GetAttribute("OrigCanTouch") == nil then
					descendant:SetAttribute("OrigCanTouch", descendant.CanTouch)
				end

				if enabled then
					local originalCollide = descendant:GetAttribute("OrigCollide")
					if originalCollide ~= nil then
						descendant.CanCollide = originalCollide
					end

					local originalQuery = descendant:GetAttribute("OrigCanQuery")
					if originalQuery ~= nil then
						descendant.CanQuery = originalQuery
					end

					local originalTouch = descendant:GetAttribute("OrigCanTouch")
					if originalTouch ~= nil then
						descendant.CanTouch = originalTouch
					end
				else
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.CanTouch = false
				end
			elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
				if descendant:GetAttribute("OrigTrans") == nil then
					descendant:SetAttribute("OrigTrans", descendant.Transparency)
				end

				if enabled then
					local originalTransparency = descendant:GetAttribute("OrigTrans")
					if originalTransparency ~= nil then
						descendant.Transparency = originalTransparency
					end
				else
					descendant.Transparency = 1
				end
			end
		end
	end

	function pirateApocalypseSetGhostVisual(record: ParticipantRecord, isGhost: boolean)
		local player = record.player
		if not player then return end
		local character = player.Character
		pirateApocalypseAdjustCharacterCollision(character, not isGhost)

		if not character then return end

		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				-- cache original transparency once
				if part:GetAttribute("OrigTrans") == nil then
					part:SetAttribute("OrigTrans", part.Transparency)
				end
				if isGhost then
					-- make the character non-blocking and mostly invisible to others
					part.Transparency = 1
					part.LocalTransparencyModifier = 1
				else
					local ot = part:GetAttribute("OrigTrans")
					if ot ~= nil then
						part.Transparency = ot
					end
					part.LocalTransparencyModifier = 0
				end
			elseif part:IsA("Accessory") then
				for _, descendant in part:GetDescendants() do
					if descendant:IsA("BasePart") then
						if descendant:GetAttribute("OrigTrans") == nil then
							descendant:SetAttribute("OrigTrans", descendant.Transparency)
						end
						descendant.Transparency = isGhost and 1 or (descendant:GetAttribute("OrigTrans") or 0)
						descendant.LocalTransparencyModifier = isGhost and 1 or 0
					end
				end
			end
		end
	end

	local function pirateApocalypseSendPersonal(player: Player, payload: {[string]: any})
		if not player then return end
		payload.action = "ApocalypseStatus"
		local remotes = ReplicatedStorage:FindFirstChild("PVPRemotes")
		if remotes and remotes:IsA("Folder") then
			local ev = remotes:FindFirstChild("StatusUpdate")
			if ev and ev:IsA("RemoteEvent") then
				ev:FireClient(player, payload)
				return
			end
		end
	end

	local function pirateApocalypseEnsureHeartEntry(state: {[string]: any}, player: Player)
		local hearts = state.hearts[player]
		if typeof(hearts) ~= "number" then
			state.hearts[player] = 3
		end
	end

	function pirateApocalypseBroadcastHearts(state: {[string]: any})
		local payload: {[string]: any} = {phase = "Hearts", hearts = {}}
		for player, value in pairs(state.hearts) do
			if typeof(value) == "number" then
				payload.hearts[player.UserId] = value
			end
		end
		pirateApocalypseSendStatus(payload)
	end

	local function pirateApocalypseHandlePlayerDeath(context: SpecialEventContext, state: {[string]: any}, record: ParticipantRecord): boolean
		local player = record.player
		if not player then
			return true
		end

		pirateApocalypseEnsureHeartEntry(state, player)

		local remaining = math.max((state.hearts[player] or 0) - 1, 0)
		state.hearts[player] = remaining

		local message: string? = nil
		if remaining >= 2 then
			message = string.format("You have %d hearts left", remaining)
		elseif remaining == 1 then
			message = "You have 1 heart left"
		else
			message = "This is your last chance"
		end

		if message then
			pirateApocalypseSendPersonal(player, {
				phase = "HeartMessage",
				message = message,
			})
		end

		pirateApocalypseBroadcastHearts(state)

		local statusTable = state.playerStatus
		statusTable[player] = statusTable[player] or {}
		local status = statusTable[player]

		if remaining <= 0 then
			state.ghostPlayers[player] = true
			status.isGhost = true
			pirateApocalypseAssignTeam(player, ghostTeam)
			player:LoadCharacter()
			pirateApocalypseCheckRoundFailure(context, state)
			return true
		end

		state.ghostPlayers[player] = nil
		status.isGhost = false
		pirateApocalypseAssignTeam(player, survivalTeam)
		player:LoadCharacter()
		pirateApocalypseCheckRoundFailure(context, state)
		return true
	end

	local function pirateApocalypseHasActiveSurvivors(state: {[string]: any}): boolean
		for player, hearts in pairs(state.hearts) do
			if typeof(hearts) == "number" and hearts > 0 and not state.ghostPlayers[player] then
				return true
			end
		end
		return false
	end

	function pirateApocalypseCheckRoundFailure(context: SpecialEventContext, state: {[string]: any})
		if pirateApocalypseHasActiveSurvivors(state) then
			return
		end

		pirateApocalypseSendStatus({phase = "Failure"})
		task.defer(function()
			endRound(context.roundId)
		end)
	end

	local function pirateApocalypseClearZombieTracking(state: {[string]: any})
		for zombie in pairs(state.activeZombies) do
			state.activeZombies[zombie] = nil
		end
		pirateApocalypseDisconnectConnections(state.zombieConnections)
		state.zombieConnections = {}

		local parentFolder = state.zombieParentFolder
		if parentFolder and parentFolder.Parent then
			for _, child in ipairs(parentFolder:GetChildren()) do
				if child:GetAttribute("PVPGenerated") then
					child:Destroy()
				end
			end
		end
	end

	-- Forward declaration so we can call it before its definition
	local pirateApocalypseCheckWaveComplete
	-- Forward declaration for round failure checker
	local pirateApocalypseCheckRoundFailure
	-- Forward declaration for participant iterator
	local forEachActiveParticipant

	-- ===== Music switching for milestone waves =====
	local function _findFirstChildByNames(parent, names)
		if not parent then return nil end
		for _, n in ipairs(names) do
			local c = parent:FindFirstChild(n)
			if c then return c end
		end
		return nil
	end

	local function pirateApocalypseStopMilestoneMusic(state)
		if state._musicSound and state._musicSound:IsA("Sound") then
			pcall(function() state._musicSound:Stop() end)
			pcall(function() state._musicSound:Destroy() end)
		end
		state._musicSound = nil
	end

	local function pirateApocalypsePlayMilestoneMusic(state, waveNumber)
		local milestones = {
			[10] = {"Wave10","W10","Boss10"},
			[20] = {"Wave20","W20","Boss20"},
			[30] = {"Wave30","W30","Boss30"},
			[40] = {"Wave40","W40","FinalBoss","Boss40"},
		}
		if not milestones[waveNumber] then return end

		local RS = game:GetService("ReplicatedStorage")
		local SS = game:GetService("SoundService")

		-- Search these folders (first one found wins)
		local searchRoots = {}
		for _, name in ipairs({"PirateApocalypseMusic","ApocalypseMusic","SurvivalMusic","PirateBayMusic","Music"}) do
			local inRS = RS:FindFirstChild(name)
			if inRS then table.insert(searchRoots, inRS) end
			local inSS = SS:FindFirstChild(name)
			if inSS then table.insert(searchRoots, inSS) end
		end
		table.insert(searchRoots, SS) -- also check SoundService directly

		local soundAsset
		for _, root in ipairs(searchRoots) do
			local child = _findFirstChildByNames(root, milestones[waveNumber])
			if child then
				if child:IsA("Sound") then
					soundAsset = child
					break
				elseif child:IsA("Folder") then
					local s = _findFirstChildByNames(child, {"Track","Sound","Audio","S"})
					if s and s:IsA("Sound") then
						soundAsset = s
						break
					end
				end
			end
		end

		if not soundAsset then
			pvpDebug("[Music] No milestone track found for wave %s", tostring(waveNumber))
			return
		end

		-- Stop old, play new (looped)
		pirateApocalypseStopMilestoneMusic(state)
		local clone = soundAsset:Clone()
		clone.Name = "ApocMilestoneMusic"
		clone.Looped = true
		if clone.Volume <= 0 then clone.Volume = 0.6 end
		clone.Parent = SS
		clone:Play()
		state._musicSound = clone

		-- Debug + optional client cue
		pvpDebug("[Music] Switched to milestone track for wave %s: %s", tostring(waveNumber), tostring(soundAsset.Name))
		pirateApocalypseSendStatus({ phase = "MusicChange", wave = waveNumber, track = soundAsset.Name })
	end

	function pirateApocalypseStartWave(context: SpecialEventContext, state: {[string]: any}, waveNumber: number)
		-- inside function pirateApocalypseStartWave(context, state, waveNumber)
		state.currentWave = waveNumber
		state.waveInProgress = true
		pirateApocalypsePlayMilestoneMusic(state, waveNumber)  -- << add this line

		pvpDebug("[StartWave] wave=%s", tostring(waveNumber))
		-- Allow starting during prep; just ensure round id matches
		do pvpDebug("StartWave proceeding (ignoring id mismatch): cur=%s, ctx=%s", currentRoundId, context.roundId) end

		pirateApocalypseClearZombieTracking(state)
		pirateApocalypseSendStatus({phase = "Wave", wave = waveNumber})
		state.currentWave = waveNumber
		state.waveInProgress = true
		state.waveStartTick = os.clock()
		task.delay(60, function()
			if state.waveInProgress and state.currentWave == waveNumber then
				pvpDebug("[Wave] 60s elapsed: highlighting alive zombies (wave=%s)", tostring(waveNumber))
				pirateApocalypseHighlightAliveZombies(state)
			end
		end)

		local waveConfig = PIRATE_APOCALYPSE_WAVES[waveNumber]
		pvpDebug("[StartWave] waveConfig? %s", tostring(waveConfig ~= nil))
		if waveConfig and waveConfig.musicId then
			if type(playMusic) == "function" then playMusic(waveConfig.musicId) end
		end

		if waveNumber == #PIRATE_APOCALYPSE_WAVES then
			pirateApocalypseSendStatus({phase = "FinalWave", wave = waveNumber})
			applyDeathMatchAtmosphere(activeMapConfig)
		end

		state.pendingSpawns = 0
		if waveConfig then pvpDebug("[StartWave] spawns=%s", tostring(#(waveConfig.spawns or {}))) end
		if waveConfig then
			for _, spawnInfo in ipairs(waveConfig.spawns or {}) do
				local spawnCount = math.max(spawnInfo.count or 0, 0)
				state.pendingSpawns += spawnCount
				task.spawn(function()
					for spawnIndex = 1, spawnCount do
						if not state.running then
							break
						end

						local spawnPoints = state.spawnPoints
						if not spawnPoints or #spawnPoints == 0 then
							pirateApocalypseSendStatus({phase = "Warning", message = "Zombie spawn points unavailable. Ensure 'ZombieSpawn' has BaseParts."})
							state.pendingSpawns = math.max(state.pendingSpawns - (spawnCount - spawnIndex + 1), 0)
							break
						end

						local random = state.random or Random.new()
						state.random = random
						local index = random:NextInteger(1, #spawnPoints)
						local spawnPart = spawnPoints[index]
						local zombieFolder = state.zombieFolder
						if not zombieFolder or not zombieFolder.Parent then
							zombieFolder = pirateApocalypseResolveZombieFolder()
							state.zombieFolder = zombieFolder
						end

						local template = pirateApocalypseGetTemplate(state.zombieCache, zombieFolder, spawnInfo.name or "")
						pvpDebug("Spawning '%s' at index %s/%s", tostring(spawnInfo.name or "?"), index, #spawnPoints)
						if template and spawnPart then
							local zombieClone = template:Clone()
							zombieClone:SetAttribute("PVPGenerated", true)
							local zombieParent = pirateApocalypseEnsureZombieParentFolder(state)
							if zombieClone:IsA("Model") then
								zombieClone:PivotTo(spawnPart.CFrame)
								zombieClone.Parent = zombieParent
							else
								zombieClone.Parent = zombieParent
								if zombieClone:IsA("BasePart") then
									zombieClone.CFrame = spawnPart.CFrame
								end
							end

							state.activeZombies[zombieClone] = true
							if state.waveStartTick and (os.clock() - state.waveStartTick) >= 60 then _applyGreenHighlight(zombieClone) end
							pvpDebug("Zombie %s spawned at %s (wave %d)", zombieClone.Name, spawnPart.Name, waveNumber)

							local function onZombieRemoved()
								state.activeZombies[zombieClone] = nil
								pirateApocalypseCheckWaveComplete(context, state)
							end

							local bundle = {}
							local humanoid = zombieClone:FindFirstChildOfClass("Humanoid")
							if humanoid then
								local conn = humanoid.Died:Connect(onZombieRemoved)
								table.insert(bundle, conn)
							end

							local destroyingConn = zombieClone.Destroying:Connect(onZombieRemoved)
							table.insert(bundle, destroyingConn)

							for _, conn in ipairs(bundle) do
								table.insert(state.zombieConnections, conn)
							end
						else
							pirateApocalypseSendStatus({phase = "Warning", message = string.format("Missing zombie template '%s' in ReplicatedStorage/Zombies", spawnInfo.name or "?")})
						end

						state.pendingSpawns = math.max(state.pendingSpawns - 1, 0)
						pvpDebug("[Spawn] pending now=%s", tostring(state.pendingSpawns))
						pirateApocalypseCheckWaveComplete(context, state)

						local interval = spawnInfo.interval or 1
						if interval > 0 then
							task.wait(interval)
						end
					end
				end)
			end
		end

		pirateApocalypseCheckWaveComplete(context, state)
	end

	-- Debug helper to count alive/parented zombies
	local function _dbgCountActiveZombies(state)
		local alive = 0
		for z in pairs(state.activeZombies) do
			if z and z.Parent then alive += 1 end
		end
		return alive
	end
	-- Highlight helpers
	local function _applyGreenHighlight(model: Instance)
		if not model or not model:IsA("Model") then return end
		local h = model:FindFirstChild("ApocGreenHighlight")
		if not h then
			h = Instance.new("Highlight")
			h.Name = "ApocGreenHighlight"
			h.FillColor = Color3.new(0, 1, 0)
			h.OutlineColor = Color3.new(0, 1, 0)
			h.FillTransparency = 0.5
			h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = model
		end
	end

	local function pirateApocalypseHighlightAliveZombies(state)
		for z in pairs(state.activeZombies) do
			if z and z.Parent then _applyGreenHighlight(z) end
		end
	end

	function pirateApocalypseCheckWaveComplete(context: SpecialEventContext, state: {[string]: any})
		pvpDebug("[WaveCheck] enter: pending=%s alive=%s inProgress=%s", tostring(state.pendingSpawns), tostring(_dbgCountActiveZombies(state)), tostring(state.waveInProgress))
		if state.pendingSpawns > 0 then
			pvpDebug("[WaveCheck] pending > 0 -> return")
			return
		end

		for zombie in pairs(state.activeZombies) do
			if zombie and zombie.Parent then
				pvpDebug("[WaveCheck] still alive zombie present -> return")
				return
			end
		end

		if not state.waveInProgress then
			pvpDebug("[WaveCheck] waveInProgress false -> return")
			return
		end

		state.waveInProgress = false

		local waveNumber = state.currentWave
		pirateApocalypseUnlockRewards(state, waveNumber)
		forEachActiveParticipant(function(_, participantRecord)
			pirateApocalypseProvideGear(state, participantRecord)
		end)
		pvpDebug("[WaveCheck] wave complete: wave=%s", tostring(state.currentWave))
		pirateApocalypseSendStatus({phase = "WaveComplete", wave = waveNumber, message = string.format("Wave %d cleared", waveNumber)})

		if waveNumber % PIRATE_APOCALYPSE_HEART_RESTORE_INTERVAL == 0 then
			forEachActiveParticipant(function(player, _record)
				pirateApocalypseEnsureHeartEntry(state, player)
				local current = state.hearts[player] or 0
				if current < 3 then
					state.hearts[player] = math.min(3, current + 1)
				end
				if state.ghostPlayers[player] and state.hearts[player] > 0 then
					state.ghostPlayers[player] = nil
					local statusTable = state.playerStatus
					statusTable[player] = statusTable[player] or {}
					statusTable[player].isGhost = false
					pirateApocalypseAssignTeam(player, survivalTeam)
					player:LoadCharacter()
				end
			end)
			pirateApocalypseBroadcastHearts(state)
		end

		if waveNumber >= #PIRATE_APOCALYPSE_WAVES then
			state.completed = true
			state.intermissionToken = (state.intermissionToken or 0) + 1
			pirateApocalypseSendStatus({phase = "Victory", message = "GG"})
			restoreSkybox()
			restoreAtmosphere()
			task.delay(5, function()
				endRound(context.roundId)
			end)
			return
		end

		state.intermissionToken = (state.intermissionToken or 0) + 1
		local token = state.intermissionToken
		local nextWave = waveNumber + 1
		pvpDebug("[Countdown] begin: token=%s nextWave=%s", tostring(state.intermissionToken), tostring(nextWave))
		state.countdownThread = task.spawn(function()
			for remaining = 10, 0, -1 do
				pvpDebug("[Countdown] tick: remaining=%s roundInProgress=%s token=%s", tostring(remaining), tostring(roundInProgress), tostring(state.intermissionToken))
				-- (guard removed) if not roundInProgress then
				-- return (removed)
				-- end (removed)
				if false and state.intermissionToken ~= token then
					return
				end

				pirateApocalypseSendStatus({
					phase = "Countdown",
					wave = nextWave,
					remaining = remaining,
				})

				if remaining > 0 then
					task.wait(1)
				end
			end

			-- (guard removed) if not roundInProgress then
			-- return (removed)
			-- end (removed)
			if false and state.intermissionToken ~= token then
				return
			end

			pvpDebug("[Countdown] complete: starting wave %s", tostring(nextWave))
			pirateApocalypseSendStatus({phase = "WaveStart", wave = nextWave})
			state.countdownThread = nil
			pirateApocalypseStartWave(context, state, nextWave)
			-- Fallback: if wave didn't actually start within 11s, force it
			task.delay(11, function()
				if roundInProgress and not state.waveInProgress and state.currentWave == (nextWave - 1) then
					pvpDebug("[Countdown][Fallback] Forcing start of wave %s", tostring(nextWave))
					pirateApocalypseStartWave(context, state, nextWave)
				end
			end)
		end)
	end

	local existingNeutralTeam = TeamsService:FindFirstChild("Neutral")
	if existingNeutralTeam and existingNeutralTeam:IsA("Team") then
		existingNeutralTeam:Destroy()
	end

	local function assignPlayerToNeutralState(player: Player)
		-- During Pirate Apocalypse, keep players with hearts on the Survival team.
		local s = LATEST_APOCALYPSE_STATE
		if s and player then
			local hearts = (s.hearts and s.hearts[player]) or 0
			local isGhost = s.ghostPlayers and s.ghostPlayers[player]
			if hearts > 0 and not isGhost then
				pvpDebug("[RespawnTeam] player=%s -> Survival (hearts=%s)", tostring(player.Name), tostring(hearts))
				pirateApocalypseAssignTeam(player, survivalTeam)
				return
			end
			if hearts <= 0 or isGhost then
				pvpDebug("[RespawnTeam] player=%s -> Ghost (hearts=%s)", tostring(player.Name), tostring(hearts))
				pirateApocalypseAssignTeam(player, ghostTeam)
				return
			end
		end
		-- Fallback to Neutral for non-event contexts
		player.Team = nil
		player.Neutral = true
	end

	local function isPlayerInNeutralState(player: Player): boolean
		return player.Team == nil and player.Neutral == true
	end

	local allowedUserIds = {
		[347735445] = true,
	}

	local HUMANOID_WAIT_TIMEOUT = 5

	local TELEPORT_FREEZE_DURATION = 2
	local PREP_COUNTDOWN_DURATION = 10
	local INTERMISSION_MUSIC_ID = "15689444712"
	local DEFAULT_MUSIC_VOLUME = 0.5
	local DEATHMATCH_TRANSITION_DURATION = 3
	local DEATHMATCH_MUSIC_ID = "117047384857700"
	local STORM_MIN_HORIZONTAL_SIZE = 200
	local MAP_ANCHOR_DURATION = 5
	local HOT_TOUCH_TAG_SOUND_ID = "rbxassetid://2866718318"

	local SPECIAL_EVENT_MUSIC_IDS = {
		HotTouch = "84359090886294",
		Retro = "1837768352",
		KillBot = "1836075187",
	}

	local remotesFolder = ReplicatedStorage:FindFirstChild("PVPRemotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "PVPRemotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	local function getOrCreateRemote(name: string): RemoteEvent
		local remote = remotesFolder:FindFirstChild(name) :: RemoteEvent?
		if remote then
			return remote
		end

		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder

		return remote
	end

	local startRoundRemote = getOrCreateRemote("StartRound")
	local statusUpdateRemote = getOrCreateRemote("StatusUpdate")
	local roundStateRemote = getOrCreateRemote("RoundState")
	local toggleInventorySlotRemote = getOrCreateRemote("ToggleInventorySlot")

	local function sendStatusUpdate(data: {})
		statusUpdateRemote:FireAllClients(data)
	end

	local function isGameOwner(player: Player): boolean
		if allowedUserIds[player.UserId] then
			return true
		end

		local creatorId = game.CreatorId
		local creatorType = game.CreatorType

		if creatorType == Enum.CreatorType.User then
			return player.UserId == creatorId
		elseif creatorType == Enum.CreatorType.Group then
			local success, rank = pcall(function()
				return player:GetRankInGroup(creatorId)
			end)
			return success and rank == 255
		end

		return false
	end

	local R15_PART_NAMES = {
		UpperTorso = true,
		LowerTorso = true,
		LeftUpperArm = true,
		LeftLowerArm = true,
		LeftHand = true,
		RightUpperArm = true,
		RightLowerArm = true,
		RightHand = true,
		LeftUpperLeg = true,
		LeftLowerLeg = true,
		LeftFoot = true,
		RightUpperLeg = true,
		RightLowerLeg = true,
		RightFoot = true,
	}

	local function cleanupResidualRigParts(character: Model, humanoid: Humanoid?)
		if not character then
			return
		end

		if humanoid and humanoid.Parent ~= character then
			humanoid = nil
		end

		humanoid = humanoid or character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
			return
		end

		local torso = character:FindFirstChild("Torso")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not torso or not rootPart then
			return
		end

		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") and R15_PART_NAMES[descendant.Name] then
				descendant:Destroy()
			end
		end
	end

	local function ensureRigIsR6(player: Player, character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			local existing = character:FindFirstChild("Humanoid")
			if existing and existing:IsA("Humanoid") then
				humanoid = existing
			else
				local waitResult = character:WaitForChild("Humanoid", HUMANOID_WAIT_TIMEOUT)
				if waitResult and waitResult:IsA("Humanoid") then
					humanoid = waitResult
				end
			end
		end

		if not humanoid then
			return
		end

		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			cleanupResidualRigParts(character, humanoid)
			return
		end

		local description: HumanoidDescription? = nil
		local success, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)

		if success and result and result:IsA("HumanoidDescription") then
			description = result
		end

		if description then
			pcall(function()
				humanoid:ApplyDescription(description :: HumanoidDescription, Enum.HumanoidRigType.R6)
			end)
		else
			pcall(function()
				humanoid.RigType = Enum.HumanoidRigType.R6
			end)
		end

		task.defer(function()
			cleanupResidualRigParts(character, humanoid)
		end)
	end

	type MusicCycleSound = {
		id: string | number,
		playbackSpeed: number?,
	}

	type MusicCycleConfig = {
		sounds: {MusicCycleSound},
		minDelay: number?,
		maxDelay: number?,
	}

	type MapConfig = {
		id: string,
		displayName: string,
		modelName: string,
		spawnContainer: string,
		skyboxName: string,
		musicId: string?,
		musicCycle: MusicCycleConfig?,
		deathMatchMusicId: string?,
		deathMatchMusicStartTime: number?,
		deathMatchStormSize: Vector2?,
		deathMatchShrinkDuration: number?,
		lightningBrightness: number?,
		deathMatchStormColor: Color3?,
		deathMatchAtmosphereDensity: number?,
		deathMatchAtmosphereOffset: number?,
		deathMatchAtmosphereColor: Color3?,
		deathMatchAtmosphereDecay: Color3?,
		deathMatchAtmosphereGlare: number?,
		deathMatchAtmosphereHaze: number?,
		forcedSpecialEventId: string?,
	}

	local mapConfigurations: {[string]: MapConfig} = {
		Crossroad = {
			id = "Crossroad",
			displayName = "Crossroad",
			modelName = "Crossroad",
			spawnContainer = "CrossroadSpawns",
			skyboxName = "CrossroadSky",
			musicId = "95137069632101",
		},
		SFOTH = {
			id = "SFOTH",
			displayName = "SFOTH",
			modelName = "SFOTH",
			spawnContainer = "SFOTHSpawns",
			skyboxName = "SFOTHSky",
			musicId = "11470520383",
			deathMatchMusicId = "108063319549878",
			deathMatchMusicStartTime = 8,
			deathMatchStormSize = Vector2.new(700, 700),
			deathMatchShrinkDuration = 100,
		},
		ChaosCanyon = {
			id = "ChaosCanyon",
			displayName = "Chaos Canyon",
			modelName = "ChaosCanyon",
			spawnContainer = "ChaosCanyonSpawns",
			skyboxName = "ChaosCanyonSky",
			musicId = "100710950168570",
			deathMatchMusicId = "113378366723798",
			deathMatchStormSize = Vector2.new(350, 350),
			deathMatchShrinkDuration = 100,
		},
		Doomspire = {
			id = "Doomspire",
			displayName = "Doomspire",
			modelName = "Doomspire",
			spawnContainer = "DoomspireSpawns",
			skyboxName = "",
			musicId = "79269713968295",
			deathMatchMusicId = "74999952792352",
			deathMatchStormSize = Vector2.new(400, 400),
			deathMatchShrinkDuration = 100,
		},
		GlassHouses = {
			id = "GlassHouses",
			displayName = "Glass Houses",
			modelName = "GlassHouses",
			spawnContainer = "GlassHouseSpawns",
			skyboxName = "",
			musicId = "126261663857384",
			deathMatchMusicId = "81120877995774",
			deathMatchStormSize = Vector2.new(400, 400),
			deathMatchShrinkDuration = 100,
		},
		RobloxHQ = {
			id = "RobloxHQ",
			displayName = "Roblox HQ",
			modelName = "RobloxHQ",
			spawnContainer = "HQSpawns",
			skyboxName = "",
			musicId = "93577082200195",
			deathMatchMusicId = "1837863050",
			deathMatchStormSize = Vector2.new(500, 500),
			deathMatchShrinkDuration = 100,
		},
		RocketArena = {
			id = "RocketArena",
			displayName = "Rocket Arena",
			modelName = "RocketArena",
			spawnContainer = "RocketArenaSpawns",
			skyboxName = "RocketSky",
			musicId = "78606778500481",
			deathMatchMusicId = "80286513161881",
			deathMatchMusicStartTime = 7,
			deathMatchStormSize = Vector2.new(400, 400),
			deathMatchShrinkDuration = 100,
		},
		HauntedMansion = {
			id = "HauntedMansion",
			displayName = "Haunted Mansion",
			modelName = "HauntedMansion",
			spawnContainer = "HauntedSpawns",
			skyboxName = "ScarySky",
			musicCycle = {
				sounds = {
					{id = "13061810", playbackSpeed = 0.3},
					{id = "13061809", playbackSpeed = 0.2},
					{id = "13061802", playbackSpeed = 0.1},
					{id = "12229501", playbackSpeed = 0.1},
				},
				minDelay = 8,
				maxDelay = 10,
			},
			deathMatchMusicId = "9041745502",
			deathMatchStormSize = Vector2.new(400, 400),
			deathMatchShrinkDuration = 100,
			lightningBrightness = 0.25,
			deathMatchStormColor = Color3.fromRGB(0, 0, 0),
			deathMatchAtmosphereColor = Color3.fromRGB(0, 0, 0),
			deathMatchAtmosphereDecay = Color3.fromRGB(0, 0, 0),
		},
		BowlingAlley = {
			id = "BowlingAlley",
			displayName = "Bowling Alley",
			modelName = "BowlingAlley",
			spawnContainer = "BowlingSpawns",
			skyboxName = "",
			musicId = "114905649764615",
			deathMatchMusicId = "78847441253467",
			deathMatchStormSize = Vector2.new(325, 325),
			deathMatchShrinkDuration = 100,
		},
		HappyHomeOfRobloxia = {
			id = "HappyHomeOfRobloxia",
			displayName = "Happy Home of Robloxia",
			modelName = "HappyHomeOfRobloxia",
			spawnContainer = "HappySpawns",
			skyboxName = "",
			musicId = "71576296239106",
			deathMatchMusicId = "123764887251796",
			deathMatchStormSize = Vector2.new(500, 500),
			deathMatchShrinkDuration = 100,
		},
		RavenRock = {
			id = "RavenRock",
			displayName = "Raven Rock",
			modelName = "RavenRock",
			spawnContainer = "RavenSpawns",
			skyboxName = "",
			musicId = "1837755509",
			deathMatchMusicId = "113109916386013",
			deathMatchStormSize = Vector2.new(400, 400),
			deathMatchShrinkDuration = 100,
		},
		PirateBay = {
			id = "PirateBay",
			displayName = "Pirate Bay",
			modelName = "PirateBay",
			spawnContainer = "PirateBaySpawn",
			skyboxName = "PirateBaySky",
			musicId = "114905649764615",
			forcedSpecialEventId = "PirateBayApocalypse",
		},

	}

	type ParticipantRecord = {
		player: Player,
		roundId: number,
		spawnPart: BasePart?,
		characterConn: RBXScriptConnection?,
		deathConn: RBXScriptConnection?,
		healConn: RBXScriptConnection?,
		humanoid: Humanoid?,
		originalWalkSpeed: number?,
		originalJumpPower: number?,
		countdownComplete: boolean?,
		freezeToken: number?,
		eventData: {},
	}

	type SpecialEventContext = {
		definition: SpecialEventDefinition,
		roundId: number,
		state: {},
		ownerDifficultyOverride: number?,
	}

	type SpecialEventDefinition = {
		id: string,
		displayName: string,
		description: string?,
		ignoreDefaultGear: boolean?,
		onRoundPrepared: ((context: SpecialEventContext, config: MapConfig, mapModel: Model) -> ())?,
		onParticipantCharacter: ((context: SpecialEventContext, record: ParticipantRecord, character: Model, humanoid: Humanoid) -> ())?,
		onCountdownComplete: ((context: SpecialEventContext) -> ())?,
		onParticipantCleanup: ((context: SpecialEventContext, record: ParticipantRecord) -> ())?,
		onParticipantEliminated: ((context: SpecialEventContext, record: ParticipantRecord) -> ())?,
		onRoundEnded: ((context: SpecialEventContext) -> ())?,
		provideGear: ((context: SpecialEventContext, record: ParticipantRecord) -> ())?,
	}

	local participantRecords: {[Player]: ParticipantRecord} = {}
	local roundInProgress = false
	local currentRoundId = 0
	local activeMapModel: Model? = nil
	local activeMapConfig: MapConfig? = nil
	local activeSkybox: Instance? = nil
	local storedNormalSky: Instance? = nil
	local storedNormalSkyParent: Instance? = nil
	local currentStormPart: BasePart? = nil
	local deathMatchActive = false
	local managedAtmosphere: Atmosphere? = nil
	local createdManagedAtmosphere = false
	local storedAtmosphereProps: {Density: number, Offset: number, Color: Color3, Decay: Color3, Glare: number, Haze: number}? = nil
	local activeAtmosphereTween: Tween? = nil
	local selectedSpecialEventId: string? = nil
	local activeSpecialEvent: SpecialEventContext? = nil
	local storedLightingBrightness: number? = nil
	local lightingOverrideActive = false

	local function performDeathMatchTransition(roundId: number)
		-- Forward declaration; defined later.
	end

	local function endRound(roundId: number)
	end

	local function checkRoundCompletion(roundId: number)
	end

	local function handleElimination(player: Player, roundId: number)
	end

	local specialEventDefinitions: {[string]: SpecialEventDefinition} = {}
	local specialEventList: {SpecialEventDefinition} = {}

	local function registerSpecialEvent(definition: SpecialEventDefinition)
		specialEventDefinitions[definition.id] = definition
		table.insert(specialEventList, definition)
	end

	local function callSpecialEventCallback(context: SpecialEventContext?, methodName: string, ...)
		if not context then
			return nil
		end

		local definition = context.definition
		local callback = (definition :: any)[methodName]
		if typeof(callback) == "function" then
			local ok, result = pcall(callback, context, ...)
			if not ok then
				warn(string.format("Special event '%s' %s error: %s", definition.id, methodName, result))
				return nil
			end
			return result
		end

		return nil
	end

	local function setActiveSpecialEvent(eventId: string?, roundId: number, difficultyOverride: number?): SpecialEventContext?
		selectedSpecialEventId = eventId

		if not eventId then
			activeSpecialEvent = nil
			return nil
		end

		local definition = specialEventDefinitions[eventId]
		if not definition then
			warn(string.format("Unknown special event id '%s'", eventId))
			selectedSpecialEventId = nil
			activeSpecialEvent = nil
			return nil
		end

		local normalizedDifficulty: number? = nil
		if typeof(difficultyOverride) == "number" then
			local floored = math.floor(difficultyOverride)
			if floored >= 1 and floored < math.huge then
				normalizedDifficulty = floored
			end
		end

		local context: SpecialEventContext = {
			definition = definition,
			roundId = roundId,
			state = {},
			ownerDifficultyOverride = normalizedDifficulty,
		}

		activeSpecialEvent = context
		return context
	end

	local function clearActiveSpecialEvent()
		selectedSpecialEventId = nil
		activeSpecialEvent = nil
	end

	local function getRandomSpecialEventId(): string?
		if #specialEventList == 0 then
			return nil
		end

		local rng = Random.new()
		local index = rng:NextInteger(1, #specialEventList)
		local definition = specialEventList[index]
		return if definition then definition.id else nil
	end

	local function getOwnerDifficultyOverride(context: SpecialEventContext?, maxValue: number): number?
		if not context then
			return nil
		end

		local override = context.ownerDifficultyOverride
		if typeof(override) ~= "number" then
			return nil
		end

		local floored = math.floor(override)
		if floored < 1 then
			return nil
		end

		if floored > maxValue then
			floored = maxValue
		end

		return floored
	end

	function forEachActiveParticipant(callback: (Player, ParticipantRecord) -> ())
		for player, record in participantRecords do
			if record.roundId == currentRoundId then
				callback(player, record)
			end
		end
	end

	local function getNeutralParticipantRecords(): {ParticipantRecord}
		local records: {ParticipantRecord} = {}
		forEachActiveParticipant(function(player, record)
			if isPlayerInNeutralState(player) then
				table.insert(records, record)
			end
		end)
		return records
	end

	local function clearPVPTools(player: Player)
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, tool in backpack:GetChildren() do
				if tool:GetAttribute("PVPGenerated") then
					tool:Destroy()
				end
			end
		end

		local starterGear = player:FindFirstChild("StarterGear")
		if starterGear then
			for _, tool in starterGear:GetChildren() do
				if tool:GetAttribute("PVPGenerated") then
					tool:Destroy()
				end
			end
		end
	end

	local function getParticipantFromPlayer(targetPlayer: Player): ParticipantRecord?
		local record = participantRecords[targetPlayer]
		if record and record.roundId == currentRoundId then
			return record
		end
		return nil
	end

	local function getActiveMapBounds(): (CFrame, Vector3)
		local mapModel = activeMapModel
		if mapModel then
			local cf, size = mapModel:GetBoundingBox()
			return cf, size
		end

		return CFrame.new(), Vector3.new(400, 0, 400)
	end

	local function getStormHorizontalSize(): Vector2
		if activeMapConfig and activeMapConfig.deathMatchStormSize then
			return activeMapConfig.deathMatchStormSize
		end

		local _, size = getActiveMapBounds()
		return Vector2.new(math.max(400, size.X), math.max(400, size.Z))
	end

	do
		registerSpecialEvent({
			id = "ShatteredHeart",
			displayName = "?? Shattered Heart",
			onParticipantCharacter = function(context, record, _character, humanoid)
				if not isPlayerInNeutralState(record.player) then
					return
				end

				local data = record.eventData
				local bundle = data.ShatteredHeart
				if bundle and bundle.conn then
					bundle.conn:Disconnect()
				end

				local originalMaxHealth = humanoid.MaxHealth
				humanoid.MaxHealth = 1
				if humanoid.Health > 1 then
					humanoid.Health = 1
				end

				local conn = humanoid.HealthChanged:Connect(function(newHealth)
					if newHealth > 1 then
						humanoid.Health = 1
					end
				end)

				data.ShatteredHeart = {
					conn = conn,
					originalMax = originalMaxHealth,
				}
			end,
			onParticipantCleanup = function(context, record)
				local data = record.eventData
				local bundle = data.ShatteredHeart
				if not bundle then
					return
				end

				if bundle.conn then
					bundle.conn:Disconnect()
				end

				local humanoid = record.humanoid
				if not humanoid then
					local character = record.player.Character
					if character then
						humanoid = character:FindFirstChildOfClass("Humanoid")
					end
				end

				if humanoid and bundle.originalMax then
					humanoid.MaxHealth = bundle.originalMax
				end

				data.ShatteredHeart = nil
			end,
			onParticipantEliminated = function(context, record)
				callSpecialEventCallback(context, "onParticipantCleanup", record)
			end,
		})

		registerSpecialEvent({
			id = "SprintProhibit",
			displayName = "?? Sprint Prohibit",
			onRoundPrepared = function()
				sendStatusUpdate({
					action = "SpecialEventEffect",
					id = "SprintProhibit",
					sprintDisabled = true,
				})
			end,
			onRoundEnded = function()
				sendStatusUpdate({
					action = "SpecialEventEffect",
					id = "SprintProhibit",
					sprintDisabled = false,
				})
			end,
		})

		registerSpecialEvent({
			id = "Retro",
			displayName = "??? RETRO",
			ignoreDefaultGear = true,
			provideGear = function(context, record)
				local gearRoot = ReplicatedStorage:FindFirstChild("PVPGears")
				if not gearRoot or not gearRoot:IsA("Folder") then
					return
				end

				local available: {Tool} = {}
				for _, child in gearRoot:GetDescendants() do
					if child:IsA("Tool") then
						table.insert(available, child)
					end
				end

				if #available == 0 then
					return
				end

				local player = record.player
				local backpack = player:FindFirstChildOfClass("Backpack")
				if not backpack then
					return
				end

				local starterGear = player:FindFirstChild("StarterGear")
				local rng = Random.new()
				local taken: {[number]: boolean} = {}
				local selections = math.min(3, #available)

				while selections > 0 do
					local index = rng:NextInteger(1, #available)
					if taken[index] then
						continue
					end

					taken[index] = true
					selections -= 1

					local template = available[index]
					if template then
						local backpackTool = template:Clone()
						backpackTool:SetAttribute("PVPGenerated", true)
						backpackTool.Parent = backpack

						if starterGear then
							local starterTool = template:Clone()
							starterTool:SetAttribute("PVPGenerated", true)
							starterTool.Parent = starterGear
						end
					end
				end
			end,
		})

		registerSpecialEvent({
			id = "Invisible",
			displayName = "?? Invisible",
			onRoundPrepared = function()
				sendStatusUpdate({
					action = "SpecialEventEffect",
					id = "Invisible",
					invisible = true,
					pulseInterval = 5,
					pulseDuration = 1,
				})
			end,
			onRoundEnded = function()
				sendStatusUpdate({
					action = "SpecialEventEffect",
					id = "Invisible",
					invisible = false,
				})
			end,
		})

		registerSpecialEvent({
			id = "Bunny",
			displayName = "?? Bunny",
			onParticipantCharacter = function(context, record, _character, humanoid)
				local data = record.eventData
				local bundle = data.Bunny
				if bundle and bundle.conn then
					bundle.conn:Disconnect()
				end

				local conn: RBXScriptConnection? = nil
				conn = RunService.Heartbeat:Connect(function()
					if context.roundId ~= currentRoundId or not roundInProgress then
						if conn then
							conn:Disconnect()
						end
						return
					end

					if humanoid.Parent and humanoid.Health > 0 then
						humanoid.Jump = true
						if humanoid.FloorMaterial ~= Enum.Material.Air then
							humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end)

				data.Bunny = {
					conn = conn,
				}
			end,
			onParticipantCleanup = function(context, record)
				local data = record.eventData
				local bundle = data.Bunny
				if bundle and bundle.conn then
					bundle.conn:Disconnect()
				end
				local humanoid = record.humanoid
				if not humanoid and record.player.Character then
					humanoid = record.player.Character:FindFirstChildOfClass("Humanoid")
				end
				if humanoid then
					humanoid.Jump = false
				end
				data.Bunny = nil
			end,
			onParticipantEliminated = function(context, record)
				callSpecialEventCallback(context, "onParticipantCleanup", record)
			end,
		})

		registerSpecialEvent({
			id = "Slippery",
			displayName = "?? Slippery",
			onRoundPrepared = function(context, _config, mapModel)
				local originals: {[BasePart]: PhysicalProperties?} = {}
				for _, descendant in mapModel:GetDescendants() do
					if descendant:IsA("BasePart") then
						originals[descendant] = descendant.CustomPhysicalProperties

						local props = descendant.CustomPhysicalProperties
						local density = if props then props.Density else 1
						local elasticity = if props then props.Elasticity else 0
						local elasticityWeight = if props then props.ElasticityWeight else 0
						descendant.CustomPhysicalProperties = PhysicalProperties.new(density, 0, elasticity, 100, elasticityWeight)
					end
				end

				context.state.Slippery = {
					originals = originals,
				}
			end,
			onRoundEnded = function(context)
				local stored = context.state.Slippery
				if not stored then
					return
				end

				for part, props in stored.originals do
					if part and part.Parent then
						part.CustomPhysicalProperties = props
					end
				end

				context.state.Slippery = nil
			end,
		})

		registerSpecialEvent({
			id = "RainingBomb",
			displayName = "?? Raining Bomb",
			onRoundPrepared = function(context)
				local difficultySettings = {
					{spawnInterval = 1, blastRadius = 10, countdownTime = 3},
					{spawnInterval = 0.6, blastRadius = 10, countdownTime = 2.5},
					{spawnInterval = 0.45, blastRadius = 12, countdownTime = 2},
					{spawnInterval = 0.3, blastRadius = 12, countdownTime = 1.5},
					{spawnInterval = 0.1, blastRadius = 15, countdownTime = 1},
					{spawnInterval = 0.25, blastRadius = 20, countdownTime = 0, explodeOnImpact = true},
				}

				local state = context.state
				local eventState = state.RainingBomb
				if eventState and eventState.active then
					return
				end

				local difficultyRng = Random.new()
				local overrideIndex = getOwnerDifficultyOverride(context, #difficultySettings)
				local maxRandomDifficulty = math.min(#difficultySettings, 5)
				local difficultyIndex
				if overrideIndex then
					difficultyIndex = overrideIndex
				else
					difficultyIndex = difficultyRng:NextInteger(1, math.max(1, maxRandomDifficulty))
				end

				local config = difficultySettings[difficultyIndex] or difficultySettings[1]

				eventState = eventState or {}
				eventState.difficulty = difficultyIndex
				eventState.config = config
				eventState.difficultyBroadcasted = true
				eventState.active = false
				state.RainingBomb = eventState

				sendStatusUpdate({
					action = "SpecialEventDifficulty",
					id = context.definition.id,
					name = context.definition.displayName,
					difficulty = difficultyIndex,
					rollDuration = 2.4,
					displaySeconds = 3,
					flashCritical = difficultyIndex == 6,
				})
			end,
			onCountdownComplete = function(context)
				local state = context.state
				local eventState = state.RainingBomb

				local difficultySettings = {
					{spawnInterval = 1, blastRadius = 10, countdownTime = 3},
					{spawnInterval = 0.6, blastRadius = 10, countdownTime = 2.5},
					{spawnInterval = 0.45, blastRadius = 12, countdownTime = 2},
					{spawnInterval = 0.3, blastRadius = 12, countdownTime = 1.5},
					{spawnInterval = 0.1, blastRadius = 15, countdownTime = 1},
					{spawnInterval = 0.25, blastRadius = 20, countdownTime = 0, explodeOnImpact = true},
				}

				local difficultyIndex
				local config

				if eventState and eventState.config then
					difficultyIndex = eventState.difficulty or 1
					config = eventState.config
				else
					local difficultyRng = Random.new()
					local overrideIndex = getOwnerDifficultyOverride(context, #difficultySettings)
					local maxRandomDifficulty = math.min(#difficultySettings, 5)
					if overrideIndex then
						difficultyIndex = overrideIndex
					else
						difficultyIndex = difficultyRng:NextInteger(1, math.max(1, maxRandomDifficulty))
					end

					config = difficultySettings[difficultyIndex] or difficultySettings[1]

					eventState = eventState or {}
					eventState.difficulty = difficultyIndex
					eventState.config = config
					state.RainingBomb = eventState
				end

				if not eventState then
					eventState = {}
					state.RainingBomb = eventState
				end

				if not eventState.difficultyBroadcasted then
					sendStatusUpdate({
						action = "SpecialEventDifficulty",
						id = context.definition.id,
						name = context.definition.displayName,
						difficulty = difficultyIndex,
						rollDuration = 2.4,
						displaySeconds = 3,
						flashCritical = difficultyIndex == 6,
					})
					eventState.difficultyBroadcasted = true
				end

				if eventState.active then
					return
				end

				local running = true
				local activeBombs: {[BasePart]: boolean} = {}

				local function removeBomb(bomb: BasePart?, alreadyDestroying: boolean?)
					if not bomb then
						return
					end

					if activeBombs[bomb] then
						activeBombs[bomb] = nil
					end

					if not alreadyDestroying and bomb.Parent then
						bomb:Destroy()
					end
				end

				local function playExplosionSound(position: Vector3)
					local soundAnchor = Instance.new("Part")
					soundAnchor.Anchored = true
					soundAnchor.CanCollide = false
					soundAnchor.CanQuery = false
					soundAnchor.CanTouch = false
					soundAnchor.Transparency = 1
					soundAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
					soundAnchor.CFrame = CFrame.new(position)
					soundAnchor.Parent = Workspace

					local sound = Instance.new("Sound")
					sound.Name = "RainingBombExplosion"
					sound.SoundId = "rbxassetid://129988148028967"
					sound.Volume = 1
					sound.RollOffMaxDistance = 140
					sound.Parent = soundAnchor
					sound:Play()

					Debris:AddItem(soundAnchor, math.max(sound.TimeLength, 2))
				end

				local function createExplosion(bomb: BasePart)
					local explosion = Instance.new("Explosion")
					explosion.BlastRadius = config.blastRadius or 12
					explosion.BlastPressure = 500000
					explosion.Position = bomb.Position
					explosion.Parent = Workspace
					playExplosionSound(bomb.Position)
					removeBomb(bomb)
				end

				eventState.active = true
				eventState.bombs = activeBombs
				eventState.stop = function()
					running = false
					for part in pairs(activeBombs) do
						removeBomb(part)
					end
				end
				eventState.difficulty = difficultyIndex
				eventState.config = config

				local stormSize = getStormHorizontalSize()
				local cf, _ = getActiveMapBounds()
				local origin = cf.Position

				task.spawn(function()
					local spawnDelay = math.max(config.spawnInterval or 0.5, 0.1)
					local rng = Random.new()
					while running and roundInProgress and context.roundId == currentRoundId do
						local offsetX = rng:NextNumber(-stormSize.X / 2, stormSize.X / 2)
						local offsetZ = rng:NextNumber(-stormSize.Y / 2, stormSize.Y / 2)
						local spawnPosition = Vector3.new(origin.X + offsetX, origin.Y + 120, origin.Z + offsetZ)

						local bomb = Instance.new("Part")
						bomb.Name = "RainingBomb"
						bomb.Shape = Enum.PartType.Ball
						bomb.Material = Enum.Material.Neon
						bomb.Color = Color3.fromRGB(255, 0, 0)
						bomb.Size = Vector3.new(4, 4, 4)
						bomb.TopSurface = Enum.SurfaceType.Smooth
						bomb.BottomSurface = Enum.SurfaceType.Smooth
						bomb.CastShadow = false
						bomb.Anchored = false
						bomb.CanCollide = false
						bomb.CanTouch = true
						bomb.CanQuery = true
						bomb.Position = spawnPosition
						bomb.Parent = Workspace

						activeBombs[bomb] = true

						bomb.Destroying:Connect(function()
							removeBomb(bomb, true)
						end)

						local countdownStarted = false
						local exploded = false
						local function explode()
							if exploded or not bomb.Parent then
								return
							end
							exploded = true
							createExplosion(bomb)
						end

						local function startCountdown()
							if countdownStarted or exploded then
								return
							end

							if config.explodeOnImpact then
								explode()
								return
							end

							countdownStarted = true
							bomb.Anchored = false
							bomb.AssemblyLinearVelocity *= 0.5
							bomb.AssemblyAngularVelocity *= 0.5

							local totalDuration = config.countdownTime or 3
							local startTime = os.clock()
							local flashStyles = {
								{color = Color3.fromRGB(0, 0, 0), material = Enum.Material.SmoothPlastic},
								{color = Color3.fromRGB(255, 0, 0), material = Enum.Material.Neon},
							}

							task.spawn(function()
								local flashIndex = 1
								local maxInterval = math.clamp(totalDuration / 3, 0.18, 0.6)
								local minInterval = math.clamp(totalDuration / 12, 0.05, 0.25)
								if minInterval > maxInterval then
									minInterval, maxInterval = maxInterval, minInterval
								end

								while countdownStarted and not exploded and bomb.Parent do
									flashIndex = flashIndex == 1 and 2 or 1
									local style = flashStyles[flashIndex]
									bomb.Color = style.color
									bomb.Material = style.material

									local elapsed = os.clock() - startTime
									if elapsed >= totalDuration then
										break
									end

									local progress = math.clamp(elapsed / totalDuration, 0, 1)
									local interval = maxInterval - (maxInterval - minInterval) * progress
									task.wait(math.clamp(interval, 0.03, 1))
								end

								if bomb.Parent and not exploded then
									local finalStyle = flashStyles[2]
									bomb.Color = finalStyle.color
									bomb.Material = finalStyle.material
								end
							end)

							task.delay(totalDuration, function()
								if not exploded and bomb.Parent then
									explode()
								end
							end)
						end

						bomb.Touched:Connect(function(hit)
							if not hit or not hit:IsA("BasePart") then
								return
							end
							if config.explodeOnImpact then
								explode()
								return
							end
							startCountdown()
						end)
						-- Ensure server controls physics and apply downward velocity so it actually falls
						pcall(function() bomb:SetNetworkOwner(nil) end)
						bomb.AssemblyLinearVelocity = Vector3.new(0, -120, 0)
						-- Fallback: start the countdown even if no impact is detected
						-- removed: countdown now starts only on touch

						Debris:AddItem(bomb, 15)
						task.wait(spawnDelay)
					end
				end)
			end,
		})
		registerSpecialEvent({
			id = "KillBot",
			displayName = "?? KillBot",
			onRoundPrepared = function(context)
				local state = {
					bots = {},
					rockets = {},
					heartbeatConn = nil :: RBXScriptConnection?,
					difficulty = 1,
					config = nil,
				}
				context.state.KillBot = state

				local cf, _ = getActiveMapBounds()
				local origin = cf.Position
				local killBotRandom = Random.new()

				local difficultySettings = {
					{botCount = 2, rocketsPerVolley = 1, missileSpeed = 50, maxActiveRockets = 1},
					{botCount = 3, rocketsPerVolley = 1, missileSpeed = 65, maxActiveRockets = 1},
					{botCount = 4, rocketsPerVolley = 2, missileSpeed = 80, maxActiveRockets = 2},
					{botCount = 5, rocketsPerVolley = 2, missileSpeed = 100, maxActiveRockets = 2},
					{botCount = 6, rocketsPerVolley = 3, missileSpeed = 125, maxActiveRockets = 3},
					{botCount = 10, rocketsPerVolley = 3, missileSpeed = 100, maxActiveRockets = 4},
				}

				local overrideIndex = getOwnerDifficultyOverride(context, #difficultySettings)
				local randomMax = math.min(#difficultySettings, 5)
				local difficultyIndex
				if overrideIndex then
					difficultyIndex = overrideIndex
				else
					difficultyIndex = killBotRandom:NextInteger(1, math.max(1, randomMax))
				end

				local difficultyConfig = difficultySettings[difficultyIndex] or difficultySettings[1]
				state.difficulty = difficultyIndex
				state.config = difficultyConfig

				sendStatusUpdate({
					action = "SpecialEventDifficulty",
					id = context.definition.id,
					name = context.definition.displayName,
					difficulty = difficultyIndex,
					rollDuration = 2.4,
					displaySeconds = 3,
					flashCritical = difficultyIndex == 6,
				})

				-- Original Roblox KillBot settings
				local MIN_BOT_SPEED = 30
				local MAX_BOT_SPEED = 100
				local BOT_SIZE = Vector3.new(6, 6, 6)
				local BOT_MATERIAL = Enum.Material.Neon
				local BOT_COUNT = difficultyConfig.botCount or 3
				local MIN_MOVE_DISTANCE = 100
				local MAX_MOVE_DISTANCE = 500
				local MAX_ACTIVE_MISSILES_PER_BOT = math.max(difficultyConfig.maxActiveRockets or 1, 1)
				local ROCKETS_PER_VOLLEY = math.max(difficultyConfig.rocketsPerVolley or 1, 1)
				local BOT_COLOR_PALETTE = {
					Color3.fromRGB(255, 75, 75),
					Color3.fromRGB(255, 200, 90),
					Color3.fromRGB(80, 175, 255),
					Color3.fromRGB(120, 70, 255),
					Color3.fromRGB(60, 220, 150),
				}
				local MISSILE_DELAY = 0.75
				local MISSILE_SPEED = difficultyConfig.missileSpeed or 55
				local MISSILE_DAMAGE = 50
				local MISSILE_BLAST_RADIUS = 15
				local MOVE_INTERVAL = 2.0
				local STOP_INTERVAL = 3.0

				local function hasLineOfSight(botPosition: Vector3, targetPosition: Vector3): boolean
					local direction = targetPosition - botPosition
					local distance = direction.Magnitude
					if distance == 0 then
						return true
					end

					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Blacklist
					params.FilterDescendantsInstances = {activeMapModel}

					local result = Workspace:Raycast(botPosition, direction, params)
					if not result then
						return true
					end

					return (result.Position - targetPosition).Magnitude < 5
				end

				local function findNearestPlayer(botPosition: Vector3): Player?
					local nearestPlayer: Player? = nil
					local nearestDistance = math.huge

					for _, record in ipairs(getNeutralParticipantRecords()) do
						local character = record.player.Character
						if not character then
							continue
						end

						local humanoid = record.humanoid or character:FindFirstChildOfClass("Humanoid")
						if not humanoid or humanoid.Health <= 0 then
							continue
						end

						local hrp = character:FindFirstChild("HumanoidRootPart")
						if not hrp or not hrp:IsA("BasePart") then
							continue
						end

						local distance = (hrp.Position - botPosition).Magnitude
						if distance < nearestDistance then
							nearestDistance = distance
							nearestPlayer = record.player
						end
					end

					return nearestPlayer
				end

				local stormSize = getStormHorizontalSize()
				local horizontalRadiusX = math.max(stormSize.X / 2, 1)
				local horizontalRadiusZ = math.max(stormSize.Y / 2, 1)

				local function isWithinHorizontalRadius(position: Vector3): boolean
					local offset = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
					local normalizedX = offset.X / horizontalRadiusX
					local normalizedZ = offset.Z / horizontalRadiusZ
					return normalizedX * normalizedX + normalizedZ * normalizedZ <= 1
				end

				local function clampToHorizontalRadius(position: Vector3): Vector3
					if isWithinHorizontalRadius(position) then
						return position
					end

					local offset = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
					if offset.Magnitude < 1e-3 then
						return Vector3.new(origin.X, position.Y, origin.Z)
					end

					local angle = math.atan2(offset.Z, offset.X)
					local clampedX = math.cos(angle) * horizontalRadiusX
					local clampedZ = math.sin(angle) * horizontalRadiusZ

					return Vector3.new(origin.X + clampedX, position.Y, origin.Z + clampedZ)
				end

				local function getRandomHoverHeight(): number
					return killBotRandom:NextNumber(50, 100)
				end

				local function getRandomPosition(): Vector3
					while true do
						local candidateX = killBotRandom:NextNumber(-horizontalRadiusX, horizontalRadiusX)
						local candidateZ = killBotRandom:NextNumber(-horizontalRadiusZ, horizontalRadiusZ)
						local normalizedX = candidateX / horizontalRadiusX
						local normalizedZ = candidateZ / horizontalRadiusZ
						if normalizedX * normalizedX + normalizedZ * normalizedZ <= 1 then
							return Vector3.new(
								origin.X + candidateX,
								getRandomHoverHeight(),
								origin.Z + candidateZ
							)
						end
					end
				end

				local function getMaxDistanceWithinRadius(currentPosition: Vector3, direction: Vector3): number
					local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)
					if horizontalDirection.Magnitude < 1e-3 then
						return 0
					end

					local unitDirection = horizontalDirection.Unit
					local normalizedPosX = (currentPosition.X - origin.X) / horizontalRadiusX
					local normalizedPosZ = (currentPosition.Z - origin.Z) / horizontalRadiusZ
					local normalizedDirX = unitDirection.X / horizontalRadiusX
					local normalizedDirZ = unitDirection.Z / horizontalRadiusZ

					local a = normalizedDirX * normalizedDirX + normalizedDirZ * normalizedDirZ
					if a <= 1e-6 then
						return 0
					end

					local b = 2 * (normalizedPosX * normalizedDirX + normalizedPosZ * normalizedDirZ)
					local c = normalizedPosX * normalizedPosX + normalizedPosZ * normalizedPosZ - 1

					local discriminant = b * b - 4 * a * c
					if discriminant <= 0 then
						return 0
					end

					local sqrtDisc = math.sqrt(discriminant)
					local root1 = (-b - sqrtDisc) / (2 * a)
					local root2 = (-b + sqrtDisc) / (2 * a)

					local minPositive = math.huge
					if root1 > 1e-3 then
						minPositive = math.min(minPositive, root1)
					end
					if root2 > 1e-3 then
						minPositive = math.min(minPositive, root2)
					end

					if minPositive == math.huge then
						return 0
					end

					return math.max(minPositive, 0)
				end

				local function getRandomMovementTarget(currentPosition: Vector3): (Vector3, number)
					local bestDirection: Vector3? = nil
					local bestMaxDistance = 0

					for _ = 1, 16 do
						local angle = killBotRandom:NextNumber(0, math.pi * 2)
						local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
						if direction.Magnitude < 1e-3 then
							continue
						end

						direction = direction.Unit
						local maxDistance = getMaxDistanceWithinRadius(currentPosition, direction)
						if maxDistance > bestMaxDistance then
							bestMaxDistance = maxDistance
							bestDirection = direction
						end

						if maxDistance < MIN_MOVE_DISTANCE then
							continue
						end

						local desiredDistance = killBotRandom:NextNumber(MIN_MOVE_DISTANCE, MAX_MOVE_DISTANCE)
						local travelDistance = math.min(desiredDistance, maxDistance)
						local targetPosition = Vector3.new(
							currentPosition.X + direction.X * travelDistance,
							getRandomHoverHeight(),
							currentPosition.Z + direction.Z * travelDistance
						)

						if isWithinHorizontalRadius(targetPosition) then
							return targetPosition, travelDistance
						end
					end

					local toCenter = Vector3.new(origin.X - currentPosition.X, 0, origin.Z - currentPosition.Z)
					if toCenter.Magnitude > 1e-3 then
						local direction = toCenter.Unit
						local maxDistance = getMaxDistanceWithinRadius(currentPosition, direction)
						if maxDistance >= MIN_MOVE_DISTANCE then
							local desiredDistance = killBotRandom:NextNumber(MIN_MOVE_DISTANCE, MAX_MOVE_DISTANCE)
							local travelDistance = math.min(desiredDistance, maxDistance)
							local targetPosition = Vector3.new(
								currentPosition.X + direction.X * travelDistance,
								getRandomHoverHeight(),
								currentPosition.Z + direction.Z * travelDistance
							)

							local clampedTarget = clampToHorizontalRadius(targetPosition)
							return clampedTarget, (clampedTarget - currentPosition).Magnitude
						end
					end

					if bestDirection and bestMaxDistance > 0 then
						local desiredFallback = killBotRandom:NextNumber(MIN_MOVE_DISTANCE, MAX_MOVE_DISTANCE)
						local fallbackDistance = math.min(desiredFallback, bestMaxDistance)

						local fallbackTarget = Vector3.new(
							currentPosition.X + bestDirection.X * fallbackDistance,
							getRandomHoverHeight(),
							currentPosition.Z + bestDirection.Z * fallbackDistance
						)

						local clampedTarget = clampToHorizontalRadius(fallbackTarget)
						return clampedTarget, (clampedTarget - currentPosition).Magnitude
					end

					local finalTarget = clampToHorizontalRadius(Vector3.new(currentPosition.X, getRandomHoverHeight(), currentPosition.Z))
					return finalTarget, (finalTarget - currentPosition).Magnitude
				end

				local function damageInRadius(center: Vector3, radius: number)
					local params = OverlapParams.new()
					for _, part in ipairs(Workspace:GetPartBoundsInRadius(center, radius, params)) do
						local parent = part.Parent
						if not parent then
							continue
						end

						local humanoid = parent:FindFirstChildWhichIsA("Humanoid")
						if not humanoid and parent.Parent then
							humanoid = parent.Parent:FindFirstChildWhichIsA("Humanoid")
						end

						if humanoid and humanoid.Health > 0 then
							local character = humanoid.Parent
							local hrp = character and character:FindFirstChild("HumanoidRootPart")
							if hrp then
								local distance = (hrp.Position - center).Magnitude
								if distance <= radius then
									local damage = math.clamp(MISSILE_DAMAGE * (1 - (distance / radius)), 10, MISSILE_DAMAGE)
									humanoid:TakeDamage(damage)
								end
							end
						end
					end
				end

				local function destroyEnvironmentInRadius(center: Vector3, radius: number, ignoreModel: Model?)
					if not activeMapModel then
						return
					end

					local overlapParams = OverlapParams.new()
					overlapParams.FilterType = Enum.RaycastFilterType.Whitelist
					overlapParams.FilterDescendantsInstances = {activeMapModel}

					local partsInRadius = Workspace:GetPartBoundsInRadius(center, radius, overlapParams)
					for _, part in ipairs(partsInRadius) do
						if not part:IsA("BasePart") then
							continue
						end

						if ignoreModel and part:IsDescendantOf(ignoreModel) then
							continue
						end

						if part:GetAttribute("KillBotIndestructible") then
							continue
						end

						local parent = part.Parent
						if parent then
							local humanoid = parent:FindFirstChildWhichIsA("Humanoid")
							if not humanoid and parent.Parent then
								humanoid = parent.Parent:FindFirstChildWhichIsA("Humanoid")
							end
							if humanoid then
								continue
							end
						end

						local shouldDestroy = not part.Anchored or part:GetAttribute("KillBotDestructible")
						if not shouldDestroy then
							continue
						end

						if part.Anchored then
							part.Anchored = false
						end

						part:BreakJoints()

						local offset = part.Position - center
						if offset.Magnitude > 0 then
							local push = offset.Unit * 80
							part.AssemblyLinearVelocity = part.AssemblyLinearVelocity + push
						end

						Debris:AddItem(part, 8)
					end
				end

				local function getRocketCFrame(position: Vector3, direction: Vector3): CFrame
					local xAxis: Vector3
					if direction.Magnitude > 1e-3 then
						xAxis = direction.Unit
					else
						xAxis = Vector3.xAxis
					end

					local zAxis = xAxis:Cross(Vector3.yAxis)
					if zAxis.Magnitude < 1e-3 then
						zAxis = xAxis:Cross(Vector3.xAxis)
					end
					if zAxis.Magnitude < 1e-3 then
						zAxis = xAxis:Cross(Vector3.zAxis)
					end
					if zAxis.Magnitude < 1e-3 then
						zAxis = Vector3.zAxis
					else
						zAxis = zAxis.Unit
					end

					local yAxis = zAxis:Cross(xAxis)
					if yAxis.Magnitude < 1e-3 then
						yAxis = Vector3.yAxis
					end
					yAxis = yAxis - yAxis:Dot(xAxis) * xAxis
					if yAxis.Magnitude < 1e-3 then
						yAxis = xAxis:Cross(Vector3.zAxis)
						if yAxis.Magnitude < 1e-3 then
							yAxis = xAxis:Cross(Vector3.xAxis)
						end
					end
					if yAxis.Magnitude < 1e-3 then
						yAxis = Vector3.yAxis
					else
						yAxis = yAxis.Unit
					end

					return CFrame.fromMatrix(position, xAxis, yAxis, zAxis)
				end

				local function createRocket(botState, targetPosition: Vector3)
					local botPart = botState.part
					if not botPart or not botPart.Parent then
						return false
					end

					if botState.activeRockets >= MAX_ACTIVE_MISSILES_PER_BOT then
						return false
					end

					botState.activeRockets += 1

					local rocketFinished = false
					local function markRocketFinished()
						if rocketFinished then
							return
						end
						rocketFinished = true
						if botState.activeRockets > 0 then
							botState.activeRockets -= 1
						end
					end

					local rocket = Instance.new("Part")
					rocket.Name = "KillBotRocket"
					rocket.Shape = Enum.PartType.Block
					rocket.Size = Vector3.new(3, 1, 1)
					rocket.Material = Enum.Material.Neon
					rocket.Color = Color3.fromRGB(255, 100, 100)
					rocket.CanCollide = false
					rocket.CanQuery = false
					rocket.CanTouch = false
					rocket.Anchored = true
					rocket.Massless = true

					local spawnPosition = botPart.Position
					local targetClamped = clampToHorizontalRadius(Vector3.new(targetPosition.X, spawnPosition.Y, targetPosition.Z))
					targetPosition = Vector3.new(targetClamped.X, targetPosition.Y, targetClamped.Z)

					local travelVector = targetPosition - spawnPosition
					local travelDistance = travelVector.Magnitude
					if travelDistance < 1e-3 then
						travelVector = Vector3.new(0, -1, 0)
						travelDistance = 1
					end

					local travelDirection = travelVector.Unit

					rocket.CFrame = getRocketCFrame(spawnPosition, travelDirection)
					rocket.Parent = Workspace

					rocket.Anchored = false
					rocket:SetNetworkOwner(nil)

					local flightSound = Instance.new("Sound")
					flightSound.Name = "KillBotRocketFlight"
					flightSound.SoundId = "rbxassetid://12222095"
					flightSound.Volume = 0.6
					flightSound.Looped = true
					flightSound.RollOffMaxDistance = 120
					flightSound.PlayOnRemove = false
					flightSound.Parent = rocket
					flightSound:Play()

					local raycastIgnore = {}
					if botState.model then
						table.insert(raycastIgnore, botState.model)
					end
					table.insert(raycastIgnore, rocket)

					local raycastParams = RaycastParams.new()
					raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
					raycastParams.FilterDescendantsInstances = raycastIgnore

					local detonated = false
					local flightConnection: RBXScriptConnection? = nil
					local traveledDistance = 0
					local lastPosition = spawnPosition

					local function explode(hitInstance: Instance?, impactPosition: Vector3?)
						if detonated then
							return
						end

						detonated = true
						markRocketFinished()

						if flightConnection then
							flightConnection:Disconnect()
							flightConnection = nil
						end

						if flightSound.IsPlaying then
							flightSound:Stop()
						end

						local explosionPosition = impactPosition or rocket.Position

						local explosion = Instance.new("Explosion")
						explosion.BlastRadius = MISSILE_BLAST_RADIUS
						explosion.BlastPressure = 500000
						explosion.DestroyJointRadiusPercent = 100
						explosion.Position = explosionPosition
						explosion.Parent = Workspace

						explosion.Hit:Connect(function(hitPart)
							if not hitPart or not hitPart:IsA("BasePart") then
								return
							end

							if botState.model and hitPart:IsDescendantOf(botState.model) then
								return
							end

							if hitPart:GetAttribute("KillBotIndestructible") then
								return
							end

							local hitParent = hitPart.Parent
							if hitParent then
								local humanoid = hitParent:FindFirstChildWhichIsA("Humanoid")
								if not humanoid and hitParent.Parent then
									humanoid = hitParent.Parent:FindFirstChildWhichIsA("Humanoid")
								end
								if humanoid then
									return
								end
							end

							if hitPart:IsDescendantOf(activeMapModel) then
								if hitPart.Anchored and not hitPart:GetAttribute("KillBotDestructible") then
									return
								end
							end

							if hitPart.Anchored then
								hitPart.Anchored = false
							end

							hitPart:BreakJoints()

							local pushOffset = hitPart.Position - explosionPosition
							if pushOffset.Magnitude > 0 then
								local impulse = pushOffset.Unit * 80
								hitPart.AssemblyLinearVelocity = hitPart.AssemblyLinearVelocity + impulse
							end

							Debris:AddItem(hitPart, 10)
						end)

						damageInRadius(explosionPosition, MISSILE_BLAST_RADIUS)
						destroyEnvironmentInRadius(explosionPosition, MISSILE_BLAST_RADIUS, botState.model)

						local soundAnchor = Instance.new("Part")
						soundAnchor.Anchored = true
						soundAnchor.CanCollide = false
						soundAnchor.CanQuery = false
						soundAnchor.CanTouch = false
						soundAnchor.Transparency = 1
						soundAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
						soundAnchor.CFrame = CFrame.new(explosionPosition)
						soundAnchor.Parent = Workspace

						local impactSound = Instance.new("Sound")
						impactSound.Name = "KillBotRocketExplosion"
						impactSound.SoundId = "rbxassetid://129988148028967"
						impactSound.Volume = 1
						impactSound.RollOffMaxDistance = 120
						impactSound.Parent = soundAnchor
						impactSound:Play()

						Debris:AddItem(soundAnchor, math.max(impactSound.TimeLength, 2))

						if rocket.Parent then
							rocket:Destroy()
						end
					end

					flightConnection = RunService.Heartbeat:Connect(function(dt)
						if detonated or not rocket.Parent then
							if flightConnection then
								flightConnection:Disconnect()
								flightConnection = nil
							end
							return
						end

						local stepDistance = MISSILE_SPEED * dt
						local nextDistance = math.clamp(traveledDistance + stepDistance, 0, travelDistance)
						local position = spawnPosition + travelDirection * nextDistance

						local movement = position - lastPosition
						if movement.Magnitude > 0 then
							local result = Workspace:Raycast(lastPosition, movement, raycastParams)
							if result and result.Instance then
								local lookVector = travelDirection
								if lookVector.Magnitude < 1e-3 then
									lookVector = movement
								end
								if lookVector.Magnitude < 1e-3 then
									lookVector = Vector3.new(0, -1, 0)
								end
								rocket.CFrame = getRocketCFrame(result.Position, lookVector.Unit)
								explode(result.Instance, result.Position)
								return
							end
						end

						rocket.CFrame = getRocketCFrame(position, travelDirection)
						lastPosition = position

						traveledDistance = nextDistance

						if traveledDistance >= travelDistance - 1e-3 then
							explode(nil, position)
						end
					end)

					rocket.Destroying:Connect(function()
						markRocketFinished()
						if flightConnection then
							flightConnection:Disconnect()
							flightConnection = nil
						end
						if flightSound.IsPlaying then
							flightSound:Stop()
						end
					end)

					-- Auto-explode after 8 seconds
					task.delay(8, function()
						if not detonated and rocket.Parent then
							explode(nil, rocket.Position)
						end
					end)

					table.insert(state.rockets, function()
						markRocketFinished()
						if flightConnection then
							flightConnection:Disconnect()
							flightConnection = nil
						end
						if flightSound.IsPlaying then
							flightSound:Stop()
						end
						if rocket.Parent then
							rocket:Destroy()
						end
					end)

					return true
				end

				local function createKillBot(index: number, botColor: Color3)
					local model = Instance.new("Model")
					model.Name = string.format("KillBot_%d", index)

					local botPart = Instance.new("Part")
					botPart.Name = "BotPart"
					botPart.Shape = Enum.PartType.Ball
					botPart.Size = BOT_SIZE
					botPart.Material = BOT_MATERIAL
					botPart.Color = botColor
					botPart.CanCollide = false
					botPart.CanTouch = false
					botPart.CanQuery = false
					botPart.Anchored = false
					botPart.Massless = true

					local spawnPosition = getRandomPosition()
					botPart.CFrame = CFrame.new(spawnPosition)
					botPart.Parent = model
					model.PrimaryPart = botPart
					model.Parent = Workspace

					botPart:SetNetworkOwner(nil)

					local botState = {
						model = model,
						part = botPart,
						target = nil :: Player?,
						velocity = Vector3.zero,
						lastStopTime = 0,
						lastMissileTime = 0,
						currentTarget = Vector3.zero,
						isMoving = false,
						isStopped = false,
						moveSpeed = killBotRandom:NextNumber(MIN_BOT_SPEED, MAX_BOT_SPEED),
						activeRockets = 0,
						travelEndTime = 0,
					}

					model.Destroying:Connect(function()
						botState.part = nil
					end)

					table.insert(state.bots, botState)
				end

				-- Spawn bots
				local botColors = table.clone(BOT_COLOR_PALETTE)
				for i = #botColors, 2, -1 do
					local j = killBotRandom:NextInteger(1, i)
					botColors[i], botColors[j] = botColors[j], botColors[i]
				end
				if #botColors == 0 then
					botColors = {Color3.fromRGB(255, 0, 0)}
				end

				for index = 1, BOT_COUNT do
					local colorIndex = ((index - 1) % #botColors) + 1
					createKillBot(index, botColors[colorIndex])
				end

				-- Main bot AI loop
				state.heartbeatConn = RunService.Heartbeat:Connect(function(dt)
					if not roundInProgress or context.roundId ~= currentRoundId then
						return
					end

					for _, botState in ipairs(state.bots) do
						local botPart = botState.part
						if not botPart or not botPart.Parent then
							continue
						end

						local botPosition = botPart.Position
						local currentTime = os.clock()
						local targetPlayer = findNearestPlayer(botPosition)

						-- Random movement behavior
						if not botState.isMoving and not botState.isStopped then
							-- Start moving to a random position
							local targetPosition, travelDistance = getRandomMovementTarget(botPosition)
							travelDistance = travelDistance or 0
							botState.currentTarget = targetPosition
							botState.isMoving = true
							botState.moveSpeed = killBotRandom:NextNumber(MIN_BOT_SPEED, MAX_BOT_SPEED)
							if botState.moveSpeed <= 0 then
								botState.moveSpeed = MIN_BOT_SPEED
							end
							if travelDistance > 0 then
								botState.travelEndTime = currentTime + (travelDistance / botState.moveSpeed)
							else
								botState.travelEndTime = currentTime + MOVE_INTERVAL
							end
						elseif botState.isMoving then
							-- Check if we've reached the target or time to stop
							local distanceToTarget = (botState.currentTarget - botPosition).Magnitude
							if distanceToTarget < 10 or currentTime >= botState.travelEndTime then
								-- Stop and wait
								botState.isMoving = false
								botState.isStopped = true
								botState.lastStopTime = currentTime
								botState.velocity = Vector3.zero
								botState.travelEndTime = 0
							else
								-- Continue moving towards target
								local directionVector = botState.currentTarget - botPosition
								local direction = directionVector.Magnitude > 0 and directionVector.Unit or Vector3.zero
								botState.velocity = direction * botState.moveSpeed
							end
						elseif botState.isStopped then
							-- Check if it's time to start moving again
							if currentTime - botState.lastStopTime >= STOP_INTERVAL then
								botState.isStopped = false
							else
								botState.velocity = Vector3.zero
							end
						end

						-- Fire missiles at nearest player while stopped
						if botState.isStopped and targetPlayer and targetPlayer.Character then
							local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
							if targetHRP and targetHRP:IsA("BasePart") then
								local targetPosition = targetHRP.Position
								local hasLOS = hasLineOfSight(botPosition, targetPosition)

								if hasLOS and currentTime - botState.lastMissileTime >= MISSILE_DELAY then
									for volley = 1, ROCKETS_PER_VOLLEY do
										if botState.activeRockets < MAX_ACTIVE_MISSILES_PER_BOT then
											local created = createRocket(botState, targetPosition)
											if created then
												botState.lastMissileTime = currentTime
											else
												break
											end
										else
											break
										end
									end
								end
							end
						end

						-- Prevent bots from leaving the active storm radius
						local predictedPosition = botPosition + botState.velocity * dt
						if not isWithinHorizontalRadius(predictedPosition) then
							botState.currentTarget = clampToHorizontalRadius(botState.currentTarget)
							local correctedDirection = botState.currentTarget - botPosition
							if correctedDirection.Magnitude > 0 then
								botState.velocity = correctedDirection.Unit * botState.moveSpeed
							else
								botState.velocity = Vector3.zero
							end
							predictedPosition = botPosition + botState.velocity * dt
						end

						if not isWithinHorizontalRadius(botPosition) then
							local clampedPosition = clampToHorizontalRadius(botPosition)
							botPart.CFrame = CFrame.new(clampedPosition)
						end

						-- Apply velocity
						botPart.AssemblyLinearVelocity = botState.velocity

						-- Keep bot flying (above ground)
						if botPosition.Y < 20 then
							botPart.AssemblyLinearVelocity = botPart.AssemblyLinearVelocity + Vector3.new(0, 15, 0)
						end
					end
				end)
			end,
			onRoundEnded = function(context)
				local state = context.state.KillBot
				if not state then
					return
				end

				if state.heartbeatConn then
					state.heartbeatConn:Disconnect()
					state.heartbeatConn = nil
				end

				for _, botState in ipairs(state.bots) do
					if botState.model and botState.model.Parent then
						botState.model:Destroy()
					elseif botState.part and botState.part.Parent then
						botState.part:Destroy()
					end
				end

				for _, cleanup in ipairs(state.rockets) do
					local ok, err = pcall(cleanup)
					if not ok then
						warn("KillBot rocket cleanup error", err)
					end
				end

				state.bots = {}
				state.rockets = {}
				context.state.KillBot = nil
			end,
		})

		registerSpecialEvent({
			id = "HotTouch",
			displayName = "?? Hot Touch",
			ignoreDefaultGear = true,
			onRoundPrepared = function(context)
				local difficultySettings = {
					{initialTimer = 60, speedBonus = 2},
					{initialTimer = 50, speedBonus = 3},
					{initialTimer = 40, speedBonus = 4},
					{initialTimer = 30, speedBonus = 7},
					{initialTimer = 20, speedBonus = 10},
					{initialTimer = 30, speedBonus = 15},
				}

				local state = context.state
				local eventState = state.HotTouch
				if eventState and eventState.running then
					return
				end

				local rng = Random.new()
				local overrideIndex = getOwnerDifficultyOverride(context, #difficultySettings)
				local randomMax = math.min(#difficultySettings, 5)
				local difficultyIndex
				if overrideIndex then
					difficultyIndex = overrideIndex
				else
					difficultyIndex = rng:NextInteger(1, math.max(1, randomMax))
				end

				local difficultyConfig = difficultySettings[difficultyIndex] or difficultySettings[1]
				local initialTimer = math.max(difficultyConfig.initialTimer or 30, 5)
				local speedBonus = math.max(difficultyConfig.speedBonus or 0, 0)

				eventState = eventState or {}
				eventState.difficulty = difficultyIndex
				eventState.pendingConfig = difficultyConfig
				eventState.initialTimer = initialTimer
				eventState.speedBonus = speedBonus
				eventState.difficultyBroadcasted = true
				eventState.running = false
				state.HotTouch = eventState

				sendStatusUpdate({
					action = "SpecialEventDifficulty",
					id = context.definition.id,
					name = context.definition.displayName,
					difficulty = difficultyIndex,
					rollDuration = 2.4,
					displaySeconds = 3,
					flashCritical = difficultyIndex == 6,
				})
			end,
			onCountdownComplete = function(context)
				local state = context.state
				local eventState = state.HotTouch
				if eventState and eventState.running then
					return
				end

				local difficultySettings = {
					{initialTimer = 60, speedBonus = 2},
					{initialTimer = 50, speedBonus = 3},
					{initialTimer = 40, speedBonus = 4},
					{initialTimer = 30, speedBonus = 7},
					{initialTimer = 20, speedBonus = 10},
					{initialTimer = 30, speedBonus = 15},
				}

				local difficultyIndex
				local difficultyConfig
				local initialTimer
				local speedBonus

				if eventState and eventState.pendingConfig then
					difficultyIndex = eventState.difficulty or 1
					difficultyConfig = eventState.pendingConfig
					initialTimer = eventState.initialTimer
					speedBonus = eventState.speedBonus
				else
					local rng = Random.new()
					local overrideIndex = getOwnerDifficultyOverride(context, #difficultySettings)
					local randomMax = math.min(#difficultySettings, 5)
					if overrideIndex then
						difficultyIndex = overrideIndex
					else
						difficultyIndex = rng:NextInteger(1, math.max(1, randomMax))
					end

					difficultyConfig = difficultySettings[difficultyIndex] or difficultySettings[1]
					initialTimer = math.max(difficultyConfig.initialTimer or 30, 5)
					speedBonus = math.max(difficultyConfig.speedBonus or 0, 0)

					eventState = eventState or {}
					eventState.difficulty = difficultyIndex
					eventState.pendingConfig = difficultyConfig
					eventState.initialTimer = initialTimer
					eventState.speedBonus = speedBonus
					state.HotTouch = eventState
				end

				if not eventState then
					eventState = {}
					state.HotTouch = eventState
				end

				if not eventState.difficultyBroadcasted then
					sendStatusUpdate({
						action = "SpecialEventDifficulty",
						id = context.definition.id,
						name = context.definition.displayName,
						difficulty = difficultyIndex,
						rollDuration = 2.4,
						displaySeconds = 3,
						flashCritical = difficultyIndex == 6,
					})
					eventState.difficultyBroadcasted = true
				end

				local hotState = {
					holder = nil :: ParticipantRecord?,
					timer = initialTimer,
					initialTimer = initialTimer,
					maxTimer = initialTimer,
					speedBonus = speedBonus,
					difficulty = difficultyIndex,
					running = true,
					connections = {},
					disableRoundTimer = true,
				}
				state.HotTouch = hotState

				-- Broadcast the 'Survive' message to all players as soon as the event starts
				sendStatusUpdate({
					action = "MatchMessage",
					text = "Survive",
				})

				forEachActiveParticipant(function(_, participant)
					clearPVPTools(participant.player)
				end)

				local function broadcastSelecting()
					sendStatusUpdate({
						action = "HotTouchStatus",
						state = "Selecting",
					})
				end

				local function playTagSound(record: ParticipantRecord)
					local character = record.player.Character
					if not character then
						return
					end

					local rootPart = character:FindFirstChild("HumanoidRootPart")
					if not rootPart or not rootPart:IsA("BasePart") then
						return
					end

					local sound = Instance.new("Sound")
					sound.Name = "HotTouchTagSound"
					sound.SoundId = HOT_TOUCH_TAG_SOUND_ID
					sound.RollOffMode = Enum.RollOffMode.Linear
					sound.RollOffMaxDistance = 100
					sound.RollOffMinDistance = 15
					sound.EmitterSize = 10
					sound.Volume = 1
					sound.Parent = rootPart
					sound:Play()
					Debris:AddItem(sound, 4)
				end

				local function broadcastHolder(record: ParticipantRecord)
					local player = record.player
					sendStatusUpdate({
						action = "HotTouchStatus",
						state = "Holder",
						userId = player.UserId,
						name = player.Name,
						displayName = player.DisplayName,
					})
					sendStatusUpdate({
						action = "HotTouchTagged",
						userId = player.UserId,
					})
					playTagSound(record)
				end

				local function broadcastCompletion(winner: ParticipantRecord?)
						local payload: {[string]: any} = {
							action = "HotTouchStatus",
							state = "Complete",
						}

						if winner and winner.player then
							local player = winner.player
							payload.userId = player.UserId
							payload.name = player.Name
							payload.displayName = player.DisplayName
						end

						sendStatusUpdate(payload)

						-- When the event completes, display the winner's name to everyone. If there is no winner, fall back to a generic message.
						local message
						if winner and winner.player then
							message = "Winner: " .. tostring(winner.player.Name)
						else
							message = "No winner"
						end
						sendStatusUpdate({
							action = "MatchMessage",
							text = message,
						})
					end

				local function clearConnections()
					for _, conn in pairs(hotState.connections) do
						conn:Disconnect()
					end
					table.clear(hotState.connections)
				end

				local function applyHolderMovement(record: ParticipantRecord, active: boolean)
					local character = record.player.Character
					if not character then
						return
					end

					local humanoid = record.humanoid or character:FindFirstChildOfClass("Humanoid")
					if not humanoid then
						return
					end

					record.humanoid = humanoid

					if active then
						if record.eventData.HotTouchOriginalWalk == nil then
							record.eventData.HotTouchOriginalWalk = humanoid.WalkSpeed
						end

						local bonusAmount = hotState.speedBonus or 0

						if record.eventData.HotTouchHadSprintBonus == nil then
							local existingBonus = humanoid:GetAttribute("SprintSpeedBonus")
							if typeof(existingBonus) == "number" then
								record.eventData.HotTouchSprintBonus = existingBonus
								record.eventData.HotTouchHadSprintBonus = true
							else
								record.eventData.HotTouchSprintBonus = nil
								record.eventData.HotTouchHadSprintBonus = false
								existingBonus = 0
							end

							local bonusValue = if typeof(existingBonus) == "number" then existingBonus else 0
							humanoid:SetAttribute("SprintSpeedBonus", bonusValue + bonusAmount)
						else
							local storedBonus = record.eventData.HotTouchSprintBonus
							local baseValue = if typeof(storedBonus) == "number" then storedBonus else 0
							humanoid:SetAttribute("SprintSpeedBonus", baseValue + bonusAmount)
						end

						local baseline = record.eventData.HotTouchOriginalWalk or humanoid.WalkSpeed
						humanoid.WalkSpeed = baseline + bonusAmount
					else
						if record.eventData.HotTouchOriginalWalk ~= nil then
							humanoid.WalkSpeed = record.eventData.HotTouchOriginalWalk
						end
						record.eventData.HotTouchOriginalWalk = nil

						local hadBonus = record.eventData.HotTouchHadSprintBonus
						local originalBonus = record.eventData.HotTouchSprintBonus
						if hadBonus then
							humanoid:SetAttribute("SprintSpeedBonus", originalBonus)
						else
							humanoid:SetAttribute("SprintSpeedBonus", nil)
						end
						record.eventData.HotTouchHadSprintBonus = nil
						record.eventData.HotTouchSprintBonus = nil
					end
				end

				local function updateTargetHighlights(holder: ParticipantRecord?, enable: boolean)
					forEachActiveParticipant(function(_, rec)
						if not rec or (holder and rec == holder) then return end
						local ch = rec.player and rec.player.Character
						if not ch then return end
						local h = ch:FindFirstChild("HotTouchTarget")
						if enable then
							if not h then
								h = Instance.new("Highlight")
								h.Name = "HotTouchTarget"
								h.FillColor = Color3.fromRGB(255,255,255)
								h.OutlineColor = Color3.fromRGB(255,255,255)
								h.FillTransparency = 0.7
								h.OutlineTransparency = 0
								h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
								h.Parent = ch
							end
						else
							if h then h:Destroy() end
						end
					end)
				end

				-- Ensure BillboardGui for timer on the holder's root
				local function ensureTimerBillboard(holder: ParticipantRecord?)
					if not holder or not holder.player then return nil, nil end
					local ch = holder.player.Character
					if not ch then return nil, nil end
					local root = ch:FindFirstChild("HumanoidRootPart")
					if not root then
						local hum = holder.humanoid
						if hum and hum.RootPart then root = hum.RootPart end
					end
					if not root then return nil, nil end
					local gui = root:FindFirstChild("HotTouchBillboard")
					if not gui then
						gui = Instance.new("BillboardGui")
						gui.Name = "HotTouchBillboard"
						gui.AlwaysOnTop = true
						gui.Size = UDim2.new(0, 0, 0, 0)
						gui.StudsOffset = Vector3.new(0, 3, 0)
						gui.MaxDistance = 1000
						gui.Parent = root
					end
					local label = gui:FindFirstChild("HotTouchLabel")
					if not label then
						label = Instance.new("TextLabel")
						label.Name = "HotTouchLabel"
						label.BackgroundTransparency = 1
						label.TextColor3 = Color3.fromRGB(255, 255, 0)
						label.Font = Enum.Font.GothamBold
						label.TextScaled = true
						label.Size = UDim2.new(2, 0, 1, 0)
						label.AnchorPoint = Vector2.new(0.5, 0.5)
						label.Position = UDim2.new(0.5, 0, 0, 0)
						label.Parent = gui
					end
					return gui, label
				end

				local function updateHolderVisual(record: ParticipantRecord?, active: boolean)
					if not record then
						return
					end

					local character = record.player.Character
					if not character then
						return
					end

					applyHolderMovement(record, active)

					if active then
						local highlight = character:FindFirstChild("HotTouchHighlight") :: Highlight?
						if not highlight then
							highlight = Instance.new("Highlight")
							highlight.Name = "HotTouchHighlight"
							highlight.FillColor = Color3.fromRGB(255, 0, 0)
							highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
							highlight.FillTransparency = 1
							highlight.OutlineTransparency = 0
							highlight.Parent = character
						end
						highlight.FillTransparency = 1
						highlight.OutlineTransparency = 0
						highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
					else
						local highlight = character:FindFirstChild("HotTouchHighlight")
						if highlight then
							highlight:Destroy()
						end
					end

					local head = character:FindFirstChild("Head")
					local existingBillboard = character:FindFirstChild("HotTouchBillboard")
					if active then
						local billboard = if existingBillboard and existingBillboard:IsA("BillboardGui") then existingBillboard else Instance.new("BillboardGui")
						billboard.Name = "HotTouchBillboard"
						billboard.Size = UDim2.new(0, 80, 0, 40)
						billboard.StudsOffset = Vector3.new(0, 3, 0)
						billboard.AlwaysOnTop = true
						billboard.MaxDistance = 500
						billboard.Parent = head or character

						local label = billboard:FindFirstChild("Label") :: TextLabel?
						if not label then
							label = Instance.new("TextLabel")
							label.Name = "Label"
							label.Size = UDim2.new(1, 0, 1, 0)
							label.BackgroundTransparency = 1
							label.TextColor3 = Color3.fromRGB(255, 255, 255)
							label.TextStrokeTransparency = 0
							label.Font = Enum.Font.GothamBold
							label.TextScaled = true
							label.Parent = billboard
						end

						label.Text = tostring(hotState.timer)
					elseif existingBillboard then
						existingBillboard:Destroy()
					end
				end

				local function updateTimerVisual()
					local holder = hotState.holder
					if not holder then
						return
					end

					local character = holder.player.Character
					if not character then
						return
					end

                    -- Find and update any HotTouchBillboard instances on the character or its descendants
                    local secondsRemaining = math.max(0, math.floor(hotState.timer))
                    local maxTimer = math.max(hotState.maxTimer or hotState.initialTimer or 60, 1)
                    local ratio = math.clamp(hotState.timer / maxTimer, 0, 1)
                    local color = Color3.fromRGB(255, 255 * ratio, 255 * ratio)
                    -- Update all billboard labels (both visible head label and root label)
                    for _, descendant in ipairs(character:GetDescendants()) do
                        if descendant:IsA("BillboardGui") and descendant.Name == "HotTouchBillboard" then
                            -- There can be two different label names: 'Label' and 'HotTouchLabel'
                            local label1 = descendant:FindFirstChild("Label")
                            if label1 and label1:IsA("TextLabel") then
                                label1.Text = tostring(secondsRemaining)
                                label1.TextColor3 = color
                            end
                            local label2 = descendant:FindFirstChild("HotTouchLabel")
                            if label2 and label2:IsA("TextLabel") then
                                label2.Text = tostring(secondsRemaining)
                                label2.TextColor3 = color
                            end
                        end
                    end
                    -- Ensure and update the holder-head billboard (root label) so it exists for remote UI
                    local _, headLabel = ensureTimerBillboard(holder)
                    if headLabel then
                        headLabel.Text = tostring(secondsRemaining)
                    end
                    -- Broadcast to clients so ScreenGui can update
                    sendStatusUpdate({
                        action = "HotTouchTimer",
                        seconds = secondsRemaining,
                        remaining = secondsRemaining,
                        time = secondsRemaining,
                        holderUserId = holder.player.UserId,
                    })
				end

				local function detachHolder(record: ParticipantRecord?)
					if record then
						updateHolderVisual(record, false)
						updateTargetHighlights(nil, false)
					end
					clearConnections()
					-- cleanup any residual hitbox
					if record and record.player and record.player.Character then
						local ch = record.player.Character
						local hb = ch:FindFirstChild("HotTouch_Hitbox", true)
						if hb then hb:Destroy() end
					end

				end


				local function attachHolderConnections(record: ParticipantRecord)
					clearConnections()
					local character = record.player.Character
					if not character then
						return
					end


					-- Add an invisible welded hitbox for reliable tagging across platforms (esp. mobile)
					local hrp = character:FindFirstChild("HumanoidRootPart")
					if hrp and not character:FindFirstChild("HotTouch_Hitbox") then
						local hb = Instance.new("Part")
						hb.Name = "HotTouch_Hitbox"
						hb.Shape = Enum.PartType.Ball
						hb.Size = Vector3.new(6, 6, 6)
						hb.Massless = true
						hb.Transparency = 1
						hb.CanCollide = false
						hb.CanQuery = false
						hb.CanTouch = true
						hb.Parent = character
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = hb
						weld.Part1 = hrp
						weld.Parent = hb
						-- Touch handler mirrors the per-part handlers
						hotState.connections[#hotState.connections + 1] = hb.Touched:Connect(function(hit)
							if not hotState.running or context.roundId ~= currentRoundId then return end
							if hotState.holder ~= record then return end
							if not hit or not hit.Parent then return end
							local otherCharacter = hit:FindFirstAncestorOfClass("Model")
							if not otherCharacter then return end
							local otherPlayer = Players:GetPlayerFromCharacter(otherCharacter)
							if not otherPlayer or otherPlayer == record.player then return end
                            local targetRecord = getParticipantFromPlayer(otherPlayer)
                            -- Only proceed if there's a valid target that isn't the holder
                            if not targetRecord or targetRecord == hotState.holder then return end
                            -- Resolve the target's humanoid on demand; don't rely on targetRecord.humanoid being prepopulated
                            local targetHumanoid = targetRecord.humanoid
                            if not targetHumanoid then
                                local targetChar = targetRecord.player and targetRecord.player.Character
                                if targetChar then
                                    targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
                                    -- Cache it on the record so subsequent checks succeed
                                    if targetHumanoid then
                                        targetRecord.humanoid = targetHumanoid
                                    end
                                end
                            end
                            if not targetHumanoid or targetHumanoid.Health <= 0 then return end
                            local maxTimer = math.max(hotState.maxTimer or hotState.initialTimer or 60, 1)
                            -- Increase timer by 5 seconds (do not exceed maxTimer)
                            hotState.timer = math.min(hotState.timer + 5, maxTimer)
                            -- Unfreeze the current holder so they can run once the timer is passed on
                            setParticipantFrozen(record, false)
                            -- Transfer holder to the target without resetting timer
                            setHolder(targetRecord, false)
                            -- Freeze the new holder for 3 seconds; after the delay, unfreeze them if round still active
                            setParticipantFrozen(targetRecord, true)
                            task.delay(3, function()
                                if context.roundId == currentRoundId and roundInProgress then
                                    setParticipantFrozen(targetRecord, false)
                                end
                            end)
						end)
					end

					for _, descendant in character:GetDescendants() do
						if descendant:IsA("BasePart") then
							local basePart = descendant
							if not basePart.CanTouch then
								basePart.CanTouch = true
							end
							hotState.connections[#hotState.connections + 1] = basePart.Touched:Connect(function(hit)
								if not hotState.running or context.roundId ~= currentRoundId then
									return
								end

								if hotState.holder ~= record then
									return
								end

								if not hit or not hit.Parent then
									return
								end

								local otherCharacter = hit:FindFirstAncestorOfClass("Model")
								if not otherCharacter then
									return
								end

								local otherPlayer = Players:GetPlayerFromCharacter(otherCharacter)
								if not otherPlayer or otherPlayer == record.player then
									return
								end

                                local targetRecord = getParticipantFromPlayer(otherPlayer)
                                -- Only proceed if there's a valid target that isn't the current holder
                                if not targetRecord or targetRecord == hotState.holder then
                                    return
                                end
                                -- Resolve the target's humanoid on demand; don't rely on targetRecord.humanoid being prepopulated
                                local targetHumanoid = targetRecord.humanoid
                                if not targetHumanoid then
                                    local targetChar = targetRecord.player and targetRecord.player.Character
                                    if targetChar then
                                        targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
                                        if targetHumanoid then
                                            targetRecord.humanoid = targetHumanoid
                                        end
                                    end
                                end
                                if not targetHumanoid or targetHumanoid.Health <= 0 then
                                    return
                                end

                                local maxTimer = math.max(hotState.maxTimer or hotState.initialTimer or 60, 1)
                                -- Increase timer by 5 seconds, capping at maxTimer
                                hotState.timer = math.min(hotState.timer + 5, maxTimer)
                                -- Unfreeze the current holder so they can run once the timer is passed on
                                setParticipantFrozen(record, false)
                                -- Transfer the holder status to the tagged participant without resetting the timer
                                setHolder(targetRecord, false)
                                -- Freeze the new holder for 3 seconds, then unfreeze them when the delay ends
                                setParticipantFrozen(targetRecord, true)
                                task.delay(3, function()
                                    if context.roundId == currentRoundId and roundInProgress then
                                        setParticipantFrozen(targetRecord, false)
                                    end
                                end)
							end)
						end
					end
				end

				local function setHolder(newRecord: ParticipantRecord?, resetTimer: boolean)
				if newRecord == hotState.holder then
						if newRecord then
							if resetTimer then
								hotState.timer = hotState.initialTimer or 30
							end
                            updateHolderVisual(newRecord, true)
                            -- Update target highlights for the current holder so they can see potential targets
                            updateTargetHighlights(newRecord, true)
                            updateTimerVisual()
                            attachHolderConnections(newRecord)
                            broadcastHolder(newRecord)
						else
							broadcastSelecting()
							pvpDebug("[HotTouch] selecting next holder...")
						end
						return
					end

					detachHolder(hotState.holder)
						hotState.holder = newRecord
						pvpDebug("[HotTouch] holder=%s reset=%s", tostring(newRecord and newRecord.player and newRecord.player.Name), tostring(resetTimer))
						if newRecord then
							if resetTimer then
								hotState.timer = hotState.initialTimer or 30
							end
							updateHolderVisual(newRecord, true)
							-- Update target highlights for a new holder so they see all targets
							updateTargetHighlights(newRecord, true)
							updateTimerVisual()
							attachHolderConnections(newRecord)
							broadcastHolder(newRecord)
						else
							broadcastSelecting()
						end
					end

				hotState.setHolder = setHolder
				hotState.detachHolder = detachHolder

				local function selectNextHolder()
					local candidates = {}
					forEachActiveParticipant(function(_, record)
						local humanoid = record and record.humanoid
						if humanoid and humanoid.Health > 0 then
							table.insert(candidates, record)
						end
					end)

					if #candidates <= 1 then
						local winner = nil
						if #candidates == 1 then winner = candidates[1] end
						setHolder(nil, false)
						hotState.running = false
						broadcastCompletion(winner)
						return
					end

					pvpDebug("[HotTouch] candidates=%s", tostring(#candidates))
					local rng = Random.new()
					local newHolder = candidates[rng:NextInteger(1, #candidates)]
					setHolder(newHolder, true)
				end

				broadcastSelecting()
				selectNextHolder()

				task.spawn(function()
					while hotState.running and roundInProgress and context.roundId == currentRoundId do
						if not hotState.holder then
							task.wait(1)
							selectNextHolder()
							continue
						end

						hotState.timer -= 1
						updateTimerVisual()

						if hotState.timer <= 0 then
							local holder = hotState.holder
							if holder and holder.humanoid then
								local rootPart = holder.humanoid.RootPart or (holder.player and holder.player.Character and holder.player.Character:FindFirstChild("HumanoidRootPart"))
								if rootPart then
									local explosion = Instance.new("Explosion")
									explosion.BlastRadius = 15
									explosion.BlastPressure = 600000
									explosion.Position = rootPart.Position
									explosion.Parent = Workspace
								end
								holder.humanoid.Health = 0
							end

							selectNextHolder()
						end

						task.wait(1)
					end
				end)

				hotState.cleanup = function()
					hotState.running = false
					detachHolder(hotState.holder)
					hotState.holder = nil
					sendStatusUpdate({
						action = "HotTouchStatus",
						state = "Clear",
					})
				end
			end,
			onParticipantEliminated = function(context, record)
				local state = context.state.HotTouch
				if not state then
					return
				end

				if state.holder == record then
					if state.setHolder then
						state.setHolder(nil, false)
					else
						state.holder = nil
					end
				end
			end,
			onParticipantCleanup = function(context, record)
				local state = context.state.HotTouch
				if not state then
					return
				end

				if state.holder == record then
					if state.setHolder then
						state.setHolder(nil, false)
					else
						state.holder = nil
					end
				end
			end,
			onRoundEnded = function(context)
				local state = context.state.HotTouch
				if not state then
					return
				end

				if state.cleanup then
					state.cleanup()
				end
				context.state.HotTouch = nil
			end,
		})

		registerSpecialEvent({
			id = "PirateBayApocalypse",
			displayName = "????? Pirate Bay Apocalypse",
			ignoreDefaultGear = true,
			onRoundPrepared = function(context, _config, mapModel)
				local state = pirateApocalypseEnsureState(context, mapModel)
				state.hearts = {}
				state.ghostPlayers = {}
				state.playerStatus = {}
				state.running = false
				state.completed = false
				state.currentWave = 0
				state.pendingSpawns = 0
				state.spawnPoints = pirateApocalypseResolveSpawnPoints(mapModel)
				pvpDebug("Resolved %d zombie spawn points for PirateBay", #(state.spawnPoints or {}))
				pirateApocalypseUnlockRewards(state, 0)
				pirateApocalypseBroadcastHearts(state)
				pirateApocalypseSendStatus({phase = "ApocalypseReady", totalWaves = #PIRATE_APOCALYPSE_WAVES})
				context.state.DisableRoundTimer = true
				context.state.DisableCompletionCheck = true
			end,
			onParticipantCharacter = function(context, record, _character, _humanoid)
				local state = pirateApocalypseEnsureState(context, activeMapModel)
				local player = record.player
				pirateApocalypseEnsureHeartEntry(state, player)

				local statusTable = state.playerStatus
				statusTable[player] = statusTable[player] or {}
				local isGhost = state.ghostPlayers[player] or statusTable[player].isGhost
				statusTable[player].isGhost = isGhost

				if isGhost then
					pirateApocalypseAssignTeam(player, ghostTeam)
					pirateApocalypseSetGhostVisual(record, true)
				else
					pirateApocalypseAssignTeam(player, survivalTeam)
					pirateApocalypseSetGhostVisual(record, false)
					pirateApocalypseProvideGear(state, record)
				end
			end,
			provideGear = function(context, record)
				local state = pirateApocalypseEnsureState(context, activeMapModel)
				pirateApocalypseProvideGear(state, record)
			end,
			onCountdownComplete = function(context)
				local state = pirateApocalypseEnsureState(context, activeMapModel)
				if state.running then
					return
				end

				state.running = true
				pvpDebug("IDs: currentRoundId=%s, ctx.roundId=%s", currentRoundId, context.roundId)
				context.state.DisableRoundTimer = true
				context.state.DisableCompletionCheck = true
				pirateApocalypseUnlockRewards(state, 0)

				for player, participantRecord in participantRecords do
					if participantRecord and participantRecord.roundId == context.roundId then
						pirateApocalypseEnsureHeartEntry(state, player)
						state.playerStatus[player] = state.playerStatus[player] or {}
						state.playerStatus[player].isGhost = false
						state.ghostPlayers[player] = nil
						pirateApocalypseAssignTeam(player, survivalTeam)
						pirateApocalypseProvideGear(state, participantRecord)
					end
				end

				pirateApocalypseBroadcastHearts(state)
				pvpDebug("Survivors after setup: %d", (function() local c=0; for _ in pairs(state.hearts) do c+=1 end; return c end)())
				pirateApocalypseSendStatus({phase = "WaveStart", wave = 1})
				pirateApocalypseStartWave(context, state, 1)
			end,
			onParticipantEliminating = function(context, record)
				local state = pirateApocalypseEnsureState(context, activeMapModel)
				return pirateApocalypseHandlePlayerDeath(context, state, record)
			end,
			onParticipantCleanup = function(_context, record)
				pirateApocalypseSetGhostVisual(record, false)
			end,
			onRoundEnded = function(context)
				context.state.DisableRoundTimer = nil
				context.state.DisableCompletionCheck = nil
				local state = context.state.PirateApocalypse
				if not state then
					return
				end

				pirateApocalypseDisconnectConnections(state.zombieConnections)
				state.zombieConnections = {}
				state.activeZombies = {}
				state.intermissionToken = (state.intermissionToken or 0) + 1
				state.running = false
				pirateApocalypseSendStatus({phase = "Cleanup"})
			end,
		})
	end

	local mapsFolder = ReplicatedStorage:FindFirstChild("Maps")
	local skyboxFolder = ReplicatedStorage:FindFirstChild("Skybox")
	local gearsFolder = ReplicatedStorage:FindFirstChild("PVPGears")
	local stormUnionTemplate: UnionOperation? = nil

	local function updateStormTemplate()
		local templateCandidate = ReplicatedStorage:FindFirstChild("StormPart", true)
		if templateCandidate and templateCandidate:IsA("UnionOperation") then
			stormUnionTemplate = templateCandidate
		else
			stormUnionTemplate = nil
		end
	end

	updateStormTemplate()

	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "Maps" and child:IsA("Folder") then
			mapsFolder = child
		elseif child.Name == "Skybox" and child:IsA("Folder") then
			skyboxFolder = child
		elseif child.Name == "PVPGears" and child:IsA("Folder") then
			gearsFolder = child
		end
	end)

	ReplicatedStorage.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "StormPart" and descendant:IsA("UnionOperation") then
			stormUnionTemplate = descendant
		end
	end)

	ReplicatedStorage.ChildRemoved:Connect(function(child)
		if child == mapsFolder then
			mapsFolder = nil
		elseif child == skyboxFolder then
			skyboxFolder = nil
		elseif child == gearsFolder then
			gearsFolder = nil
		end
	end)

	ReplicatedStorage.DescendantRemoving:Connect(function(descendant)
		if descendant == stormUnionTemplate then
			task.defer(updateStormTemplate)
		end
	end)

	local function sendRoundState(state: string, extra: {}?)
		local payload = if type(extra) == "table" then table.clone(extra :: {}) else {}
		payload.state = state
		roundStateRemote:FireAllClients(payload)
	end

	local currentMusic: Sound? = nil
	local currentMusicId: string? = nil
	local currentMusicLoopThread: thread? = nil
	local currentMusicLoopToken = 0

	local function cancelMusicLoopThread()
		currentMusicLoopToken += 1

		if currentMusicLoopThread then
			task.cancel(currentMusicLoopThread)
			currentMusicLoopThread = nil
		end
	end

	local function normalizeSoundId(assetId: string | number | nil): string?
		local idType = typeof(assetId)
		if idType == "number" then
			assetId = tostring(assetId :: number)
		elseif idType ~= "string" then
			return nil
		end

		if assetId == "" then
			return nil
		end

		if string.find(assetId, "rbxassetid://", 1, true) then
			return assetId
		end

		return "rbxassetid://" .. assetId
	end

	local function stopCurrentMusic()
		cancelMusicLoopThread()

		if currentMusic then
			currentMusic:Stop()
			currentMusic:Destroy()
			currentMusic = nil
			currentMusicId = nil
		end
	end

	local function playMusic(assetId: string | number | nil)
		local normalizedId = normalizeSoundId(assetId)
		if not normalizedId then
			stopCurrentMusic()
			return
		end

		if currentMusic and currentMusicId == normalizedId then
			currentMusic.Volume = DEFAULT_MUSIC_VOLUME
			currentMusic.PlaybackSpeed = 1
			if not currentMusic.IsPlaying then
				currentMusic:Play()
			end
			return
		end

		stopCurrentMusic()

		local sound = Instance.new("Sound")
		sound.Name = "PVPBackgroundMusic"
		sound.SoundId = normalizedId
		sound.Looped = true
		sound.Volume = DEFAULT_MUSIC_VOLUME
		sound.Parent = SoundService
		sound:Play()

		currentMusic = sound
		currentMusicId = normalizedId
	end

	local function playMusicCycle(config: MusicCycleConfig)
		if not config then
			stopCurrentMusic()
			return
		end

		local normalizedSounds = {}
		for _, soundConfig in ipairs(config.sounds) do
			local normalizedId = normalizeSoundId(soundConfig.id)
			if normalizedId then
				table.insert(normalizedSounds, {
					id = normalizedId,
					playbackSpeed = soundConfig.playbackSpeed,
				})
			end
		end

		if #normalizedSounds == 0 then
			stopCurrentMusic()
			return
		end

		stopCurrentMusic()

		local sound = Instance.new("Sound")
		sound.Name = "PVPBackgroundMusic"
		sound.Looped = false
		sound.Volume = DEFAULT_MUSIC_VOLUME
		sound.Parent = SoundService

		currentMusic = sound
		currentMusicId = "MusicCycle"

		local loopToken = currentMusicLoopToken
		local random = Random.new()
		local minDelay = config.minDelay or 0
		local maxDelay = config.maxDelay or minDelay
		if maxDelay < minDelay then
			maxDelay = minDelay
		end

		currentMusicLoopThread = task.spawn(function()
			while currentMusic and currentMusicLoopToken == loopToken do
				local choice = normalizedSounds[random:NextInteger(1, #normalizedSounds)]
				sound.SoundId = choice.id
				sound.TimePosition = 0
				sound.PlaybackSpeed = choice.playbackSpeed or 1
				sound:Play()

				local delayDuration
				if minDelay == maxDelay then
					delayDuration = minDelay
				elseif math.floor(minDelay) == minDelay and math.floor(maxDelay) == maxDelay then
					delayDuration = random:NextInteger(minDelay, maxDelay)
				else
					delayDuration = random:NextNumber(minDelay, maxDelay)
				end

				local remaining = math.max(delayDuration, 0)
				while remaining > 0 and currentMusic and currentMusicLoopToken == loopToken do
					local waitTime = task.wait(math.min(1, remaining))
					if not waitTime then
						waitTime = 0.03
					end
					remaining -= waitTime
				end
			end

			if currentMusicLoopToken == loopToken then
				currentMusicLoopThread = nil
			end
		end)
	end

	local function playIntermissionMusic()
		playMusic(INTERMISSION_MUSIC_ID)
	end

	local function playMapMusic(config: MapConfig)
		if config.musicCycle then
			playMusicCycle(config.musicCycle)
		elseif config.musicId then
			playMusic(config.musicId)
		else
			playIntermissionMusic()
		end
	end

	local function playDeathMatchMusic(config: MapConfig?)
		local musicId = DEATHMATCH_MUSIC_ID
		if config and config.deathMatchMusicId then
			musicId = config.deathMatchMusicId
		end

		playMusic(musicId)

		if currentMusic and config then
			local startTime = config.deathMatchMusicStartTime
			if typeof(startTime) == "number" then
				currentMusic.TimePosition = math.max(0, startTime)
			end
		end
	end

	playIntermissionMusic()

	local function cancelAtmosphereTween()
		if activeAtmosphereTween then
			activeAtmosphereTween:Cancel()
			activeAtmosphereTween = nil
		end
	end

	local function ensureManagedAtmosphere(): Atmosphere?
		if managedAtmosphere and managedAtmosphere.Parent then
			return managedAtmosphere
		end

		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			managedAtmosphere = atmosphere
			createdManagedAtmosphere = false
		else
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Name = "PVPAtmosphere"
			atmosphere.Parent = Lighting
			managedAtmosphere = atmosphere
			createdManagedAtmosphere = true
		end

		if atmosphere and not storedAtmosphereProps then
			storedAtmosphereProps = {
				Density = atmosphere.Density,
				Offset = atmosphere.Offset,
				Color = atmosphere.Color,
				Decay = atmosphere.Decay,
				Glare = atmosphere.Glare,
				Haze = atmosphere.Haze,
			}
		end

		return managedAtmosphere
	end

	local function restoreAtmosphere()
		cancelAtmosphereTween()

		local atmosphere = managedAtmosphere
		local created = createdManagedAtmosphere

		if not atmosphere or not atmosphere.Parent then
			managedAtmosphere = nil
			createdManagedAtmosphere = false
			storedAtmosphereProps = nil
			return
		end

		if storedAtmosphereProps then
			atmosphere.Density = storedAtmosphereProps.Density
			atmosphere.Offset = storedAtmosphereProps.Offset
			atmosphere.Color = storedAtmosphereProps.Color
			atmosphere.Decay = storedAtmosphereProps.Decay
			atmosphere.Glare = storedAtmosphereProps.Glare
			atmosphere.Haze = storedAtmosphereProps.Haze
		end

		if created then
			atmosphere:Destroy()
			managedAtmosphere = nil
			createdManagedAtmosphere = false
			storedAtmosphereProps = nil
		end
	end

	local function getDeathMatchAtmosphereGoal(config: MapConfig?): { [string]: any }
		local goal = {
			Density = 0.5,
			Offset = 1,
			Color = Color3.fromRGB(255, 0, 0),
			Decay = Color3.fromRGB(255, 0, 0),
			Glare = 0.5,
			Haze = 5,
		}

		if config then
			if typeof(config.deathMatchAtmosphereDensity) == "number" then
				goal.Density = config.deathMatchAtmosphereDensity
			end

			if typeof(config.deathMatchAtmosphereOffset) == "number" then
				goal.Offset = config.deathMatchAtmosphereOffset
			end

			if config.deathMatchAtmosphereColor then
				goal.Color = config.deathMatchAtmosphereColor
			end

			if config.deathMatchAtmosphereDecay then
				goal.Decay = config.deathMatchAtmosphereDecay
			end

			if typeof(config.deathMatchAtmosphereGlare) == "number" then
				goal.Glare = config.deathMatchAtmosphereGlare
			end

			if typeof(config.deathMatchAtmosphereHaze) == "number" then
				goal.Haze = config.deathMatchAtmosphereHaze
			end
		end

		return goal
	end

	local function tweenAtmosphereForDeathMatch(config: MapConfig?)
		local atmosphere = ensureManagedAtmosphere()
		if not atmosphere then
			return
		end

		cancelAtmosphereTween()

		local tweenInfo = TweenInfo.new(DEATHMATCH_TRANSITION_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local goal = getDeathMatchAtmosphereGoal(config)

		activeAtmosphereTween = TweenService:Create(atmosphere, tweenInfo, goal)
		local thisTween = activeAtmosphereTween
		thisTween:Play()

		task.delay(DEATHMATCH_TRANSITION_DURATION, function()
			if activeAtmosphereTween == thisTween then
				activeAtmosphereTween = nil
			end
		end)
	end

	local function applyDeathMatchAtmosphere(config: MapConfig?)
		local atmosphere = ensureManagedAtmosphere()
		if not atmosphere then
			return
		end

		cancelAtmosphereTween()

		local goal = getDeathMatchAtmosphereGoal(config)
		atmosphere.Density = goal.Density
		atmosphere.Offset = goal.Offset
		atmosphere.Color = goal.Color
		atmosphere.Decay = goal.Decay
		atmosphere.Glare = goal.Glare
		atmosphere.Haze = goal.Haze
	end

	local function clearStorm()
		if currentStormPart then
			currentStormPart:Destroy()
			currentStormPart = nil
		end
		deathMatchActive = false
		restoreAtmosphere()
	end

	local function restoreSkybox()
		if activeSkybox then
			activeSkybox:Destroy()
			activeSkybox = nil
		end

		if storedNormalSky then
			storedNormalSky.Parent = storedNormalSkyParent or Lighting
			storedNormalSky = nil
			storedNormalSkyParent = nil
		end
	end

	local function restoreLighting()
		if not lightingOverrideActive then
			return
		end

		if storedLightingBrightness ~= nil then
			Lighting.Brightness = storedLightingBrightness
		end

		storedLightingBrightness = nil
		lightingOverrideActive = false
	end

	local function applyMapLighting(config: MapConfig)
		local brightnessOverride = config.lightningBrightness
		if typeof(brightnessOverride) == "number" then
			if not lightingOverrideActive then
				storedLightingBrightness = Lighting.Brightness
			end

			Lighting.Brightness = brightnessOverride
			lightingOverrideActive = true
		else
			restoreLighting()
		end
	end

	local function applySkybox(config: MapConfig)
		if not skyboxFolder then
			return
		end

		local skyboxName = config.skyboxName
		if config.id == "ChaosCanyon" then
			skyboxName = "ChaosCanyonSky"
		end

		local container = skyboxFolder:FindFirstChild(skyboxName)
		if not container then
			return
		end

		-- stash normal sky once
		if not storedNormalSky then
			local normalSky = Lighting:FindFirstChild("NormalSky")
			if normalSky then
				storedNormalSky = normalSky
				storedNormalSkyParent = normalSky.Parent
				normalSky.Parent = nil
			end
		end

		-- Remove previous injected sky
		if activeSkybox then
			activeSkybox:Destroy()
			activeSkybox = nil
		end

		-- If the container is a Folder, look for Sky/Atmosphere and extra Lighting values
		local skySource: Instance? = nil
		local atmosphereSource: Instance? = nil

		if container:IsA("Sky") then
			skySource = container
		else
			skySource = container:FindFirstChildOfClass("Sky")
			atmosphereSource = container:FindFirstChildOfClass("Atmosphere")
		end

		-- Clone Sky if present
		if skySource and skySource:IsA("Sky") then
			local skyClone = skySource:Clone()
			skyClone.Name = "ActiveSkybox"
			skyClone.Parent = Lighting
			activeSkybox = skyClone
		else
			restoreSkybox()
		end

		-- Replace Atmosphere if provided
		if atmosphereSource and atmosphereSource:IsA("Atmosphere") then
			-- remove any managed atmosphere first
			if managedAtmosphere and managedAtmosphere.Parent then
				managedAtmosphere:Destroy()
			end
			createdManagedAtmosphere = false
			managedAtmosphere = atmosphereSource:Clone()
			managedAtmosphere.Parent = Lighting
		end

		-- Apply Lighting property overrides from Values inside the folder
		local function applyValueChild(child: Instance)
			pcall(function()
				if child:IsA("NumberValue") then
					if Lighting[child.Name] ~= nil then
						Lighting[child.Name] = child.Value
					end
				elseif child:IsA("BoolValue") then
					if Lighting[child.Name] ~= nil then
						Lighting[child.Name] = child.Value
					end
				elseif child:IsA("StringValue") then
					if Lighting[child.Name] ~= nil then
						Lighting[child.Name] = child.Value
					end
				elseif child:IsA("Color3Value") then
					if Lighting[child.Name] ~= nil then
						Lighting[child.Name] = child.Value
					end
				end
			end)
		end

		if container:IsA("Folder") then
			for _, child in container:GetChildren() do
				applyValueChild(child)
			end
		end
	end

	local function clearParticipantConnections(record: ParticipantRecord)
		if record.characterConn then
			record.characterConn:Disconnect()
			record.characterConn = nil
		end

		if record.deathConn then
			record.deathConn:Disconnect()
			record.deathConn = nil
		end

		if record.healConn then
			record.healConn:Disconnect()
			record.healConn = nil
		end
	end

	local function setParticipantFrozen(record: ParticipantRecord, freeze: boolean)
		local player = record.player
		local character = player.Character
		if not character then
			return
		end

		local humanoid = record.humanoid or character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		record.humanoid = humanoid

		if freeze then
			if not record.originalWalkSpeed then
				record.originalWalkSpeed = humanoid.WalkSpeed
			end
			if not record.originalJumpPower then
				record.originalJumpPower = humanoid.JumpPower
			end
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.AutoRotate = false
		else
			if record.originalWalkSpeed then
				humanoid.WalkSpeed = record.originalWalkSpeed
				record.originalWalkSpeed = nil
			end
			if record.originalJumpPower then
				humanoid.JumpPower = record.originalJumpPower
				record.originalJumpPower = nil
			end
			humanoid.AutoRotate = true
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			rootPart.Anchored = freeze
			if not freeze then
				rootPart.AssemblyLinearVelocity = Vector3.zero
				rootPart.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end

	local function teleportParticipant(record: ParticipantRecord)
		local player = record.player
		local character = player.Character
		local spawnPart = record.spawnPart
		if not character or not spawnPart then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then
			return
		end

		local offset = spawnPart.CFrame.UpVector * (spawnPart.Size.Y / 2 + 3)
		character:PivotTo(spawnPart.CFrame + offset)
	end

	local function cleanupParticipant(player: Player)
		local record = participantRecords[player]
		if not record then
			return
		end

		record.freezeToken = (record.freezeToken or 0) + 1

		clearParticipantConnections(record)

		callSpecialEventCallback(activeSpecialEvent, "onParticipantCleanup", record)

		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				rootPart.Anchored = false
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				if record.originalWalkSpeed then
					humanoid.WalkSpeed = record.originalWalkSpeed
				end
				if record.originalJumpPower then
					humanoid.JumpPower = record.originalJumpPower
				end
				humanoid.AutoRotate = true
			end
		end

		participantRecords[player] = nil
	end

	local function findToolByName(root: Instance?, targetName: string): Tool?
		if not root then
			return nil
		end

		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("Tool") and descendant.Name == targetName then
				return descendant
			end
		end

		return nil
	end

	local function giveParticipantGear(record: ParticipantRecord)
		local player = record.player
		clearPVPTools(player)

		local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
		if not backpack then
			backpack = player:WaitForChild("Backpack", 5)
		end

		if not backpack then
			return
		end

		local specialContext = activeSpecialEvent
		if specialContext then
			callSpecialEventCallback(specialContext, "provideGear", record)
			if specialContext.definition.ignoreDefaultGear then
				return
			end
		end

		local classicSwordTemplate = findToolByName(gearsFolder, "ClassicSword")
		if not classicSwordTemplate then
			return
		end

		local starterGear = player:FindFirstChild("StarterGear")

		local backpackTool = classicSwordTemplate:Clone()
		backpackTool:SetAttribute("PVPGenerated", true)
		backpackTool.Parent = backpack

		if starterGear and starterGear:IsA("Folder") then
			local starterTool = classicSwordTemplate:Clone()
			starterTool:SetAttribute("PVPGenerated", true)
			starterTool.Parent = starterGear
		end
	end

	local function handleToggleInventorySlot(player: Player, tool: Tool?)
		if not tool or not tool:IsA("Tool") then
			return
		end

		if tool:GetAttribute("PVPGenerated") ~= true then
			return
		end

		local character = player.Character
		local backpack = player:FindFirstChildOfClass("Backpack")

		if tool.Parent ~= character and tool.Parent ~= backpack then
			return
		end

		if tool.Parent == character then
			if backpack then
				tool.Parent = backpack
			else
				tool.Parent = nil
			end
			return
		end

		if backpack and tool.Parent == backpack and character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:EquipTool(tool)
			end
		end
	end

	toggleInventorySlotRemote.OnServerEvent:Connect(handleToggleInventorySlot)

	local function disableParticipantHealing(record: ParticipantRecord)
		if not isPlayerInNeutralState(record.player) then
			return
		end

		local humanoid = record.humanoid
		if not humanoid then
			local character = record.player.Character
			if character then
				humanoid = character:FindFirstChildOfClass("Humanoid")
			end
		end

		if not humanoid then
			return
		end

		record.humanoid = humanoid

		if record.healConn then
			record.healConn:Disconnect()
			record.healConn = nil
		end

		local adjusting = false
		local lastHealth = humanoid.Health

		record.healConn = humanoid.HealthChanged:Connect(function(newHealth)
			if adjusting then
				lastHealth = newHealth
				return
			end

			if newHealth > lastHealth then
				adjusting = true
				humanoid.Health = math.min(lastHealth, humanoid.MaxHealth)
				adjusting = false
			else
				lastHealth = newHealth
			end
		end)
	end

	local function prepareParticipant(record: ParticipantRecord, spawnPart: BasePart, roundId: number)
		record.spawnPart = spawnPart

		local function onCharacter(character: Model)
			if roundId ~= currentRoundId or not roundInProgress then
				return
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart")

			if not humanoid then
				humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
			end

			if not rootPart then
				rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
			end

			if not humanoid or not rootPart then
				return
			end

			record.humanoid = humanoid
			record.eventData = record.eventData or {}
			callSpecialEventCallback(activeSpecialEvent, "onParticipantCharacter", record, character, humanoid)
			setParticipantFrozen(record, true)
			teleportParticipant(record)

			record.freezeToken = (record.freezeToken or 0) + 1
			local activeFreezeToken = record.freezeToken

			local function releaseTeleportFreeze()
				if roundId ~= currentRoundId or not roundInProgress then
					return
				end

				if record.freezeToken ~= activeFreezeToken then
					return
				end

				setParticipantFrozen(record, false)
			end

			if TELEPORT_FREEZE_DURATION > 0 then
				task.delay(TELEPORT_FREEZE_DURATION, releaseTeleportFreeze)
			else
				task.defer(releaseTeleportFreeze)
			end

			if record.deathConn then
				record.deathConn:Disconnect()
			end

			record.deathConn = humanoid.Died:Connect(function()
				handleElimination(record.player, roundId)
			end)

			assignPlayerToNeutralState(record.player)

			if record.countdownComplete then
				task.defer(function()
					if roundId ~= currentRoundId or not roundInProgress then
						return
					end

					setParticipantFrozen(record, false)
					giveParticipantGear(record)

					if deathMatchActive and isPlayerInNeutralState(record.player) then
						disableParticipantHealing(record)
					end
				end)
			end
		end

		if record.characterConn then
			record.characterConn:Disconnect()
		end

		record.characterConn = record.player.CharacterAdded:Connect(onCharacter)

		if record.player.Character then
			onCharacter(record.player.Character)
		else
			record.player:LoadCharacter()
		end
	end

	handleElimination = function(player: Player, roundId: number)
		local record = participantRecords[player]
		if not record or record.roundId ~= roundId then
			return
		end

		local prevented = callSpecialEventCallback(activeSpecialEvent, "onParticipantEliminating", record)
		if prevented then
			return
		end

		callSpecialEventCallback(activeSpecialEvent, "onParticipantEliminated", record)
		cleanupParticipant(player)
		clearPVPTools(player)
		player.Team = spectateTeam
		player.Neutral = false

		task.defer(function()
			checkRoundCompletion(roundId)
		end)
	end

	checkRoundCompletion = function(roundId: number)
		if roundId ~= currentRoundId or not roundInProgress then
			return
		end

		if activeSpecialEvent and activeSpecialEvent.state then
			local stateTable = activeSpecialEvent.state
			if (stateTable :: any).DisableCompletionCheck then
				return
			end
		end

		for player, record in participantRecords do
			if record.roundId == roundId and isPlayerInNeutralState(player) then
				local humanoid = record.humanoid
				if not humanoid then
					local character = player.Character
					if character then
						humanoid = character:FindFirstChildOfClass("Humanoid")
						record.humanoid = humanoid
					end
				end

				if humanoid and humanoid.Health > 0 then
					return
				end
			end
		end

		endRound(roundId)
	end

	endRound = function(roundId: number)
		if roundId ~= currentRoundId or not roundInProgress then
			return
		end

		callSpecialEventCallback(activeSpecialEvent, "onRoundEnded")
		clearActiveSpecialEvent()

		roundInProgress = false
		activeMapConfig = nil

		local wasDeathMatch = deathMatchActive

		clearStorm()
		restoreSkybox()
		restoreLighting()

		if activeMapModel then
			activeMapModel:Destroy()
			activeMapModel = nil
		end

		for player, record in participantRecords do
			cleanupParticipant(player)
			clearPVPTools(player)
			player.Team = spectateTeam
			player.Neutral = false

			task.defer(function()
				local currentCharacter = player.Character
				if currentCharacter then
					moveCharacterToLobby(currentCharacter)
				end
			end)
		end

		table.clear(participantRecords)

		if wasDeathMatch then
			sendStatusUpdate({
				action = "DeathMatch",
				active = false,
			})
		end

		sendStatusUpdate({action = "RoundEnded"})
		sendRoundState("Idle")
		playIntermissionMusic()
	end

	local function beginDeathMatch(roundId: number)
		if roundId ~= currentRoundId or not roundInProgress then
			return
		end

		deathMatchActive = true

		local config = activeMapConfig
		playDeathMatchMusic(config)

		sendStatusUpdate({
			action = "DeathMatch",
			active = true,
		})

		applyDeathMatchAtmosphere(config)

		local stormPart: BasePart
		local usedTemplate = false
		if stormUnionTemplate then
			stormPart = stormUnionTemplate:Clone()
			usedTemplate = true
		else
			stormPart = Instance.new("Part")
			stormPart.Name = "StormPart"
		end

		stormPart.Name = "StormPart"

		stormPart.CanCollide = false
		stormPart.CanTouch = false
		stormPart.CanQuery = false
		stormPart.Anchored = true
		stormPart.CastShadow = false

		if not usedTemplate then
			stormPart.Transparency = 0.5
			stormPart.Color = Color3.fromRGB(255, 0, 0)
			stormPart.Material = Enum.Material.Neon
			stormPart.Size = Vector3.new(600, 1000, 600)
		end

		if config and config.deathMatchStormColor then
			stormPart.Color = config.deathMatchStormColor
		end

		if config and config.deathMatchStormSize then
			local override = config.deathMatchStormSize
			local currentSize = stormPart.Size
			local overrideX = math.max(override.X, STORM_MIN_HORIZONTAL_SIZE)
			local overrideZ = math.max(override.Y, STORM_MIN_HORIZONTAL_SIZE)
			stormPart.Size = Vector3.new(overrideX, currentSize.Y, overrideZ)
		end

		local currentSize = stormPart.Size
		local adjustedSize = Vector3.new(
			math.max(currentSize.X, STORM_MIN_HORIZONTAL_SIZE),
			if currentSize.Y > 0 then currentSize.Y else 100,
			math.max(currentSize.Z, STORM_MIN_HORIZONTAL_SIZE)
		)

		if adjustedSize ~= currentSize then
			stormPart.Size = adjustedSize
		end

		stormPart:PivotTo(CFrame.new(0, 0, 0))
		stormPart.Parent = activeMapModel or Workspace
		currentStormPart = stormPart

		for _, record in pairs(participantRecords) do
			if record.roundId == roundId and isPlayerInNeutralState(record.player) then
				disableParticipantHealing(record)
			end
		end

		local shrinkDuration = 60
		if config and typeof(config.deathMatchShrinkDuration) == "number" then
			shrinkDuration = math.max(config.deathMatchShrinkDuration, 0)
		end

		if shrinkDuration > 0 then
			local shrinkTween = TweenService:Create(stormPart, TweenInfo.new(shrinkDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
				Size = Vector3.new(0, stormPart.Size.Y, 0),
			})
			shrinkTween:Play()
		else
			stormPart.Size = Vector3.new(0, stormPart.Size.Y, 0)
		end

		task.spawn(function()
			while deathMatchActive and roundInProgress and currentRoundId == roundId do
				task.wait(0.1)

				local activeStorm = currentStormPart
				if not activeStorm or not activeStorm.Parent then
					break
				end

				local halfSize = activeStorm.Size * 0.5
				local stormCFrame = activeStorm.CFrame

				if halfSize.X <= 0 or halfSize.Z <= 0 then
					continue
				end

				for player, record in participantRecords do
					if record.roundId ~= roundId or not isPlayerInNeutralState(player) then
						continue
					end

					local character = player.Character
					if not character then
						continue
					end

					local humanoid = record.humanoid or character:FindFirstChildOfClass("Humanoid")
					local rootPart = character:FindFirstChild("HumanoidRootPart")

					if not humanoid or humanoid.Health <= 0 or not rootPart then
						continue
					end

					record.humanoid = humanoid

					local relative = stormCFrame:PointToObjectSpace(rootPart.Position)
					local outsideX = math.abs(relative.X) > halfSize.X
					local outsideZ = math.abs(relative.Z) > halfSize.Z

					if outsideX or outsideZ then
						humanoid:TakeDamage(1)
					end
				end
			end
		end)
	end

	performDeathMatchTransition = function(roundId: number)
		if roundId ~= currentRoundId or not roundInProgress then
			return
		end

		cancelMusicLoopThread()

		sendStatusUpdate({
			action = "DeathMatchTransition",
			duration = DEATHMATCH_TRANSITION_DURATION,
		})

		local config = activeMapConfig
		tweenAtmosphereForDeathMatch(config)

		local tweens: {Tween} = {}

		local activeMusic = currentMusic
		if activeMusic then
			local tweenInfo = TweenInfo.new(DEATHMATCH_TRANSITION_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

			local speedTween = TweenService:Create(activeMusic, tweenInfo, {
				PlaybackSpeed = 0.5,
			})
			local volumeTween = TweenService:Create(activeMusic, tweenInfo, {
				Volume = 0,
			})

			speedTween:Play()
			volumeTween:Play()

			tweens = {speedTween, volumeTween}
		end

		local function cancelTransition(shouldRestoreMusic: boolean)
			for _, tween in pairs(tweens) do
				tween:Cancel()
			end

			if shouldRestoreMusic and activeMusic then
				activeMusic.PlaybackSpeed = 1
				activeMusic.Volume = DEFAULT_MUSIC_VOLUME
			end

			restoreAtmosphere()
		end

		local elapsed = 0
		while elapsed < DEATHMATCH_TRANSITION_DURATION do
			local waitTime = task.wait(0.1)
			if not waitTime then
				waitTime = 0.1
			end
			elapsed += waitTime

			if roundId ~= currentRoundId or not roundInProgress then
				cancelTransition(true)
				return
			end
		end

		for _, tween in pairs(tweens) do
			tween:Cancel()
		end

		if roundId ~= currentRoundId or not roundInProgress then
			cancelTransition(true)
			return
		end

		if activeMusic then
			activeMusic.PlaybackSpeed = 1
		end

		stopCurrentMusic()

		beginDeathMatch(roundId)
	end

	local function startRound(player: Player, mapId: string, requestedEventId: string?, requestedDifficulty: number?)
		if roundInProgress then
			sendRoundState("Error", {
				message = "A round is already running.",
			})
			return
		end

		local config = mapConfigurations[mapId]
		if not config then
			sendRoundState("Error", {
				message = "Unknown map selection.",
			})
			return
		end

		if not mapsFolder then
			mapsFolder = ReplicatedStorage:FindFirstChild("Maps")
		end

		if not mapsFolder then
			sendRoundState("Error", {
				message = "Maps folder is missing from ReplicatedStorage.",
			})
			return
		end

		local mapTemplate = mapsFolder:FindFirstChild(config.modelName)
		if not mapTemplate or not mapTemplate:IsA("Model") then
			sendRoundState("Error", {
				message = string.format("Map '%s' could not be found.", config.displayName),
			})
			return
		end

		local readyPlayers: {Player} = {}
		for _, targetPlayer in Players:GetPlayers() do
			if targetPlayer.Team == spectateTeam or targetPlayer.Team == survivalTeam then
				table.insert(readyPlayers, targetPlayer)
			end
		end

		if #readyPlayers == 0 then
			sendRoundState("Error", {
				message = "No players are waiting in the Spectate team.",
			})
			return
		end

		clearActiveSpecialEvent()

		local resolvedEventId: string? = config.forcedSpecialEventId
		local requestedEventRaw = if typeof(requestedEventId) == "string" then requestedEventId else nil
		local rolledRandomEvent = false

		if not resolvedEventId and requestedEventRaw and requestedEventRaw ~= "" then
			if string.upper(requestedEventRaw) == "RANDOM" then
				rolledRandomEvent = true
				resolvedEventId = getRandomSpecialEventId()
			else
				if specialEventDefinitions[requestedEventRaw] then
					resolvedEventId = requestedEventRaw
				else
					local searchKey = string.upper(requestedEventRaw)
					for candidateId in pairs(specialEventDefinitions) do
						if string.upper(candidateId) == searchKey then
							resolvedEventId = candidateId
							break
						end
					end
				end
			end
		end

		if rolledRandomEvent and not resolvedEventId then
			resolvedEventId = getRandomSpecialEventId()
		end

		if config.forcedSpecialEventId then
			resolvedEventId = config.forcedSpecialEventId
			rolledRandomEvent = false
		end

		roundInProgress = true
		currentRoundId += 1
		local roundId = currentRoundId

		table.clear(participantRecords)

		sendRoundState("Starting", {
			map = mapId,
		})
		local eventMusicId = if resolvedEventId then SPECIAL_EVENT_MUSIC_IDS[resolvedEventId] else nil
		if eventMusicId then
			playMusic(eventMusicId)
		else
			playMapMusic(config)
		end
		activeMapConfig = config

		local mapClone = mapTemplate:Clone()
		mapClone.Name = string.format("Active_%s", config.modelName)
		local originalAnchoredStates: {[BasePart]: boolean} = {}

		if mapClone:IsA("BasePart") then
			originalAnchoredStates[mapClone] = mapClone.Anchored
			mapClone.Anchored = true
		end

		for _, descendant in mapClone:GetDescendants() do
			if descendant:IsA("BasePart") then
				originalAnchoredStates[descendant] = descendant.Anchored
				descendant.Anchored = true
			end
		end

		mapClone.Parent = Workspace
		activeMapModel = mapClone

		local eventContext = setActiveSpecialEvent(resolvedEventId, roundId, requestedDifficulty)

		local randomRevealDuration = 3

		local function dispatchSpecialEventStatus(context: SpecialEventContext?, randomized: boolean)
			if context then
				sendStatusUpdate({
					action = "SpecialEvent",
					header = "- Special Round -",
					id = context.definition.id,
					name = context.definition.displayName,
					randomized = randomized,
				})
			else
				sendStatusUpdate({
					action = "SpecialEvent",
					active = false,
				})
			end
		end

		if rolledRandomEvent then
			local eventOptions = {}
			for _, definition in ipairs(specialEventList) do
				eventOptions[#eventOptions + 1] = {
					id = definition.id,
					name = definition.displayName,
				}
			end

			sendStatusUpdate({
				action = "SpecialEventRandomizing",
				header = "- Special Round -",
				options = eventOptions,
				chosenId = if eventContext then eventContext.definition.id else nil,
				chosenName = if eventContext then eventContext.definition.displayName else nil,
				duration = randomRevealDuration,
			})

			task.delay(randomRevealDuration, function()
				if not roundInProgress or currentRoundId ~= roundId then
					return
				end

				dispatchSpecialEventStatus(eventContext, true)
			end)
		else
			dispatchSpecialEventStatus(eventContext, false)
		end

		task.delay(MAP_ANCHOR_DURATION, function()
			for part, wasAnchored in originalAnchoredStates do
				if part.Parent then
					part.Anchored = wasAnchored
				end
			end
		end)

		applySkybox(config)
		applyMapLighting(config)

		local spawnContainer = mapClone:FindFirstChild(config.spawnContainer)
		if not spawnContainer or not spawnContainer:IsA("Model") then
			sendRoundState("Error", {
				message = string.format("Spawn container '%s' is missing.", config.spawnContainer),
			})
			endRound(roundId)
			return
		end

		local spawnParts: {BasePart} = {}
		for _, descendant in spawnContainer:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(spawnParts, descendant)
			end
		end

		if #spawnParts == 0 then
			sendRoundState("Error", {
				message = string.format("No spawn points were found for %s.", config.displayName),
			})
			endRound(roundId)
			return
		end

		local shuffledSpawnParts = table.clone(spawnParts)
		local rng = Random.new()
		for shuffleIndex = #shuffledSpawnParts, 2, -1 do
			local swapIndex = rng:NextInteger(1, shuffleIndex)
			shuffledSpawnParts[shuffleIndex], shuffledSpawnParts[swapIndex] = shuffledSpawnParts[swapIndex], shuffledSpawnParts[shuffleIndex]
		end

		local function nextSpawn(index: number): BasePart
			local spawnPart = shuffledSpawnParts[index]
			if spawnPart then
				return spawnPart
			end

			if #shuffledSpawnParts == 0 then
				return spawnParts[((index - 1) % #spawnParts) + 1]
			end

			return shuffledSpawnParts[((index - 1) % #shuffledSpawnParts) + 1]
		end

		for index, targetPlayer in ipairs(readyPlayers) do
			local record: ParticipantRecord = {
				player = targetPlayer,
				roundId = roundId,
				spawnPart = nil,
				characterConn = nil,
				deathConn = nil,
				healConn = nil,
				humanoid = nil,
				originalJumpPower = nil,
				originalWalkSpeed = nil,
				countdownComplete = false,
				freezeToken = 0,
				eventData = {},
			}

			participantRecords[targetPlayer] = record

			local spawnPart = nextSpawn(index)
			record.spawnPart = spawnPart
			prepareParticipant(record, spawnPart, roundId)
		end

		local countdownStart = math.max(0, PREP_COUNTDOWN_DURATION)

		sendStatusUpdate({
			action = "PrepCountdown",
			remaining = countdownStart,
			map = mapId,
		})

		for remaining = countdownStart - 1, 0, -1 do
			if not roundInProgress or currentRoundId ~= roundId then
				return
			end

			task.wait(1)
			if not roundInProgress or currentRoundId ~= roundId then
				return
			end

			sendStatusUpdate({
				action = "PrepCountdown",
				remaining = remaining,
				map = mapId,
			})
		end

		if not roundInProgress or currentRoundId ~= roundId then
			return
		end

		for playerKey, record in participantRecords do
			if record.roundId == roundId then
				record.countdownComplete = true
				setParticipantFrozen(record, false)
				giveParticipantGear(record)

				if deathMatchActive and isPlayerInNeutralState(record.player) then
					disableParticipantHealing(record)
				end
			end
		end

		if activeSpecialEvent then
			callSpecialEventCallback(activeSpecialEvent, "onRoundPrepared", config, mapClone)
		end

		callSpecialEventCallback(activeSpecialEvent, "onCountdownComplete")

		sendRoundState("Active", {
			map = mapId,
		})



		-- Fail-safe: ensure everyone is unfrozen and mobile devices regain control
		task.delay(0.1, function()
			for player, record in participantRecords do
				if record.roundId == roundId then
					setParticipantFrozen(record, false)
					local char = record.player.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local hrp = char and (char:FindFirstChild("HumanoidRootPart") or (hum and hum.RootPart))
					if hum then
						hum.AutoRotate = true
						if hum.WalkSpeed <= 0 then hum.WalkSpeed = 16 end
					end
					if hrp then hrp.Anchored = false end
				end
			end
		end)

		checkRoundCompletion(roundId)
		if not roundInProgress or currentRoundId ~= roundId then
			return
		end

		local skipRoundTimer = false
		if activeSpecialEvent and activeSpecialEvent.state then
			local stateTable = activeSpecialEvent.state
			local disableToken = (stateTable :: any).DisableRoundTimer
			if disableToken then
				skipRoundTimer = true
			end
			local hotTouchState = (stateTable :: any).HotTouch
			if hotTouchState and hotTouchState.disableRoundTimer then
				skipRoundTimer = true
			end
		end

		if skipRoundTimer then
			local disableCompletion = false
			if activeSpecialEvent and activeSpecialEvent.state then
				local stateTable = activeSpecialEvent.state
				if (stateTable :: any).DisableCompletionCheck then
					disableCompletion = true
				end
			end

			if disableCompletion then
				return
			end

			while roundInProgress and currentRoundId == roundId do
				task.wait(1)
				if not roundInProgress or currentRoundId ~= roundId then
					break
				end
				checkRoundCompletion(roundId)
			end
			return
		end

		for remaining = 120, 0, -1 do
			if not roundInProgress or currentRoundId ~= roundId then
				return
			end

			sendStatusUpdate({
				action = "MatchTimer",
				remaining = remaining,
			})

			if remaining == 0 then
				break
			end

			task.wait(1)

			if not roundInProgress or currentRoundId ~= roundId then
				return
			end

			checkRoundCompletion(roundId)
			if not roundInProgress or currentRoundId ~= roundId then
				return
			end
		end

		if not roundInProgress or currentRoundId ~= roundId then
			return
		end

		performDeathMatchTransition(roundId)
	end

	local lobbyParts: {BasePart} = {}
	local lobbyConnections: {RBXScriptConnection} = {}
	local currentLobbyModel: Model? = nil

	local function clearLobbyConnections()
		for _, connection in pairs(lobbyConnections) do
			connection:Disconnect()
		end
		table.clear(lobbyConnections)
	end

	-- Certain lobby models include kill bricks or other hazards alongside decorative
	-- geometry. Filtering by keyword helps avoid teleporting players onto those parts.
	local HAZARD_KEYWORDS = {
		kill = true,
		lava = true,
		damage = true,
		acid = true,
	}

	local function isPreferredLobbySpawnPart(part: BasePart): boolean
		if part:GetAttribute("LobbySpawnPoint") then
			return true
		end

		if part:IsA("SpawnLocation") then
			return true
		end

		local lowerName = string.lower(part.Name)
		return string.find(lowerName, "spawn") ~= nil
	end

	local function isValidLobbySpawnPart(part: BasePart, preferred: boolean): boolean
		if not part.CanCollide then
			return false
		end

		if part.Size.Magnitude <= 0 then
			return false
		end

		if part:GetAttribute("LobbySpawnExcluded") then
			return false
		end

		if not preferred and part.Transparency >= 1 then
			return false
		end

		local lowerName = string.lower(part.Name)
		for keyword in pairs(HAZARD_KEYWORDS) do
			if string.find(lowerName, keyword, 1, true) then
				return false
			end
		end

		return true
	end

	local function refreshLobbyParts()
		table.clear(lobbyParts)
		if not currentLobbyModel then
			return
		end

		local preferredParts: {BasePart} = {}
		local fallbackParts: {BasePart} = {}

		local function registerPart(instance: Instance)
			if not instance:IsA("BasePart") then
				return
			end

			local part = instance :: BasePart
			local isPreferred = isPreferredLobbySpawnPart(part)
			if not isValidLobbySpawnPart(part, isPreferred) then
				return
			end

			if isPreferred then
				table.insert(preferredParts, part)
			else
				table.insert(fallbackParts, part)
			end
		end

		if currentLobbyModel:IsA("BasePart") then
			registerPart(currentLobbyModel)
		end

		for _, descendant in currentLobbyModel:GetDescendants() do
			registerPart(descendant)
		end

		local source = if #preferredParts > 0 then preferredParts else fallbackParts
		for _, part in ipairs(source) do
			table.insert(lobbyParts, part)
		end
	end

	local function setLobbyModel(model: Model?)
		currentLobbyModel = model
		clearLobbyConnections()
		refreshLobbyParts()

		if not model then
			return
		end

		lobbyConnections[#lobbyConnections + 1] = model.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				refreshLobbyParts()
			end
		end)

		lobbyConnections[#lobbyConnections + 1] = model.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				refreshLobbyParts()
			end
		end)
	end

	setLobbyModel(Workspace:FindFirstChild("LobbySpawn") :: Model?)

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "LobbySpawn" and child:IsA("Model") then
			setLobbyModel(child)
		end
	end)

	Workspace.ChildRemoved:Connect(function(child)
		if child == currentLobbyModel then
			setLobbyModel(nil)
		end
	end)

	local function moveCharacterToLobby(character: Model)
		if #lobbyParts == 0 then
			refreshLobbyParts()
		end

		if #lobbyParts == 0 then
			return
		end

		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if not humanoidRootPart then
			return
		end

		local targetPart = lobbyParts[math.random(1, #lobbyParts)]
		local offset = targetPart.CFrame.UpVector * (targetPart.Size.Y / 2 + 3)
		character:PivotTo(targetPart.CFrame + offset)
	end

	local function onCharacterAdded(player: Player, character: Model)
		task.defer(function()
			ensureRigIsR6(player, character)
		end)

		if player.Team == spectateTeam then
			moveCharacterToLobby(character)
		end
	end

	local function onPlayerAdded(player: Player)
		player.Team = spectateTeam
		player.Neutral = false

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)

			-- Wait for character to fully load
			task.wait(0.5)

			sendStatusUpdate({
				action = "SpecialEventEffect",
				id = "SprintProhibit",
				sprintDisabled = false,
			})
			sendStatusUpdate({
				action = "SpecialEventEffect",
				id = "Invisible",
				invisible = false,
			})

			-- Force reset movement for this specific player
			roundStateRemote:FireClient(player, {
				action = "ResetMovement",
				playerId = player.UserId,
			})
		end)

		player.CharacterAppearanceLoaded:Connect(function(character)
			ensureRigIsR6(player, character)
		end)

		if player.Character then
			onCharacterAdded(player, player.Character)
		end

		if roundInProgress then
			roundStateRemote:FireClient(player, {
				state = "Active",
			})
		else
			roundStateRemote:FireClient(player, {
				state = "Idle",
			})
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local record = participantRecords[player]
		if record then
			cleanupParticipant(player)
			participantRecords[player] = nil
			if roundInProgress then
				task.defer(function()
					checkRoundCompletion(record.roundId)
				end)
			end
		end

		clearPVPTools(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	startRoundRemote.OnServerEvent:Connect(function(player, payload)
		if not isGameOwner(player) then
			return
		end

		local mapId: string? = nil
		local eventId: string? = nil
		local difficultyOverride: number? = nil

		if typeof(payload) == "table" then
			mapId = payload.mapId or payload.modelName or payload.id
			local eventValue = payload.eventId or payload.event
			if typeof(eventValue) == "string" then
				eventId = eventValue
			end

			local difficultyValue = payload.difficulty or payload.difficultyOverride
			local numericDifficulty = tonumber(difficultyValue)
			if numericDifficulty then
				local floored = math.floor(numericDifficulty)
				if floored >= 1 then
					difficultyOverride = floored
				end
			end
		elseif typeof(payload) == "string" then
			mapId = payload
		end

		if typeof(mapId) ~= "string" then
			sendRoundState("Error", {
				message = "Select a map before starting the round.",
			})
			return
		end

		startRound(player, mapId, eventId, difficultyOverride)
	end)
end
