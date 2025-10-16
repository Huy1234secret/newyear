--!strict
-- Place this LocalScript in StarterPlayerScripts so each player can see match updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

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

local isTouchDevice = UserInputService.TouchEnabled

local DEFAULT_BACKGROUND_COLOR = Color3.fromRGB(28, 32, 45)
local DEFAULT_BACKGROUND_TRANSPARENCY = 0.15
local DEFAULT_TEXT_SIZE = if isTouchDevice then 22 else 26
local EMPHASIZED_TEXT_SIZE = if isTouchDevice then 28 else 32

local DEFAULT_CURSOR_IMAGE_ASSET = ""
local GEAR_CURSOR_IMAGE_ASSET = "rbxassetid://9925913476"
local currentCursorImageAsset = DEFAULT_CURSOR_IMAGE_ASSET
local DEFAULT_WALK_SPEED = 16

local energyBarFill: Frame? = nil
local energyTextLabel: TextLabel? = nil
local sprintButton: TextButton? = nil
local centerCursorImage: ImageLabel? = nil

local existingGui = playerGui:FindFirstChild("PVPStatusGui")
if existingGui then
    existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PVPStatusGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local statusFrame = Instance.new("Frame")
statusFrame.Name = "StatusFrame"
statusFrame.Size = UDim2.fromOffset(isTouchDevice and 220 or 260, isTouchDevice and 52 or 56)
statusFrame.Position = UDim2.new(0.5, 0, 0, 32)
statusFrame.AnchorPoint = Vector2.new(0.5, 0)
statusFrame.BackgroundColor3 = DEFAULT_BACKGROUND_COLOR
statusFrame.BackgroundTransparency = DEFAULT_BACKGROUND_TRANSPARENCY
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
statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
statusLabel.Position = UDim2.fromScale(0.5, 0.5)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = ""
statusLabel.TextSize = DEFAULT_TEXT_SIZE
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

local sprintContainer = Instance.new("Frame")
sprintContainer.Name = "SprintEnergyContainer"
sprintContainer.Size = UDim2.new(1, 0, 0, 48)
sprintContainer.Position = UDim2.new(0.5, 0, 1, 0)
sprintContainer.AnchorPoint = Vector2.new(0.5, 1)
sprintContainer.BackgroundTransparency = 1
sprintContainer.ZIndex = 5
sprintContainer.Parent = screenGui

local sprintPadding = Instance.new("UIPadding")
sprintPadding.PaddingLeft = UDim.new(0, isTouchDevice and 24 or 32)
sprintPadding.PaddingRight = UDim.new(0, isTouchDevice and 24 or 32)
sprintPadding.PaddingBottom = UDim.new(0, 12)
sprintPadding.Parent = sprintContainer

local sprintBackground = Instance.new("Frame")
sprintBackground.Name = "EnergyBackground"
sprintBackground.Size = UDim2.new(1, 0, 1, -12)
sprintBackground.Position = UDim2.new(0, 0, 0, 0)
sprintBackground.BackgroundColor3 = Color3.fromRGB(20, 24, 35)
sprintBackground.BackgroundTransparency = 0.2
sprintBackground.Parent = sprintContainer

local sprintBackgroundCorner = Instance.new("UICorner")
sprintBackgroundCorner.CornerRadius = UDim.new(0, 14)
sprintBackgroundCorner.Parent = sprintBackground

local sprintBackgroundStroke = Instance.new("UIStroke")
sprintBackgroundStroke.Thickness = 1.5
sprintBackgroundStroke.Transparency = 0.35
sprintBackgroundStroke.Color = Color3.fromRGB(80, 100, 150)
sprintBackgroundStroke.Parent = sprintBackground

local energyFillContainer = Instance.new("Frame")
energyFillContainer.Name = "EnergyFill"
energyFillContainer.AnchorPoint = Vector2.new(0, 0.5)
energyFillContainer.Position = UDim2.new(0, 8, 0.5, 0)
energyFillContainer.Size = UDim2.new(1, isTouchDevice and -100 or -120, 0, isTouchDevice and 16 or 18)
energyFillContainer.BackgroundTransparency = 1
energyFillContainer.ClipsDescendants = true
energyFillContainer.Parent = sprintBackground

