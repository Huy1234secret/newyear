--!strict
-- Place this LocalScript in StarterPlayerScripts so it only runs for each player.
-- It will create an owner-only control panel button that slides in and out with animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local allowedUserIds = {
    [347735445] = true,
}

type MapDefinition = {
    id: string,
    displayName: string,
    modelName: string,
}

local mapDefinitions: {MapDefinition} = {
    {
        id = "Crossroad",
        displayName = "Crossroad",
        modelName = "Crossroad",
    },
    {
        id = "SFOTH",
        displayName = "SFOTH",
        modelName = "SFOTH",
    },
    {
        id = "ChaosCanyon",
        displayName = "Chaos Canyon",
        modelName = "ChaosCanyon",
    },
}

local mapButtonDefaultColor = Color3.fromRGB(190, 60, 60)
local mapButtonSelectedColor = Color3.fromRGB(70, 170, 95)
local mapButtonTextColor = Color3.fromRGB(255, 255, 255)

local remotesFolder = ReplicatedStorage:FindFirstChild("PVPRemotes")
if not remotesFolder then
    remotesFolder = ReplicatedStorage:WaitForChild("PVPRemotes", 5)
end

local startRoundRemote: RemoteEvent? = nil
local roundStateRemote: RemoteEvent? = nil

if remotesFolder and remotesFolder:IsA("Folder") then
    startRoundRemote = remotesFolder:FindFirstChild("StartRound") :: RemoteEvent?
    roundStateRemote = remotesFolder:FindFirstChild("RoundState") :: RemoteEvent?

    remotesFolder.ChildAdded:Connect(function(child)
        if child.Name == "StartRound" and child:IsA("RemoteEvent") then
            startRoundRemote = child
        elseif child.Name == "RoundState" and child:IsA("RemoteEvent") then
            roundStateRemote = child
        end
    end)
end

local function isGameOwner(): boolean
    if allowedUserIds[player.UserId] then
        return true
    end

    local creatorId = game.CreatorId
    local creatorType = game.CreatorType

    if creatorType == Enum.CreatorType.User then
        return player.UserId == creatorId
    elseif creatorType == Enum.CreatorType.Group then
        -- Treat the group owner (rank 255) as the "game owner"
        local success, rank = pcall(function()
            return player:GetRankInGroup(creatorId)
        end)

        return success and rank == 255
    end

    return false
end

if not isGameOwner() then
    return
end

local playerGui = player:WaitForChild("PlayerGui")

local existingScreenGui = playerGui:FindFirstChild("OwnerPanel")
if existingScreenGui then
    existingScreenGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OwnerPanel"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panelWidth = 240
local panelHeight = 200
local buttonWidth = 32

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
panel.Position = UDim2.new(0, -panelWidth + buttonWidth, 0.5, -panelHeight / 2)
panel.BackgroundColor3 = Color3.fromRGB(32, 35, 50)
panel.BorderSizePixel = 0
panel.AnchorPoint = Vector2.new(0, 0)
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 62, 85)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 35, 50))
})
gradient.Rotation = 90
gradient.Parent = panel

panel.ZIndex = 2

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0.5, 0, 0.5, 6)
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://1316045217"
shadow.ImageTransparency = 0.4
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ZIndex = 0
shadow.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0, 0)
title.Position = UDim2.new(0, 20, 0, 20)
title.Size = UDim2.new(1, -40, 0, 32)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Owner Panel"
title.TextColor3 = Color3.fromRGB(245, 245, 255)
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "ButtonContainer"
buttonContainer.Size = UDim2.new(1, -40, 0, 48)
buttonContainer.Position = UDim2.new(0, 20, 0, 80)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Parent = panel

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Vertical
buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Top
buttonLayout.Padding = UDim.new(0, 10)
buttonLayout.Parent = buttonContainer

local pvpButton = Instance.new("TextButton")
pvpButton.Name = "PVPButton"
pvpButton.Size = UDim2.new(0, 160, 0, 36)
pvpButton.BackgroundColor3 = Color3.fromRGB(94, 108, 160)
pvpButton.AutoButtonColor = false
pvpButton.Font = Enum.Font.GothamBold
pvpButton.Text = "PVP"
pvpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
pvpButton.TextSize = 18
pvpButton.TextStrokeTransparency = 0.4
pvpButton.ZIndex = 4
pvpButton.Parent = buttonContainer

