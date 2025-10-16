--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamsService = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
local neutralTeam = getOrCreateTeam("Neutral", Color3.fromRGB(255, 255, 255), false)

spectateTeam.AutoAssignable = true
neutralTeam.AutoAssignable = false

local allowedUserIds = {
    [347735445] = true,
}

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

type MapConfig = {
    id: string,
    displayName: string,
    modelName: string,
    spawnContainer: string,
    skyboxName: string,
}

local mapConfigurations: {[string]: MapConfig} = {
    Crossroad = {
        id = "Crossroad",
        displayName = "Crossroad",
        modelName = "Crossroad",
        spawnContainer = "CrossroadSpawns",
        skyboxName = "CrossroadSky",
    },
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

local mapsFolder = ReplicatedStorage:FindFirstChild("Maps")
local skyboxFolder = ReplicatedStorage:FindFirstChild("Skybox")
local gearsFolder = ReplicatedStorage:FindFirstChild("PVPGears")
local stormTemplate = ReplicatedStorage:FindFirstChild("StormPart") :: BasePart?

ReplicatedStorage.ChildAdded:Connect(function(child)
    if child.Name == "Maps" and child:IsA("Folder") then
        mapsFolder = child
    elseif child.Name == "Skybox" and child:IsA("Folder") then
        skyboxFolder = child
    elseif child.Name == "PVPGears" and child:IsA("Folder") then
        gearsFolder = child
    elseif child.Name == "StormPart" and child:IsA("BasePart") then
        stormTemplate = child
    end
end)

ReplicatedStorage.ChildRemoved:Connect(function(child)
    if child == mapsFolder then
        mapsFolder = nil
    elseif child == skyboxFolder then
        skyboxFolder = nil
    elseif child == gearsFolder then
        gearsFolder = nil
    elseif child == stormTemplate then
        stormTemplate = nil
    end
end)

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
}

local participantRecords: {[Player]: ParticipantRecord} = {}
local roundInProgress = false
local currentRoundId = 0
local activeMapModel: Model? = nil
local activeSkybox: Instance? = nil
local storedNormalSky: Instance? = nil
local storedNormalSkyParent: Instance? = nil
local currentStormPart: BasePart? = nil
local deathMatchActive = false

local function endRound(roundId: number)
end

local function checkRoundCompletion(roundId: number)
end

local function handleElimination(player: Player, roundId: number)
end

local function sendRoundState(state: string, extra: {}?)
    local payload = if type(extra) == "table" then table.clone(extra :: {}) else {}
    payload.state = state
    roundStateRemote:FireAllClients(payload)
end

local function sendStatusUpdate(data: {})
    statusUpdateRemote:FireAllClients(data)
end

local function clearStorm()
    if currentStormPart then
        currentStormPart:Destroy()
        currentStormPart = nil
    end
    deathMatchActive = false
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

    local targetSky = skyboxFolder:FindFirstChild(config.skyboxName)
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
    skyClone.Name = string.format("%s_Active", config.skyboxName)
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
        end
        if record.originalJumpPower then
            humanoid.JumpPower = record.originalJumpPower
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

    clearParticipantConnections(record)

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

local function giveParticipantGear(record: ParticipantRecord)
    if not gearsFolder then
        return
    end

    local player = record.player
    clearPVPTools(player)

    local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
    if not backpack then
        backpack = player:WaitForChild("Backpack", 5)
    end

    if not backpack then
        return
    end

    for _, item in gearsFolder:GetChildren() do
        if item:IsA("Tool") then
            local backpackTool = item:Clone()
            backpackTool:SetAttribute("PVPGenerated", true)
            backpackTool.Parent = backpack

            local starterTool = item:Clone()
            starterTool:SetAttribute("PVPGenerated", true)
            starterTool.Parent = player.StarterGear
        end
    end
end