local energyFillBackground = Instance.new("Frame")
energyFillBackground.Name = "EnergyFillBackground"
energyFillBackground.Size = UDim2.new(1, 0, 1, 0)
energyFillBackground.BackgroundColor3 = Color3.fromRGB(45, 52, 70)
energyFillBackground.BackgroundTransparency = 0.4
energyFillBackground.Parent = energyFillContainer

local energyFillBackgroundCorner = Instance.new("UICorner")
energyFillBackgroundCorner.CornerRadius = UDim.new(0, 9)
energyFillBackgroundCorner.Parent = energyFillBackground

energyBarFill = Instance.new("Frame")
energyBarFill.Name = "EnergyFillValue"
energyBarFill.AnchorPoint = Vector2.new(0, 0.5)
energyBarFill.Position = UDim2.new(0, 0, 0.5, 0)
energyBarFill.Size = UDim2.new(1, 0, 1, 0)
energyBarFill.BackgroundColor3 = Color3.fromRGB(80, 190, 255)
energyBarFill.Parent = energyFillBackground

local energyFillCorner = Instance.new("UICorner")
energyFillCorner.CornerRadius = UDim.new(0, 9)
energyFillCorner.Parent = energyBarFill

local energyFillGradient = Instance.new("UIGradient")
energyFillGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 190, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 240, 200)),
})
energyFillGradient.Parent = energyBarFill

energyTextLabel = Instance.new("TextLabel")
energyTextLabel.Name = "EnergyText"
energyTextLabel.AnchorPoint = Vector2.new(1, 0.5)
energyTextLabel.Position = UDim2.new(1, -12, 0.5, 0)
energyTextLabel.Size = UDim2.new(0, 96, 0, 24)
energyTextLabel.BackgroundTransparency = 1
energyTextLabel.Font = Enum.Font.GothamSemibold
energyTextLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
energyTextLabel.TextScaled = false
energyTextLabel.TextSize = isTouchDevice and 16 or 18
energyTextLabel.TextXAlignment = Enum.TextXAlignment.Right
energyTextLabel.TextYAlignment = Enum.TextYAlignment.Center
energyTextLabel.Text = "Energy 100%"
energyTextLabel.Parent = sprintBackground

centerCursorImage = Instance.new("ImageLabel")
centerCursorImage.Name = "ShiftLockCursor"
centerCursorImage.BackgroundTransparency = 1
centerCursorImage.AnchorPoint = Vector2.new(0.5, 0.5)
centerCursorImage.Position = UDim2.fromScale(0.5, 0.5)
centerCursorImage.Size = UDim2.fromOffset(isTouchDevice and 40 or 48, isTouchDevice and 40 or 48)
centerCursorImage.Image = GEAR_CURSOR_IMAGE_ASSET
centerCursorImage.ZIndex = 50
centerCursorImage.Visible = false
centerCursorImage.Parent = screenGui

if isTouchDevice then
    sprintButton = Instance.new("TextButton")
    sprintButton.Name = "SprintToggleButton"
    sprintButton.AnchorPoint = Vector2.new(1, 1)
    sprintButton.Position = UDim2.new(1, -32, 1, -100)
    sprintButton.Size = UDim2.fromOffset(130, 52)
    sprintButton.BackgroundColor3 = Color3.fromRGB(40, 48, 65)
    sprintButton.AutoButtonColor = false
    sprintButton.Text = "Sprint"
    sprintButton.TextSize = 18
    sprintButton.Font = Enum.Font.GothamSemibold
    sprintButton.TextColor3 = Color3.fromRGB(210, 235, 255)
    sprintButton.ZIndex = 20
    sprintButton.Parent = screenGui

    local sprintButtonCorner = Instance.new("UICorner")
    sprintButtonCorner.CornerRadius = UDim.new(0, 14)
    sprintButtonCorner.Parent = sprintButton
end
local defaultColor = statusLabel.TextColor3
local countdownColor = Color3.fromRGB(245, 245, 255)
local matchColor = Color3.fromRGB(210, 235, 255)
local deathMatchBackground = Color3.fromRGB(60, 10, 10)
local deathMatchStroke = Color3.fromRGB(255, 90, 90)
local highlightStyles = {
    Spectate = {
        outlineColor = Color3.fromRGB(255, 255, 255),
        fillColor = Color3.fromRGB(255, 255, 255),
        fillTransparency = 0.5,
    },
    DeathMatch = {
        outlineColor = Color3.fromRGB(255, 0, 0),
        fillColor = Color3.fromRGB(255, 0, 0),
        fillTransparency = 0.5,
    },
}