local pvpButtonCorner = Instance.new("UICorner")
pvpButtonCorner.CornerRadius = UDim.new(0, 8)
pvpButtonCorner.Parent = pvpButton

local pvpButtonStroke = Instance.new("UIStroke")
pvpButtonStroke.Thickness = 1.5
pvpButtonStroke.Color = Color3.fromRGB(150, 160, 210)
pvpButtonStroke.Transparency = 0.3
pvpButtonStroke.Parent = pvpButton

local toggleButton = Instance.new("ImageButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.fromOffset(buttonWidth, 60)
toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
toggleButton.Position = UDim2.new(0, panelWidth - (buttonWidth / 2), 0.5, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(74, 87, 120)
toggleButton.AutoButtonColor = false
toggleButton.Image = "rbxassetid://4726772330"
toggleButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.ScaleType = Enum.ScaleType.Fit
toggleButton.Parent = panel

toggleButton.ZIndex = 3

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(1, 0)
buttonCorner.Parent = toggleButton

local buttonGradient = Instance.new("UIGradient")
buttonGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(101, 115, 173)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(74, 87, 120))
})
buttonGradient.Parent = toggleButton

local glow = Instance.new("UIStroke")
glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
glow.Thickness = 1.5
glow.Color = Color3.fromRGB(120, 135, 200)
glow.Transparency = 0.2
glow.Parent = toggleButton

local pvpFrame = Instance.new("Frame")
pvpFrame.Name = "PVPPanel"
pvpFrame.Size = UDim2.fromOffset(420, 260)
pvpFrame.Position = UDim2.fromScale(0.5, 0.5)
pvpFrame.AnchorPoint = Vector2.new(0.5, 0.5)
pvpFrame.BackgroundColor3 = Color3.fromRGB(32, 35, 50)
pvpFrame.Visible = false
pvpFrame.ZIndex = 5
pvpFrame.Parent = screenGui

local pvpCorner = Instance.new("UICorner")
pvpCorner.CornerRadius = UDim.new(0, 12)
pvpCorner.Parent = pvpFrame

local pvpStroke = Instance.new("UIStroke")
pvpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pvpStroke.Thickness = 2
pvpStroke.Color = Color3.fromRGB(120, 135, 200)
pvpStroke.Transparency = 0.4
pvpStroke.Parent = pvpFrame

local pvpTitle = Instance.new("TextLabel")
pvpTitle.Name = "PVPTitle"
pvpTitle.Size = UDim2.new(1, -40, 0, 40)
pvpTitle.Position = UDim2.new(0, 20, 0, 20)
pvpTitle.BackgroundTransparency = 1
pvpTitle.Font = Enum.Font.GothamBold
pvpTitle.Text = "PVP"
pvpTitle.TextColor3 = Color3.fromRGB(245, 245, 255)
pvpTitle.TextSize = 26
pvpTitle.TextXAlignment = Enum.TextXAlignment.Left
pvpTitle.ZIndex = 6
pvpTitle.Parent = pvpFrame

local mapSection = Instance.new("Frame")
mapSection.Name = "MapSection"
mapSection.Size = UDim2.new(1, -40, 0, 110)
mapSection.Position = UDim2.new(0, 20, 0, 70)
mapSection.BackgroundTransparency = 1
mapSection.ZIndex = 6
mapSection.Parent = pvpFrame

local mapHeader = Instance.new("TextLabel")
mapHeader.Name = "Header"
mapHeader.Size = UDim2.new(1, 0, 0, 24)
mapHeader.BackgroundTransparency = 1
mapHeader.Font = Enum.Font.GothamBold
mapHeader.Text = "Map"
mapHeader.TextColor3 = Color3.fromRGB(245, 245, 255)
mapHeader.TextSize = 20
mapHeader.TextXAlignment = Enum.TextXAlignment.Left
mapHeader.ZIndex = 6
mapHeader.Parent = mapSection

local mapList = Instance.new("Frame")
mapList.Name = "MapList"
mapList.Size = UDim2.new(1, 0, 0, 64)
mapList.Position = UDim2.new(0, 0, 0, 32)
mapList.BackgroundTransparency = 1
mapList.ZIndex = 6
mapList.Parent = mapSection

