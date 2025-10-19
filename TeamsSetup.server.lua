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

local KillBotEvent = require(script.Parent:WaitForChild("KillBotEvent"))

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

do
	local existingNeutralTeam = TeamsService:FindFirstChild("Neutral")
	if existingNeutralTeam and existingNeutralTeam:IsA("Team") then
		existingNeutralTeam:Destroy()
	end
end

local function assignPlayerToNeutralState(player: Player)
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
	HotTouch = "101070309888602",
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

	if not humanoid or humanoid.RigType == Enum.HumanoidRigType.R6 then
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
end

type MapConfig = {
	id: string,
	displayName: string,
	modelName: string,
	spawnContainer: string,
	skyboxName: string,
	musicId: string?,
	deathMatchMusicId: string?,
	deathMatchMusicStartTime: number?,
	deathMatchStormSize: Vector2?,
	deathMatchShrinkDuration: number?,
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
		return
	end

	local definition = context.definition
	local callback = (definition :: any)[methodName]
	if typeof(callback) == "function" then
		local ok, err = pcall(callback, context, ...)
		if not ok then
			warn(string.format("Special event '%s' %s error: %s", definition.id, methodName, err))
		end
	end
end

local function setActiveSpecialEvent(eventId: string?, roundId: number): SpecialEventContext?
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

	local context: SpecialEventContext = {
		definition = definition,
		roundId = roundId,
		state = {},
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

local function forEachActiveParticipant(callback: (Player, ParticipantRecord) -> ())
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
		displayName = "Shattered Heart??",
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
		displayName = "Sprint Prohibit????",
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
		displayName = "RETRO??",
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
		displayName = "Invisible??",
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
		displayName = "Bunny??",
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
		displayName = "Slippery??",
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
		displayName = "Raining Bomb??",
		onCountdownComplete = function(context)
			local state = context.state
			if state.RainingBomb and state.RainingBomb.active then
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

			local function createExplosion(bomb: BasePart)
				local explosion = Instance.new("Explosion")
				explosion.BlastRadius = 12
				explosion.BlastPressure = 500000
				explosion.Position = bomb.Position
				explosion.Parent = Workspace
				removeBomb(bomb)
			end

			state.RainingBomb = {
				active = true,
				bombs = activeBombs,
				stop = function()
					running = false
					for part in pairs(activeBombs) do
						removeBomb(part)
					end
				end,
			}

			local stormSize = getStormHorizontalSize()
			local cf, _ = getActiveMapBounds()
			local origin = cf.Position

			task.spawn(function()
				local rng = Random.new()
				while running and roundInProgress and context.roundId == currentRoundId do
					local offsetX = rng:NextNumber(-stormSize.X / 2, stormSize.X / 2)
					local offsetZ = rng:NextNumber(-stormSize.Y / 2, stormSize.Y / 2)
					local spawnPosition = Vector3.new(origin.X + offsetX, origin.Y + 120, origin.Z + offsetZ)

					local bomb = Instance.new("Part")
					bomb.Shape = Enum.PartType.Ball
					bomb.Name = "EventBomb"
					bomb.Size = Vector3.new(2.5, 2.5, 2.5)
					bomb.Material = Enum.Material.SmoothPlastic
					bomb.Color = Color3.fromRGB(0, 0, 0)
					bomb.Transparency = 0
					bomb.CanCollide = true
					bomb.CanQuery = true
					bomb.CanTouch = true
					bomb.Anchored = false
					bomb.Position = spawnPosition
					bomb.Parent = Workspace
					bomb:SetNetworkOwner(nil)

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

						countdownStarted = true
						bomb.Anchored = false
						bomb.AssemblyLinearVelocity *= 0.5
						bomb.AssemblyAngularVelocity *= 0.5

						local totalDuration = 3
						local startTime = os.clock()
						local flashStyles = {
							{color = Color3.fromRGB(0, 0, 0), material = Enum.Material.SmoothPlastic},
							{color = Color3.fromRGB(255, 0, 0), material = Enum.Material.Neon},
						}

						task.spawn(function()
							local flashIndex = 1
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
								local interval = math.clamp(0.55 - progress * 0.4, 0.08, 0.55)
								task.wait(interval)
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
						startCountdown()
					end)

					Debris:AddItem(bomb, 15)
					task.wait(0.5)
				end
			end)
		end,
		onRoundEnded = function(context)
			local state = context.state.RainingBomb
			if state then
				if state.stop then
					state.stop()
				end
				if state.bombs then
					for part in pairs(state.bombs) do
						if part and part.Parent then
							part:Destroy()
						end
					end
				end
			end
			context.state.RainingBomb = nil
		end,
	})

	registerSpecialEvent({
		id = "InvertedControl",
		displayName = "Inverted Control??",
		onRoundPrepared = function()
			sendStatusUpdate({
				action = "SpecialEventEffect",
				id = "InvertedControl",
				inverted = true,
			})
		end,
		onRoundEnded = function()
			sendStatusUpdate({
				action = "SpecialEventEffect",
				id = "InvertedControl",
				inverted = false,
			})
		end,
	})

	registerSpecialEvent(KillBotEvent.create({
		getNeutralParticipantRecords = getNeutralParticipantRecords,
		getActiveMapBounds = getActiveMapBounds,
		RunService = RunService,
		Workspace = Workspace,
		Debris = Debris,
		isRoundActive = function(roundId: number)
			return roundInProgress and roundId == currentRoundId
		end,
	}))

	registerSpecialEvent({
		id = "HotTouch",
		displayName = "Hot Touch??",
		ignoreDefaultGear = true,
		onCountdownComplete = function(context)
			local state = context.state
			if state.HotTouch then
				return
			end

			local hotState = {
				holder = nil :: ParticipantRecord?,
				timer = 30,
				running = true,
				connections = {},
				disableRoundTimer = true,
			}
			state.HotTouch = hotState

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
			end

			sendStatusUpdate({
				action = "MatchMessage",
				text = "Survive",
			})

			local function clearConnections()
				for _, conn in hotState.connections do
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
						humanoid:SetAttribute("SprintSpeedBonus", bonusValue + 2)
					else
						local storedBonus = record.eventData.HotTouchSprintBonus
						local baseValue = if typeof(storedBonus) == "number" then storedBonus else 0
						humanoid:SetAttribute("SprintSpeedBonus", baseValue + 2)
					end

					local baseline = record.eventData.HotTouchOriginalWalk or humanoid.WalkSpeed
					humanoid.WalkSpeed = baseline + 2
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

				local billboard = character:FindFirstChild("HotTouchBillboard")
				if billboard and billboard:IsA("BillboardGui") then
					local label = billboard:FindFirstChild("Label")
					if label and label:IsA("TextLabel") then
						label.Text = tostring(math.max(0, math.floor(hotState.timer)))
						local ratio = math.clamp(hotState.timer / 60, 0, 1)
						local color = Color3.fromRGB(255, 255 * ratio, 255 * ratio)
						label.TextColor3 = color
					end
				end
			end

			local function detachHolder(record: ParticipantRecord?)
				if record then
					updateHolderVisual(record, false)
				end
				clearConnections()
			end

			local function attachHolderConnections(record: ParticipantRecord)
				clearConnections()
				local character = record.player.Character
				if not character then
					return
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
							if not targetRecord or not isPlayerInNeutralState(targetRecord.player) then
								return
							end

							hotState.timer = math.min(hotState.timer + 5, 60)
							setParticipantFrozen(targetRecord, true)
							task.delay(2, function()
								if context.roundId == currentRoundId and roundInProgress then
									setParticipantFrozen(targetRecord, false)
								end
							end)

							setHolder(targetRecord, false)
						end)
					end
				end
			end

			local function setHolder(newRecord: ParticipantRecord?, resetTimer: boolean)
				if newRecord == hotState.holder then
					if newRecord then
						if resetTimer then
							hotState.timer = 30
						end
						updateHolderVisual(newRecord, true)
						updateTimerVisual()
						attachHolderConnections(newRecord)
						broadcastHolder(newRecord)
					else
						broadcastSelecting()
					end
					return
				end

				detachHolder(hotState.holder)
				hotState.holder = newRecord
				if newRecord then
					if resetTimer then
						hotState.timer = 30
					end
					updateHolderVisual(newRecord, true)
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
				for _, record in ipairs(getNeutralParticipantRecords()) do
					local humanoid = record.humanoid
					if not humanoid or humanoid.Health <= 0 then
						continue
					end
					table.insert(candidates, record)
				end

				if #candidates <= 1 then
					local winner = if #candidates == 1 then candidates[1] else nil
					setHolder(nil, false)
					hotState.running = false
					broadcastCompletion(winner)
					return
				end

				local rng = Random.new()
				local chosen = candidates[rng:NextInteger(1, #candidates)]
				setHolder(chosen, true)
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
							local rootPart = holder.humanoid.RootPart or (holder.player.Character and holder.player.Character:FindFirstChild("HumanoidRootPart"))
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

local function playIntermissionMusic()
	playMusic(INTERMISSION_MUSIC_ID)
end

local function playMapMusic(config: MapConfig)
	if config.musicId then
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

local function tweenAtmosphereForDeathMatch()
	local atmosphere = ensureManagedAtmosphere()
	if not atmosphere then
		return
	end

	cancelAtmosphereTween()

	local tweenInfo = TweenInfo.new(DEATHMATCH_TRANSITION_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local goal = {
		Density = 0.5,
		Offset = 1,
		Color = Color3.fromRGB(255, 0, 0),
		Decay = Color3.fromRGB(255, 0, 0),
		Glare = 0.5,
		Haze = 5,
	}

	activeAtmosphereTween = TweenService:Create(atmosphere, tweenInfo, goal)
	local thisTween = activeAtmosphereTween
	thisTween:Play()

	task.delay(DEATHMATCH_TRANSITION_DURATION, function()
		if activeAtmosphereTween == thisTween then
			activeAtmosphereTween = nil
		end
	end)
end

local function applyDeathMatchAtmosphere()
	local atmosphere = ensureManagedAtmosphere()
	if not atmosphere then
		return
	end

	cancelAtmosphereTween()

	atmosphere.Density = 0.5
	atmosphere.Offset = 1
	atmosphere.Color = Color3.fromRGB(255, 0, 0)
	atmosphere.Decay = Color3.fromRGB(255, 0, 0)
	atmosphere.Glare = 0.5
	atmosphere.Haze = 5
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

local function applySkybox(config: MapConfig)
	if not skyboxFolder then
		return
	end

	local skyboxName = config.skyboxName
	if config.id == "ChaosCanyon" then
		skyboxName = "ChaosCanyonSky"
	end

	local targetSky = skyboxFolder:FindFirstChild(skyboxName)
	if not targetSky then
		return
	end

	if not storedNormalSky then
		local normalSky = Lighting:FindFirstChild("NormalSky")
		if normalSky then
			storedNormalSky = normalSky
			storedNormalSkyParent = normalSky.Parent
			normalSky.Parent = nil
		end
	end

	if activeSkybox then
		activeSkybox:Destroy()
	end

	local skyClone = targetSky:Clone()
	skyClone.Name = string.format("%s_Active", skyboxName)
	skyClone.Parent = Lighting
	activeSkybox = skyClone
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

	applyDeathMatchAtmosphere()

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

	for _, record in participantRecords do
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

	sendStatusUpdate({
		action = "DeathMatchTransition",
		duration = DEATHMATCH_TRANSITION_DURATION,
	})

	tweenAtmosphereForDeathMatch()

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
		for _, tween in tweens do
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

	for _, tween in tweens do
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

local function startRound(player: Player, mapId: string, requestedEventId: string?)
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
		if targetPlayer.Team == spectateTeam then
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

	local resolvedEventId: string? = nil
	local requestedEventRaw = if typeof(requestedEventId) == "string" then requestedEventId else nil
	local rolledRandomEvent = false

	if requestedEventRaw and requestedEventRaw ~= "" then
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

	local eventContext = setActiveSpecialEvent(resolvedEventId, roundId)

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

	checkRoundCompletion(roundId)
	if not roundInProgress or currentRoundId ~= roundId then
		return
	end

	local skipRoundTimer = false
	if activeSpecialEvent and activeSpecialEvent.state then
		local stateTable = activeSpecialEvent.state
		local hotTouchState = (stateTable :: any).HotTouch
		if hotTouchState and hotTouchState.disableRoundTimer then
			skipRoundTimer = true
		end
	end

	if skipRoundTimer then
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
	for _, connection in lobbyConnections do
		connection:Disconnect()
	end
	table.clear(lobbyConnections)
end

local function refreshLobbyParts()
	table.clear(lobbyParts)
	if not currentLobbyModel then
		return
	end

	for _, child in currentLobbyModel:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Part" then
			table.insert(lobbyParts, child)
		end
	end
end

local function setLobbyModel(model: Model?)
	currentLobbyModel = model
	clearLobbyConnections()
	refreshLobbyParts()

	if not model then
		return
	end

	lobbyConnections[#lobbyConnections + 1] = model.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") and child.Name == "Part" then
			table.insert(lobbyParts, child)
		end
	end)

	lobbyConnections[#lobbyConnections + 1] = model.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") and child.Name == "Part" then
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

	if typeof(payload) == "table" then
		mapId = payload.mapId or payload.modelName or payload.id
		local eventValue = payload.eventId or payload.event
		if typeof(eventValue) == "string" then
			eventId = eventValue
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

	startRound(player, mapId, eventId)
end)