local baseFramePosition = statusFrame.Position
local baseLabelPosition = statusLabel.Position
local currentRemaining = 0
local flashConnection: RBXScriptConnection? = nil
local shakeConnection: RBXScriptConnection? = nil

local transitionState = {
    active = false,
    token = 0,
}

type HighlightConnections = {RBXScriptConnection}

type HighlightStyle = {
    outlineColor: Color3,
    fillColor: Color3,
    fillTransparency: number,
}

local highlightState = {
    active = false,
    context = nil :: string?,
    style = nil :: HighlightStyle?,
    highlights = {} :: {[Player]: Highlight},
    playerConnections = {} :: {[Player]: HighlightConnections},
    playerAddedConn = nil :: RBXScriptConnection?,
    playerRemovingConn = nil :: RBXScriptConnection?,
}

local deathMatchHighlightActive = false

type SprintState = {
    energy: number,
    isSprinting: boolean,
    sprintIntent: boolean,
    keyboardIntent: boolean,
    touchIntent: boolean,
    rechargeBlockedUntil: number,
    originalWalkSpeed: number,
    speedTween: Tween?,
    cameraTween: Tween?,
    originalCameraFov: number?,
}

local MAX_SPRINT_ENERGY = 100
local SPRINT_DRAIN_RATE = 10
local SPRINT_RECHARGE_RATE = 20
local SPRINT_RECHARGE_DELAY = 2
local SPRINT_SPEED = 28
local SPRINT_TWEEN_TIME = 1
local SPRINT_FOV_OFFSET = 8

local SPRINT_BUTTON_DEFAULT_COLOR = Color3.fromRGB(40, 48, 65)
local SPRINT_BUTTON_ACTIVE_COLOR = Color3.fromRGB(80, 190, 255)
local SPRINT_BUTTON_DISABLED_COLOR = Color3.fromRGB(70, 76, 90)

local sprintState: SprintState = {
    energy = MAX_SPRINT_ENERGY,
    isSprinting = false,
    sprintIntent = false,
    keyboardIntent = false,
    touchIntent = false,
    rechargeBlockedUntil = 0,
    originalWalkSpeed = DEFAULT_WALK_SPEED,
    speedTween = nil,
    cameraTween = nil,
    originalCameraFov = nil,
}

local currentHumanoid: Humanoid? = nil
local humanoidSpeedChangedConn: RBXScriptConnection? = nil

local mouse = if UserInputService.TouchEnabled then nil else localPlayer:GetMouse()
local applyingMouseIcon = false

type GearConnections = {
    equipped: RBXScriptConnection?,
    unequipped: RBXScriptConnection?,
    ancestry: RBXScriptConnection?,
    destroying: RBXScriptConnection?,
}

type GearTrackingInfo = {
    tool: Tool,
    isEquipped: boolean,
    connections: GearConnections,
}

local trackedGearTools: {[Tool]: GearTrackingInfo} = {}
local equippedGearCount = 0
local currentBackpack: Backpack? = nil
local backpackConnections: {RBXScriptConnection} = {}
local characterGearConn: RBXScriptConnection? = nil

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

local function getHighlightStyleForContext(context: string?): HighlightStyle?
    if not context then
        return nil
    end

    if context == "Spectate" then
        local team = localPlayer.Team
        if team and team.Name == "Spectate" then
            return highlightStyles.Spectate
        end
    elseif context == "DeathMatch" then
        if localPlayer.Neutral then
            return highlightStyles.DeathMatch
        end
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
        and highlightState.style ~= nil
        and targetPlayer.Neutral

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
        highlight.Name = "DeathMatchTransitionHighlight"
        highlight.FillTransparency = 1
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlightState.highlights[targetPlayer] = highlight
    end

    local style = highlightState.style or highlightStyles.DeathMatch
    highlight.OutlineColor = style.outlineColor
    highlight.FillColor = style.fillColor
    highlight.FillTransparency = style.fillTransparency
    highlight.OutlineTransparency = 0
    highlight.Adornee = character
    highlight.Parent = character
end

