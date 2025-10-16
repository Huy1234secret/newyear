--!strict
-- Place this LocalScript in StarterPlayerScripts so each player can see match updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
if not localPlayer then
    return
end

local remotesFolder = ReplicatedStorage:WaitForChild("PVPRemotes", 10)
if not remotesFolder or not remotesFolder:IsA("Folder") then
    return
end

local statusRemote = remotesFolder:WaitForChild("StatusUpdate", 10)
if not statusRemote or not statusRemote:IsA("RemoteEvent") then
    return
end

local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PVPStatusGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local statusFrame = Instance.new("Frame")
statusFrame.Name = "StatusFrame"
statusFrame.Size = UDim2.fromOffset(260, 56)
statusFrame.Position = UDim2.new(0.5, 0, 0, 32)
statusFrame.AnchorPoint = Vector2.new(0.5, 0)
statusFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
statusFrame.BackgroundTransparency = 0.15
statusFrame.Visible = false
statusFrame.ZIndex = 10
statusFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = statusFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
frameStroke.Thickness = 2
frameStroke.Color = Color3.fromRGB(120, 135, 200)
frameStroke.Transparency = 0.35
frameStroke.Parent = statusFrame

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.Parent = statusFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = ""
statusLabel.TextSize = 26
statusLabel.TextColor3 = Color3.fromRGB(245, 245, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.TextYAlignment = Enum.TextYAlignment.Center
statusLabel.ZIndex = 11
statusLabel.Parent = statusFrame

local labelStroke = Instance.new("UIStroke")
labelStroke.Color = Color3.fromRGB(20, 20, 35)
labelStroke.Thickness = 2
labelStroke.Transparency = 0.3
labelStroke.Parent = statusLabel

local defaultColor = statusLabel.TextColor3
local countdownColor = Color3.fromRGB(245, 245, 255)
local matchColor = Color3.fromRGB(210, 235, 255)
local deathMatchBackground = Color3.fromRGB(60, 10, 10)
local deathMatchStroke = Color3.fromRGB(255, 90, 90)
local neutralOutlineColor = Color3.fromRGB(255, 70, 70)
local spectateOutlineColor = Color3.fromRGB(255, 255, 255)

local baseFramePosition = statusFrame.Position
local currentRemaining = 0
local flashConnection: RBXScriptConnection? = nil
local shakeConnection: RBXScriptConnection? = nil

local transitionState = {
    active = false,
    token = 0,
}

type HighlightConnections = {RBXScriptConnection}

local highlightState = {
    active = false,
    color = nil :: Color3?,
    highlights = {} :: {[Player]: Highlight},
    playerConnections = {} :: {[Player]: HighlightConnections},
    playerAddedConn = nil :: RBXScriptConnection?,
    playerRemovingConn = nil :: RBXScriptConnection?,
}

local function removeHighlightForPlayer(targetPlayer: Player)
    local highlight = highlightState.highlights[targetPlayer]
    if highlight then
        highlight:Destroy()
        highlightState.highlights[targetPlayer] = nil
    end
end

local function clearConnectionsForPlayer(targetPlayer: Player)
    local connections = highlightState.playerConnections[targetPlayer]
    if connections then
        for _, connection in connections do
            connection:Disconnect()
        end
        highlightState.playerConnections[targetPlayer] = nil
    end
end

local function getOutlineColorForLocalPlayer(): Color3?
    local team = localPlayer.Team
    if not team then
        return nil
    end

    local teamName = team.Name
    if teamName == "Neutral" then
        return neutralOutlineColor
    elseif teamName == "Spectate" then
        return spectateOutlineColor
    end

    return nil
end

local function updateHighlightForPlayer(targetPlayer: Player)
    if targetPlayer == localPlayer then
        removeHighlightForPlayer(targetPlayer)
        return
    end

    local highlight = highlightState.highlights[targetPlayer]
    local shouldShow = highlightState.active
        and highlightState.color ~= nil
        and targetPlayer.Team ~= nil
        and targetPlayer.Team.Name == "Neutral"

    if not shouldShow then
        if highlight then
            highlight:Destroy()
            highlightState.highlights[targetPlayer] = nil
        end
        return
    end

    local character = targetPlayer.Character
    if not character then
        if highlight then
            highlight.Parent = nil
        end
        return
    end

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "DeathMatchTransitionOutline"
        highlight.FillTransparency = 1
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlightState.highlights[targetPlayer] = highlight
    end

    highlight.OutlineColor = highlightState.color or neutralOutlineColor
    highlight.Adornee = character
    highlight.Parent = character
end

local function refreshLocalOutlineColor()
    if not highlightState.active then
        return
    end

    local newColor = getOutlineColorForLocalPlayer()
    if not newColor then
        highlightState.color = nil
        for player, highlight in highlightState.highlights do
            highlight:Destroy()
        end
        table.clear(highlightState.highlights)
        return
    end

    highlightState.color = newColor

    for _, highlight in highlightState.highlights do
        highlight.OutlineColor = newColor
    end

    for _, player in Players:GetPlayers() do
        updateHighlightForPlayer(player)
    end
end

local function disableDeathMatchTransitionVisuals()
    if highlightState.playerAddedConn then
        highlightState.playerAddedConn:Disconnect()
        highlightState.playerAddedConn = nil
    end

    if highlightState.playerRemovingConn then
        highlightState.playerRemovingConn:Disconnect()
        highlightState.playerRemovingConn = nil
    end

    for player, connections in highlightState.playerConnections do
        for _, connection in connections do
            connection:Disconnect()
        end
    end
    table.clear(highlightState.playerConnections)

    for player, highlight in highlightState.highlights do
        highlight:Destroy()
    end
    table.clear(highlightState.highlights)

    highlightState.active = false
    highlightState.color = nil
end

local function trackPlayerForHighlights(targetPlayer: Player)
    if targetPlayer == localPlayer then
        return
    end

    clearConnectionsForPlayer(targetPlayer)

    local connections: HighlightConnections = {}

    connections[#connections + 1] = targetPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        updateHighlightForPlayer(targetPlayer)
    end)

    connections[#connections + 1] = targetPlayer.CharacterAdded:Connect(function()
        task.defer(function()
            updateHighlightForPlayer(targetPlayer)
        end)
    end)

    connections[#connections + 1] = targetPlayer.CharacterRemoving:Connect(function()
        removeHighlightForPlayer(targetPlayer)
    end)

    highlightState.playerConnections[targetPlayer] = connections

    updateHighlightForPlayer(targetPlayer)
end

local function enableDeathMatchTransitionVisuals()
    if highlightState.active then
        refreshLocalOutlineColor()
        return
    end

    local outlineColor = getOutlineColorForLocalPlayer()
    if not outlineColor then
        disableDeathMatchTransitionVisuals()
        return
    end

    highlightState.active = true
    highlightState.color = outlineColor

    for _, player in Players:GetPlayers() do
        trackPlayerForHighlights(player)
    end

    highlightState.playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if highlightState.active then
            trackPlayerForHighlights(player)
        end
    end)

    highlightState.playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        clearConnectionsForPlayer(player)
        removeHighlightForPlayer(player)
    end)

    refreshLocalOutlineColor()
