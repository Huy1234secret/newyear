--!strict

local Players = game:GetService("Players")
local TeamsService = game:GetService("Teams")
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
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
    onPlayerAdded(player)
end