local function refreshHighlightStyle()
    if not highlightState.active then
        return
    end

    local newStyle = getHighlightStyleForContext(highlightState.context)
    if not newStyle then
        disableHighlights()
        updateHighlightActivation()
        return
    end

    highlightState.style = newStyle

    for _, highlight in highlightState.highlights do
        highlight.OutlineColor = newStyle.outlineColor
        highlight.FillColor = newStyle.fillColor
        highlight.FillTransparency = newStyle.fillTransparency
    end

    for _, player in Players:GetPlayers() do
        updateHighlightForPlayer(player)
    end
end

local function disableHighlights()
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
    highlightState.context = nil
    highlightState.style = nil
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

    connections[#connections + 1] = targetPlayer:GetPropertyChangedSignal("Neutral"):Connect(function()
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

local function enableHighlights(context: string)
    if highlightState.active and highlightState.context == context then
        highlightState.style = getHighlightStyleForContext(context)
        refreshHighlightStyle()
        return
    end

    disableHighlights()

    local style = getHighlightStyleForContext(context)
    if not style then
        return
    end

    highlightState.context = context
    highlightState.active = true
    highlightState.style = style

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

    refreshHighlightStyle()
end

local function updateHighlightActivation()
    local desiredContext: string? = nil

    local team = localPlayer.Team
    if team and team.Name == "Spectate" then
        desiredContext = "Spectate"
    elseif deathMatchHighlightActive and localPlayer.Neutral then
        desiredContext = "DeathMatch"
    end

    if desiredContext then
        enableHighlights(desiredContext)
    else
        disableHighlights()
    end
end

local function updateSprintButtonState()
    if not sprintButton then
        return
    end

    local hasEnergy = sprintState.energy > 0
    local buttonActive = sprintState.touchIntent

    if not hasEnergy and not buttonActive then
        sprintButton.Text = "Rest"
    elseif buttonActive then
        sprintButton.Text = "Unsprint"
    else
        sprintButton.Text = "Sprint"
    end

    if not hasEnergy then
        sprintButton.BackgroundColor3 = SPRINT_BUTTON_DISABLED_COLOR
        sprintButton.TextColor3 = Color3.fromRGB(200, 210, 225)
    elseif buttonActive then
        sprintButton.BackgroundColor3 = SPRINT_BUTTON_ACTIVE_COLOR
        sprintButton.TextColor3 = Color3.fromRGB(20, 30, 40)
    else
        sprintButton.BackgroundColor3 = SPRINT_BUTTON_DEFAULT_COLOR
        sprintButton.TextColor3 = Color3.fromRGB(210, 235, 255)
    end
end

local function recomputeSprintIntent()
    sprintState.sprintIntent = sprintState.keyboardIntent or sprintState.touchIntent
    updateSprintButtonState()
end

local function updateEnergyUI()
    if not energyBarFill or not energyTextLabel then
        return
    end

    local normalized = math.clamp(sprintState.energy / MAX_SPRINT_ENERGY, 0, 1)
    if normalized <= 0 then
        energyBarFill.Visible = false
    else
        energyBarFill.Visible = true
        energyBarFill.Size = UDim2.new(normalized, 0, 1, 0)
    end

    local percent = math.clamp(math.floor(normalized * 100 + 0.5), 0, 100)
    energyTextLabel.Text = string.format("Energy %d%%", percent)

    if percent <= 15 then
        energyTextLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    elseif sprintState.isSprinting then
        energyTextLabel.TextColor3 = Color3.fromRGB(180, 255, 220)
    else
        energyTextLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
    end

    updateSprintButtonState()
end

local function tweenHumanoidSpeed(targetSpeed: number, instant: boolean)
    local humanoid = currentHumanoid
    if not humanoid then
        return
    end

    if sprintState.speedTween then
        sprintState.speedTween:Cancel()
        sprintState.speedTween = nil
    end

    if instant then
        humanoid.WalkSpeed = targetSpeed
        return
    end

    local tween = TweenService:Create(humanoid, TweenInfo.new(SPRINT_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        WalkSpeed = targetSpeed,
    })
    sprintState.speedTween = tween
    tween.Completed:Connect(function()
        if sprintState.speedTween == tween then
            sprintState.speedTween = nil
        end
    end)
    tween:Play()
end

local function tweenCameraFov(targetFov: number, instant: boolean)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    if sprintState.cameraTween then
        sprintState.cameraTween:Cancel()
        sprintState.cameraTween = nil
    end

    if instant then
        camera.FieldOfView = targetFov
        return
    end

    local tween = TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FieldOfView = targetFov,
    })
    sprintState.cameraTween = tween
    tween.Completed:Connect(function()
        if sprintState.cameraTween == tween then
            sprintState.cameraTween = nil
        end
    end)
    tween:Play()