local function disableParticipantHealing(record: ParticipantRecord)
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
        setParticipantFrozen(record, true)
        teleportParticipant(record)

        if record.deathConn then
            record.deathConn:Disconnect()
        end

        record.deathConn = humanoid.Died:Connect(function()
            handleElimination(record.player, roundId)
        end)

        record.player.Team = neutralTeam
        record.player.Neutral = false

        if record.countdownComplete then
            task.defer(function()
                if roundId ~= currentRoundId or not roundInProgress then
                    return
                end

                setParticipantFrozen(record, false)
                giveParticipantGear(record)

                if deathMatchActive then
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
        if record.roundId == roundId and player.Team == neutralTeam then
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

    roundInProgress = false

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
end

local function beginDeathMatch(roundId: number)
    if roundId ~= currentRoundId or not roundInProgress then
        return
    end

    deathMatchActive = true

    sendStatusUpdate({
        action = "DeathMatch",
        active = true,
    })

    local stormPart: BasePart
    if stormTemplate and stormTemplate:IsA("BasePart") then
        stormPart = stormTemplate:Clone()
    else
        stormPart = Instance.new("Part")
        stormPart.Material = Enum.Material.Neon
        stormPart.Color = Color3.fromRGB(255, 45, 45)
        stormPart.Name = "StormPart"
    end

    stormPart.CanCollide = false
    stormPart.CanTouch = false
    stormPart.Anchored = true
    stormPart.CastShadow = false
    stormPart.Transparency = 0.5
    stormPart.Size = Vector3.new(600, 1000, 600)

    local mapPivot = if activeMapModel then activeMapModel:GetPivot().Position else Vector3.zero
    stormPart.CFrame = CFrame.new(mapPivot.X, mapPivot.Y + stormPart.Size.Y / 2, mapPivot.Z)

    stormPart.Parent = activeMapModel or Workspace
    currentStormPart = stormPart

    for _, record in participantRecords do
        if record.roundId == roundId then
            disableParticipantHealing(record)
        end
    end

    local shrinkTween = TweenService:Create(stormPart, TweenInfo.new(60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
        Size = Vector3.new(0, stormPart.Size.Y, 0),
    })
    shrinkTween:Play()

    task.spawn(function()
        while deathMatchActive and roundInProgress and currentRoundId == roundId do
            task.wait(0.2)

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
                if record.roundId ~= roundId or player.Team ~= neutralTeam then
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
                if math.abs(relative.X) > halfSize.X or math.abs(relative.Z) > halfSize.Z then
                    humanoid:TakeDamage(1)
                end
            end
        end
    end)
end

local function startRound(player: Player, mapId: string)
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

    roundInProgress = true
    currentRoundId += 1
    local roundId = currentRoundId

    table.clear(participantRecords)

    sendRoundState("Starting", {
        map = mapId,
    })

    local mapClone = mapTemplate:Clone()
    mapClone.Name = string.format("Active_%s", config.modelName)
    mapClone.Parent = Workspace
    activeMapModel = mapClone

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

    local spawnQueue = table.clone(spawnParts)

    local function nextSpawn(index: number): BasePart
        if #spawnQueue == 0 then
            spawnQueue = table.clone(spawnParts)
        end

        if #spawnQueue == 0 then
            return spawnParts[((index - 1) % #spawnParts) + 1]
        end

        local selectionIndex = ((index - 1) % #spawnQueue) + 1
        return table.remove(spawnQueue, selectionIndex)
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
        }

        participantRecords[targetPlayer] = record

        local spawnPart = nextSpawn(index)
        record.spawnPart = spawnPart
        prepareParticipant(record, spawnPart, roundId)
    end

    sendStatusUpdate({
        action = "PrepCountdown",
        remaining = 10,
        map = mapId,
    })

    for remaining = 9, 0, -1 do
        if not roundInProgress or currentRoundId ~= roundId then
            return
        end

        task.wait(1)
        sendStatusUpdate({
            action = "PrepCountdown",
            remaining = remaining,
            map = mapId,
        })
    end

    for playerKey, record in participantRecords do
        if record.roundId == roundId then
            setParticipantFrozen(record, false)
            giveParticipantGear(record)
            record.countdownComplete = true
        end
    end

    sendRoundState("Active", {
        map = mapId,
    })

    checkRoundCompletion(roundId)
    if not roundInProgress or currentRoundId ~= roundId then
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

    beginDeathMatch(roundId)
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

    if typeof(payload) == "table" then
        mapId = payload.mapId or payload.modelName or payload.id
    elseif typeof(payload) == "string" then
        mapId = payload
    end

    if typeof(mapId) ~= "string" then
        sendRoundState("Error", {
            message = "Select a map before starting the round.",
        })
        return
    end

    startRound(player, mapId)
end)