local mapListLayout = Instance.new("UIListLayout")
mapListLayout.FillDirection = Enum.FillDirection.Horizontal
mapListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
mapListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
mapListLayout.Padding = UDim.new(0, 12)
mapListLayout.SortOrder = Enum.SortOrder.LayoutOrder
mapListLayout.Parent = mapList

local actionContainer = Instance.new("Frame")
actionContainer.Name = "ActionContainer"
actionContainer.AnchorPoint = Vector2.new(1, 1)
actionContainer.Position = UDim2.new(1, -20, 1, -20)
actionContainer.Size = UDim2.fromOffset(200, 40)
actionContainer.BackgroundTransparency = 1
actionContainer.ZIndex = 6
actionContainer.Parent = pvpFrame

local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "MessageLabel"
messageLabel.AnchorPoint = Vector2.new(0, 1)
messageLabel.Position = UDim2.new(0, 20, 1, -72)
messageLabel.Size = UDim2.new(1, -40, 0, 20)
messageLabel.BackgroundTransparency = 1
messageLabel.Font = Enum.Font.Gotham
messageLabel.Text = ""
messageLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
messageLabel.TextSize = 16
messageLabel.TextTransparency = 1
messageLabel.TextXAlignment = Enum.TextXAlignment.Left
messageLabel.ZIndex = 6
messageLabel.Parent = pvpFrame

local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
actionLayout.Padding = UDim.new(0, 12)
actionLayout.Parent = actionContainer

local function createActionButton(name: string, text: string): TextButton
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.fromOffset(90, 36)
    button.AutoButtonColor = false
    button.BackgroundColor3 = Color3.fromRGB(94, 108, 160)
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 18
    button.ZIndex = 6
    button.Parent = actionContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(150, 160, 210)
    stroke.Transparency = 0.3
    stroke.Parent = button

    return button
end

local startButton = createActionButton("StartButton", "Start")
local cancelButton = createActionButton("CancelButton", "Cancel")

local startButtonDefaultColor = startButton.BackgroundColor3
local startButtonDisabledColor = Color3.fromRGB(70, 80, 110)

local mapButtons: {[string]: TextButton} = {}
local selectedMapId: string? = nil
local startButtonLocked = false
local startButtonLabel = startButton.Text
local messageFadeToken = 0
local messageFadeTween: Tween? = nil

local function updateStartButtonVisual()
    startButton.Text = startButtonLabel
    startButton.BackgroundColor3 = startButtonLocked and startButtonDisabledColor or startButtonDefaultColor
    startButton.Active = not startButtonLocked
    startButton.AutoButtonColor = not startButtonLocked
    startButton.TextTransparency = startButtonLocked and 0.2 or 0
end

local function setStartButtonState(isLocked: boolean, label: string?)
    startButtonLocked = isLocked
    if not isLocked then
        startButtonLabel = "Start"
    elseif label then
        startButtonLabel = label
    end
    updateStartButtonVisual()
end

local function clearMessage()
    if messageFadeTween then
        messageFadeTween:Cancel()
        messageFadeTween = nil
    end
    messageLabel.Text = ""
    messageLabel.TextTransparency = 1
end

local function showMessage(text: string, color: Color3?)
    messageFadeToken += 1
    local token = messageFadeToken

    if messageFadeTween then
        messageFadeTween:Cancel()
        messageFadeTween = nil
    end

    messageLabel.Text = text
    messageLabel.TextColor3 = color or Color3.fromRGB(255, 120, 120)
    messageLabel.TextTransparency = 0

    task.delay(3, function()
        if token ~= messageFadeToken then
            return
        end

        messageFadeTween = TweenService:Create(messageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextTransparency = 1,
        })
        messageFadeTween:Play()
    end)
end

local function updateMapButtonVisual(button: TextButton, isSelected: boolean)
    button.BackgroundColor3 = isSelected and mapButtonSelectedColor or mapButtonDefaultColor
    button.TextColor3 = mapButtonTextColor

    local stroke = button:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = isSelected and Color3.fromRGB(185, 255, 205) or Color3.fromRGB(120, 40, 40)
        stroke.Transparency = isSelected and 0 or 0.2
    end
end