end

local function stopSprinting(instant: boolean)
    local wasSprinting = sprintState.isSprinting
    sprintState.isSprinting = false

    if wasSprinting then
        sprintState.rechargeBlockedUntil = os.clock() + SPRINT_RECHARGE_DELAY
    end

    if currentHumanoid then
        tweenHumanoidSpeed(sprintState.originalWalkSpeed, instant)
    end

    if sprintState.originalCameraFov then
        tweenCameraFov(sprintState.originalCameraFov, instant)
        sprintState.originalCameraFov = nil
    end

    updateEnergyUI()
end

local function startSprinting()
    if sprintState.isSprinting then
        return
    end

    if sprintState.energy <= 0 then
        return
    end

    local humanoid = currentHumanoid
    if not humanoid then
        return
    end

    sprintState.isSprinting = true
    local baselineSpeed = humanoid.WalkSpeed
    if math.abs(baselineSpeed - SPRINT_SPEED) < 0.001 then
        baselineSpeed = DEFAULT_WALK_SPEED
    elseif baselineSpeed <= 0 then
        baselineSpeed = DEFAULT_WALK_SPEED
    end
    sprintState.originalWalkSpeed = baselineSpeed

    tweenHumanoidSpeed(SPRINT_SPEED, false)

    local camera = Workspace.CurrentCamera
    if camera then
        if not sprintState.originalCameraFov then
            sprintState.originalCameraFov = camera.FieldOfView
        end
        local targetFov = math.clamp(sprintState.originalCameraFov + SPRINT_FOV_OFFSET, 5, 120)
        tweenCameraFov(targetFov, false)
    end

    updateEnergyUI()
end

local function resetSprintState()
    stopSprinting(true)
    sprintState.keyboardIntent = false
    sprintState.touchIntent = false
    recomputeSprintIntent()
    sprintState.energy = MAX_SPRINT_ENERGY
    sprintState.rechargeBlockedUntil = 0
    sprintState.speedTween = nil
    sprintState.cameraTween = nil
    sprintState.originalCameraFov = nil
    sprintState.originalWalkSpeed = DEFAULT_WALK_SPEED
    updateEnergyUI()
end

local function applyDesktopCursorIcon()
    if not mouse then
        return
    end

    local iconAsset = currentCursorImageAsset
    if mouse.Icon ~= iconAsset then
        applyingMouseIcon = true
        mouse.Icon = iconAsset
        applyingMouseIcon = false
    end

    if centerCursorImage then
        centerCursorImage.Image = if iconAsset ~= "" then iconAsset else ""
    end
end

local function updateCenterCursorVisibility()
    if not centerCursorImage then
        return
    end

    local shouldShow = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
        and currentCursorImageAsset ~= ""
    centerCursorImage.Visible = shouldShow
    if shouldShow then
        centerCursorImage.Image = currentCursorImageAsset
    end
end

local function setCursorAsset(assetId: string)
    if currentCursorImageAsset == assetId then
        return
    end

    currentCursorImageAsset = assetId

    if mouse then
        applyDesktopCursorIcon()
    end

    updateCenterCursorVisibility()
end

local function updateCursorForGearState()
    if equippedGearCount > 0 then
        setCursorAsset(GEAR_CURSOR_IMAGE_ASSET)
    else
        setCursorAsset(DEFAULT_CURSOR_IMAGE_ASSET)
    end
end

local function handleGearEquipped(info: GearTrackingInfo)
    if info.isEquipped then
        return
    end

    info.isEquipped = true
    equippedGearCount += 1
    updateCursorForGearState()
end

local function handleGearUnequipped(info: GearTrackingInfo)
    if not info.isEquipped then
        return
    end

    info.isEquipped = false
    if equippedGearCount > 0 then
        equippedGearCount -= 1
    end
    updateCursorForGearState()
end

local function clearBackpackConnections()
    for _, connection in backpackConnections do
        connection:Disconnect()
    end
    table.clear(backpackConnections)
end

local function untrackGearTool(tool: Tool)
    local tracked = trackedGearTools[tool]
    if not tracked then
        return
    end

    trackedGearTools[tool] = nil
    handleGearUnequipped(tracked)

    for _, connection in tracked.connections do
        if connection then
            connection:Disconnect()
        end
    end