end

local function playDeathMatchCameraSequence()
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local originalFov = camera.FieldOfView
    local zoomOutFov = math.clamp(originalFov + 25, 5, 120)

    local zoomOutTween = TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        FieldOfView = zoomOutFov,
    })
    zoomOutTween:Play()

    task.delay(0.3, function()
        local activeCamera = Workspace.CurrentCamera
        if activeCamera ~= camera then
            return
        end

        local zoomInTween = TweenService:Create(camera, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
            FieldOfView = originalFov,
        })
        zoomInTween:Play()
    end)
end

local function stopDeathMatchTransition()
    if transitionState.active then
        transitionState.token += 1
        transitionState.active = false
    end

    disableDeathMatchTransitionVisuals()
end

local function startDeathMatchTransition(duration: number?)
    transitionState.token += 1
    transitionState.active = true
    local currentToken = transitionState.token

    enableDeathMatchTransitionVisuals()
    playDeathMatchCameraSequence()

    local delayTime = duration or 3
    task.delay(delayTime, function()
        if transitionState.active and transitionState.token == currentToken then
            stopDeathMatchTransition()
        end
    end)
end

localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    refreshLocalOutlineColor()
end)

local function resetFrameVisual()
    statusFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
    frameStroke.Color = Color3.fromRGB(120, 135, 200)
    frameStroke.Transparency = 0.35
    statusFrame.Position = baseFramePosition
    statusLabel.TextColor3 = defaultColor