local function selectMap(mapId: string)
    selectedMapId = mapId
    for id, button in mapButtons do
        updateMapButtonVisual(button, id == selectedMapId)
    end
end

for order, definition in ipairs(mapDefinitions) do
    local button = Instance.new("TextButton")
    button.Name = string.format("%sButton", definition.id)
    button.LayoutOrder = order
    button.Size = UDim2.new(0, 120, 0, 44)
    button.BackgroundColor3 = mapButtonDefaultColor
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamBold
    button.Text = definition.displayName
    button.TextColor3 = mapButtonTextColor
    button.TextSize = 18
    button.ZIndex = 6
    button.Parent = mapList

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.6
    stroke.Transparency = 0.2
    stroke.Color = Color3.fromRGB(120, 40, 40)
    stroke.Parent = button

    mapButtons[definition.id] = button
    updateMapButtonVisual(button, false)

    button.Activated:Connect(function()
        if selectedMapId == definition.id then
            return
        end

        selectMap(definition.id)
    end)
end

updateStartButtonVisual()

local opened = false
local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

local openPosition = UDim2.new(0, 20, 0.5, -panelHeight / 2)
local closedPosition = UDim2.new(0, -panelWidth + buttonWidth, 0.5, -panelHeight / 2)

local function updateToggleVisual()
    local targetRotation = opened and 180 or 0
    TweenService:Create(toggleButton, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Rotation = targetRotation
    }):Play()
end

local function tweenPanel()
    local targetPosition = opened and openPosition or closedPosition
    TweenService:Create(panel, tweenInfo, {Position = targetPosition}):Play()
end

local function animateButtonPress()
    local pressTween = TweenService:Create(toggleButton, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(buttonWidth - 4, 56)
    })
    pressTween:Play()
    pressTween.Completed:Connect(function()
        TweenService:Create(toggleButton, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(buttonWidth, 60)
        }):Play()
    end)
end

local function showPanelUI()
    pvpFrame.Visible = false
    panel.Visible = true
    opened = true
    updateToggleVisual()
    tweenPanel()
    clearMessage()
end

local function closeAllUI()
    pvpFrame.Visible = false
    panel.Visible = true
    opened = false
    updateToggleVisual()
    tweenPanel()
    clearMessage()
end

local function showPVPUI()
    panel.Visible = false
    pvpFrame.Visible = true
    clearMessage()
    updateStartButtonVisual()
end

local toggleDebounce = false
local pvpDebounce = false

local function onPVPActivated()
    if pvpDebounce then
        return
    end

    pvpDebounce = true
    showPVPUI()
    task.wait(0.15)
    pvpDebounce = false
end

pvpButton.Activated:Connect(onPVPActivated)

startButton.Activated:Connect(function()
    if startButtonLocked then
        return
    end

    if not selectedMapId then
        showMessage("Select a map to begin a round.")
        return
    end

    if not startRoundRemote then
        showMessage("PVP controls are not ready yet.")
        return
    end

    setStartButtonState(true, "Starting...")
    startRoundRemote:FireServer({
        mapId = selectedMapId,
    })
    closeAllUI()
end)

cancelButton.Activated:Connect(function()
    clearMessage()
    showPanelUI()
end)

if roundStateRemote then
    roundStateRemote.OnClientEvent:Connect(function(payload)
        if typeof(payload) == "table" then
            local state = payload.state
            if state == "Starting" then
                setStartButtonState(true, "Starting...")
            elseif state == "Active" then
                setStartButtonState(true, "In Progress")
            elseif state == "Idle" or state == "Ended" then
                setStartButtonState(false)
                clearMessage()
            elseif state == "Error" then
                setStartButtonState(false)
                if payload.message then
                    showMessage(payload.message)
                end
            end
        elseif typeof(payload) == "string" then
            if payload == "Active" then
                setStartButtonState(true, "In Progress")
            elseif payload == "Idle" then
                setStartButtonState(false)
                clearMessage()
            end
        end
    end)
end

toggleButton.Activated:Connect(function()
    if toggleDebounce then
        return
    end

    toggleDebounce = true
    opened = not opened
    updateToggleVisual()
    tweenPanel()
    animateButtonPress()

    task.wait(0.25)
    toggleDebounce = false
end)

updateToggleVisual()
tweenPanel()