end

local function isPVPGear(instance: Instance): boolean
    if not instance:IsA("Tool") then
        return false
    end

    return instance:GetAttribute("PVPGenerated") == true
end

local function trackGearTool(tool: Tool)
    if trackedGearTools[tool] or not isPVPGear(tool) then
        return
    end

    local info: GearTrackingInfo = {
        tool = tool,
        isEquipped = false,
        connections = {} :: GearConnections,
    }

    trackedGearTools[tool] = info

    info.connections.equipped = tool.Equipped:Connect(function()
        handleGearEquipped(info)
    end)

    info.connections.unequipped = tool.Unequipped:Connect(function()
        handleGearUnequipped(info)
    end)

    info.connections.ancestry = tool.AncestryChanged:Connect(function(_, parent)
        if parent == localPlayer.Character then
            handleGearEquipped(info)
        else
            handleGearUnequipped(info)
            if parent == nil then
                untrackGearTool(tool)
            end
        end
    end)

    info.connections.destroying = tool.Destroying:Connect(function()
        untrackGearTool(tool)
    end)

    if tool.Parent == localPlayer.Character then
        handleGearEquipped(info)
    else
        updateCursorForGearState()
    end
end

local function trackToolsIn(container: Instance)
    for _, child in container:GetChildren() do
        if child:IsA("Tool") then
            trackGearTool(child)
        end
    end
end

local function watchBackpack(backpack: Backpack?)
    if currentBackpack == backpack then
        return
    end

    clearBackpackConnections()
    currentBackpack = backpack

    if not backpack then
        updateCursorForGearState()
        return
    end

    trackToolsIn(backpack)

    local addedConn = backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            trackGearTool(child)
        end
    end)
    table.insert(backpackConnections, addedConn)
end

local function watchCharacterTools(character: Model)
    if characterGearConn then
        characterGearConn:Disconnect()
        characterGearConn = nil
    end

    trackToolsIn(character)

    characterGearConn = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            trackGearTool(child)
        end
    end)
end

local function initializeBackpackTracking()
    local backpack = localPlayer:FindFirstChildOfClass("Backpack")
    watchBackpack(backpack)

    localPlayer.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            watchBackpack(child)
        end
    end)

    localPlayer.ChildRemoved:Connect(function(child)
        if child:IsA("Backpack") then
            watchBackpack(nil)
        end
    end)
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

    updateHighlightActivation()
end

local function startDeathMatchTransition(duration: number?)
    transitionState.token += 1
    transitionState.active = true
    local currentToken = transitionState.token

    deathMatchHighlightActive = true
    updateHighlightActivation()
    playDeathMatchCameraSequence()

    local delayTime = duration or 3
    task.delay(delayTime, function()
        if transitionState.active and transitionState.token == currentToken then
            stopDeathMatchTransition()
        end
    end)
end

localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    updateHighlightActivation()
end)

localPlayer:GetPropertyChangedSignal("Neutral"):Connect(function()
    updateHighlightActivation()
end)

initializeBackpackTracking()
updateCursorForGearState()

if mouse then
    UserInputService.MouseIconEnabled = true
    applyDesktopCursorIcon()

    mouse:GetPropertyChangedSignal("Icon"):Connect(function()
        if not applyingMouseIcon then
            applyDesktopCursorIcon()
        end
    end)
end

UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
    if mouse then
        applyDesktopCursorIcon()
    end
    updateCenterCursorVisibility()
end)

UserInputService.WindowFocusReleased:Connect(function()
    sprintState.keyboardIntent = false
    sprintState.touchIntent = false
    recomputeSprintIntent()
    stopSprinting(true)
end)

updateCenterCursorVisibility()
updateEnergyUI()
updateHighlightActivation()