end

local function stopFlash()
    if flashConnection then
        flashConnection:Disconnect()
        flashConnection = nil
    end

    statusLabel.TextColor3 = matchColor
    labelStroke.Color = Color3.fromRGB(20, 20, 35)
    labelStroke.Transparency = 0.3
end

local function startFlash()
    stopFlash()

    labelStroke.Color = Color3.fromRGB(255, 110, 110)
    labelStroke.Transparency = 0

    flashConnection = RunService.RenderStepped:Connect(function()
        local timeScale = math.clamp(currentRemaining / 30, 0, 1)
        local frequency = 3 + (1 - timeScale) * 6
        local pulse = math.abs(math.sin(os.clock() * frequency))
        local green = 60 + math.floor(140 * (1 - pulse))
        statusLabel.TextColor3 = Color3.fromRGB(255, green, green)
    end)
end

local function stopShake()
    if shakeConnection then
        shakeConnection:Disconnect()
        shakeConnection = nil
    end

    statusFrame.Position = baseFramePosition
    statusFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
    frameStroke.Color = Color3.fromRGB(120, 135, 200)
    frameStroke.Transparency = 0.35
    statusLabel.TextColor3 = defaultColor
end

local function startDeathMatchEffect()
    stopFlash()
    stopShake()

    statusFrame.BackgroundColor3 = deathMatchBackground
    frameStroke.Color = deathMatchStroke
    frameStroke.Transparency = 0

    shakeConnection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local amplitude = 3 + math.abs(math.sin(now * 3)) * 5
        local offsetX = math.sin(now * 12) * amplitude
        local offsetY = math.cos(now * 9) * amplitude * 0.6
        statusFrame.Position = baseFramePosition + UDim2.fromOffset(offsetX, offsetY)

        local pulse = (math.sin(now * 6) + 1) / 2
        local colorOffset = math.floor(40 * pulse)
        statusLabel.TextColor3 = Color3.fromRGB(255, 90 + colorOffset, 90 + colorOffset)
    end)
end

local function hideStatus()
    stopFlash()
    stopShake()
    stopDeathMatchTransition()
    statusFrame.Visible = false
    statusLabel.Text = ""
end

local function formatCountdown(seconds: number): string
    if seconds <= 0 then
        return "Match starting..."
    end
    return string.format("Starting in %ds", seconds)
end

local function formatTimer(seconds: number): string
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    return string.format("%d:%02d", minutes, remainingSeconds)
end

statusRemote.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then
        return
    end

    local action = payload.action
    if action == "PrepCountdown" then
        currentRemaining = tonumber(payload.remaining) or 0
        stopShake()
        stopFlash()
        resetFrameVisual()
        statusFrame.Visible = true
        statusLabel.TextColor3 = countdownColor
        statusLabel.Text = formatCountdown(currentRemaining)
    elseif action == "MatchTimer" then
        currentRemaining = math.max(0, math.floor(tonumber(payload.remaining) or 0))
        statusFrame.Visible = true
        resetFrameVisual()
        statusLabel.TextColor3 = matchColor
        statusLabel.Text = formatTimer(currentRemaining)

        if currentRemaining <= 30 then
            startFlash()
        else
            stopFlash()
        end
    elseif action == "DeathMatchTransition" then
        stopFlash()
        stopShake()
        statusFrame.Visible = true
        statusFrame.BackgroundColor3 = deathMatchBackground
        frameStroke.Color = deathMatchStroke
        frameStroke.Transparency = 0
        statusLabel.TextColor3 = matchColor
        statusLabel.Text = "Death Match"

        local duration = tonumber(payload.duration) or 3
        startDeathMatchTransition(duration)
    elseif action == "DeathMatch" then
        local isActive = payload.active == nil or payload.active
        if isActive then
            stopDeathMatchTransition()
            statusFrame.Visible = true
            statusLabel.Text = "Death Match"
            startDeathMatchEffect()
        else
            stopShake()
            stopFlash()
            stopDeathMatchTransition()
            resetFrameVisual()
            statusFrame.Visible = false
        end
    elseif action == "RoundEnded" then
        hideStatus()
    end
end)