local function onHumanoidAdded(humanoid: Humanoid)
    if humanoidSpeedChangedConn then
        humanoidSpeedChangedConn:Disconnect()
        humanoidSpeedChangedConn = nil
    end

    currentHumanoid = humanoid
    if humanoid.WalkSpeed <= 0 then
        humanoid.WalkSpeed = DEFAULT_WALK_SPEED
    end

    local currentSpeed = humanoid.WalkSpeed
    if math.abs(currentSpeed - SPRINT_SPEED) < 0.001 then
        currentSpeed = DEFAULT_WALK_SPEED
    end
    sprintState.originalWalkSpeed = currentSpeed

    humanoidSpeedChangedConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not sprintState.isSprinting then
            local newSpeed = humanoid.WalkSpeed
            if newSpeed <= 0 then
                newSpeed = DEFAULT_WALK_SPEED
            elseif math.abs(newSpeed - SPRINT_SPEED) < 0.001 then
                newSpeed = DEFAULT_WALK_SPEED
            end

            sprintState.originalWalkSpeed = newSpeed
        end
    end)

    humanoid.Died:Connect(function()
        sprintState.keyboardIntent = false
        sprintState.touchIntent = false
        recomputeSprintIntent()
        stopSprinting(true)
    end)
end

local function onCharacterAdded(character: Model)
    resetSprintState()
    watchCharacterTools(character)

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        onHumanoidAdded(humanoid)
    else
        local pendingConn: RBXScriptConnection?
        pendingConn = character.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then
                if pendingConn then
                    pendingConn:Disconnect()
                    pendingConn = nil
                end
                onHumanoidAdded(child)
            end
        end)
    end
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)

localPlayer.CharacterRemoving:Connect(function()
    sprintState.keyboardIntent = false
    sprintState.touchIntent = false
    recomputeSprintIntent()
    stopSprinting(true)
    if humanoidSpeedChangedConn then
        humanoidSpeedChangedConn:Disconnect()
        humanoidSpeedChangedConn = nil
    end
    currentHumanoid = nil
    if characterGearConn then
        characterGearConn:Disconnect()
        characterGearConn = nil
    end
    updateCursorForGearState()
end)

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
else
    resetSprintState()
end

local function toggleKeyboardSprintIntent()
    if sprintState.keyboardIntent then
        sprintState.keyboardIntent = false
        recomputeSprintIntent()
        if not sprintState.sprintIntent then
            stopSprinting(false)
        end
    else
        sprintState.keyboardIntent = true
        recomputeSprintIntent()
        if sprintState.energy > 0 then
            startSprinting()
        end
    end
end

local function sprintAction(_: string, inputState: Enum.UserInputState, inputObject: InputObject?): Enum.ContextActionResult
    local keyCode = if inputObject then inputObject.KeyCode else nil

    if keyCode == Enum.KeyCode.LeftControl or keyCode == Enum.KeyCode.RightControl then
        if inputState == Enum.UserInputState.Begin then
            toggleKeyboardSprintIntent()
        end
        return Enum.ContextActionResult.Sink
    elseif keyCode == Enum.KeyCode.ButtonL3 then
        if inputState == Enum.UserInputState.Begin then
            sprintState.keyboardIntent = true
            recomputeSprintIntent()
            if sprintState.energy > 0 then
                startSprinting()
            end
            return Enum.ContextActionResult.Sink
        elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
            sprintState.keyboardIntent = false
            recomputeSprintIntent()
            if not sprintState.sprintIntent then
                stopSprinting(false)
            end
            return Enum.ContextActionResult.Sink
        end
    elseif inputState == Enum.UserInputState.Begin and not inputObject then
        toggleKeyboardSprintIntent()
        return Enum.ContextActionResult.Sink
    end

    return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("SprintAction", sprintAction, true, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("SprintAction", "Sprint")
ContextActionService:SetImage("SprintAction", GEAR_CURSOR_IMAGE_ASSET)

if sprintButton then
    sprintButton.Activated:Connect(function()
        if sprintState.touchIntent then
            sprintState.touchIntent = false
            recomputeSprintIntent()
            if not sprintState.sprintIntent then
                stopSprinting(false)
            end
        else
            if sprintState.energy <= 0 then
                updateSprintButtonState()
                return
            end
            sprintState.touchIntent = true
            recomputeSprintIntent()
            if not sprintState.isSprinting then
                startSprinting()
            end
        end
    end)
end

RunService.Heartbeat:Connect(function(deltaTime)
    local dt = math.max(deltaTime, 0)
    local now = os.clock()

    if sprintState.sprintIntent and not sprintState.isSprinting and sprintState.energy > 0 then
        startSprinting()
    end

    if sprintState.isSprinting then
        sprintState.energy = math.max(0, sprintState.energy - dt * SPRINT_DRAIN_RATE)
        sprintState.rechargeBlockedUntil = now + SPRINT_RECHARGE_DELAY
        if sprintState.energy <= 0 then
            sprintState.energy = 0
            if sprintState.touchIntent then
                sprintState.touchIntent = false
                recomputeSprintIntent()
            end
            stopSprinting(false)
        end
    elseif sprintState.energy < MAX_SPRINT_ENERGY and now >= sprintState.rechargeBlockedUntil then
        sprintState.energy = math.min(MAX_SPRINT_ENERGY, sprintState.energy + dt * SPRINT_RECHARGE_RATE)
    end

    updateEnergyUI()

    if mouse and not applyingMouseIcon and mouse.Icon ~= currentCursorImageAsset then
        applyDesktopCursorIcon()
    end
end)

local function resetFrameVisual()
    statusFrame.BackgroundColor3 = DEFAULT_BACKGROUND_COLOR
    statusFrame.BackgroundTransparency = DEFAULT_BACKGROUND_TRANSPARENCY
    frameStroke.Color = Color3.fromRGB(120, 135, 200)
    frameStroke.Transparency = 0.35
    statusFrame.Position = baseFramePosition
    statusLabel.TextColor3 = defaultColor
    statusLabel.TextSize = DEFAULT_TEXT_SIZE
    statusLabel.Position = baseLabelPosition
    statusLabel.Rotation = 0
    labelStroke.Transparency = 0.3
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
    statusLabel.Position = baseLabelPosition
    statusLabel.Rotation = 0
    statusLabel.TextColor3 = defaultColor
    statusLabel.TextSize = DEFAULT_TEXT_SIZE
end

local function startDeathMatchEffect()
    stopFlash()
    stopShake()

    statusFrame.BackgroundColor3 = deathMatchBackground
    frameStroke.Color = deathMatchStroke
    frameStroke.Transparency = 0
    statusFrame.BackgroundTransparency = 1
    statusLabel.TextSize = EMPHASIZED_TEXT_SIZE
    labelStroke.Transparency = 0

    shakeConnection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local frameMagnitude = 1 + math.abs(math.sin(now * 5)) * 1.4
        local offsetX = math.noise(now * 8, 0, 0) * frameMagnitude * 4
        local offsetY = math.noise(now * 9, 1, 0) * frameMagnitude * 3
        statusFrame.Position = baseFramePosition + UDim2.fromOffset(offsetX, offsetY)

        local textMagnitude = 0.5 + math.abs(math.sin(now * 12)) * 1.5
        local textOffsetX = math.noise(now * 20, 2, 0) * textMagnitude * 4
        local textOffsetY = math.noise(now * 18, 3, 0) * textMagnitude * 3
        statusLabel.Position = baseLabelPosition + UDim2.fromOffset(textOffsetX, textOffsetY)
        statusLabel.Rotation = math.noise(now * 14, 4, 0) * 8

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
        statusFrame.BackgroundTransparency = DEFAULT_BACKGROUND_TRANSPARENCY
        statusFrame.Visible = true
        statusLabel.TextColor3 = countdownColor
        statusLabel.TextSize = EMPHASIZED_TEXT_SIZE
        statusLabel.Text = formatCountdown(currentRemaining)
        labelStroke.Transparency = 0.1
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
        statusLabel.TextSize = EMPHASIZED_TEXT_SIZE
        statusLabel.Text = "Death Match"
        statusFrame.BackgroundTransparency = 1
        labelStroke.Transparency = 0

        local duration = tonumber(payload.duration) or 3
        deathMatchHighlightActive = true
        updateHighlightActivation()
        startDeathMatchTransition(duration)
    elseif action == "DeathMatch" then
        local isActive = payload.active == nil or payload.active
        if isActive then
            deathMatchHighlightActive = true
            stopDeathMatchTransition()
            statusFrame.Visible = true
            statusLabel.Text = "Death Match"
            startDeathMatchEffect()
        else
            deathMatchHighlightActive = false
            stopShake()
            stopFlash()
            stopDeathMatchTransition()
            resetFrameVisual()
            statusFrame.Visible = false
        end
    elseif action == "RoundEnded" then
        deathMatchHighlightActive = false
        updateHighlightActivation()
        stopDeathMatchTransition()
        stopFlash()
        stopShake()
        resetFrameVisual()
        statusFrame.Visible = true
        statusLabel.TextColor3 = countdownColor
        statusLabel.TextSize = DEFAULT_TEXT_SIZE
        statusLabel.Text = "Intermission"
        labelStroke.Transparency = 0.3
    end
end)
